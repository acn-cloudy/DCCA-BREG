global class MVRRenewalPushThruBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private String query = 'Select Id, SoleOwner__c, LicenseType__r.Name from License__c where (LicenseType__r.Name = \'RD\' or LicenseType__r.Name = \'RDS\')' 
    +  ' and ThisLicenseRenewed__c = true and Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\' ';
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> records = (List<License__c>)scope;
        List<License__c> soleRecords = (new LicenseDomain(records)).filterLicenseBySoleOwner(true);
        List<License__c> unSoleRecords = (new LicenseDomain(records)).filterLicenseBySoleOwner(false);

        
        List<String> soleRecordIds = (new LicenseDomain(soleRecords)).getIds();
        List<String> unSoleRecordIds = (new LicenseDomain(unSoleRecords)).getIds();

        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<AssociatedLicense__c> associatedLicensesSoleOwner = AssociatedLicenseSelector.getSoleOwnerLicenses(soleRecordIds);
        List<AssociatedLicense__c> associatedLicensesUnSoleOwner = AssociatedLicenseSelector.getUnSoleOwnerLicenses(unSoleRecordIds);
        associatedLicenses.addAll(associatedLicensesSoleOwner);
        associatedLicenses.addAll(associatedLicensesUnSoleOwner);
        Set<String> entityLicenseIds = new Set<String>();
        for(AssociatedLicense__c record: associatedLicenses) {
            entityLicenseIds.add(record.EntityLicense__c);
        }
        List<License__c> filteredLicenses = (new LicenseDomain(records)).filterRecords(entityLicenseIds);
        if(!filteredLicenses.isEmpty()) {
            List<License__c> rdLicenses = (new LicenseDomain(filteredLicenses)).getLicenseByLicenseTypeCodes(new Set<String>{'RD'});
            List<String> rdLicenseIds = (new LicenseDomain(rdLicenses)).getIds();

            List<License__c> rdsLicenses = (new LicenseDomain(filteredLicenses)).getLicenseByLicenseTypeCodes(new Set<String>{'RDS'});
            
            Set<String> rdsLicenseIds = processRDSLicense(rdsLicenses);
            rdLicenseIds.addAll(rdsLicenseIds);

            System.debug('####rdLicenseIds###' + rdLicenseIds);
            processRDLicense(rdLicenseIds);
        }
    }

    // 00029027
    public static Set<String> processRDSLicense(List<License__c> records) {
        List<String> licenseIds = (new LicenseDomain(records)).getIds();
        List<AssociatedLicense__c> associatedLicenses 
            = AssociatedLicenseSelector.getActiveAssociatedLicenses(licenseIds);
        // Check if it is MR Licenses
        Set<String> MREntityLicenseIds = (new AssociatedLicenseDomain(associatedLicenses)).getMRAssociatedLicenses();

        // Check if it is None MR Licenses
        Set<String> noneMRLicenseIds = (new AssociatedLicenseDomain(associatedLicenses)).getNoneMRAssociatedLicenses();
        List<String> noneMRLicenseIdList = new List<String>();
        noneMRLicenseIdList.addAll(noneMRLicenseIds);
        Map<String, Boolean> employeeLicenseWithAllClasses = LicenseClassificationService.checkClassNames(noneMRLicenseIdList);
        Set<String> noneMREntityLicenseIds 
            = (new AssociatedLicenseDomain(associatedLicenses)
                ).getEntityLicenseIdsByClassificationCheck(employeeLicenseWithAllClasses);
        MREntityLicenseIds.addAll(noneMREntityLicenseIds);
        return MREntityLicenseIds;
    }

    // 00029027
    public static void processRDLicense(List<String> licenseIds) {
        // Query Renewal Application,
        List<Application__c> applications = ApplicationSelector.getRenewalApplications(licenseIds);
        // Renew current license
        if(!applications.isEmpty()) {
            // Skip Application Phase and status update
            ApplicationService.skipApplicationPhaseUpdate = true;
            (new ApplicationDomain(applications)).renewApplication();
            // 
            update applications;

            List<License__c> licenses = (new ApplicationDomain(applications)).getRenewLicenses();
            (new LicenseDomain(licenses)).renewLicenses();
            update licenses;
            
            List<String> renewLicenseIds = (new LicenseDomain(licenses)).getIds();
            
            // 
            List<LicenseHistory__c> histories 
                = LicenseHistorySelector.getHistories(new List<String>{'RNEW - RENEWED'}, renewLicenseIds);
            
            Map<String, String> licenseId2LicensePeriodRNEW 
                = (new ApplicationDomain(applications)).getLicenseId2LicensePeriodRNEW();
            
            Set<String> licenseIdsWithHistory = (new LicenseHistoryDomain(histories)
                ).checkExistingLicenses(licenseId2LicensePeriodRNEW);
            
            Set<String> renewLicenseIdSet = new Set<String>();
            renewLicenseIdSet.addAll(renewLicenseIds);
            renewLicenseIdSet.removeAll(licenseIdsWithHistory);
            
            (new ApplicationDomain(applications)).createLicenseHistory(renewLicenseIdSet);
            // Reset Application Phase and status update
            ApplicationService.skipApplicationPhaseUpdate = false;
        }
        
    }

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new MVRRenewalPushThruBatch(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {

    }
}