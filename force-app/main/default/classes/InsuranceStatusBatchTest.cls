@isTest
private class InsuranceStatusBatchTest {
    @isTest private static void testBatch() {
        TestDataFactory.insertInsuranceBonds();
        Test.startTest();
        Database.executeBatch(new InsuranceStatusBatch(), 200);
        List<InsuranceBond__c> bonds = [Select Id, CancelDate__c, TermDate__c, Status__c from InsuranceBond__c];
        (new InsuranceStatusBatch()).execute(null, bonds);
        Test.stopTest();
    }
    @isTest private static void testScheduleJobs() {
        Test.startTest();
        Date d = Date.today();
        
        String CRON_EXP = '0 0 0 31 12 ? '+ d.year();
        String jobId = System.schedule('InsuranceStatusBatchTest', CRON_EXP, new InsuranceStatusBatch());


    }
}