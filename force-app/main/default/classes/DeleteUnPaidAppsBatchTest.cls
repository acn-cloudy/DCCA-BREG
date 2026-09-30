@isTest
private class DeleteUnPaidAppsBatchTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createDummyChargebackPayment();
        TestDataFactory.createDummyApplication();
        List<Application__c> apps = [Select Id from Application__c];
        List<Transaction__c> trans = [Select Id, Application__c from Transaction__c];
        for(Transaction__c tran: trans) {
            tran.Application__c = apps.get(0).Id;
        }
        update trans;
    }
    @isTest 
    static void testBatchJob() {
        Test.startTest();
        Database.executeBatch(new DeleteUnPaidAppsBatch(), 100);
        Test.stopTest();
    }
    @isTest 
    static void testBatchJobForFutureDate() {
        Test.startTest();
        DeleteUnPaidAppsBatch batch = new DeleteUnPaidAppsBatch(2);
        List<Application__c> apps = [Select Id from Application__c ];
        batch.execute(null, apps);
        Test.stopTest();
    }
}