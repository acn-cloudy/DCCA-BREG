// Covers the following classes:
// - BREGBatch
// - BREGBatchInterface
// - BREGBatchInterfaceExtTest
// - BREGBatchScheduler
@IsTest
public with sharing class BREGBatchTest {

    /**
     * Create test data factory methods
     */
    @TestSetup
    static void setupTestData() {
        List<Account> testAccounts = BREGTestDataFactory.createEntityAccounts(5);
        for (Integer i = 0; i < testAccounts.size(); i++) {
            testAccounts[i].Name = 'Test Account ' + (i + 1);
        }
        update testAccounts;
    }

    @IsTest
    static void testScheduleBatch() {
        Test.startTest();
        String jobId = System.schedule('Test Schedule', '0 0 22 * * ? *', new BREGBatchScheduler());
        Test.stopTest();

        CronTrigger scheduledJob = [SELECT Id FROM CronTrigger WHERE Id = :jobId LIMIT 1];
        System.assertNotEquals(null, scheduledJob, 'Batch scheduler job should be created');
    }

    /**
     * Test batch execution by using the BREGBatchInterfaceExtTest class as an extension of BREGBatchInterface
     */
    @IsTest
    static void testExecuteBatch() {
        // Verify no accounts have been processed before batch execution
        List<Account> processedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Batch_%'];
        System.assertEquals(0, processedAccounts.size(), 'Expected 0 processed accounts before batch execution');
        List<Task> processedTasks = [SELECT Id, Subject FROM Task];
        System.assertEquals(0, processedTasks.size(), 'Expected 0 processed tasks before batch execution');

        Test.startTest();
        Database.executeBatch(new BREGBatch('Account'));
        Test.stopTest();

        // Verify the batch processed the correct number of records
        processedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Batch_%'];
        System.assertEquals(5, processedAccounts.size(), 'Expected 5 processed accounts');
        processedTasks = [SELECT Id, Subject FROM Task];
        System.assertEquals(5, processedTasks.size(), 'Expected 5 processed tasks');
    }

    /**
     * Test the isRunningToday method with invalid cron expressions
     */
    @IsTest
    static void testIsRunningTodayInvalidCronExpression() {
        BREGBatchInterfaceExtTest processor = new BREGBatchInterfaceExtTest();
        processor.logs = new List<String>();

        Test.startTest();

        // Test with null/empty cron expression
        processor.cronExp = null;
        System.assertEquals(false, processor.isRunningToday(), 'Null cron should not run');

        processor.cronExp = '';
        System.assertEquals(false, processor.isRunningToday(), 'Empty cron should not run');

        // Test with invalid cron expression
        processor.cronExp = 'invalid cron';
        processor.lastRunDate = Date.today().addDays(-1);
        System.assertEquals(false, processor.isRunningToday(), 'Invalid cron should not run');

        Test.stopTest();
    }

    @IsTest
    static void testEscapeXml() {
        System.assertEquals('', BREGBatch.escapeXml(null), 'Null input should return an empty string');
        System.assertEquals(
            'A&amp;B&lt;&quot;&apos;&gt;',
            BREGBatch.escapeXml('A&B<"\'>'),
            'XML special characters should be escaped'
        );
    }

    @IsTest
    static void testGetRelatedInvDissolveDocumentsIds() {
        Account accountRecord = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1];
        BREGBatch.involuntaryBatchUpdatedRecords = new List<SObject>{ accountRecord };

        insert new List<breg_Document__c>{
            new breg_Document__c(
                Name = 'CERTIFICATE OF ADMINISTRATIVE DISSOLUTION',
                breg_Account__c = accountRecord.Id,
                breg_Docusign_Document_Id__c = 'DOC-001',
                breg_Availability__c = 'Available Now'
            ),
            new breg_Document__c(
                Name = 'CERTIFICATE OF REVOCATION',
                breg_Account__c = accountRecord.Id,
                breg_Docusign_Document_Id__c = 'DOC-002',
                breg_Availability__c = 'Available Now'
            ),
            new breg_Document__c(
                Name = 'CERTIFICATE OF ADMINISTRATIVE TERMINATION',
                breg_Account__c = accountRecord.Id,
                breg_Availability__c = 'Available Now'
            ),
            new breg_Document__c(
                Name = 'Other Document',
                breg_Account__c = accountRecord.Id,
                breg_Docusign_Document_Id__c = 'DOC-999',
                breg_Availability__c = 'Available Now'
            )
        };

        String relatedDocumentIds = BREGBatch.getRelatedInvDissolveDocumentsIds();
        Set<String> returnedIds = new Set<String>(relatedDocumentIds.split(','));

        System.assertEquals(2, returnedIds.size(), 'Only matching documents with DocuSign ids should be returned');
        System.assert(returnedIds.contains('DOC-001'), 'Dissolution certificate should be included');
        System.assert(returnedIds.contains('DOC-002'), 'Revocation certificate should be included');

        BREGBatch.involuntaryBatchUpdatedRecords = new List<SObject>();
    }
}