public class CommercialEmploymentRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    @InvocableMethod(
        label='Commercial Employment Renewal'
        description='Renew application with license types EMA, EMA - Sole Proprietor and EMP'
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
        List<Application__c> emaApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'EMA'});
        if(!emaApps.isEmpty()) captureRenewApp(processEMAApps(emaApps));

        List<Application__c> emaSoleApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'EMA - Sole Proprietor'});
        if(!emaSoleApps.isEmpty()) captureRenewApp(processEMASoleProprietorApps(emaSoleApps));
        
        List<Application__c> empApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'EMP'});
        if(!empApps.isEmpty()) captureRenewApp(processEMPApps(empApps));

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

    public static List<Application__c> processEMAApps(List<Application__c> records) {
        List<String> emaLicenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> empAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(emaLicenseIds, new List<String>{'EMP'}, '');
        List<String> empLicenseIds = (List<String>) new AssociatedLicenseDomain(empAssociatedLicenses).getFieldValues('EmployeeLicense__c');
        List<Application__c> empRNApps = ApplicationSelector.getRNApplicationsByLicenseIds(empLicenseIds);
        List<String> empRNLicenses = (List<String>)new ApplicationDomain(empRNApps).getFieldValues('CurrentLicense__c');
        Set<String> empRNLicenseSet = new Set<String>();
        empRNLicenseSet.addAll(empRNLicenses);

        Set<String> emaLicenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: empAssociatedLicenses) {
            if(empRNLicenseSet.contains(record.EmployeeLicense__c)) {
                emaLicenseIdSet.add(record.EntityLicense__c);
            }
        }

        List<Application__c> renewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(emaLicenseIdSet);
        
        List<String> emaLicenses = new List<String>();
        emaLicenses.addAll(emaLicenseIds);


        renewalApplications.addAll(empRNApps);

        return renewalApplications;
    }

    public static List<Application__c> processEMASoleProprietorApps(List<Application__c> records) {
        List<String> emaLicenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> empAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(emaLicenseIds, new List<String>{'EMP'}, ' and Position__c =\'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)\' ');
        List<String> empLicenseIds = (List<String>) new AssociatedLicenseDomain(empAssociatedLicenses).getFieldValues('EmployeeLicense__c');
        List<Application__c> empRNApps = ApplicationSelector.getRNApplicationsByLicenseIds(empLicenseIds);

        List<String> empRNLicenses = (List<String>)new ApplicationDomain(empRNApps).getFieldValues('CurrentLicense__c');
        Set<String> empRNLicenseSet = new Set<String>();
        empRNLicenseSet.addAll(empRNLicenses);

        Set<String> emaLicenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: empAssociatedLicenses) {
            if(empRNLicenseSet.contains(record.EmployeeLicense__c)) {
                emaLicenseIdSet.add(record.EntityLicense__c);
            }
        }

        List<Application__c> renewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(emaLicenseIdSet);
        
        List<String> emaLicenses = new List<String>();
        emaLicenses.addAll(emaLicenseIds);

        List<AssociatedLicense__c> empEAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(emaLicenses, new List<String>{'EMP'}, '');
        List<String> empEntityLicenseIds = (List<String>) (new AssociatedLicenseDomain(empEAssociatedLicenses)).getFieldValues('EntityLicense__c');
        
        List<Application__c> empRenewalApplications = ApplicationSelector.getRNApplicationsByLicenseIds(empEntityLicenseIds);

        renewalApplications.addAll(empRNApps);
        renewalApplications.addAll(empRenewalApplications);

        return renewalApplications;
    }
    
    public static List<Application__c> processEMPApps(List<Application__c> records) {
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'EMA', 'EMA - Sole Proprietor'}, '');
        List<String> entityLicenseIds = (List<String>)new AssociatedLicenseDomain(associatedLicenses).getFieldValues('EntityLicense__c');
        List<Application__c> emRNApps = ApplicationSelector.getRNApplicationsByLicenseIds(entityLicenseIds);
        List<String> emRNLicenses = (List<String>)new ApplicationDomain(emRNApps).getFieldValues('CurrentLicense__c');
        Set<String> emRNLicenseSet = new Set<String>();
        emRNLicenseSet.addAll(emRNLicenses);

        Set<String> emaLicenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: associatedLicenses) {
            if(emRNLicenseSet.contains(record.EntityLicense__c)) {
                emaLicenseIdSet.add(record.EmployeeLicense__c);
            }
        }

        List<Application__c> renewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(emaLicenseIdSet);
        

        List<AssociatedLicense__c> empEAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(emRNLicenses, new List<String>{'EMP'}, '');
        List<String> empEmployeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(empEAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        
        List<Application__c> empRenewalApplications = ApplicationSelector.getRNApplicationsByLicenseIds(empEmployeeLicenseIds);

        renewalApplications.addAll(emRNApps);
        renewalApplications.addAll(empRenewalApplications);

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