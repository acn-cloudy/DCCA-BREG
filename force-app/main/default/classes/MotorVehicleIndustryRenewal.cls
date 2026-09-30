public class MotorVehicleIndustryRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    public static Boolean forPushThrough = false;

    @InvocableMethod(
        label='Motor Vehicle Industry Renewal'
        description='Renew application with license types MVD, CS, MVB and MVD - Sole'
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
        List<Application__c> mvdApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'MVD'});
        if(!mvdApps.isEmpty()) captureRenewApp(processMVDApps(mvdApps));

        List<Application__c> csApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'CS'});
        if(!csApps.isEmpty()) captureRenewApp(processCSApps(csApps));
        
        List<Application__c> mvbApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'MVB'});
        if(!mvbApps.isEmpty()) captureRenewApp(processMVBApps(mvbApps));

        List<Application__c> mvdSoleApp = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'MVD - Sole Proprietor'});
        if(!mvdSoleApp.isEmpty()) captureRenewApp(processMVDSoleProprietor(mvdSoleApp));

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
        Database.update(appsForUpdate.values(), false);

        // update licenses
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

    public static List<Application__c> processMVDApps(List<Application__c> records) {
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        System.debug('########licenseIds#size#####' + licenseIds.size());

        List<Application__c> renewalApplications = new List<Application__c>();
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'CS'}, ' and EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> ccsLicenseIds = new List<String>();
        if(forPushThrough)ccsLicenseIds.addAll((List<String>) new AssociatedLicenseDomain(cAssociatedLicenses).getFieldValues('EntityLicense__c'));
        renewalApplications.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(ccsLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'CS'}, '');
        System.debug('########associatedLicenses#size#####' + associatedLicenses.size());
        List<String> csLicenseIds = (List<String>) new AssociatedLicenseDomain(associatedLicenses).getFieldValues('EmployeeLicense__c');
        System.debug('########csLicenseIds#size#####' + csLicenseIds.size());
        List<Application__c> csRNApps = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(csLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(csLicenseIds);
        System.debug('########csRNApps#size#####' + csRNApps.size());
        List<String> csRNLicenses = (List<String>)new ApplicationDomain(csRNApps).getFieldValues('CurrentLicense__c');
        System.debug('########csRNLicenses#size#####' + csRNLicenses.size());

        Set<String> mvdLicenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: associatedLicenses) {
            if(
                csRNLicenses.contains(record.EmployeeLicense__c)
                && !ccsLicenseIds.contains(record.EntityLicense__c)
            ) {
                mvdLicenseIdSet.add(record.EntityLicense__c);
            }
        }
        System.debug('########mvdLicenseIdSet#size#####' + mvdLicenseIdSet.size());
        renewalApplications.addAll(new ApplicationDomain(records).filterApplicationByLicenseIds(mvdLicenseIdSet));
        System.debug('########renewalApplications#size#####' + renewalApplications.size());
        List<String> mvdRNLicenses = new List<String>();
        mvdRNLicenses.addAll(mvdLicenseIdSet);
        mvdRNLicenses.addAll(ccsLicenseIds);
        System.debug('####mvdRNLicenses#size####' + mvdRNLicenses.size());

        List<AssociatedLicense__c> mvbsAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(mvdRNLicenses, new List<String>{'MVB'}, '');
        System.debug('####mvbsAssociatedLicenses#size####' + mvbsAssociatedLicenses.size());
        List<String> mvbEntityLicenseIds = (List<String>) (new AssociatedLicenseDomain(mvbsAssociatedLicenses)).getFieldValues('EntityLicense__c');
        System.debug('####mvbEntityLicenseIds#size####' + mvbEntityLicenseIds.size());
        List<Application__c> mvbRenewalApplications = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(mvbEntityLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(mvbEntityLicenseIds);
        System.debug('####mvbRenewalApplications#size####' + mvbRenewalApplications.size());
        renewalApplications.addAll(csRNApps);
        renewalApplications.addAll(mvbRenewalApplications);
        System.debug('####renewalApplications#size####' + renewalApplications.size());

        return renewalApplications;
    }

    public static List<Application__c> processCSApps(List<Application__c> records) {
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'MVD', 'MVD - Sole Proprietor'}, '');
        
        List<String> rawMVDLicenseIds = (List<String>) new AssociatedLicenseDomain(associatedLicenses).getFieldValues('EntityLicense__c');
        List<Application__c> renewalApplications = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(rawMVDLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(rawMVDLicenseIds);
        List<String> mvdLicenseIds = (List<String>) new ApplicationDomain(renewalApplications).getFieldValues('CurrentLicense__c');
        
        Set<String> licenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: associatedLicenses) {
            if(mvdLicenseIds.contains(record.EntityLicense__c) || record.EntityLicenseStatus__c == 'C - Current, Valid & In Good Standing') {
                licenseIdSet.add(record.EmployeeLicense__c);
            }
        }

        List<Application__c> csApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdSet);
        
        List<AssociatedLicense__c>  mVBs = AssociatedLicenseSelector.getPDGByEmployee(mvdLicenseIds, new List<String> {'MVB'}, '');
        List<String> mVBIds = (List<String>) (new AssociatedLicenseDomain(mVBs)).getFieldValues('EntityLicense__c');
        List<Application__c> mVBApps = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(mVBIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(mVBIds);

        renewalApplications.addAll(mVBApps);
        renewalApplications.addAll(csApplications);
        return renewalApplications;
    }
    
    public static List<Application__c> processMVBApps(List<Application__c> records) {
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'MVD', 'MVD - Sole Proprietor'}, ' and EmployeeLicenseStatus__c =\'C - Current, Valid & In Good Standing\' ');
        System.debug('####associatedLicenses#size####' + associatedLicenses.size());
        List<String> entityLicenseIds = (List<String>)new AssociatedLicenseDomain(associatedLicenses).getFieldValues('EntityLicense__c');
        System.debug('####entityLicenseIds#size####' + entityLicenseIds.size());
        Set<String> entityLicenseSet = new Set<String>();
        entityLicenseSet.addAll(entityLicenseIds);

        
        List<Application__c> renewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(entityLicenseSet);
        System.debug('####renewalApplications#size####' + renewalApplications.size());
        return renewalApplications;
    }

    public static List<Application__c> processMVDSoleProprietor(List<Application__c> records) {
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicesnes = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'CS'}, '');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicesnes)).getFieldValues('EmployeeLicense__c');
        List<Application__c> csApps = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(employeeLicenseIds);
        List<Application__c> csD1Apps = !forPushThrough ? ApplicationSelector.getD1RNApplicationsByLicenseIds(employeeLicenseIds) : ApplicationSelector.getPrevD1RNApplicationsByLicenseIds(employeeLicenseIds);
   
        List<Application__c> renewalApplications = new ApplicationDomain(records).filterApplicationByLicenseIds(new Set<String>(licenseIds));
        renewalApplications.addAll(csD1Apps);

        if(!csD1Apps.isEmpty() || Test.isRunningTest()){            
            List<AssociatedLicense__c> mvbAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'MVB'}, '');
            List<String> mvbLicenseIds = (List<String>)new AssociatedLicenseDomain(mvbAssociatedLicenses).getFieldValues('EntityLicense__c');
            List<Application__c> mvbRNApps = !forPushThrough ? ApplicationSelector.getRNApplicationsByLicenseIds(mvbLicenseIds) : ApplicationSelector.getPrevRNApplicationsByLicenseIds(mvbLicenseIds); 
            renewalApplications.addAll(mvbRNApps);
        }

        return renewalApplications;
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