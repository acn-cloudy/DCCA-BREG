public class ContractorRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    @InvocableMethod(
        label='Contractor Renewal'
        description='Renew application with license types CT - Entity, CT - Sole Proprietor and CT - RME'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> appIds = new List<String>();
        for(Input inp: inputs) {
            appIds.add(inp.record.Id);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
      
        List<Application__c> ctEntityApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'CT - Entity'});
        if(!ctEntityApps.isEmpty()) captureRenewApp(processCTEntity(ctEntityApps));

        List<Application__c> ctSoleApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'CT - Sole Proprietor'});
        if(!ctSoleApps.isEmpty()) captureRenewApp(processCTSole(ctSoleApps));
                
        List<Application__c> ctRMEApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'CT - RME'});
        if(!ctRMEApps.isEmpty()) captureRenewApp(processCTRME(ctRMEApps));  

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
        
        List<Application__c> currentApps = new List<Application__c>();
        List<Input> extraApps = new List<Input>();
        for(Application__c appForUpdate : appsForUpdate.values()){
            Input input = new Input();
            input.record = appForUpdate;
            if(appIds.contains(appForUpdate.Id)) currentApps.add(appForUpdate);
            else extraApps.add(input);
        }

        // update licenses
        List<License__c> renewCurrentLicenses = (new ApplicationDomain(currentApps)).renewLicenses();
        update renewCurrentLicenses; 

        // update applications
        if(!currentApps.isEmpty()) update currentApps;  

        BarberingCosmetologyRenewal.checkToCreateLicenseHistory(currentApps);

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

        // Clear values variables
        appIdsForRenew = new Set<String>();
        renewApps = new Map<String, Application__c>();         
        if(!extraApps.isEmpty()) execute(extraApps);

        return responseWrapper;
    }   

    public static List<Application__c> processCTEntity(List<Application__c> records) {   
        List<Application__c> renewalApplications = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> pAssocaitedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String> {'CT - RME', 'CT - Sole Proprietor'},' and PositionStatus__c = \'P - PRINCIPAL\'');
        List<String> entityIds = (List<String>) (new AssociatedLicenseDomain(pAssocaitedLicenses)).getFieldValues('EntityLicense__c');
           
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(entityIds, new List<String>{'CT - RME', 'CT - Sole Proprietor'}, ' and EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
      
        List<AssociatedLicense__c> assocaitedLicenses = AssociatedLicenseSelector.getPDGByEntity(entityIds, new List<String> {'CT - RME', 'CT - Sole Proprietor'}, '');
        Map<String, List<String>> notCurrentEntityIds = new Map<String, List<String>>();
        List<String> notCurrentEmployeeIds = new List<String>();
        for(AssociatedLicense__c assocaitedLicense : assocaitedLicenses){
            List<String> employeeList = notCurrentEntityIds.get(assocaitedLicense.EntityLicense__c);
            if(employeeList == null) employeeList = new List<String>();
            employeeList.add(assocaitedLicense.EmployeeLicense__c);
            notCurrentEntityIds.put(assocaitedLicense.EntityLicense__c, employeeList);
            notCurrentEmployeeIds.add(assocaitedLicense.EmployeeLicense__c);
        }

        List<Application__c> employeeApps = ApplicationSelector.getRNApplicationsByLicenseIds(notCurrentEmployeeIds);
        List<String> employeeIds = (List<String>) (new ApplicationDomain(employeeApps)).getFieldValues('CurrentLicense__c');
        List<String> withAllD1Employees = new List<String>();
        for(String entityId : notCurrentEntityIds.keySet()){
            Boolean allD1 = true;
            for(String employeeId : notCurrentEntityIds.get(entityId)){
                if(!employeeIds.contains(employeeId) && !cEmployeeLicenseIds.contains(employeeId)) allD1 = false;
            }
            if(allD1) withAllD1Employees.add(entityId);
        }

        // update licenses
        List<License__c> renewChildrenLicenses = new List<License__c>();
        for(String withAllD1Employee : withAllD1Employees){
            List<Application__c> employeeD1Apps = (new ApplicationDomain(employeeApps)).filterApplicationByLicenseIds(new Set<String>(notCurrentEntityIds.get(withAllD1Employee)));
            (new ApplicationDomain(employeeD1Apps)).renewApplication();
            renewalApplications.addAll(employeeD1Apps);
            renewChildrenLicenses.addAll((new ApplicationDomain(employeeD1Apps)).renewLicenses());
        }

        List<Application__c> withAllD1Apps = (new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(withAllD1Employees));
        if(!withAllD1Apps.isEmpty()) renewChildrenLicenses.addAll((new ApplicationDomain(withAllD1Apps)).renewLicenses());
        if(!withAllD1Apps.isEmpty()) renewalApplications.addAll(withAllD1Apps);

        Set<License__c> licenseSet = new Set<License__c>(renewChildrenLicenses);
        if(!renewChildrenLicenses.isEmpty()) update new List<License__c>(licenseSet); 

        appIdsForRenew.addAll((new ApplicationDomain(renewalApplications)).getIdToApplication().keySet());
        return renewalApplications;
    }

    public static List<Application__c> processCTRME(List<Application__c> records) {   
        List<Application__c> appsForRenewal = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'CT - Entity', 'CT - Sole Proprietor'}, ' and EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        appsForRenewal.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEmployeeLicenseIds)));

        List<AssociatedLicense__c> cteAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'CT - Entity'}, ' and EntityLicenseStatus__c != \'C - Current, Valid & In Good Standing\'');
        List<String> cteEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cteAssociatedLicenses)).getFieldValues('EntityLicense__c');
   
        List<Application__c> cteEntityApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(cteEntityLicenseIds);
        if(!cteEntityApps.isEmpty()) (new ApplicationDomain(cteEntityApps)).renewApplication();
        if(!cteEntityApps.isEmpty()) appsForRenewal.addAll(cteEntityApps);    

        List<AssociatedLicense__c> ctsAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'CT - Sole Proprietor'}, ' and EntityLicenseStatus__c != \'C - Current, Valid & In Good Standing\'');
        List<String> ctsEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(ctsAssociatedLicenses)).getFieldValues('EntityLicense__c');
    
        List<Application__c> ctSoleApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(ctsEntityLicenseIds);
        if(!ctSoleApps.isEmpty()) (new ApplicationDomain(ctSoleApps)).renewApplication();
        if(!ctSoleApps.isEmpty()) appsForRenewal.addAll(ctSoleApps);   

        appIdsForRenew.addAll((new ApplicationDomain(appsForRenewal)).getIdToApplication().keySet());
        return appsForRenewal;
    } 

    public static List<Application__c> processCTSole(List<Application__c> records) {         
        List<Application__c> renewalApplications = new List<Application__c>();
        List<Application__c> unRestrictedRecords = new List<Application__c>();
        List<Application__c> restrictedRecords = new List<Application__c>();
        for(Application__c record: records) {
            if(record.CurrentLicense__r.LicenseRestriction__c != 'R - Restricted') {
                unRestrictedRecords.add(record);
            } else {
                restrictedRecords.add(record);
            }
        }
        
        List<String> forEntityProcess = new List<String>();    
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<String> cLicenseIds = new List<String>();
        
        List<AssociatedLicense__c> soleAppAssociatedLicenses = new List<AssociatedLicense__c>();
        List<String> restrictedLicenseIds = (List<String>) (new ApplicationDomain(restrictedRecords)).getFieldValues('CurrentLicense__c');        
        List<AssociatedLicense__c> cRestrictedAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds, new List<String>{'CT - RME'}, ' and EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cRestrictedEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cRestrictedAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<AssociatedLicense__c> restrictedAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(restrictedLicenseIds, new List<String>{'CT - RME'}, '');
        soleAppAssociatedLicenses.addAll(restrictedAssociatedLicenses);

        List<String> unrestrictedLicenseIds = (List<String>) (new ApplicationDomain(unrestrictedRecords)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> cUnrestrictedAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(unrestrictedLicenseIds, new List<String>{'CT - RME'}, ' and EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cUnrestrictedEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cUnrestrictedAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<AssociatedLicense__c> urestrictedAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(unrestrictedLicenseIds, new List<String>{'CT - RME'}, '');
        List<String> unrestrictedEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(urestrictedAssociatedLicenses)).getFieldValues('EntityLicense__c');
        soleAppAssociatedLicenses.addAll(urestrictedAssociatedLicenses);

        Map<String, List<String>> notCurrentEntityIds = new Map<String, List<String>>();
        List<String> notCurrentEmployeeIds = new List<String>();
        for(AssociatedLicense__c assocaitedLicense : soleAppAssociatedLicenses){
            List<String> employeeList = notCurrentEntityIds.get(assocaitedLicense.EntityLicense__c);
            if(employeeList == null) employeeList = new List<String>();
            employeeList.add(assocaitedLicense.EmployeeLicense__c);
            notCurrentEntityIds.put(assocaitedLicense.EntityLicense__c, employeeList);
            notCurrentEmployeeIds.add(assocaitedLicense.EmployeeLicense__c);
        }        

        List<Application__c> employeeApps = ApplicationSelector.getRNApplicationsByLicenseIds(notCurrentEmployeeIds);
        List<String> employeeIds = (List<String>) (new ApplicationDomain(employeeApps)).getFieldValues('CurrentLicense__c');
        List<String> withAllD1Employees = new List<String>();
        for(String entityId : notCurrentEntityIds.keySet()){
            Boolean allD1 = true;
            for(String employeeId : notCurrentEntityIds.get(entityId)){
                if(!employeeIds.contains(employeeId) && !cRestrictedEmployeeLicenseIds.contains(employeeId) && !cUnrestrictedEmployeeLicenseIds.contains(employeeId)) allD1 = false;
            }
            if(allD1) withAllD1Employees.add(entityId);
        }
        forEntityProcess.addAll(withAllD1Employees);

        List<License__c> renewChildrenLicenses = new List<License__c>();
        for(String withAllD1Employee : withAllD1Employees){
            List<Application__c> employeeD1Apps = (new ApplicationDomain(employeeApps)).filterApplicationByLicenseIds(new Set<String>(notCurrentEntityIds.get(withAllD1Employee)));
            (new ApplicationDomain(employeeD1Apps)).renewApplication();
            renewalApplications.addAll(employeeD1Apps);
            renewChildrenLicenses.addAll((new ApplicationDomain(employeeD1Apps)).renewLicenses());
        }

        List<Application__c> withAllD1Apps = (new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(withAllD1Employees));
        if(!withAllD1Apps.isEmpty()) renewChildrenLicenses.addAll((new ApplicationDomain(withAllD1Apps)).renewLicenses());
        if(!withAllD1Apps.isEmpty()) renewalApplications.addAll(withAllD1Apps);
        
        if(!renewChildrenLicenses.isEmpty()) update renewChildrenLicenses;
        appIdsForRenew.addAll((new ApplicationDomain(renewalApplications)).getIdToApplication().keySet());

        for(String unrestrictedLicenseId: unrestrictedLicenseIds){
            if(!unrestrictedEntityLicenseIds.contains(unrestrictedLicenseId)) renewalApplications.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>{unrestrictedLicenseId}));
            if(!unrestrictedEntityLicenseIds.contains(unrestrictedLicenseId)) forEntityProcess.add(unrestrictedLicenseId);
        }

        renewalApplications.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cLicenseIds)));

        List<Application__c> forEntityAppUpdates = new List<Application__c>();        
        List<AssociatedLicense__c> entityAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(forEntityProcess, new List<String>{'CT - Entity'}, '');
        List<String> entityAssociatedLicenseIds = (List<String>)(new AssociatedLicenseDomain(entityAssociatedLicenses)).getFieldValues('EntityLicense__c');

        if(!forEntityProcess.isEmpty()) forEntityAppUpdates = ApplicationSelector.getD1RNApplicationsByLicenseIds(entityAssociatedLicenseIds);
        if(!forEntityAppUpdates.isEmpty()) (new ApplicationDomain(forEntityAppUpdates)).renewApplication();
        if(!forEntityAppUpdates.isEmpty()) renewalApplications.addAll(forEntityAppUpdates);
 
        appIdsForRenew.addAll((new ApplicationDomain(renewalApplications)).getIdToApplication().keySet());
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