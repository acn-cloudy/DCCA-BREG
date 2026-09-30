@isTest
private class CleanRenewApplicationJobTest {
    @TestSetup
    static void makeData(){
        Application__c app = TestDataFactory.createDummyApplication();
        app.Type__c = 'RNEW - Renewal';
        app.Status__c = 'AP - Application Pending Submittal by Applicant/Licensee';
        app.OnlineApplicationType__c = 'Online Renewal/Restore';
        insert app;
        TestDataFactory.createDummyChargebackPayment();
        List<Transaction__c> trans = [Select Id, Application__c from Transaction__c];
        for(Transaction__c tran: trans) {
            tran.Application__c = app.Id;
        }
        
        update trans;
    }
    @isTest
    private static void testBatch() {
        Test.startTest();
        Datetime dt = System.now();
        dt.addHours(1);
        Database.executeBatch(new CleanRenewApplicationJob(dt), 100);
        Test.stopTest();
        //System.assert([Select id from Transaction__c].size() == 0);
        //System.assert([Select id from Application__c].size() > 0);
    }
}