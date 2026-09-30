/*
 * ___________________________________________________________________________________
 * Create New Apex for Veterinarian Renewal called "VeterinarianRenewal"
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA04062024 - Created for Case 00034841
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 04/06/2024
 * __________________________________________________________________________________
 */
public class VeterinarianRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();

    @InvocableMethod(
        label='Veterinarian Renewal'
        description='Renew Veterinarian Licenses'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> appIds = new List<String>();
        for(Input inp: inputs) {
            appIds.add(inp.inputApplication.Id);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
        appIdsForRenew.addAll((new ApplicationDomain(appsForCustom)).getIds());


        List<Application__c> vEApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'VE'});
        if(!vEApps.isEmpty()) captureRenewApp(doVERenewals(vEApps));

        List<Application__c> vTApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'VT'});
        if(!vTApps.isEmpty()) captureRenewApp(doVTRenewals(vTApps));

        // Renew application
        (new ApplicationDomain(renewApps.values())).renewApplication();
        
        List<Application__c> d1Update = (new ApplicationDomain(appsForCustom)).filterRecordsByIds(renewApps.keySet());
        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        
        appsForUpdate.putAll(renewApps);

        for(Application__c record: d1Update) {
            if(!appsForUpdate.containsKey(record.Id)) {
                System.debug('######record.Status__c#####' + record.Status__c);
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

    public static List<Application__c> doVERenewals(List<Application__c> records) {
        List<Application__c> renewalApps = new List<Application__c>();
        renewalApps.addAll(records);
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'VT'}, '');
        List<String> employeeIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> vtDependentApps = ApplicationSelector.getRNApplicationsByLicenseIds(employeeIds);
        renewalApps.addAll(vtDependentApps);
        return renewalApps;
    }

    public static List<Application__c> doVTRenewals(List<Application__c> records){
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPestControlByEmployee(licenseIds, new List<String>{'VE'});
        List<String> employeeLicenseIds = (List<String>)new AssociatedLicenseDomain(associatedLicenses).getFieldValues('EmployeeLicense__c');
        Set<String> licenseIdSet = new Set<String>();
        licenseIdSet.addAll(employeeLicenseIds);

        List<Application__c> renewalApplications = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdSet);
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
        @InvocableVariable(label='License Record for Input' description='Input License' required=true)
        public License__c inputLicense;
        @InvocableVariable(label='Application Record for Input' description='Input Application' required=true)
        public Application__c inputApplication ;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output' required=true)
        public String operationOutcome;
    }
}