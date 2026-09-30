@IsTest
public with sharing class BREGBatchJobConfigurationControllerTest {
    @TestSetup
    static void setupTestData() {
        Date today = Date.today();
        Date pastDate = today.addDays(-10);

        List<Account> testAccounts = new List<Account>();
        for (Integer i = 1; i <= 4; i++) {
            testAccounts.add(
                new Account(
                    Name = 'Test R7 Expire ' + i,
                    breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                    breg_Expiration_Date__c = pastDate,
                    breg_Entity_Status__c = 'Active (A)',
                    breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
                )
            );
        }
        insert testAccounts;
    }

    @IsTest
    static void testGetBatchJobConfigurationsWithReports() {
        Test.startTest();
        List<BREGBatchJobConfigurationController.BatchJobConfigurationWrapper> wrappers = BREGBatchJobConfigurationController.getBatchJobConfigurations();
        Test.stopTest();

        System.assertNotEquals(0, wrappers.size(), 'Wrappers should not be null');

        for (BREGBatchJobConfigurationController.BatchJobConfigurationWrapper wrapper : wrappers) {
            System.assertNotEquals(null, wrapper.id, 'Wrapper should have an id');
            System.assertNotEquals(null, wrapper.jobClass, 'Wrapper should have jobClass');
            System.assertNotEquals(null, wrapper.jobName, 'Wrapper should have jobName');
        }
    }

    @IsTest
    static void testRunBatchJobSuccess() {
        String testBatchClassName = 'BREGR7ExpirationBatch';

        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = testBatchClassName;
        request.batchSize = 200;
        request.previewMode = false;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();
        System.assertEquals('success', response.status, 'Status should be success');
        System.assertNotEquals(null, response.jobId, 'Job ID should not be null');
        System.assert(response.message.contains('successfully'), 'Message should indicate success');
    }

    @IsTest
    static void testGetJobInfoSuccess() {
        String testBatchClassName = 'BREGR7ExpirationBatch';

        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = testBatchClassName;
        request.batchSize = 10;
        request.previewMode = false;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();

        AsyncApexJob jobInfo = BREGBatchJobConfigurationController.getJobInfo(response.jobId);

        System.assertNotEquals(null, jobInfo, 'Job info should not be null');
        System.assertNotEquals(null, jobInfo.Status, 'Status should not be null');
        System.assertNotEquals(null, jobInfo.TotalJobItems, 'Total job items should not be null');
    }

    @IsTest
    static void testGetBatchJobResult() {
        String testRunId = 'test-run-id-123';
        String testJobName = 'BREGDelinquencyStatusUpdateBatchJob';
        String testResults = 'Test results summary';

        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = testJobName;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();
        List<breg_Batch_Job_Execution__c> results = BREGBatchJobConfigurationController.getBatchJobResult(testJobName);
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one execution record');
        System.assertEquals(testJobName, results[0].breg_Job_Name__c, 'Job name should match');
        System.assertEquals(UserInfo.getUserId(), results[0].breg_User__c, 'User should match');
        System.assertNotEquals(null, results[0].breg_Execution_Status__c, 'Execution status should be set');
    }

    @IsTest
    static void testGetBatchJobResultWithBlankJobClassName() {
        Test.startTest();
        List<breg_Batch_Job_Execution__c> results = BREGBatchJobConfigurationController.getBatchJobResult('');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for blank job class name');
    }

    @IsTest
    static void testCalculateDurationHours() {
        DateTime startDate = DateTime.newInstance(2024, 1, 1, 10, 0, 0);
        DateTime endDate = DateTime.newInstance(2024, 1, 1, 13, 30, 45);

        Test.startTest();
        String duration = BREGBatchJobConfigurationController.calculateDuration(startDate, endDate);
        Test.stopTest();

        System.assertEquals('3h 30m 45s', duration, 'Duration should be 3 hours 30 minutes 45 seconds');
    }

    @IsTest
    static void testCalculateDurationMinutes() {
        DateTime startDate = DateTime.newInstance(2024, 1, 1, 10, 0, 0);
        DateTime endDate = DateTime.newInstance(2024, 1, 1, 10, 15, 30);

        Test.startTest();
        String duration = BREGBatchJobConfigurationController.calculateDuration(startDate, endDate);
        Test.stopTest();

        System.assertEquals('15m 30s', duration, 'Duration should be 15 minutes 30 seconds');
    }

    @IsTest
    static void testCalculateDurationSeconds() {
        DateTime startDate = DateTime.newInstance(2024, 1, 1, 10, 0, 0);
        DateTime endDate = DateTime.newInstance(2024, 1, 1, 10, 0, 45);

        Test.startTest();
        String duration = BREGBatchJobConfigurationController.calculateDuration(startDate, endDate);
        Test.stopTest();

        System.assertEquals('45s', duration, 'Duration should be 45 seconds');
    }

    @IsTest
    static void testCalculateDurationWithNullStartDate() {
        DateTime endDate = DateTime.newInstance(2024, 1, 1, 10, 0, 0);

        Test.startTest();
        String duration = BREGBatchJobConfigurationController.calculateDuration(null, endDate);
        Test.stopTest();

        System.assertEquals(null, duration, 'Duration should be null when start date is null');
    }

    @IsTest
    static void testCalculateDurationWithNullEndDate() {
        DateTime startDate = DateTime.newInstance(2024, 1, 1, 10, 0, 0);

        Test.startTest();
        String duration = BREGBatchJobConfigurationController.calculateDuration(startDate, null);
        Test.stopTest();

        System.assertEquals(null, duration, 'Duration should be null when end date is null');
    }

    @IsTest
    static void testRunBatchJobWithBlankJobClassName() {
        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = '';
        request.batchSize = 200;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();

        System.assertEquals('error', response.status, 'Status should be error');
        System.assert(response.message.contains('required'), 'Message should indicate job class name is required');
    }

    @IsTest
    static void testRunBatchJobWithInvalidBatchClass() {
        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = 'NonExistentBatchClass';
        request.batchSize = 200;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();

        System.assertEquals('error', response.status, 'Status should be error');
        System.assert(response.message.contains('Error'), 'Message should contain error information');
    }

    @IsTest
    static void testRunBatchJobWithNullBatchSize() {
        String testBatchClassName = 'BREGR7ExpirationBatch';

        Test.startTest();
        BREGBatchJobConfigurationController.BatchJobRunRequest request = new BREGBatchJobConfigurationController.BatchJobRunRequest();
        request.jobClassName = testBatchClassName;
        request.batchSize = null;
        request.previewMode = false;

        BREGBatchJobConfigurationController.ResponseWrapper response = BREGBatchJobConfigurationController.runBatchJob(JSON.serialize(request));
        Test.stopTest();

        System.assertEquals('success', response.status, 'Status should be success with default batch size');
    }
}