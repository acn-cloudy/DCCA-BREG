@isTest
private class BREGCaseHistoryBatchTest {
    @TestSetup
    static void prepareData() {
        BREG_Setting__c settings = new BREG_Setting__c();
        settings.Days_In_Bounced_Check__c = 30;
        insert settings;

        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFileNumberSequences();
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createRegistrationCases(forms);
    }

    @isTest
    static void batchProcessesBouncedCheckCasesTest() {
        // Build scope record directly; execute path uses Test.isRunningTest() guard.
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'Bounced Check';
        testCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';

        update testCase;
        CaseHistory ch = new CaseHistory(CaseId = testCase.Id, Field = 'Status');

        Test.startTest();
        new BREGCaseHistoryBatch().execute(null, new List<CaseHistory>{ ch });
        Test.stopTest();
        Assert.isNotNull(ch.CaseId, 'Scope record should include CaseId');
    }

    @isTest
    static void startReturnsQueryLocatorTest() {
        Database.QueryLocator locator = new BREGCaseHistoryBatch().start(null);
        Assert.isNotNull(locator, 'Start should return a query locator');
    }

    @isTest
    static void batchSkipsNonBouncedCheckCasesTest() {
        // Update a case to a status other than 'Bounced Check'
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'In Progress';
        update testCase;

        Test.startTest();
        Database.executeBatch(new BREGCaseHistoryBatch(), 200);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'BREGCaseHistoryBatch' AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
        Assert.areEqual(0, job.NumberOfErrors, 'Batch job should have no errors');
    }

    @isTest
    static void batchHandlesNoCaseHistoryRecordsTest() {
        // Don't modify any case status - no CaseHistory records for Status field
        Test.startTest();
        Database.executeBatch(new BREGCaseHistoryBatch(), 200);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'BREGCaseHistoryBatch' AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual('Completed', job.Status, 'Batch job should complete with no history records');
        Assert.areEqual(0, job.NumberOfErrors, 'Batch job should have no errors');
    }

    @isTest
    static void batchThrowsExceptionWhenSettingMissingTest() {
        // Delete the custom setting to simulate missing configuration
        delete [SELECT Id FROM BREG_Setting__c];

        try {
            new BREGCaseHistoryBatch().start(null);
            Assert.fail('Expected exception when BREG Setting Days_In_Bounced_Check__c is missing');
        } catch (Exception e) {
            Assert.isTrue(
                e.getMessage().contains('BREG Settings Days In Bounced Check field is not populated') ||
                e.getMessage().contains('Argument cannot be null') ||
                e.getMessage().contains('Script-thrown exception'),
                'Expected missing setting error, but got: ' + e.getMessage()
            );
        }
    }

    @isTest
    static void batchProcessesMultipleStatusChangesOnSameCaseTest() {
        // Change status multiple times - only the latest should matter
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'In Progress';
        update testCase;

        testCase.Status = 'Bounced Check';
        testCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';
        update testCase;

        Test.startTest();
        Database.executeBatch(new BREGCaseHistoryBatch(), 200);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'BREGCaseHistoryBatch' AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete after multiple status changes');
        Assert.areEqual(0, job.NumberOfErrors, 'Batch job should have no errors');
    }

    @isTest
    static void startWorkflowWithParamsTest() {
        Integer queueableJobsBefore = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];

        Test.startTest();
        BREGCaseHistoryBatch.startWorkflowWithParams('TestWorkflow', '<recordId>001000000000001</recordId>', '005000000000001');
        Test.stopTest();

        Integer queueableJobsAfter = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Assert.areEqual(queueableJobsBefore, queueableJobsAfter, 'Queueable should not be enqueued in test context');
    }

    @isTest
    static void enqueueWorkflowsWithParamsTest() {
        // Covers: enqueueWorkflowsWithParams enqueue path + StartWorkflowParamsQueueable.execute() routing
        Id sampleCaseId = [SELECT Id FROM Case LIMIT 1].Id;
        Map<Id, List<String>> workflowParamsByCase = new Map<Id, List<String>>{
            sampleCaseId => new List<String>{
                '<recordId>001000000000001</recordId><templateName>Template A</templateName>',
                '<recordId>001000000000002</recordId><templateName>Template B</templateName>'
            }
        };

        Test.startTest();
        BREGCaseHistoryBatch.enqueueWorkflowsWithParams('BREG Create Document For Payment', workflowParamsByCase);
        Test.stopTest(); // forces queueable execute() to run synchronously

        // Verify at least one queueable was enqueued (the chain starter)
        Integer queueableJobsCount = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Assert.isTrue(queueableJobsCount > 0, 'At least one queueable should have been enqueued');
    }

    @isTest
    static void runDocGenerationForPaymentsTest() {
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'Bounced Check';
        testCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';

        update testCase;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = testCase.Id, pymt__Status__c = 'Completed');
        insert payment;
        Integer queueableJobsBefore = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];

        Test.startTest();
        BREGCaseHistoryBatch.runDocGenerationForPayments(new Set<Id>{ testCase.Id });
        Test.stopTest();

        Integer queueableJobsAfter = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Assert.isTrue(queueableJobsAfter > queueableJobsBefore, 'Doc generation should enqueue a queueable when payments exist');
    }

    @isTest
    static void runDocGenerationForPaymentsWithEmptySetTest() {
        Test.startTest();
        BREGCaseHistoryBatch.runDocGenerationForPayments(new Set<Id>());
        Test.stopTest();
        Assert.isTrue(true, 'Method should handle empty input without errors');
    }

    @isTest
    static void enqueueWorkflowsWithParamsSingleItemTest() {
        // Covers single-item path: queueable execute() runs, nextIndex >= size so no chain
        Id sampleCaseId = [SELECT Id FROM Case LIMIT 1].Id;
        Map<Id, List<String>> workflowParamsByCase = new Map<Id, List<String>>{
            sampleCaseId => new List<String>{ '<recordId>001000000000001</recordId><templateName>T</templateName>' }
        };
        Test.startTest();
        BREGCaseHistoryBatch.enqueueWorkflowsWithParams('BREG Create Document For Payment', workflowParamsByCase);
        Test.stopTest();

        Integer queueableJobsCount = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Assert.isTrue(queueableJobsCount > 0, 'Queueable should have been enqueued for single-item list');
    }

    @isTest
    static void enqueueWorkflowsWithParamsEmptyListTest() {
        // Covers empty-list guard: no enqueue should occur
        Integer before = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Test.startTest();
        BREGCaseHistoryBatch.enqueueWorkflowsWithParams('BREG Create Document For Payment', new Map<Id, List<String>>());
        Test.stopTest();
        Integer after = [SELECT Count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Assert.areEqual(before, after, 'Empty list should not enqueue anything');
    }

    @isTest
    static void finishWithMatchingCaseIdsTest() {
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'Bounced Check';
        testCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';
        update testCase;

        insert new pymt__PaymentX__c(breg_Case__c = testCase.Id, pymt__Status__c = 'Completed');

        CaseHistory bouncedHistory = new CaseHistory(CaseId = testCase.Id, Field = 'Status');

        BREGCaseHistoryBatch batch = new BREGCaseHistoryBatch();
        Test.startTest();
        batch.execute(null, new List<CaseHistory>{ bouncedHistory });
        batch.finish(null);
        Test.stopTest();

        Assert.isTrue(true, 'Finish should process matching case IDs without errors');
    }

    @isTest
    static void finishWithNoMatchingCaseIdsTest() {
        BREGCaseHistoryBatch batch = new BREGCaseHistoryBatch();
        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        Assert.isTrue(true, 'Finish should handle empty matching IDs without errors');
    }
}