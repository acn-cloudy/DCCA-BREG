@isTest
public with sharing class LicenseTypeBatchUpdateLicenseTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        List<License__c> records = [Select Id, FlaggedforAudit__c from License__c ];
        for(License__c record: records) {
            record.FlaggedforAudit__c = true;
        }
        update records;
    }
    public static testMethod void testBatchJob() {
        LicenseType__c licenseType = [Select Id from LicenseType__c limit 1];

        LicenseTypeBatchUpdateLicense ltBatchJob = new LicenseTypeBatchUpdateLicense('FlaggedforAudit__c', 'true', licenseType.Id, 'FlaggedforAudit__c');
        LicenseTypeBatchUpdateLicense ltBatchJobRenewal = new LicenseTypeBatchUpdateLicense('FlaggedforAudit__c', 'true', licenseType.Id, 'FlaggedforAudit__c', true);
        Database.executeBatch(ltBatchJob, 100);
        Database.executeBatch(ltBatchJobRenewal, 100);
    }
}