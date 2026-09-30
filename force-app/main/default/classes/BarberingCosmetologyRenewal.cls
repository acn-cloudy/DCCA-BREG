public class BarberingCosmetologyRenewal {

    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    @InvocableMethod(
        label='Barbering Cosmetology Renewal'
        description='Renew application with license types BAR BAS/BSH BED BSC'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<Results> responseWrapper= new List<Results>();
        // Get Application Records
        if(System.isBatch()) {
            return responseWrapper;
        }
        List<String> appIds = new List<String>();
        for(Input inp: inputs) {
            appIds.add(inp.record.Id);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        processApplication(applications);
        
        
        for(Input inp: inputs) {
            Results re = new Results();
            re.operationOutcome = 'Success';
            responseWrapper.add(re);
        }
        return responseWrapper;
    }

    public static void processApplication(List<Application__c> applications) {
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
        
        List<Application__c> appsForClassificationForCheck = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String> {'I', 'BSC'});

        // get the licenseIdSet
        List<LicenseClassification__c> lclassifications = checkOnClassifcations(appsForClassificationForCheck);
        Map<String, List<LicenseClassification__c>> classifications = (new LicenseClassificationDomain(lclassifications)).getLicenseId2Classifications();
        
        // Check next step: 
        // BSC
        List<Application__c> bscApps = (new ApplicationDomain(appsForClassificationForCheck)).filterAppByLicenseTypes(new Set<String>{'BSC'});
        if(!bscApps.isEmpty()) captureRenewApp(bscRenewCheck(bscApps, classifications));


        // I
        List<Application__c> iApps = (new ApplicationDomain(appsForClassificationForCheck)).filterAppByLicenseTypes(new Set<String>{'I'});
        if(!iApps.isEmpty()) captureRenewApp(iRenewCheck(classifications, iApps));
        
        // BAR
        List<Application__c> barApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String>{'BAR'});
        if(!barApps.isEmpty()) captureRenewApp(barRenewCheck(barApps));

        // BAS
        List<Application__c> basApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String>{'BAS'});
        if(!basApps.isEmpty()) captureRenewApp(basBshRenewCheck(basApps, 'BAR'));
        // BSH
        List<Application__c> bshApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String>{'BSH'});
        if(!bshApps.isEmpty()) captureRenewApp(basBshRenewCheck(bshApps, 'BEO'));

        // BEO
        List<Application__c> beoApps = (new ApplicationDomain(appsForCustom)).filterAppByLicenseTypes(new Set<String>{'BEO'});
        if(!beoApps.isEmpty()) captureRenewApp(beoRenewCheck(beoApps));

        //  get all that I applications that are going for renew.
        List<Application__c> iApplications = (new ApplicationDomain(renewApps.values())).filterAppByLicenseTypes(new Set<String> {'I'});
        if(!iApplications.isEmpty()) captureRenewApp(extraBSCAppRenew(iApplications));

        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        appsForUpdate.putAll(renewApps);
        // Capture for D1 Update:
        List<Application__c> d1Update = (new ApplicationDomain(appsForCustom)).filterRecordsByIds(renewApps.keySet());
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

        checkToCreateLicenseHistory(appsForUpdate.values());

        // Filter records to launch Application: Renewing Inactive flow
        List<Application__c> appsForInactive = (new ApplicationDomain(applications)).filterApplicationsForInactiveRenew();
        for(Application__c record: appsForInactive) {
            lanchRenewingInactiveFlow(record);
        }
    }

    public static List<Application__c> extraBSCAppRenew(List<Application__c> iApplications) {
        
        List<Application__c> iApplicationsTobeRenewed = (new ApplicationDomain(iApplications)).filterRecordByStatus('HC - Application Completed');
        // For all the I applications, we need to do a reverse check to find the bsc applications
        List<String> iLicenseIds 
            = (List<String> ) (new ApplicationDomain(iApplicationsTobeRenewed)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenseBSC 
            = AssociatedLicenseSelector.getAssociatedLicensesForEntityLicenseBSC(iLicenseIds);
        List<String> associatedIds = (new AssociatedLicenseDomain(associatedLicenseBSC)).getIds();
        
        Map<String, List<AssociatedLicense__c>> bscAssociatedLicensesMap = (new AssociatedLicenseDomain(associatedLicenseBSC)).getEntityId2Records();
        List<Application__c> applicationForBSC = ApplicationSelector.getRenewalApplicationsByLicenseIds(new List<String>(bscAssociatedLicensesMap.keySet()));

        List<AssociatedLicense__c> bscAssociatedLicenses = AssociatedLicenseSelector.getAssociatedLicensesForEmployeeLicenseIAndIds(bscAssociatedLicensesMap.keySet(), associatedIds);
        bscAssociatedLicensesMap = (new AssociatedLicenseDomain(bscAssociatedLicenses)).getEntityId2Records();

        List<Application__c> bscApplicationsFurtherCheck = (new ApplicationDomain(applicationForBSC)).filterApplicationOnAssociatedLicenseSize(bscAssociatedLicensesMap);
        List<LicenseClassification__c> lclassifications = checkOnClassifcations(bscApplicationsFurtherCheck);
        Map<String, List<LicenseClassification__c>> classifications = (new LicenseClassificationDomain(lclassifications)).getLicenseId2Classifications();
        return bscRenewCheck(bscApplicationsFurtherCheck, classifications, bscAssociatedLicenses);
    }

    public static List<Application__c> beoRenewCheck(List<Application__c> records) {
        List<Application__c> beoApplications = (new ApplicationDomain(records)).filterApplicationsNotForInactiveRenew();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getActiveBSHEntityLicenses(licenseIds);
        List<String> bshEntityLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        List<Application__c> bshApplications = ApplicationSelector.getRenewalApplicationsByLicenseIds(bshEntityLicenseIds);

        List<String> applicantIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('Applicant__c');
        List<LicenseClassification__c> iClassifications = LicenseClassificationSelector.getRRecordsByAccountdsAndLT(applicantIds, new List<String>{'I'});
        List<String> iLicenseIds = (List<String>) (new LicenseClassificationDomain(iClassifications)).getFieldValues('License__c');

        List<Application__c> iApplications = ApplicationSelector.getRenewalApplicationsByLicenseIds(iLicenseIds);
        Map<String, List<LicenseClassification__c>> iclassificationMap = (new LicenseClassificationDomain(iClassifications)).getLicenseId2Classifications();
        List<LicenseClassification__c> beoClassifications = checkOnClassifcations(records);
        Map<String, List<LicenseClassification__c>> beoClassificationMap = (new LicenseClassificationDomain(beoClassifications)).getLicenseId2Classifications();
        Map<String, List<LicenseClassification__c>> classMap = new Map<String, List<LicenseClassification__c>>();
        for(String str: beoClassificationMap.keySet()) {
            classMap.put(str, beoClassificationMap.get(str));
        }

        for(String str: iclassificationMap.keySet()) {
            classMap.put(str, iclassificationMap.get(str));
        }
        Map<String, Set<String>> licenseeId2LicenseId = (new LicenseClassificationDomain(beoClassifications)).getLicenseeId2LicenseSet();
        List<Application__c> appsForUpdate = (new ApplicationDomain(iApplications)).checkBEOClassifications(classMap, licenseeId2LicenseId);
        appsForUpdate.addAll(bshApplications);
        appsForUpdate.addAll(beoApplications);

        (new ApplicationDomain(appsForUpdate)).renewApplication();
        return appsForUpdate;

    }

    public static List<Application__c> basBshRenewCheck(List<Application__c> records, String licenseType) {
        List<License__c> licensesForRenew = (new ApplicationDomain(records)).getRenewLicenses();
        List<License__c> soleOwnerLicenses = (new LicenseDomain(licensesForRenew)).filterLicenseBySoleOwner(true);
        List<License__c> nonSoleOwnerLicenses = (new LicenseDomain(licensesForRenew)).filterLicenseBySoleOwner(false);
        List<String> soleOwnerIds = new LicenseDomain(soleOwnerLicenses).getIds();
        List<String> nonSoleOwnerIds = new LicenseDomain(nonSoleOwnerLicenses).getIds();
        List<AssociatedLicense__c> associatedLicenses 
            = AssociatedLicenseSelector.getAssociatedLicensesWWoSoleOwner(soleOwnerIds, nonSoleOwnerIds, licenseType);
        
        Map<String, List<AssociatedLicense__c>> associatedLicenseMap 
            = (new AssociatedLicenseDomain(associatedLicenses)).getEntityId2Records();
        
        List<Application__c> recordsForUpdate = new ApplicationDomain(records).filterApplicationByLicenseIds(associatedLicenseMap.keySet());
        (new ApplicationDomain(recordsForUpdate)).renewApplication();


        return recordsForUpdate;
    }

    public static List<Application__c> barRenewCheck(List<Application__c> records) {
        List<Application__c> appsForRenew = new List<Application__c>();
        List<String> currentLicenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> basEntityLicenses = AssociatedLicenseSelector.getActiveBASEntityLicenses(currentLicenseIds);
        List<String> entityLicenseIds = (List<String>) (new AssociatedLicenseDomain(basEntityLicenses)).getFieldValues('EntityLicense__c');
        List<Application__c> basAppsForRenew = ApplicationSelector.getRenewalApplicationsByLicenseIds(entityLicenseIds);
        appsForRenew.addAll(records);
        appsForRenew.addAll(basAppsForRenew);
        (new ApplicationDomain(appsForRenew)).updateToHCApplicationCompleted();
        return appsForRenew;
    }

    public static List<Application__c> iRenewCheck(Map<String, List<LicenseClassification__c>> classifications, List<Application__c> records) {
        Set<String> licenseIdSet = classifications.keySet();
        List<Application__c> recordsFiltered = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdSet);
        List<String> applicantIds = (List<String>) (new ApplicationDomain(recordsFiltered)).getFieldValues('Applicant__c');
        List<LicenseClassification__c> beoClassifications = LicenseClassificationSelector.getValidRecordsByAccountdsAndLT(applicantIds, new List<String>{'BEO'});
        Map<String, List<LicenseClassification__c>> lId2Classifications = (new LicenseClassificationDomain(beoClassifications)).getLicenseId2Classifications();
        Map<String, Set<String>> licenseeId2LicenseId = (new LicenseClassificationDomain(beoClassifications)).getLicenseeId2LicenseSet();
        Map<String, List<LicenseClassification__c>> classMap = new Map<String, List<LicenseClassification__c>>();
        for(String str: lId2Classifications.keySet()) {
            classMap.put(str, lId2Classifications.get(str));
        }

        for(String str: classifications.keySet()) {
            classMap.put(str, classifications.get(str));
        }
        List<Application__c> appsForUpdate = (new ApplicationDomain(recordsFiltered)).checkBEOClassifications(classMap, licenseeId2LicenseId);

        return appsForUpdate;
    }
    public static void captureRenewApp(List<Application__c> records) {
        for(Application__c app: records) {
            renewApps.put(app.Id, app);
        }
    }

    public static List<Application__c> bscRenewCheck(List<Application__c> records, 
        Map<String, List<LicenseClassification__c>> classifications, List<AssociatedLicense__c> bscAssociatedLicenses) {

        Set<String> licenseIdSet = classifications.keySet();
        List<Application__c> bscAppsFiltered = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdSet);
        
        Map<String, List<AssociatedLicense__c>> bscAssociatedLicensesMap = (new AssociatedLicenseDomain(bscAssociatedLicenses)).getEntityId2Records();
        //  Check for the if size is more than 2
        // Query Associated License;
        List<Application__c> bscApplicationsFurtherCheck = (new ApplicationDomain(bscAppsFiltered)).filterApplicationOnAssociatedLicenseSize(bscAssociatedLicensesMap);
        List<AssociatedLicense__c> bscFilteredAssociatedLicenses = (new ApplicationDomain(bscApplicationsFurtherCheck)).getAllAssociatedLicenses(bscAssociatedLicensesMap);
        List<String> bscemployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(bscFilteredAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        // Query Calssifications
        List<LicenseClassification__c> bscEmployeeClassifications = LicenseClassificationSelector.getValidGoodLicenseClassifications(bscemployeeLicenseIds);
        Map<String, List<LicenseClassification__c>> bscEmployeeClassificationMap = (new LicenseClassificationDomain(bscEmployeeClassifications)).getLicenseId2Classifications(); 
        Map<String, List<LicenseClassification__c>> classMap = new Map<String, List<LicenseClassification__c>>();
        for(String str: bscEmployeeClassificationMap.keySet()) {
            classMap.put(str, bscEmployeeClassificationMap.get(str));
        }

        for(String str: classifications.keySet()) {
            classMap.put(str, classifications.get(str));
        }
        List<Application__c> appsForUpdate = (new ApplicationDomain(bscApplicationsFurtherCheck)).checkBSCClassifications(classMap, bscAssociatedLicensesMap);
        
        return appsForUpdate;


    }
    public static List<Application__c> bscRenewCheck( List<Application__c> records, Map<String, List<LicenseClassification__c>> classifications) {

        Set<String> licenseIdSet = classifications.keySet();
        List<Application__c> bscAppsFiltered = (new ApplicationDomain(records)).filterApplicationByLicenseIds(licenseIdSet);
        List<String> bcsLicenseIds = (List<String>) (new ApplicationDomain(bscAppsFiltered)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> bscAssociatedLicenses = AssociatedLicenseSelector.getAssociatedLicensesForEmployeeLicenseI(bcsLicenseIds);
        return bscRenewCheck(records, classifications, bscAssociatedLicenses);
    }

    public static List<LicenseClassification__c> checkOnClassifcations(List<Application__c> applications) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(applications)).getFieldValues('CurrentLicense__c');
        // Query Classifications
        List<LicenseClassification__c> licenseClassifications = LicenseClassificationSelector.getValidGoodLicenseClassifications(licenseIds);
        return licenseClassifications;
    }

    public class Input {
        @InvocableVariable(label='Application Record for Input' description='Input Application for BAS Renewals' required=true)
        public Application__c record;
        @InvocableVariable(label='License Record for Input' description='Input License for BAS Renewals' required=true)
        public License__c license;

        public void connectLicense() {
            String appId = record.Id;
            String licenseId = license.Id;
            record = record.clone();
            record.Id = appId;
            license = license.clone();
            license.Id = licenseId;
            record.CurrentLicense__r = license;
        }
    }

    public static void checkToCreateLicenseHistory(List<Application__c> applications) {
        List<String> renewLicenseIds = (List<String>) (new ApplicationDomain(applications)).getFieldValues('CurrentLicense__c');
        List<LicenseHistory__c> histories 
                = LicenseHistorySelector.getHistories(new List<String>{'RNEW - RENEWED', 'RSTR - Restoration'}, renewLicenseIds);
            
        Map<String, String> licenseId2LicensePeriodRNEW 
            = (new ApplicationDomain(applications)).getLicenseId2LicensePeriodRNEW();
        
        Set<String> licenseIdsWithHistory = (new LicenseHistoryDomain(histories)
            ).checkExistingLicenses(licenseId2LicensePeriodRNEW);
        
        Set<String> renewLicenseIdSet = new Set<String>();
        renewLicenseIdSet.addAll(renewLicenseIds);
        renewLicenseIdSet.removeAll(licenseIdsWithHistory);
        
        (new ApplicationDomain(applications)).createLicenseHistory(renewLicenseIdSet);
    }

    public static void lanchRenewingInactiveFlow(Application__c record) {
        Map<String, Object> params = new Map<String, Object>();
        params.put('InputApplication', record);
        Flow.Interview.Application_Renewing_Inactive_Flow f = new Flow.Interview.Application_Renewing_Inactive_Flow(params);
        f.start();
    }

    public class Results {
        @InvocableVariable(label='Records for Output' description='Output for Real Estate Branch Renewals' required=true)
        public String operationOutcome;
    }
}