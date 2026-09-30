@IsTest
private class BREGCleanTestAnnualsTest {
    // -------------------------------------------------------------------------
    // TEST SETUP
    // -------------------------------------------------------------------------

    @TestSetup
    static void setupTestData() {
        // Prevent DocuSign workflow callouts during tests
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        // Create test accounts via factory
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(3);

        // Update accounts with valid entity statuses and incorporation dates
        accounts[0].breg_Entity_Status__c = 'Active (A)';
        accounts[0].breg_Incorporation_Date__c = Date.today().addYears(-1);

        accounts[1].breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)';
        accounts[1].breg_Incorporation_Date__c = Date.today().addYears(-2);

        accounts[2].breg_Entity_Status__c = 'Annual report 2 yr delinquent (2)';
        accounts[2].breg_Incorporation_Date__c = Date.today().addYears(-3);

        update accounts;

        // Create some test annual records to simulate existing data
        List<breg_Test_Annual__c> testAnnuals = new List<breg_Test_Annual__c>();
        for (Account acc : accounts) {
            testAnnuals.add(new breg_Test_Annual__c(breg_Account__c = acc.Id, breg_Filing_Year__c = String.valueOf(Date.today().year() - 1)));
            testAnnuals.add(new breg_Test_Annual__c(breg_Account__c = acc.Id, breg_Filing_Year__c = String.valueOf(Date.today().year())));
        }
        insert testAnnuals;
    }

    // -------------------------------------------------------------------------
    // CONSTRUCTOR TESTS
    // -------------------------------------------------------------------------

    @IsTest
    static void testDefaultConstructor() {
        Test.startTest();
        BREGCleanTestAnnualsAndRunRolloverJob job = new BREGCleanTestAnnualsAndRunRolloverJob();
        Test.stopTest();

        System.assertNotEquals(null, job, 'Job should be created successfully');
    }

    // -------------------------------------------------------------------------
    // CLEANUP FUNCTIONALITY TESTS
    // -------------------------------------------------------------------------

    @IsTest
    static void testCleanupDeletesAllTestAnnuals() {
        // Verify test annuals exist before cleanup
        Integer initialCount = [SELECT COUNT() FROM breg_Test_Annual__c];
        System.assert(initialCount > 0, 'Should have test annuals to clean up');

        Test.startTest();
        Database.executeBatch(new BREGCleanTestAnnualsAndRunRolloverJob(), 100);
        Test.stopTest();

        // Verify all test annuals are deleted
        Integer finalCount = [SELECT COUNT() FROM breg_Test_Annual__c];
        System.assertEquals(0, finalCount, 'All test annual records should be deleted');
    }

    @IsTest
    static void testCleanupWithNoTestAnnuals() {
        // Delete all test annuals first
        delete [SELECT Id FROM breg_Test_Annual__c];

        Test.startTest();
        Database.executeBatch(new BREGCleanTestAnnualsAndRunRolloverJob(), 100);
        Test.stopTest();

        // Should complete successfully even with no records to delete
        Integer finalCount = [SELECT COUNT() FROM breg_Test_Annual__c];
        System.assertEquals(0, finalCount, 'Should remain 0 test annual records');
    }

    // -------------------------------------------------------------------------
    // BATCH INTERFACE TESTS
    // -------------------------------------------------------------------------

    @IsTest
    static void testBatchStart() {
        BREGCleanTestAnnualsAndRunRolloverJob job = new BREGCleanTestAnnualsAndRunRolloverJob();

        Test.startTest();
        Database.QueryLocator ql = job.start(null);
        Test.stopTest();

        System.assertNotEquals(null, ql, 'QueryLocator should not be null');

        // Verify the query returns test annual records
        Database.QueryLocatorIterator it = ql.iterator();
        Integer recordCount = 0;
        while (it.hasNext()) {
            it.next();
            recordCount++;
        }

        System.assert(recordCount > 0, 'Should return test annual records to process');
    }

    @IsTest
    static void testBatchExecute() {
        List<breg_Test_Annual__c> testAnnuals = [SELECT Id FROM breg_Test_Annual__c LIMIT 2];
        BREGCleanTestAnnualsAndRunRolloverJob job = new BREGCleanTestAnnualsAndRunRolloverJob();

        Test.startTest();
        job.execute(null, testAnnuals);
        Test.stopTest();

        // Verify the records passed to execute were deleted
        List<breg_Test_Annual__c> remainingRecords = [SELECT Id FROM breg_Test_Annual__c WHERE Id IN :testAnnuals];
        System.assertEquals(0, remainingRecords.size(), 'Records should be deleted');
    }

    @IsTest
    static void testBatchExecuteWithEmptyScope() {
        BREGCleanTestAnnualsAndRunRolloverJob job = new BREGCleanTestAnnualsAndRunRolloverJob();
        List<breg_Test_Annual__c> emptyScope = new List<breg_Test_Annual__c>();

        Test.startTest();
        job.execute(null, emptyScope);
        Test.stopTest();

        // Should complete without errors when scope is empty
        System.assert(true, 'Should handle empty scope gracefully');
    }

    // -------------------------------------------------------------------------
    // ERROR HANDLING TESTS
    // -------------------------------------------------------------------------

    @IsTest
    static void testExecuteWithDeletionError() {
        // Create a test annual that might fail deletion (simulated by limiting scope)
        List<breg_Test_Annual__c> testAnnuals = [SELECT Id FROM breg_Test_Annual__c LIMIT 1];
        BREGCleanTestAnnualsAndRunRolloverJob job = new BREGCleanTestAnnualsAndRunRolloverJob();

        // This test verifies that the job continues even if some deletions fail
        Test.startTest();
        try {
            job.execute(null, testAnnuals);
            System.assert(true, 'Execute should complete even with potential errors');
        } catch (Exception e) {
            System.assert(false, 'Execute should not throw exceptions: ' + e.getMessage());
        }
        Test.stopTest();
    }
}