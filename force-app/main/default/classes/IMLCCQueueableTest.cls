@isTest
private class IMLCCQueueableTest {
    @TestSetup
    static void makeData(){
        insert new List<LicenseType__c>{
            new LicenseType__c(Name='MD'),
            new LicenseType__c(Name='DOS')
        };
    }

    @isTest
    static void test_step1() {
        Test.startTest();
        System.enqueueJob(new IMLCCQueueable(1));
        Test.stopTest();
    }

    @isTest
    static void test_step2() {
        Test.startTest();
        List<IMLCCQueueable.IMLCCQueueableItem> items = new List<IMLCCQueueable.IMLCCQueueableItem>();
        IMLCCQueueable.PhysiciantoLicenseIdDetails new_PhysiciantoLicenseId = new IMLCCQueueable.PhysiciantoLicenseIdDetails();
        new_PhysiciantoLicenseId.fullname = 'TEST';
        new_PhysiciantoLicenseId.new_cdnpi = 'test123';
        new_PhysiciantoLicenseId.contactid = 'contact123';

        IMLCCQueueable.StandardLicenseValue licVal = new IMLCCQueueable.StandardLicenseValue();
        licVal.new_physicianlicenseid = null;
        licVal.createdon = null;
        licVal.new_name = 'TEST - HAWAII MEDICAL BOARD - MD';
        licVal.new_PhysiciantoLicenseId = new_PhysiciantoLicenseId;

        IMLCCQueueable.IMLCCQueueableItem item = new IMLCCQueueable.IMLCCQueueableItem();
        item.accountId = 'test123';
        item.nipId = 'test123';
        item.physicianId = 'test123';
        item.licVal = licVal;
        items.add(item);
        System.enqueueJob(new IMLCCQueueable(2, items));
        Test.stopTest();
    }

    @isTest
    static void test_step3() {
        Test.startTest();
        List<IMLCCQueueable.IMLCCQueueablePushItem> items = new List<IMLCCQueueable.IMLCCQueueablePushItem>();
        IMLCCQueueable.IMLCCQueueablePushItem item = new IMLCCQueueable.IMLCCQueueablePushItem();
        item.licenseNumber = 'Test123';
        item.dateOfIssue = String.valueOf(Date.today());
        item.dateOfExpiration = String.valueOf(Date.today());
        item.signer = 'Test Signer';
        item.physicianId = 'test123';
        items.add(item);
        System.enqueueJob(new IMLCCQueueable(3, items));
        Test.stopTest();
    }

    @isTest
    static void test_step4() {
        Test.startTest();
        List<IMLCCQueueable.IMLCCQueueableBulkPushItem> items = new List<IMLCCQueueable.IMLCCQueueableBulkPushItem>();
        IMLCCQueueable.IMLCCQueueableBulkPushItem item = new IMLCCQueueable.IMLCCQueueableBulkPushItem();
        item.new_issueddate = String.valueOf(Date.today());
        item.new_expires = String.valueOf(Date.today());
        item.imlcc_signaturembtypedname = 'Test Signer';
        item.licenseNumbers = new Map<String, String>();
        items.add(item);
        System.enqueueJob(new IMLCCQueueable(4, items));
        Test.stopTest();
    }
}