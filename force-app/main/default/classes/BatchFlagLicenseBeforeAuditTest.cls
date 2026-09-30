/*****
 * Test code for BatchFlagLicenseBeforeAudit
 * 00029406
 * Created Date: 6/26/23
 * Created By: Alvin Zhou
 * *** */
@isTest
private class BatchFlagLicenseBeforeAuditTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        List<License__c> records = [Select Id, FlaggedforAudit__c, AuditDate__c, AuditNumber__c from License__c];
        Integer index = 0;
        for(License__c record: records){
            record.FlaggedforAudit__c = true;
            record.AuditDate__c = Date.today();
            record.AuditNumber__c = index;
            index ++;
        }
        update records;
    }

    @isTest static void testBatch() {
        List<LicenseType__c> licenseTypes = [Select Id from LicenseType__c];
        List<String> licenseTypeIds = (new LicenseTypeDomain(licenseTypes)).getIds();
        Set<String> licenseTypeIdSet = new Set<String>();
        licenseTypeIdSet.addAll(licenseTypeIds);
        Test.startTest();
        BatchFlagLicenseBeforeAudit batch = new BatchFlagLicenseBeforeAudit(licenseTypeIdSet);
        Database.executeBatch(batch);
        Test.stopTest();
    }

    @isTest static void testBatch2() {
        List<LicenseType__c> licenseTypes = [Select Id from LicenseType__c];
        List<String> licenseTypeIds = (new LicenseTypeDomain(licenseTypes)).getIds();
        Set<String> licenseTypeIdSet = new Set<String>();
        licenseTypeIdSet.addAll(licenseTypeIds);
        Test.startTest();
        BatchFlagLicenseBeforeAudit batch = new BatchFlagLicenseBeforeAudit(licenseTypeIds.get(0), true);
        Database.executeBatch(batch);
        Test.stopTest();
    }

    @isTest static void testBatch3() {
        List<LicenseType__c> licenseTypes = [Select Id from LicenseType__c];
        List<String> licenseTypeIds = (new LicenseTypeDomain(licenseTypes)).getIds();
        Set<String> licenseTypeIdSet = new Set<String>();
        licenseTypeIdSet.addAll(licenseTypeIds);
        Test.startTest();
        BatchFlagLicenseBeforeAudit batch = new BatchFlagLicenseBeforeAudit(licenseTypeIds.get(0));
        Database.executeBatch(batch);
        Test.stopTest();
    }

    @isTest static void testBatchWithAuditFilters() {
        String ltId = [SELECT Id FROM LicenseType__c LIMIT 1].Id;
        Set<String> statuses = new Set<String>{ 'C - Current, Valid & In Good Standing' };
        Set<String> activeInactive = new Set<String>{ 'Active' };
        Test.startTest();
        new BatchFlagLicenseBeforeAudit(ltId, true, statuses);
        Database.executeBatch(new BatchFlagLicenseBeforeAudit(ltId, true, statuses, activeInactive));
        Test.stopTest();
    }

}