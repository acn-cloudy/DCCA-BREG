@isTest
private class OnlineRenewalControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
        insert TestDataFactory.createDummyChargebackPayment();
        Account acc = [Select Id from Account limit 1];
        LicenseType__c licenseTypeRecord = [Select Id from LicenseType__c limit 1];
        Application__c dependentApplication = new Application__c();
        dependentApplication.Applicant__c = acc.Id;
        dependentApplication.LicenseType__c = licenseTypeRecord.Id;
        dependentApplication.Type__c = 'LICN - New License';
        dependentApplication.Phase__c = 'A - Application Received';
        insert dependentApplication;


    }
    @isTest
    private static void testController() {
        List<String> tranIds = new List<String>();
        List<pymt__PaymentX__c> payments = [Select Id, Transaction__c from pymt__PaymentX__c];
        for(pymt__PaymentX__c payment: payments) {
            tranIds.add(payment.Transaction__c);
        }
        
        Transaction__c tran = [Select Id, Application__c from Transaction__c where Id in: tranIds limit 1];

        Application__c app = [Select Id, OnlineRenewalEmployment__c from Application__c limit 1];
        tran.Application__c = app.Id;
        update tran;
        
        List<AssociatedLicense__c> associatedLicenses = [Select Id from AssociatedLicense__c];
        OnlineRenewalController.OnlineRenewalEmploymentSnapshot snap = new OnlineRenewalController.OnlineRenewalEmploymentSnapshot();
        snap.employees = associatedLicenses;
        snap.employers = associatedLicenses;
        app.OnlineRenewalEmployment__c = JSON.serialize(snap);
        update app;

        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', app.Id);
        OnlineRenewalController cont = new OnlineRenewalController();
        Test.stopTest();
    }
}