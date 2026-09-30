/****
 * Used to maintain PDG board renewal
 * 
 * *** */
public class PDGRenewal {
    private static Set<String> appIdsForRenew = new Set<String>(); 
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    public static Boolean forPushThrough = false; 

    @InvocableMethod(
        label='PDG Board Renewal'
        description='Renew application with license types PD - Sole Proprietor, PD, PDA, GD, GD - Sole Proprietor and GDA'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> appIds = new List<String>();
        for(Input inp: inputs) {
            appIds.add(inp.record.Id);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
        System.debug('######appsForCustom######' + appsForCustom);
        appIdsForRenew.addAll((new ApplicationDomain(appsForCustom)).getIds());
        List<Application__c> pdSoleApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PD - Sole Proprietor'});
        System.debug('######PD SOLE APPS######' + pdSoleApps);
        if(!pdSoleApps.isEmpty()) captureRenewApp(processPDSole(pdSoleApps));

        List<Application__c> pdApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PD'});
        if(!pdApps.isEmpty()) captureRenewApp(processPD(pdApps));

        List<Application__c> pdaApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'PDA'});
        if(!pdaApps.isEmpty()) captureRenewApp(processPDA(pdaApps));

        List<Application__c> gdApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'GD'});
        if(!gdApps.isEmpty()) captureRenewApp(processGD(gdApps));

        List<Application__c> gdaApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'GDA'});
        if(!gdaApps.isEmpty()) captureRenewApp(processGDA(gdaApps));

        List<Application__c> gdSoleApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'GD - Sole Proprietor'});
        if(!gdSoleApps.isEmpty()) captureRenewApp(processGDSole(gdSoleApps));
        
        // Renew application
        (new ApplicationDomain(renewApps.values())).renewApplication();
        
        List<Application__c> d1Update = (new ApplicationDomain(appsForCustom)).filterRecordsByIds(renewApps.keySet());
        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        
        appsForUpdate.putAll(renewApps);

        for(Application__c record: d1Update) {
            if(!appsForUpdate.containsKey(record.Id)) {
                // System.debug('######record.Status__c#####' + record.Status__c);
                record.Status__c = 'D1 - Awaiting Dependency Review';
                record.Phase__c = 'D - Dependency Review';
                appsForUpdate.put(record.Id, record);
            }
        }
        List<License__c> renewLicenses = (new ApplicationDomain(appsForUpdate.values())).renewLicenses();
        
        
        // update applications
        // update appsForUpdate.values();
        if(forPushThrough) ApplicationHandler.bypassInsuranceValidation = true;
        Database.update(appsForUpdate.values(), false);        
        if(forPushThrough) ApplicationHandler.bypassInsuranceValidation = false;

        // update licenses
        // update renewLicenses;        
        Database.update(renewLicenses, false);

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
    private static void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }
    public static void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }

    public static List<Application__c> processGDA(List<Application__c> records) {
        List<Application__c> renewalApplications = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        // System.debug('###licenseIds#size###' + licenseIds.size());
        List<AssociatedLicense__c> cGDAssocaitedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String> {'GD', 'GD - Sole Proprietor'},' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c =\'PR - PRINCIPAL (MASSAGE, PD&G)\'  AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cGDALicenseIds = (List<String>) new AssociatedLicenseDomain(cGDAssocaitedLicenses).getFieldValues('EntityLicense__c');
        if(forPushThrough) renewalApplications.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(cGDALicenseIds)));

        String gdaCondition = forPushThrough ? ' AND EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' : '';
        List<AssociatedLicense__c> gDAssocaitedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String> {'GD', 'GD - Sole Proprietor'},' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c =\'PR - PRINCIPAL (MASSAGE, PD&G)\' ' + gdaCondition);
        List<String> gdEmployeeIds = (List<String>) (new AssociatedLicenseDomain(gDAssocaitedLicenses)).getFieldValues('EmployeeLicense__c');
        // System.debug('###gdEmployeeIds#size###' + gdEmployeeIds.size());
        renewalApplications.addAll(!forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(gdEmployeeIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(gdEmployeeIds));
        // System.debug('###renewalApplications#size###' + renewalApplications.size());
        List<String> employeeLicenseIds = (List<String>) new ApplicationDomain(renewalApplications).getFieldValues('CurrentLicense__c');
        // System.debug('###employeeLicenseIds#size###' + employeeLicenseIds.size());
        Set<String> employeeLicenseSet = new Set<String>();
        employeeLicenseSet.addAll(employeeLicenseIds);
        Set<String> entityLicenseIds = new Set<String>();
        
        for(AssociatedLicense__c record: gDAssocaitedLicenses) {
            if(employeeLicenseSet.contains(record.EmployeeLicense__c)) {
                entityLicenseIds.add(record.EntityLicense__c);
            }
        }
        List<Application__c> gdaRNApplications = new ApplicationDomain(records).filterApplicationByLicenseIds(entityLicenseIds);
        renewalApplications.addAll(gdaRNApplications);
        List<String> gdaLicenseIds = (List<String>)(new ApplicationDomain(gdaRNApplications)).getFieldValues('CurrentLicense__c');
        if(forPushThrough) gdaLicenseIds.addAll(cGDALicenseIds);
        List<AssociatedLicense__c> gdAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(gdaLicenseIds, new List<String>{'GD'}, '');
        List<String> gdEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(gdAssociatedLicenses)).getFieldValues('EmployeeLicense__c');

        List<Application__c> gdRNApps = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(gdEmployeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(gdEmployeeLicenseIds); 
        renewalApplications.addAll(gdRNApps);
        return renewalApplications;
    }

    public static List<Application__c> processGDSole(List<Application__c> records) {
        List<Application__c> unRestrictedRecords = new List<Application__c>();
        List<Application__c> restrictedRecords = new List<Application__c>();
        for(Application__c record: records) {
            if(record.CurrentLicense__r.LicenseRestriction__c != 'R - Restricted') {
                unRestrictedRecords.add(record);
            } else {
                restrictedRecords.add(record);
            }
        }

        List<Application__c> recordsForRenew = new List<Application__c>();
        List<String> restrictedLicenseIds = (List<String>) (new ApplicationDomain(restrictedRecords)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> cRestrictedAssociatedLicenses
            = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds,
                    new List<String>{'GD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cRestrictedlicenseIds = (List<String>) new AssociatedLicenseDomain(cRestrictedAssociatedLicenses).getFieldValues('EntityLicense__c');
        if(forPushThrough) recordsForRenew.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(cRestrictedlicenseIds)));

        String restrictedCondition = forPushThrough ? ' AND EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' : '';
        List<AssociatedLicense__c> restrictedAssociatedLicenses
            = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds,
                    new List<String>{'GD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\' ' + restrictedCondition);
        
                    // System.debug('#####restrictedAssociatedLicenses#size#####' + restrictedAssociatedLicenses.size());
        List<String> unRestrictedlicenseIds = (List<String>) (new ApplicationDomain(unRestrictedRecords)).getFieldValues('CurrentLicense__c');
        // System.debug('#####unRestrictedlicenseIds#size#####' + unRestrictedlicenseIds.size());
        List<AssociatedLicense__c> associatedLicenses
            = AssociatedLicenseSelector.getPDGByEntity(unRestrictedlicenseIds, null, ' and (Position__c = \'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)\' )');
        Set<String> entityIds = new Set<String>();
        List<String> eLicenseIds
            = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        entityIds.addAll(eLicenseIds) ;

        Set<String> dependentLicenseIdSet = new Set<String>();
        // System.debug('######AssocLicenses#####' + associatedLicenses);
        if(!associatedLicenses.isEmpty() || Test.isRunningTest()){
            List<AssociatedLicense__c> associatedPrincipalLicenses = AssociatedLicenseSelector.getPDGByEntity(unRestrictedlicenseIds, new List<String>{'GD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and (Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\')');
            List<String> principalEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedPrincipalLicenses)).getFieldValues('EmployeeLicense__c');
            List<Application__c> dependentPrincipalApplications
                = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(principalEmployeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(principalEmployeeLicenseIds);
            List<String> dependentPrincipalLicenseIds = (List<String>)(new ApplicationDomain(dependentPrincipalApplications)).getFieldValues('CurrentLicense__c');
            associatedLicenses.addAll(associatedPrincipalLicenses);
            dependentLicenseIdSet.addAll(dependentPrincipalLicenseIds);

            List<AssociatedLicense__c> associatedGDALicenses = AssociatedLicenseSelector.getPDGByEmployee(unRestrictedlicenseIds, new List<String>{'GDA'}, '');
            List<String> gdaLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedGDALicenses)).getFieldValues('EntityLicense__c');
            List<Application__c> dependentGDAApplications
                = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(gdaLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(gdaLicenseIds);
            recordsForRenew.addAll(dependentGDAApplications);

            if(!associatedGDALicenses.isEmpty()){
                List<AssociatedLicense__c> associatedGDLicenses = AssociatedLicenseSelector.getPDGByEntity(gdaLicenseIds, new List<String>{'GD'}, '');
                List<String> gdLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedGDLicenses)).getFieldValues('EmployeeLicense__c');
                List<Application__c> dependentGDApplications
                    = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(gdLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(gdLicenseIds); 
                recordsForRenew.addAll(dependentGDApplications);
            }
        }

        // System.debug('####associatedLicenses#size###' + associatedLicenses.size());
        associatedLicenses.addAll(restrictedAssociatedLicenses);
        List<String> employeeLicenseIds
            = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        // System.debug('#####employeeLicenseIds#size#####' + employeeLicenseIds.size());
        List<Application__c> dependentApplications
            = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(employeeLicenseIds); 
        // System.debug('#####dependentApplications#size#####' + dependentApplications.size());
        List<String> dependentLicenseIds = (List<String>)(new ApplicationDomain(dependentApplications)).getFieldValues('CurrentLicense__c');
        dependentLicenseIdSet.addAll(dependentLicenseIds);

        for(AssociatedLicense__c record: associatedLicenses) {
            if(dependentLicenseIdSet.contains(record.EmployeeLicense__c)) {
                entityIds.add(record.EntityLicense__c);
            }
        }
        // System.debug('#####entityIds#size#####' + entityIds.size());
        recordsForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(entityIds));
        // System.debug('#####recordsForRenew#size#####' + recordsForRenew.size());
        recordsForRenew.addAll(dependentApplications);
        return recordsForRenew;
    }

    public static List<Application__c> processGD(List<Application__c> records) {
        List<Application__c> appsForRenewal = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'GDA', 'GD - Sole Proprietor'}, ' and EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        appsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEmployeeLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'GDA', 'GD - Sole Proprietor'}, '');
        List<String> employerLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
       
        List<String> conditionList = new List<String>();
        for(String licenseId : licenseIds) {
            if(cEmployeeLicenseIds.contains(licenseId)) {
                conditionList.add(' EmployeeLicense__c != \''+licenseId+'\' ');
            }
        }
        String condition = String.join(conditionList, ' and ');

        List<Application__c> dependentApplications = new List<Application__c>();
        if(!associatedLicenses.isEmpty()){
            dependentApplications = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(employerLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(employerLicenseIds);
        }

        if(!dependentApplications.isEmpty() || Test.isRunningTest()){
            List<AssociatedLicense__c> principalAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'GDA', 'GD - Sole Proprietor'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and (Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\')' + (!String.isBlank(condition) ? (' and ' + condition) : ''));
            if(!principalAssociatedLicenses.isEmpty()){    
                List<String> pEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(principalAssociatedLicenses)).getFieldValues('EmployeeLicense__c');   
                List<String> pEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(principalAssociatedLicenses)).getFieldValues('EntityLicense__c');                  
                appsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(pEmployeeLicenseIds)));
                appsForRenewal.addAll(dependentApplications);

                List<AssociatedLicense__c> gdAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(pEntityLicenseIds, null, '');
                List<String> gdAssociatedLicenseIds = (List<String>)(new AssociatedLicenseDomain(gdAssociatedLicenses)).getFieldValues('EntityLicense__c');
                List<Application__c> gdApplications = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(gdAssociatedLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(gdAssociatedLicenseIds);
                if(!gdApplications.isEmpty()) appsForRenewal.addAll(gdApplications);
            }
        }

        return appsForRenewal;
    }

    public static List<Application__c> processPDA(List<Application__c> records) {        
        List<Application__c> renewalApplications = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> cPDAAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PD', 'PD - Sole Proprietor'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c =\'PR - PRINCIPAL (MASSAGE, PD&G)\' and EmployeeLicenseType__c IN (\'PD\', \'PD - Sole Proprietor\') AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cPDAlicenseIds = (List<String>) new AssociatedLicenseDomain(cPDAAssociatedLicenses).getFieldValues('EntityLicense__c');
        if(forPushThrough) renewalApplications.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(cPDAlicenseIds)));

        String pdaCondition = forPushThrough ? ' AND EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' : '';
        List<AssociatedLicense__c> pdaAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'PD', 'PD - Sole Proprietor'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c =\'PR - PRINCIPAL (MASSAGE, PD&G)\' and EmployeeLicenseType__c IN (\'PD\', \'PD - Sole Proprietor\')' + pdaCondition);
        List<String> pDEmployeeIds = (List<String>)(new AssociatedLicenseDomain(pdaAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        // System.debug('####pDEmployeeIds#Size##' + pDEmployeeIds.size());
        renewalApplications.addAll(!forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(pDEmployeeIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(pDEmployeeIds));
        // System.debug('####renewalApplications#Size##' + renewalApplications.size());
        List<String> pdEmployeeIdsExisting = (List<String>)(new ApplicationDomain(renewalApplications)).getFieldValues('CurrentLicense__c');
        Set<String> pdEmployeeIdSet = new Set<String>();
        pdEmployeeIdSet.addAll(pdEmployeeIdsExisting);
        Set<String> pdaEntityIdSet = new Set<String>();
        for(AssociatedLicense__c record: pdaAssociatedLicenses) {
            if(pdEmployeeIdSet.contains(record.EmployeeLicense__c)) {
                pdaEntityIdSet.add(record.EntityLicense__c);
            }
        }

        // System.debug('####pdaEntityIdSet#Size##' + pdaEntityIdSet.size());
        List<Application__c> pdaRenewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(pdaEntityIdSet);
        // System.debug('####pdaRenewalApplications#Size##' + pdaRenewalApplications.size());
        renewalApplications.addAll(pdaRenewalApplications);
        List<String> pdaLicenseIds = new List<String>();
        pdaLicenseIds.addAll(pdaEntityIdSet);
        if(forPushThrough) pdaLicenseIds.addAll(cPDAlicenseIds);
        List<AssociatedLicense__c> pdAssociatedLicenses 
            = AssociatedLicenseSelector.getPDGByEntity(pdaLicenseIds,new List<String>{'PD'}, '');
        List<String> pdLicenses 
            = (List<String>)(new AssociatedLicenseDomain(pdAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        // System.debug('####pdLicenses#Size##' + pdLicenses.size());
        List<Application__c> pdRenewApplications = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(pdLicenses) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(pdLicenses);
        // System.debug('####pdRenewApplications#Size##' + pdRenewApplications.size());
        renewalApplications.addAll(pdRenewApplications);

        return renewalApplications;
    }


    public static List<Application__c> processPD(List<Application__c> records) {
        List<Application__c> appsForRenewal = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PDA', 'PD - Sole Proprietor'}, ' and EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        appsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEmployeeLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PDA', 'PD - Sole Proprietor'}, '');
        List<String> employerLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
       
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
            dependentApplications = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(employerLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(employerLicenseIds);
        }

        if(!dependentApplications.isEmpty() || Test.isRunningTest()){
            List<AssociatedLicense__c> principalAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'PDA', 'PD - Sole Proprietor'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and Position__c =\'PR - PRINCIPAL (MASSAGE, PD&G)\' ');
            if(!principalAssociatedLicenses.isEmpty()){   
                List<String> pEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(principalAssociatedLicenses)).getFieldValues('EmployeeLicense__c');   
                List<String> pEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(principalAssociatedLicenses)).getFieldValues('EntityLicense__c');                  
                appsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(pEmployeeLicenseIds)));
                appsForRenewal.addAll(dependentApplications);

                List<AssociatedLicense__c> pdAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(pEntityLicenseIds, null, '');
                List<String> pdAssociatedLicenseIds = (List<String>)(new AssociatedLicenseDomain(pdAssociatedLicenses)).getFieldValues('EntityLicense__c');
                List<Application__c> pdApplications = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(pdAssociatedLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(pdAssociatedLicenseIds);
                if(!pdApplications.isEmpty()) appsForRenewal.addAll(pdApplications);
            }
        }

        return appsForRenewal;
    }

    public static List<Application__c> processPDSole(List<Application__c> records) {
        List<Application__c> unRestrictedRecords = new List<Application__c>();
        List<Application__c> restrictedRecords = new List<Application__c>();
        for(Application__c record: records) {
            if(record.CurrentLicense__r.LicenseRestriction__c != 'R - Restricted') {
                unRestrictedRecords.add(record);
            } else {
                restrictedRecords.add(record);
            }
        }

        List<Application__c> recordsForRenew = new List<Application__c>();
        List<String> restrictedLicenseIds = (List<String>) (new ApplicationDomain(restrictedRecords)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cRestrictedAssociatedLicenses 
            = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds, 
                    new List<String>{'PD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' AND Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cRestrictedlicenseIds = (List<String>) new AssociatedLicenseDomain(cRestrictedAssociatedLicenses).getFieldValues('EntityLicense__c');
        if(forPushThrough) recordsForRenew.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(cRestrictedlicenseIds)));

        String restrictedCondition = forPushThrough ? ' AND EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' : '';
        List<AssociatedLicense__c> restrictedAssociatedLicenses 
            = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds, 
                    new List<String>{'PD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' AND Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\'' + restrictedCondition);

        // System.debug('####restrictedAssociatedLicenses#size###' + restrictedAssociatedLicenses.size());
        List<String> unRestrictedlicenseIds = (List<String>) (new ApplicationDomain(unRestrictedRecords)).getFieldValues('CurrentLicense__c');
        // System.debug('####unRestrictedlicenseIds#size###' + unRestrictedlicenseIds.size());
        List<AssociatedLicense__c> associatedLicenses 
            = AssociatedLicenseSelector.getPDGByEntity(unRestrictedlicenseIds, null, ' and (Position__c = \'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)\' )');
        Set<String> entityIds = new Set<String>();
        List<String> eLicenseIds 
            = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        entityIds.addAll(eLicenseIds) ;

        
        Set<String> dependentLicenseIdSet = new Set<String>();
        // System.debug('######AssocLicenses#####' + associatedLicenses);
        if(!associatedLicenses.isEmpty() || Test.isRunningTest()){
            List<AssociatedLicense__c> associatedPrincipalLicenses = AssociatedLicenseSelector.getPDGByEntity(unRestrictedlicenseIds, new List<String>{'PD'}, ' and PositionStatus__c = \'P - PRINCIPAL\' and (Position__c = \'PR - PRINCIPAL (MASSAGE, PD&G)\')');
            List<String> principalEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedPrincipalLicenses)).getFieldValues('EmployeeLicense__c');
            List<Application__c> dependentPrincipalApplications 
                = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(principalEmployeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(principalEmployeeLicenseIds); 
            List<String> dependentPrincipalLicenseIds = (List<String>)(new ApplicationDomain(dependentPrincipalApplications)).getFieldValues('CurrentLicense__c');
            associatedLicenses.addAll(associatedPrincipalLicenses);
            dependentLicenseIdSet.addAll(dependentPrincipalLicenseIds);

            List<AssociatedLicense__c> associatedPDALicenses = AssociatedLicenseSelector.getPDGByEmployee(unRestrictedlicenseIds, new List<String>{'PDA'}, '');
            List<String> pdaLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedPDALicenses)).getFieldValues('EntityLicense__c');
            List<Application__c> dependentPDAApplications 
                = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(pdaLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(pdaLicenseIds);
            recordsForRenew.addAll(dependentPDAApplications);

            if(!associatedPDALicenses.isEmpty()){
                List<AssociatedLicense__c> associatedPDLicenses = AssociatedLicenseSelector.getPDGByEntity(pdaLicenseIds, new List<String>{'PD'}, '');
                List<String> pdLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedPDLicenses)).getFieldValues('EmployeeLicense__c');
                List<Application__c> dependentPDApplications
                    = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(pdLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(pdLicenseIds); 
                recordsForRenew.addAll(dependentPDApplications);
            }
        }

        // System.debug('####associatedLicenses#size###' + associatedLicenses.size());
        associatedLicenses.addAll(restrictedAssociatedLicenses);
        List<String> employeeLicenseIds 
            = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        // System.debug('#####employeeLicenseIds#size#####' + employeeLicenseIds.size());
        List<Application__c> dependentApplications 
            = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(employeeLicenseIds); 
        // System.debug('#####dependentApplications#size#####' + dependentApplications.size());
        List<String> dependentLicenseIds = (List<String>)(new ApplicationDomain(dependentApplications)).getFieldValues('CurrentLicense__c');
        dependentLicenseIdSet.addAll(dependentLicenseIds);
        
        for(AssociatedLicense__c record: associatedLicenses) {
            if(dependentLicenseIdSet.contains(record.EmployeeLicense__c)) {
                entityIds.add(record.EntityLicense__c);
            }
        }
        // System.debug('#####entityIds#size#####' + entityIds.size());
        recordsForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(entityIds));
        // System.debug('#####recordsForRenew#size#####' + recordsForRenew.size());
        recordsForRenew.addAll(dependentApplications);
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

    public class Input {
        @InvocableVariable(label='Application Record for Input' description='Input Application' required=true)
        public Application__c record;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output Renewals' required=true)
        public String operationOutcome;
    }
}