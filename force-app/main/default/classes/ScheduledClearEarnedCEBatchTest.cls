@isTest
private class ScheduledClearEarnedCEBatchTest {

    // Method to set up test data for License__c and Earned_Continuing_Education__c records.
    @TestSetup
    static void setupTestData() {
        // Create and insert License__c records with required fields and credits
        // Ensure some records meet the criteria of having non-zero Core or Elective Credits
        // Create and relate Earned_Continuing_Education__c records to these License records as needed

        TestDataFactory.createDummyEarnedCERecords();
    }

    // Test method for batch execution
    static testMethod void testBatchExecution() {
        Test.startTest();
        // Execute the batch job
        ScheduledClearEarnedCEBatch ba = new ScheduledClearEarnedCEBatch();
        ba.query = 'Select Id, (Select Id, Name from Earned_Continuing_Education__r limit 1) from License__c';
        Database.executeBatch(ba);
        Test.stopTest();
    }

    // Test method for schedulable execution
    static testMethod void testSchedulableExecution() {
        Test.startTest();
        // Instantiate the schedulable class and invoke the execute method
        String cronExp = '0 0 0 15 3 ? *'; // Example CRON expression
        System.schedule('Test Scheduled Job', cronExp, new ScheduledClearEarnedCEBatch());
        Test.stopTest();
    }
}