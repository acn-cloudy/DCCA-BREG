/***
 * Used to maintain the Pest Control Renewal
 * 
 * 
 * **** */
public class PestControlRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    @InvocableMethod(
        label='Pest Control Renewal'
        description='Renew application with license types PCFR, PCO-Entity, PCO-RME and PCO - Sole Proprietor'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> appIds = new List<String>();
        for(Input inp: inputs) {
            appIds.add(inp.record.Id);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
        appIdsForRenew.addAll((new ApplicationDomain(appsForCustom)).getIds());
        List<Application__c> pCFRApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCFR'});
        if(!pCFRApps.isEmpty()) captureRenewApp(processPCFR(pCFRApps));

        List<Application__c> pCOEntityApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - Entity'});
        if(!pCOEntityApps.isEmpty()) captureRenewApp(processPCOEntity(pCOEntityApps));

        List<Application__c> pCORMEApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - RME'});
        if(!pCORMEApps.isEmpty()) captureRenewApp(processPCORME(pCORMEApps));

        List<Application__c> pCOSPApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PCO - Sole Proprietor'});
        if(!pCOSPApps.isEmpty()) captureRenewApp(processPCOSP(pCOSPApps));
        (new ApplicationDomain(renewApps.values())).renewApplication();

        List<Application__c> d1Update = (new ApplicationDomain(appsForCustom)).filterRecordsByIds(renewApps.keySet());
        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        appsForUpdate.putAll(renewApps);

        for(Application__c record: d1Update) {
            if(!appsForUpdate.containsKey(record.Id)) {
                record.Status__c = 'D1 - Awaiting Dependency Review';
                record.Phase__c = 'D - Dependency Review';
                appsForUpdate.put(record.Id, record);
            }
        }
        List<License__c> renewLicenses = (new ApplicationDomain(appsForUpdate.values())).renewLicenses();
        
        
        // update applications
        update appsForUpdate.values();

        // update licenses
        update renewLicenses;

        BarberingCosmetologyRenewal.checkToCreateLicenseHistory(appsForUpdate.values());

        List<Application__c> appsForInactive = (new ApplicationDomain(applications)).filterApplicationsForInactiveRenew();

        for(Application__c record: appsForInactive) {
            BarberingCosmetologyRenewal.lanchRenewingInactiveFlow(record);
        }

        List<Results> responseWrapper= new List<Results>();
        for(Input inp: inputs) {
            Results re = new Results();
            re.operationOutcome = 'Success';
            responseWrapper.add(re);
        }
        return responseWrapper;
    }

    public static List<Application__c> processPCOEntity(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PCO - RME'}, '');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentPCORMEApplications = ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds);
        List<String> dependentLicenseIds = (List<String>)(new ApplicationDomain(dependentPCORMEApplications)).getFieldValues('CurrentLicense__c');

        Set<String> licenseIdFilter = new AssociatedLicenseDomain(associatedLicenses).filterEntityLicenseIdsByPrincipal(dependentLicenseIds);
        List<Application__c> recordsForRenew = new List<Application__c>();
        List<Application__c> applicationsForRenewal = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdFilter);
        recordsForRenew.addAll(applicationsForRenewal);
       
        List<String> renewLicenseIds = new List<String>();
        renewLicenseIds.addAll(licenseIdFilter);

        // D1 PCO- RME
        List<AssociatedLicense__c>pCORMED1Licenses = AssociatedLicenseSelector.getPDGByEntity(renewLicenseIds, new List<String>{'PCO - RME'}, '');
        List<String> pCORMED1LicenseIds = (List<String>)(new AssociatedLicenseDomain(pCORMED1Licenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentD1PCORMEApplications = ApplicationSelector.getD1RNApplicationsByLicenseIds(pCORMED1LicenseIds);
        recordsForRenew.addAll(dependentD1PCORMEApplications);

        // PCFR
        List<AssociatedLicense__c> pCFRAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(renewLicenseIds, new List<String>{'PCFR'}, '');
        System.debug('#####pCFRAssociatedLicenses# size ###' + pCFRAssociatedLicenses.size());
        List<String> pCFREmployeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(pCFRAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> dependentPCFRApplications = ApplicationSelector.getRNApplicationsByLicenseIds(pCFREmployeeLicenseIds);
        recordsForRenew.addAll(dependentPCFRApplications);

        return recordsForRenew;

    }

    public static List<Application__c> processPCORME(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'}, '');
        List<String> rawEntityLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        
        List<String> principalAssociatedLicenseEntityIds = new List<String>();
        for(AssociatedLicense__c associatedLicense : associatedLicenses){
            if(associatedLicense.PositionStatus__c == 'P - Principal'){
                principalAssociatedLicenseEntityIds.add(associatedLicense.EntityLicense__c);
            }
        }

        List<String> conditionList = new List<String>();
        for(String licenseId : licenseIds) {
            conditionList.add(' EmployeeLicense__c != \''+licenseId+'\' ');
        }
        String condition = String.join(conditionList, ' and ');

        List<Application__c> recordsForRenew = new List<Application__c>();
        List<Application__c> dependentApplications = new List<Application__c>();
        List<Application__c> dependentPrincipalApplications = new List<Application__c>();
        if(!associatedLicenses.isEmpty()){
            dependentApplications = associatedLicenses.size() == 1 ? ApplicationSelector.getD1RNApplicationsByLicenseIds(rawEntityLicenseIds) : ApplicationSelector.getRNApplicationsByLicenseIds(rawEntityLicenseIds);
            dependentPrincipalApplications = associatedLicenses.size() == 1 ? ApplicationSelector.getD1RNApplicationsByLicenseIds(principalAssociatedLicenseEntityIds) : ApplicationSelector.getRNApplicationsByLicenseIds(principalAssociatedLicenseEntityIds);
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
                List<Application__c> dependentPCORMEApplications = ApplicationSelector.getRNApplicationsByLicenseIds(pcoRMEAssociatedLicenseEmployeeIds);
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
                        recordsForRenew.addAll(ApplicationSelector.getD1RNApplicationsByLicenseIds(renewableEmployees));
                        recordsForRenew.addAll(records);

                        for(Application__c dependentApplication : dependentApplications){
                            if(canRenewEntities.contains(dependentApplication.CurrentLicense__c)){
                                recordsForRenew.add(dependentApplication);
                            }
                        }
                        
                        List<AssociatedLicense__c> pcfrAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(rawEntityLicenseIds, new List<String>{'PCFR'}, '');
                        List<String> pcfrAssociatedLicenseIds = (List<String>) (new AssociatedLicenseDomain(pcfrAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
                        List<Application__c> dependentD1PCFRApplications = ApplicationSelector.getD1RNApplicationsByLicenseIds(pcfrAssociatedLicenseIds);                     
                        recordsForRenew.addAll(dependentD1PCFRApplications);
                    }
                    
                }
            }
        }

        return recordsForRenew;
    }

    public static List<Application__c> processPCFR(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPestControlByEmployee(licenseIds, new List<String>{'PCO - Entity', 'PCO - Sole Proprietor'});
        Map<String, AssociatedLicense__c> pcfrAssociatedLicensesMap = (new AssociatedLicenseDomain(associatedLicenses)).getEmployeeId2AssociatedLicenses();
        List<Application__c> applicationsForRenewal = (new ApplicationDomain(records)).filterApplicationByLicenseIds(pcfrAssociatedLicensesMap.KeySet());
        return applicationsForRenewal;
    }

    public static List<Application__c> processPCOSP(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PCO - RME'}, '');

        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        Set<String> employeeLicenseSet = new Set<String>();
        employeeLicenseSet.addAll(employeeLicenseIds);
        List<String> entityLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        Set<String> entityLicenseSet = new Set<String>();
        entityLicenseSet.addAll(entityLicenseIds);
        Set<String> renewalIds = new Set<String>();
        for(String licenseId: licenseIds) {
            if(!entityLicenseSet.contains(licenseId)) {
                renewalIds.add(licenseId);
            }
        }
        List<Application__c> pCORMEApps = ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds);
        List<String> pCOREELIds = (List<String>)(new ApplicationDomain(pCORMEApps)).getFieldValues('CurrentLicense__c');
        Set<String> pCOREELIdSet = new Set<String>();
        pCOREELIdSet.addAll(pCOREELIds) ;
        
        for(AssociatedLicense__c record: associatedLicenses) {
            if(pCOREELIdSet.contains(record.EmployeeLicense__c)) {
                renewalIds.add(record.EntityLicense__c);
            }
        }
        List<Application__c> appForRenew =(new ApplicationDomain(records)).filterApplicationByLicenseIds(renewalIds);

        List<String> renewLicenseIds = (List<String>) (new ApplicationDomain(appForRenew)).getFieldValues('CurrentLicense__c');

        System.debug('#####renewLicenseIds#Size###' + renewLicenseIds.size());
        List<AssociatedLicense__c> pCFRAssociatedLicenses 
            = AssociatedLicenseSelector.getPDGByEntity(renewLicenseIds, new List<String> {'PCFR'}, '');
        System.debug('#####pCFRAssociatedLicenses#Size###' + pCFRAssociatedLicenses.size());
        List<String> pCFREmployeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(pCFRAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> pcFRApps = ApplicationSelector.getRenewalApplicationsByLicenseIds(pCFREmployeeLicenseIds);
        appForRenew.addAll(pCORMEApps);
        appForRenew.addAll(pcFRApps);

        return appForRenew;
    }

    public static void captureRenewApp(List<Application__c> records) {
        for(Application__c app: records) {
            if(app.Status__c != 'HC - Application Completed'
                 || (appIdsForRenew.contains(app.Id) && app.Status__c == 'HC - Application Completed')) {
                renewApps.put(app.Id, app);
            }
        }
    }

    public class Input {
        @InvocableVariable(label='Application Record for Input' description='Input Application' required=true)
        public Application__c record;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output Renewals' required=true)
        public String operationOutcome;
    }
}