@isTest
private class D1D2DependencyRefundNoticeTest {
    @TestSetup
    static void makeData(){
        Application__c app =  TestDataFactory.createDummyApplication();
        License__c license = [Select Id, LicenseType__r.Id, LicenseType__r.RenewalRefundNoticeTemplate__c from License__c limit 1];
        app.CurrentLicense__c = license.Id;
        insert app;
        LicenseHistory__c ih1 = new LicenseHistory__c();
        ih1.License__c = license.Id;
        ih1.TransactionType__c = 'RNEW - RENEWED' ;
        insert ih1;
        LicenseType__c ltype = license.LicenseType__r;
        ltype.RenewalRefundNoticeTemplate__c = 'CT - RME Renewal Refund Notice';
        update ltype;
    }
    @isTest 
    public static void testBatch() {
        Test.startTest();
        D1D2DependencyRefundNotice noticeBatch = new D1D2DependencyRefundNotice();
        noticeBatch.query = 'Select Id, CurrentLicense__r.Id, LicensePeriodRNEW__c, CurrentLicense__r.LicenseType__c, CurrentLicense__r.LicenseType__r.RenewalRefundNoticeTemplate__c, '
        + ' CurrentLicense__r.RespondByDate__c from Application__c';
        Database.executeBatch(noticeBatch, 100);
        Test.stopTest();

    }

    @isTest 
    public static void testBatchWithLicenseType() {
        Test.startTest();

        LicenseType__c ltype = [SELECT ID FROM LicenseType__c WHERE RenewalRefundNoticeTemplate__c = 'CT - RME Renewal Refund Notice' LIMIT 1];
        D1D2DependencyRefundNotice noticeBatch = new D1D2DependencyRefundNotice(ltype.Id);
        noticeBatch.query = 'Select Id, LicensePeriodRNEW__c, CurrentLicense__r.Id, CurrentLicense__r.LicenseType__c, CurrentLicense__r.LicenseType__r.RenewalRefundNoticeTemplate__c, '
        + ' CurrentLicense__r.RespondByDate__c from Application__c';
        Database.executeBatch(noticeBatch, 100);
        Test.stopTest();

    }
}