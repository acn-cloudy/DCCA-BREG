@isTest
private class CertificateRequestTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        Account acc = [Select Id, Contact__c from Account limit 1];
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;
        acc.Contact__c = cnt.Id;
        update acc;
    }
    private static testMethod void testCreateCertificateRequest() {
        Test.startTest();
        License__c license = [Select Id from License__c limit 1];
        
        CertificateRequest__c record = new CertificateRequest__c();
        record.License__c = license.Id;
        record.CertificateType__c = 'B - POCKET ID & WALL CERTIFICATE';
    
        insert record;
        Test.stopTest();
        
    }
    private static testMethod void testCreateCertificateRequest2() {
        Test.startTest();
        License__c license = [Select Id from License__c limit 1];

        CertificateRequest__c record = new CertificateRequest__c();
        record.License__c = license.Id;
        record.CertificateType__c = 'C - WALL CERTIFICATE';

        insert record;
        Test.stopTest();
        
    }
    private static testMethod void testCreateCertificateRequest3() {
        Test.startTest();
        License__c license = [Select Id from License__c limit 1];
        
        CertificateRequest__c record = new CertificateRequest__c();
        record.License__c = license.Id;
        record.CertificateType__c = 'P - POCKET IDENTIFICATION CARD';

        insert record;
        Test.stopTest();
        
    }
}