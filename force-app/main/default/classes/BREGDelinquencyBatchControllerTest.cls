@isTest
public class BREGDelinquencyBatchControllerTest {
    @TestSetup
    static void setupTestData() {
        List<Account> testAccounts = new List<Account>();

        testAccounts.add(new Account(Name = 'Test Account 1', breg_Entity_Status__c = 'Active (A)'));

        testAccounts.add(new Account(Name = 'Test Account 2', breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)'));

        testAccounts.add(new Account(Name = 'Test Account 3', breg_Bounced_Check__c = true, breg_Entity_Status__c = 'Active (A)'));

        insert testAccounts;
    }

    @isTest
    static void testRunDelinquencyBatchPreview() {
        Test.startTest();
        BREGDelinquencyBatchController.BatchJobResult result = BREGDelinquencyBatchController.runDelinquencyBatch(true);
        Test.stopTest();

        System.assert(result.success, 'Batch job should start successfully');
        System.assertNotEquals(null, result.jobId, 'Job ID should not be null');
        System.assertEquals(null, result.error, 'Error should be null');
    }

    @isTest
    static void testRunDelinquencyBatchProduction() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Test.startTest();
        BREGDelinquencyBatchController.BatchJobResult result = BREGDelinquencyBatchController.runDelinquencyBatch(false);
        Test.stopTest();

        System.assert(result.success, 'Batch job should start successfully');
        System.assertNotEquals(null, result.jobId, 'Job ID should not be null');
        System.assertEquals(null, result.error, 'Error should be null');
    }

    @isTest
    static void testRunDelinquencyBatchRequiresPreviewFlag() {
        Test.startTest();
        BREGDelinquencyBatchController.BatchJobResult result = BREGDelinquencyBatchController.runDelinquencyBatch(null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Null preview flag should return a failure result');
        System.assertEquals(null, result.jobId, 'Job ID should be null when validation fails');
        System.assertEquals('Preview flag is required', result.error, 'Validation error should be returned');
    }

    @isTest
    static void testBatchJobResultConstructor() {
        Id testJobId = '01p000000000000';
        String testError = 'Test error message';

        BREGDelinquencyBatchController.BatchJobResult successResult = new BREGDelinquencyBatchController.BatchJobResult(true, testJobId, null);

        BREGDelinquencyBatchController.BatchJobResult errorResult = new BREGDelinquencyBatchController.BatchJobResult(false, null, testError);

        System.assertEquals(true, successResult.success, 'Success result should be true');
        System.assertEquals(testJobId, successResult.jobId, 'Job ID should be the same');
    }

    @isTest
    static void testGetReportUrls() {
        Test.startTest();
        BREGDelinquencyBatchController.ReportUrls result = BREGDelinquencyBatchController.getReportUrls();
        Test.stopTest();

        // Verify method returns empty URLs when reports don't exist
        System.assertEquals('', result.previewReportUrl, 'Preview URL should be empty when report does not exist');
        System.assertEquals('', result.regularReportUrl, 'Regular URL should be empty when report does not exist');
    }
}