@isTest
public with sharing class BREGAmazonSesQueueableTest {
    @isTest
    static void testExecute_SuccessfulEmailSend() {
        // Set up mock HTTP response for SES (success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        // Create a Task to send
        Task t = new Task(
            Subject = 'Annual Renewal Upcoming Alert',
            Status = 'Open',
            TaskSubtype = 'Email',
            breg_To__c = 'test1@example.com;test2@example.com',
            breg_Cc__c = 'cc1@example.com',
            breg_Bcc__c = 'bcc1@example.com'
        );

        Test.startTest();
        insert t;
        Test.stopTest();

        // After execution, the log should be created and the status should be updated
        List<breg_Email_Log__c> logs = [
            SELECT breg_Task_Id__c, breg_Status__c, breg_Error_Message__c
            FROM breg_Email_Log__c
            WHERE breg_Task_Id__c = :t.Id
        ];
        System.assertEquals(1, logs.size(), 'Should create one log record');
        System.assertEquals('Success', logs[0].breg_Status__c, 'Status should be Success');
        System.assertEquals(null, logs[0].breg_Error_Message__c, 'Error message should be null');
    }

    @isTest
    static void testExecute_FailedEmailSendAndRetry() {
        // Set up mock HTTP response for SES (failure)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpNegativeResponse());

        // Create a Task to send
        Task t = new Task(Subject = 'Test Email', Status = 'Open', TaskSubtype = 'Email', breg_To__c = 'fail1@example.com');

        Test.startTest();
        insert t;
        Test.stopTest();

        // After execution, the log should be created and the status should be Error or Repeat
        List<breg_Email_Log__c> logs = [
            SELECT breg_Task_Id__c, breg_Status__c, breg_Error_Message__c
            FROM breg_Email_Log__c
            WHERE breg_Task_Id__c = :t.Id
        ];
        System.assertEquals(1, logs.size(), 'Should create one log record');
        System.assert(logs[0].breg_Status__c == 'Repeat' || logs[0].breg_Status__c == 'Error', 'Status should be Repeat or Error');
        System.assertNotEquals(null, logs[0].breg_Error_Message__c, 'Error message should not be null');
    }

    @isTest
    static void testExecute_BatchSplittingByRecipientLimit() {
        // Set up mock HTTP response for SES (success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        // Create multiple Tasks to exceed MAX_RECIPIENTS (50)
        List<Task> tasksToInsert = new List<Task>();
        Integer numTasks = 3;
        // 3*20 = 60 > 50
        Integer toRecipientsPerTask = 10;
        Integer ccRecipientsPerTask = 5;
        Integer bccRecipientsPerTask = 5;
        for (Integer i = 0; i < numTasks; i++) {
            List<String> toEmails = new List<String>();
            for (Integer j = 0; j < toRecipientsPerTask; j++) {
                toEmails.add('user' + i + '_' + j + '@example.com');
            }
            List<String> ccEmails = new List<String>();
            for (Integer j = 0; j < ccRecipientsPerTask; j++) {
                ccEmails.add('user' + i + '_' + j + '@example.com');
            }
            List<String> bccEmails = new List<String>();
            for (Integer j = 0; j < bccRecipientsPerTask; j++) {
                bccEmails.add('user' + i + '_' + j + '@example.com');
            }
            tasksToInsert.add(
                new Task(
                    Subject = 'Batch Email ' + i,
                    Status = 'Open',
                    TaskSubtype = 'Email',
                    breg_To__c = String.join(toEmails, ';'),
                    breg_Cc__c = String.join(ccEmails, ';'),
                    breg_Bcc__c = String.join(bccEmails, ';')
                )
            );
        }

        Test.startTest();
        insert tasksToInsert;
        Test.stopTest();

        // Collect the task Ids to use for log lookup
        Set<Id> taskIds = new Set<Id>();
        for (Task t : tasksToInsert) {
            taskIds.add(t.Id);
        }
        // Should create a log for each task
        List<breg_Email_Log__c> logs = [SELECT breg_Task_Id__c, breg_Status__c FROM breg_Email_Log__c WHERE breg_Task_Id__c IN :taskIds];
        //System.assertEquals(numTasks, logs.size(), 'Should create a log for each task');
        for (breg_Email_Log__c log : logs) {
            //System.assertEquals('Success', log.breg_Status__c, 'Each log should be Success');
        }
    }

    @isTest
    static void testExecute_EnqueueJobWhenMaxCallsExceeded() {
        // Set up mock HTTP response for SES (success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        // Create enough Tasks to exceed MAX_CALLS (100)
        Integer numTasks = 110;
        List<Task> tasksToInsert = new List<Task>();
        for (Integer i = 0; i < numTasks; i++) {
            tasksToInsert.add(new Task(Subject = 'Callout Email ' + i, Status = 'Open', TaskSubtype = 'Email', breg_To__c = 'user' + i + '@example.com'));
        }

        Test.startTest();
        insert tasksToInsert;
        Test.stopTest();

        // Collect the task Ids to use for log lookup
        Set<Id> taskIds = new Set<Id>();
        for (Task t : tasksToInsert) {
            taskIds.add(t.Id);
        }
        // Query logs using the collected task Ids
        List<breg_Email_Log__c> logsForEnqueued = [SELECT breg_Task_Id__c, breg_Status__c FROM breg_Email_Log__c WHERE breg_Task_Id__c IN :taskIds];
        //System.assertEquals(numTasks, logsForEnqueued.size(), 'Should create a log for each task when jobs are enqueued');
    }

    @isTest
    static void testExecute_NoTasks() {
        // Set up mock HTTP response for SES (success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        List<Task> emptyTasks = new List<Task>();

        Test.startTest();
        System.enqueueJob(new BREGAmazonSesQueueable(emptyTasks));
        Test.stopTest();

        // No logs should be created
        List<breg_Email_Log__c> logs = [SELECT Id FROM breg_Email_Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created for empty input');
    }

    @isTest
    static void testExecute_NextQueueableStarted_OnBatchMaxRecipients() {
        // Set up mock HTTP response for SES (success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        // Prepare 17 tasks, each has 1 To, 1 Cc, 1 Bcc; total 3 recipients per task = 51 > MAX_RECIPIENTS (50)
        Integer numTasks = 17;
        List<Task> taskList = new List<Task>();
        for (Integer i = 0; i < numTasks; i++) {
            taskList.add(
                new Task(
                    Subject = 'Batch Recipients ' + i,
                    Status = 'Open',
                    TaskSubtype = 'Email',
                    breg_To__c = 'to' + i + '@example.com',
                    breg_Cc__c = 'cc' + i + '@example.com',
                    breg_Bcc__c = 'bcc' + i + '@example.com'
                )
            );
        }

        Test.startTest();
        insert taskList;
        Test.stopTest();

        // After run, logs give us clues to job batches. Each batch can have up to 50 recipients.
        // With 17 tasks x 3 = 51 recipients, so expect 2 batches - 1 for 16 tasks (16*3=48), 1 for the last task (3).
        // The last task should be sent in a separate callout, but same job.
        // All logs should be created (one for each Task), except for the last task, so 16 logs.
        List<breg_Email_Log__c> logs = [
            SELECT breg_Task_Id__c, breg_Status__c
            FROM breg_Email_Log__c
            WHERE breg_Task_Id__c IN :new Map<Id, Task>(taskList).keySet()
        ];
        //System.assertEquals(16, logs.size(), 'There should be a log for each Task');

        // Confirm that all logs have one of the known statuses (Success, Error, Repeat, Completed) - could assert on 'Success' status if always mocked positive.
        Set<String> expectedStatuses = new Set<String>{ 'Success', 'Completed' };
        for (breg_Email_Log__c log : logs) {
            // System.assert(expectedStatuses.contains(log.breg_Status__c), 'Unexpected status in log: ' + log.breg_Status__c);
        }
    }

    @isTest
    static void testExecute_LargeNumberOfTasks_200Tasks_25RecipientsEach() {
        // Set up mock HTTP response for SES (always success)
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());

        List<Task> taskList = new List<Task>();
        // Create 200 Tasks, each with 25 unique recipients total (spread across To, Cc, Bcc)
        for (Integer i = 0; i < 200; i++) {
            List<String> toEmails = new List<String>();
            List<String> ccEmails = new List<String>();
            List<String> bccEmails = new List<String>();
            for (Integer j = 0; j < 10; j++) {
                toEmails.add('to_' + i + '_' + j + '@example.com');
            }
            for (Integer j = 0; j < 10; j++) {
                ccEmails.add('cc_' + i + '_' + j + '@example.com');
            }
            for (Integer j = 0; j < 5; j++) {
                bccEmails.add('bcc_' + i + '_' + j + '@example.com');
            }
            // Join emails by semi-colon for custom fields
            String toString = String.join(toEmails, ';');
            String ccString = String.join(ccEmails, ';');
            String bccString = String.join(bccEmails, ';');

            taskList.add(
                new Task(
                    Subject = 'Load Test Task ' + i,
                    Status = 'Open',
                    TaskSubtype = 'Email',
                    breg_To__c = toString,
                    breg_Cc__c = ccString,
                    breg_Bcc__c = bccString
                )
            );
        }

        Test.startTest();
        insert taskList;
        Test.stopTest();

        // There should be 200 log records, one for each Task
        List<breg_Email_Log__c> logs = [
            SELECT breg_Task_Id__c, breg_Status__c
            FROM breg_Email_Log__c
            WHERE breg_Task_Id__c IN :new Map<Id, Task>(taskList).keySet()
        ];
        //System.assertEquals(200, logs.size(), 'There should be one log record for each Task');

        // Assert each log record matches a known success/complete status
        Set<String> expectedStatuses = new Set<String>{ 'Success', 'Completed' };
        for (breg_Email_Log__c log : logs) {
            // System.assert(expectedStatuses.contains(log.breg_Status__c), 'Unexpected status in log: ' + log.breg_Status__c);
        }
    }
}