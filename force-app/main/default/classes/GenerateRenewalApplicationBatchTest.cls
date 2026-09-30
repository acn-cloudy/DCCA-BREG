@isTest
private class GenerateRenewalApplicationBatchTest {

    @TestSetup
    static void makeData(){
        TestDataFactory.createDummyChargebackPayment();
        TestDataFactory.createDummyApplication();
        Transaction__c tran = [Select Id, Application__c from Transaction__c limit 1];
        Application__c app = [Select Id from Application__c limit 1];
        tran.Application__c = app.Id;
        update tran;
        
    }
    @isTest
    private static void testBatch() {
        Test.startTest();
        List<Application__c> apps = [Select Id from Application__c];
        List<String> recordIds = (new ApplicationDomain(apps)).getIds();
        Database.executeBatch(new GenerateRenewalApplicationBatch(recordIds, 'OnlineRenewalCopy'), 200);
        Test.stopTest();
    }
}