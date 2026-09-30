@isTest 
private with sharing class D1D2DependencyRefundControllerTest {
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
    private static void testD1D2DependencyRefundController() {
        Test.startTest();
        LicenseType__c ltype = [SELECT Id FROM LicenseType__c WHERE RenewalRefundNoticeTemplate__c = 'CT - RME Renewal Refund Notice' LIMIT 1];        
        D1D2DependencyRefundController.runD1D2DependencyRefundNotice(ltype.ID);        

        LicenseHistory__c lHist = [SELECT TermDate__c FROM LicenseHistory__c LIMIT 1];
        License__c lic = [SELECT EffectiveExpireDate__c FROM License__c LIMIT 1];        
        //Integer notificationCount = [SELECT COUNT() FROM Notification__c];
        // Integer notificationCount = [SELECT COUNT() FROM Notification__c 
        //                     WHERE RecordId__c = : ltype.ID AND Status__c = 'Completed'];
        Test.stopTest();

        //System.assertEquals(2, notificationCount);
        System.assertEquals(lic.EffectiveExpireDate__c, lHist.TermDate__c);        

    }
}