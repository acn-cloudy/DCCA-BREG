@isTest
public with sharing class BREGAmazonSesLoggerTest {
    @isTest
    static void testGetNumOfRetriesByTaskId() {
        // Create valid Task records to use their Ids
        Task t1 = new Task(Subject = 'Test', Status = 'Open');
        Task t2 = new Task(Subject = 'Test', Status = 'Open');
        insert new List<Task>{t1, t2};
        // Prepare test data
        List<breg_Email_Log__c> logs = new List<breg_Email_Log__c>();
        logs.add(new breg_Email_Log__c(
            breg_Task_Id__c = t1.Id,
            breg_Status__c = 'Error',
            breg_Error_Message__c = 'First error'
        ));
        logs.add(new breg_Email_Log__c(
            breg_Task_Id__c = t1.Id,
            breg_Status__c = 'Error',
            breg_Error_Message__c = 'Second error'
        ));
        logs.add(new breg_Email_Log__c(
            breg_Task_Id__c = t2.Id,
            breg_Status__c = 'Success',
            breg_Error_Message__c = null
        ));
        insert logs;

        Set<Id> taskIds = new Set<Id>{t1.Id, t2.Id};
        // Call method under test
        Map<String, Integer> result = BREGAmazonSesLogger.getNumOfRetriesByTaskId(taskIds);

        Assert.areEqual(2, result.get(t1.Id), 't1 should have 2 retries');
        Assert.areEqual(1, result.get(t2.Id), 't2 should have 1 retry');
        Assert.areEqual(2, result.size(), 'Should return 2 keys');
    }

    @isTest
    static void testGetNumOfRetriesByTaskId_Empty() {
        // No logs inserted
        Task t = new Task(Subject = 'Test', Status = 'Open');
        insert t;
        Map<String, Integer> result = BREGAmazonSesLogger.getNumOfRetriesByTaskId(new Set<Id>{t.Id});
        Assert.areEqual(0, result.size(), 'Should return empty map for unknown task');
    }

    @isTest
    static void testGetLogRecords() {
        // Prepare LogWrapper list
        List<BREGAmazonSesLogger.LogWrapper> wrappers = new List<BREGAmazonSesLogger.LogWrapper>();
        wrappers.add(new BREGAmazonSesLogger.LogWrapper('TASK1', 'Success', null));
        wrappers.add(new BREGAmazonSesLogger.LogWrapper('TASK2', 'Error', 'Some error'));

        // Call method under test
        List<breg_Email_Log__c> logs = BREGAmazonSesLogger.getLogRecords(wrappers);

        Assert.areEqual(2, logs.size(), 'Should return 2 log records');
        Assert.areEqual('TASK1', logs[0].breg_Task_Id__c);
        Assert.areEqual('Success', logs[0].breg_Status__c);
        Assert.areEqual('TASK2', logs[1].breg_Task_Id__c);
        Assert.areEqual('Error', logs[1].breg_Status__c);
        Assert.areEqual('Some error', logs[1].breg_Error_Message__c);
    }

    @isTest
    static void testLogWrapperConstructorsAndGetLogRecord() {
        // Test default constructor and property set
        BREGAmazonSesLogger.LogWrapper wrapper = new BREGAmazonSesLogger.LogWrapper();
        wrapper.taskId = 'TASK3';
        wrapper.status = 'Retry';
        wrapper.errorMessage = 'Retry error';

        breg_Email_Log__c log = wrapper.getLogRecord();
        Assert.areEqual('TASK3', log.breg_Task_Id__c);
        Assert.areEqual('Retry', log.breg_Status__c);
        Assert.areEqual('Retry error', log.breg_Error_Message__c);

        // Test parameterized constructor
        BREGAmazonSesLogger.LogWrapper wrapper2 = new BREGAmazonSesLogger.LogWrapper('TASK4', 'Completed', null);
        breg_Email_Log__c log2 = wrapper2.getLogRecord();
        Assert.areEqual('TASK4', log2.breg_Task_Id__c);
        Assert.areEqual('Completed', log2.breg_Status__c);
        Assert.areEqual(null, log2.breg_Error_Message__c);
    }
}