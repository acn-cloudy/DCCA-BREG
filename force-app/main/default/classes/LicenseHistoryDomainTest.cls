@isTest
private class LicenseHistoryDomainTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createDummyApplication();
    }
    @isTest
    static void testUpdateMarks() {
        List<LicenseType__c> licenseTypes = [Select Id, LicenseTypeEffectiveDate__c from LicenseType__c ];
        for(LicenseType__c record: licenseTypes) {
            record.LicenseTypeEffectiveDate__c = Date.today();
        }
        update licenseTypes;
        License__c license = [Select Id, LicenseType__r.PreviousLicensePeriod__c from License__c limit 1];
        LicenseHistory__c ih1 = new LicenseHistory__c();
        ih1.License__c = license.Id;
        ih1.TransactionType__c = 'RNEW - RENEWED' ;
        ih1.Remarks__c = 'Test';
        ih1.LicensePeriod__c = license.LicenseType__r.PreviousLicensePeriod__c;
        insert ih1;
        List<LicenseHistory__c> histories = [Select Id, License__r.LicenseType__r.PreviousLicensePeriod__c, LicensePeriod__c, Remarks__c from LicenseHistory__c];
        Test.startTest();
        (new LicenseHistoryDomain(histories)).updateMarks();
        Test.stopTest();
    }
}