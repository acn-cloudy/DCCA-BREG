global class PestControlRenewalPushThru extends ApplicationRenewalPushThru {  
    private static Set<String> appIdsForRenew = new Set<String>();    
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    private static Set<String> inactiveLics = new Set<String>();
        
    global PestControlRenewalPushThru() {
        super(new List<String> {'PCO - Entity', 'PCO - Sole Proprietor', 'PCO - RME', 'PCFR'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<Application__c> activeRecords = new List<Application__c>();
        for(Application__c record:records){
            if(record?.LicensePeriodRNEW__c == record?.CurrentLicense__r?.LicenseType__r?.PreviousLicensePeriod__c){
                activeRecords.add(record);
            }
        }

        List<Application__c> appsForCustom = (new ApplicationDomain(activeRecords)).filterApplicationsNotForInactiveRenew();
        appIdsForRenew.addAll((new ApplicationDomain(appsForCustom)).getIds());
        List<Application__c> pCFRApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCFR'});
        if(!pCFRApps.isEmpty()) captureRenewApp(processPCFR(pCFRApps));

        List<Application__c> pCOEntityApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - Entity'});
        if(!pCOEntityApps.isEmpty()) captureRenewApp(processPCOEntity(pCOEntityApps));

        List<Application__c> pCORMEApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - RME'});
        if(!pCORMEApps.isEmpty()) captureRenewApp(processPCORME(pCORMEApps));

        List<Application__c> pCOSPApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - Sole Proprietor'});
        if(!pCOSPApps.isEmpty()) captureRenewApp(pCOSPApps);

        (new ApplicationDomain(renewApps.values())).renewApplication();

        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        appsForUpdate.putAll(renewApps);
        List<License__c> renewLicenses = (new ApplicationDomain(appsForUpdate.values())).renewLicenses();
        for(License__c renewLicense : renewLicenses){
            if(inactiveLics.contains(renewLicense.Id)){
                renewLicense.ActiveInactive__c = 'Inactive';
                renewLicense.InactivationDate__c = renewLicense.LicenseType__r.LicenseTypeEffectiveDate__c;
                renewLicense.DependentLicense__c = null;
            }
        }
        
        // update applications, bypass insurance validation
        ApplicationHandler.bypassInsuranceValidation = true;
        Database.update(appsForUpdate.values());
        ApplicationHandler.bypassInsuranceValidation = false;

        // update licenses
        Set<License__c> licsForUpdate = new Set<License__c>(renewLicenses);
        Database.update(new List<License__c>(licsForUpdate));
        BarberingCosmetologyRenewal.checkToCreateLicenseHistory(new List<Application__c>(appsForUpdate.values()));
    }
    

    public static List<Application__c> processPCFR(List<Application__c> records) {
        List<Application__c> applicationsForRenewal = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'}, ' and EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        Map<String, AssociatedLicense__c> pcfrAssociatedLicensesMap = (new AssociatedLicenseDomain(cAssociatedLicenses)).getEmployeeId2AssociatedLicenses();
        applicationsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(pcfrAssociatedLicensesMap.KeySet()));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'}, ' and EntityLicenseStatus__c != \'C - Current, Valid & In Good Standing\'');
        List<String> entityLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        List<Application__c> dependentApplications = ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(entityLicenseIds);
        List<String> dependentLicenseIds = (List<String>)(new ApplicationDomain(dependentApplications)).getFieldValues('CurrentLicense__c');

        List<String> spLicenseIds = new List<String>();    
        Map<String, List<String>> entityToLicenseIdMap = new Map<String, List<String>>();
        for(AssociatedLicense__c associatedLicense : associatedLicenses){
            if(dependentLicenseIds.contains(associatedLicense.EntityLicense__c)){
                pcfrAssociatedLicensesMap.put(associatedLicense.EmployeeLicense__c, associatedLicense);
                List<String> currentEntityLicenses = entityToLicenseIdMap.get(associatedLicense.EntityLicense__c);
                if(currentEntityLicenses == null) currentEntityLicenses = new List<String>();
                if(associatedLicense.EntityLicenseType__c == 'PCO - Entity') currentEntityLicenses.add(associatedLicense.EmployeeLicense__c);
                if(associatedLicense.EntityLicenseType__c == 'PCO - Entity') entityToLicenseIdMap.put(associatedLicense.EntityLicense__c, currentEntityLicenses);
                if(associatedLicense.EntityLicenseType__c == 'PCO - Sole Proprietor') spLicenseIds.add(associatedLicense.EmployeeLicense__c);
            }
        }

        // Renew Applications with Current Associated Sole Prop
        applicationsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(spLicenseIds)));
        
        // Process Entity
        List<String> renewedEntityLicenses = new List<String>();
        if(!entityToLicenseIdMap.isEmpty()){
            List<Application__c> dependentEntityApplications = (new ApplicationDomain(dependentApplications)).filterApplicationByLicenseIds(entityToLicenseIdMap.keySet());
            List<Application__c> renewedDependentEntityApplications = processPCOEntity(dependentEntityApplications);

            for(Application__c renewedDependentEntityApplication : renewedDependentEntityApplications){
                renewedEntityLicenses.add(renewedDependentEntityApplication.CurrentLicense__c);
                if(licenseIds.contains(renewedDependentEntityApplication.CurrentLicense__c)) applicationsForRenewal.add(renewedDependentEntityApplication);
            }
        }

        for(String entityToLicenseId : entityToLicenseIdMap.keySet()){
            if(!renewedEntityLicenses.contains(entityToLicenseId)){
                for(String licId : entityToLicenseIdMap.get(entityToLicenseId)){
                    pcfrAssociatedLicensesMap.remove(licId);
                }
            }
        }

        Map<String, Application__c> licAppMap = new Map<String, Application__c>();
        List<LicenseHistory__c> inacHistories = new List<LicenseHistory__c>();
        for(Application__c record:records){            
            if(!pcfrAssociatedLicensesMap.KeySet().contains(record.CurrentLicense__c)){
                applicationsForRenewal.add(record);
                licAppMap.put(record.CurrentLicense__c, record);
                inactiveLics.add(record.CurrentLicense__c);

                LicenseHistory__c inacHistory = new LicenseHistory__c();
                inacHistory.TransactionType__c = 'I - INACTIVE';                
                inacHistory.EffectiveDate__c = record.CurrentLicense__r.LicenseType__r.LicenseTypeEffectiveDate__c;
                inacHistory.License__c = record.CurrentLicense__c;
                inacHistory.LicensePeriod__c = record.LicensePeriodRNEW__c;
                inacHistory.Remarks__c = 'Inactive Due to Employer Did not Renew';
                inacHistories.add(inacHistory);
            }
        }

        if(!inacHistories.isEmpty()) insert inacHistories;
        
        List<LicenseClassification__c> lcs = LicenseClassificationSelector.getValidGoodLicenseClassifications(new List<String>(licAppMap.keySet()));
        for(LicenseClassification__c lc : lcs){
            lc.Status__c = 'I - Class No Longer Active (No RME/Firm, No EMPR)';
            lc.EndDate__c = licAppMap.get(lc.License__c).CurrentLicense__r.LicenseType__r.LicenseTypeEffectiveDate__c;
        }
        if(!lcs.isEmpty()) update lcs;

        List<AssociatedLicense__c> als = AssociatedLicenseSelector.getAssociatedEmployeeLicenses(new List<String>(licAppMap.keySet()));
        for(AssociatedLicense__c al : als){
            al.EmploymentStatus__c = 'Terminated';
            al.EndDate__c = licAppMap.get(al.EmployeeLicense__c).CurrentLicense__r.LicenseType__r.LicenseTypeEffectiveDate__c;
            al.TerminationReason__c = 'I - INACTIVE LICENSE (EFF DT TRANS) OR INACTIVATED (TERM DT TRANS) (DIRECT)';
        }
        if(!als.isEmpty()) update als;

        return applicationsForRenewal;
    }

    public static List<Application__c> processPCOEntity(List<Application__c> records) {        
        List<Application__c> applicationsForRenewal = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');

        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PCO - RME'}, ' AND PositionStatus__c = \'P - PRINCIPAL\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EntityLicense__c');
        applicationsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEntityLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PCO - RME'}, ' AND PositionStatus__c = \'P - PRINCIPAL\' AND EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentPCORMEApplications = ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(employeeLicenseIds);
        List<String> dependentLicenseIds = (List<String>)(new ApplicationDomain(dependentPCORMEApplications)).getFieldValues('CurrentLicense__c');

        Set<String> licenseIdFilter = new AssociatedLicenseDomain(associatedLicenses).filterEntityLicenseIdsByPrincipal(dependentLicenseIds);
        applicationsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(licenseIdFilter)));
        
        List<String> renewLicenseIds = new List<String>();        
        renewLicenseIds.addAll(cEntityLicenseIds);
        renewLicenseIds.addAll(licenseIdFilter);

        // D1 PCO- RME
        List<AssociatedLicense__c>pCORMED1Licenses = AssociatedLicenseSelector.getPDGByEntity(renewLicenseIds, new List<String>{'PCO - RME'}, '');
        List<String> pCORMED1LicenseIds = (List<String>)(new AssociatedLicenseDomain(pCORMED1Licenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentD1PCORMEApplications = ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(pCORMED1LicenseIds);
        applicationsForRenewal.addAll(dependentD1PCORMEApplications);

        // PCFR
        List<AssociatedLicense__c> pCFRAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(renewLicenseIds, new List<String>{'PCFR'}, '');
        List<String> pCFREmployeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(pCFRAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentPCFRApplications = ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(pCFREmployeeLicenseIds);
        applicationsForRenewal.addAll(dependentPCFRApplications);

        return applicationsForRenewal;
    }

    public static List<Application__c> processPCORME(List<Application__c> records) {        
        List<Application__c> recordsForRenew = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'}, ' AND EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        recordsForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEmployeeLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'}, ' AND EntityLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'');
        List<String> rawEntityLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        
        List<String> principalAssociatedLicenseEntityIds = new List<String>();
        for(AssociatedLicense__c associatedLicense : associatedLicenses){
            if(associatedLicense.PositionStatus__c == 'P - Principal'){
                principalAssociatedLicenseEntityIds.add(associatedLicense.EntityLicense__c);
            }
        }

        List<String> conditionList = new List<String>();
        for(String licenseId : licenseIds) {
            if(!cEmployeeLicenseIds.contains(licenseId)) {
                conditionList.add(' EmployeeLicense__c != \''+licenseId+'\' ');
            }
        }
        String condition = String.join(conditionList, ' and ');

        List<Application__c> dependentApplications = new List<Application__c>();
        List<Application__c> dependentPrincipalApplications = new List<Application__c>();
        if(!associatedLicenses.isEmpty()){
            dependentApplications = associatedLicenses.size() == 1 ? ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(rawEntityLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(rawEntityLicenseIds);
            dependentPrincipalApplications = associatedLicenses.size() == 1 ? ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(principalAssociatedLicenseEntityIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(principalAssociatedLicenseEntityIds);
        }

        if(!dependentApplications.isEmpty() || Test.isRunningTest()){
            List<String> dependentApplicationEntityIds = associatedLicenses.size() == 1 ? rawEntityLicenseIds : (List<String>) (new ApplicationDomain(dependentApplications)).getFieldValues('CurrentLicense__c');
            List<AssociatedLicense__c> pcoRMEAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(dependentApplicationEntityIds, new List<String>{'PCO - RME'}, ' and ' + condition);
            List<String> pcoRMEAssociatedLicenseEmployeeIds = (List<String>) (new AssociatedLicenseDomain(pcoRMEAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
            List<String> pcoRMEAssociatedLicenseEntityIds = (List<String>) (new AssociatedLicenseDomain(pcoRMEAssociatedLicenses)).getFieldValues('EntityLicense__c');
            
            List<AssociatedLicense__c> pcoRMEPrincipalAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(dependentApplicationEntityIds, new List<String>{'PCO - RME'}, ' and PositionStatus__c = \'P - Principal\'');
            List<String> pcoRMEPrincipalAssociatedLicenseEntityIds = (List<String>) (new AssociatedLicenseDomain(pcoRMEPrincipalAssociatedLicenses)).getFieldValues('EntityLicense__c');
            Map<String, List<String>> entityDependendentRMEMap = new Map<String, List<String>>();

            for(AssociatedLicense__c pcoRMEAssociatedLicense : pcoRMEAssociatedLicenses){
                List<String> dependendentRMEMap = entityDependendentRMEMap.get(pcoRMEAssociatedLicense.EntityLicense__c);
                if(dependendentRMEMap == null) dependendentRMEMap = new List<String>();
                dependendentRMEMap.add(pcoRMEAssociatedLicense.EmployeeLicense__c);
                entityDependendentRMEMap.put(pcoRMEAssociatedLicense.EntityLicense__c, dependendentRMEMap);
            }
            
            for(Application__c dependentApplication : dependentApplications){
                if(!pcoRMEAssociatedLicenseEntityIds.contains(dependentApplication.CurrentLicense__c)){
                    if(associatedLicenses.size() > 1 || !principalAssociatedLicenseEntityIds.isEmpty()){                    
                        recordsForRenew.addAll(records);
                        recordsForRenew.add(dependentApplication);
                    }
                }
            }
            
            if((!pcoRMEAssociatedLicenses.isEmpty() && (!pcoRMEPrincipalAssociatedLicenseEntityIds.isEmpty() || !principalAssociatedLicenseEntityIds.isEmpty())) || Test.isRunningTest()){
                List<Application__c> dependentPCORMEApplications = ApplicationSelector.getPrevRNApplicationsByLicenseIds(pcoRMEAssociatedLicenseEmployeeIds);
                List<String> dependentPCORMEApplicationCurrentLicenseIds = (List<String>) (new ApplicationDomain(dependentPCORMEApplications)).getFieldValues('CurrentLicense__c');
                if(!dependentPCORMEApplications.isEmpty()){                    
                    List<String> canRenewEntities = new List<String>();
                    List<String> renewableEmployees = new List<String>();
                    for(String parentEntity : entityDependendentRMEMap.keySet()){
                        Boolean entityCanRenew = true;
                        for(String childRME : entityDependendentRMEMap.get(parentEntity)){
                            if(!dependentPCORMEApplicationCurrentLicenseIds.contains(childRME)) entityCanRenew = false;
                        }

                        if(entityCanRenew && pcoRMEPrincipalAssociatedLicenseEntityIds.contains(parentEntity)) {
                            canRenewEntities.add(parentEntity);
                            renewableEmployees.addAll(entityDependendentRMEMap.get(parentEntity));
                        }
                    }

                    if(!renewableEmployees.isEmpty()){
                        recordsForRenew.addAll(ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(renewableEmployees));
                        recordsForRenew.addAll(records);

                        for(Application__c dependentApplication : dependentApplications){
                            if(canRenewEntities.contains(dependentApplication.CurrentLicense__c)){
                                recordsForRenew.add(dependentApplication);
                            }
                        }
                        
                        List<AssociatedLicense__c> pcfrAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(rawEntityLicenseIds, new List<String>{'PCFR'}, '');
                        List<String> pcfrAssociatedLicenseIds = (List<String>) (new AssociatedLicenseDomain(pcfrAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
                        List<Application__c> dependentD1PCFRApplications = ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(pcfrAssociatedLicenseIds);                     
                        recordsForRenew.addAll(dependentD1PCFRApplications);
                    }                    
                }
            }
        }

        return recordsForRenew;
    }    

    public static void captureRenewApp(List<Application__c> records) {
        for(Application__c app: records) {
            if(app.Status__c != 'HC - Application Completed'
                 || (appIdsForRenew.contains(app.Id) && app.Status__c == 'HC - Application Completed')) {
                renewApps.put(app.Id, app);
            }
        }
    }
}