global class BarberingCosRenewalPushThru extends ApplicationRenewalPushThru {
    global BarberingCosRenewalPushThru() {
        super(new List<String> {'BAS', 'BSH', 'BSC', 'I'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        // Check next step: 
        // BSC
        List<Application__c> bscApps = (new ApplicationDomain(records)).filterAppByLicenseTypes(new Set<String>{'BSC'});
        if(!bscApps.isEmpty()) captureRenewApp(bscRenewCheck(bscApps));
        // I
        List<Application__c> iApps = (new ApplicationDomain(records)).filterAppByLicenseTypes(new Set<String>{'I'});
        if(!iApps.isEmpty()) captureRenewApp(iRenewCheck(iApps));
        
        // BAS
        List<Application__c> basApps = (new ApplicationDomain(records)).filterAppByLicenseTypes(new Set<String>{'BAS'});
        if(!basApps.isEmpty()) captureRenewApp(BarberingCosmetologyRenewal.basBshRenewCheck(basApps, 'BAR'));
        // BSH
        List<Application__c> bshApps = (new ApplicationDomain(records)).filterAppByLicenseTypes(new Set<String>{'BSH'});
        if(!bshApps.isEmpty()) captureRenewApp(BarberingCosmetologyRenewal.basBshRenewCheck(bshApps, 'BEO'));

        //  get all that I applications that are going for renew.
        List<Application__c> iApplications = (new ApplicationDomain(appMap.values())).filterAppByLicenseTypes(new Set<String> {'I'});
        if(!iApplications.isEmpty()) captureRenewApp(extraBSCAppRenew(iApplications));
    }

    private void captureRenewApp(List<Application__c> records) {
        for(Application__c app: records) {
            appMap.put(app.Id, app);
        }
    }
    public List<Application__c>  iRenewCheck(List<Application__c> records) {
        List<String> applicantIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('Applicant__c');
        
        List<License__c> beoLicenseRecords = LicenseSelector.getLicenseByLicenseTypeStatusAndLicensee('BEO', applicantIds, 'C - Current, Valid & In Good Standing');
        List<String> beoLicenseeIds = (List<String>) new LicenseDomain(beoLicenseRecords).getFieldValues('Licensee__c');
        Set<String> beoIdSet = new Set<String>();
        beoIdSet.addAll(beoLicenseeIds);

        List<Application__c> appsForUpdate =  new List<Application__c>();
        for(Application__c app: records) {
            if(beoIdSet.contains(app.Applicant__c)) {
                app.Status__c = 'HC - Application Completed';
                app.Phase__c = 'H - License Generation';
                appsForUpdate.add(app);
            }
        }
        return appsForUpdate;
    }

    public static List<Application__c> bscRenewCheck(List<Application__c> records) {
        List<String> bcsLicenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> bscAssociatedLicenses = AssociatedLicenseSelector.getAssociatedLicensesForEmployeeLicenseI(bcsLicenseIds);
        Map<String, List<AssociatedLicense__c>> bscAssociatedLicensesMap = (new AssociatedLicenseDomain(bscAssociatedLicenses)).getEntityId2Records();
        //  Check for the if size is more than 2
        // Query Associated License;
        List<Application__c> bscApplicationsFurtherCheck = (new ApplicationDomain(records)).filterApplicationOnAssociatedLicenseSize(bscAssociatedLicensesMap);
        List<AssociatedLicense__c> bscFilteredAssociatedLicenses = (new ApplicationDomain(bscApplicationsFurtherCheck)).getAllAssociatedLicenses(bscAssociatedLicensesMap);
        Set<String> bscLicenseIds = new Set<String>();
        for(AssociatedLicense__c associatedLicense: bscAssociatedLicenses) {
            if(associatedLicense.PositionStatus__c == 'D - Designated') {
                bscLicenseIds.add(associatedLicense.EntityLicense__c);
            }
        }

        List<Application__c> appsForUpdate =  new List<Application__c>();
        for(Application__c app: bscApplicationsFurtherCheck) {
            if(bscLicenseIds.contains(app.CurrentLicense__c)) {
                app.Status__c = 'HC - Application Completed';
                app.Phase__c = 'H - License Generation';
                appsForUpdate.add(app);
            }
        }
        return appsForUpdate;

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
        List<AssociatedLicense__c> bscFilteredAssociatedLicenses = (new ApplicationDomain(bscApplicationsFurtherCheck)).getAllAssociatedLicenses(bscAssociatedLicensesMap);
        Set<String> bscLicenseIds = new Set<String>();
        for(AssociatedLicense__c associatedLicense: bscAssociatedLicenses) {
            if(associatedLicense.PositionStatus__c == 'D - Designated') {
                bscLicenseIds.add(associatedLicense.EntityLicense__c);
            }
        }

        List<Application__c> appsForUpdate =  new List<Application__c>();
        for(Application__c app: bscApplicationsFurtherCheck) {
            if(bscLicenseIds.contains(app.CurrentLicense__c)) {
                app.Status__c = 'HC - Application Completed';
                app.Phase__c = 'H - License Generation';
                appsForUpdate.add(app);
            }
        }
        return appsForUpdate;
    }


    
}