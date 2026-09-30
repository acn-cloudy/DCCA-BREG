@IsTest
private class BREGBaseBatchJobTest {
    private class TestBatchJob extends BREGBaseBatchJob {
        TestBatchJob() {
            super();
        }

        TestBatchJob(Boolean isPreview) {
            super(isPreview);
        }

        breg_Batch_Job_Execution__c buildExecutionRecord(String jobName, Map<String, Object> summaryData) {
            return createBatchExecutionRecord(jobName, summaryData);
        }

        void applyExecutionMode(Map<String, Object> summaryData) {
            addExecutionModeToSummary(summaryData);
        }
    }

    @IsTest
    static void testDefaultConstructorInitializesState() {
        TestBatchJob batchJob = new TestBatchJob();
        Date today = Date.today();
        Integer expectedQuarter = ((today.month() - 1) / 3) + 1;

        System.assertEquals(false, batchJob.isPreview, 'Default constructor should initialize live mode');
        System.assertNotEquals(null, batchJob.logs, 'Logs list should be initialized');
        System.assertEquals(0, batchJob.logs.size(), 'Logs list should start empty');
        System.assertEquals(expectedQuarter, batchJob.quarter, 'Quarter should be derived from the current date');
        System.assertEquals(today.year(), batchJob.year, 'Year should be derived from the current date');
    }

    @IsTest
    static void testPreviewConstructorAndExecutionModeSummary() {
        TestBatchJob batchJob = new TestBatchJob(true);
        Map<String, Object> summaryData = new Map<String, Object>();

        batchJob.applyExecutionMode(summaryData);

        System.assertEquals(true, batchJob.isPreview, 'Preview constructor should store preview mode');
        System.assertEquals('Preview', (String) summaryData.get('executionMode'), 'Summary should include preview execution mode');
        System.assertEquals(true, summaryData.get(BREGBaseBatchJob.SUMMARY_KEY_IS_PREVIEW_MODE), 'Summary should include preview flag');
        System.assertNotEquals(null, summaryData.get('timestamp'), 'Summary should include a timestamp');
    }

    @IsTest
    static void testCreateBatchExecutionRecordUsesSummaryValues() {
        TestBatchJob batchJob = new TestBatchJob(true);
        batchJob.batchJobId = 'RUN-123';
        batchJob.quarter = 2;
        batchJob.year = 2026;

        Map<String, Object> summaryData = new Map<String, Object>{
            BREGBaseBatchJob.SUMMARY_KEY_EXECUTION_STATUS => BREGBaseBatchJob.EXECUTION_STATUS_ERROR,
            BREGBaseBatchJob.SUMMARY_KEY_IS_PREVIEW_MODE => true,
            'processedCount' => 5
        };

        breg_Batch_Job_Execution__c executionRecord = batchJob.buildExecutionRecord('UnitTestBatch', summaryData);

        System.assertEquals('RUN-123', executionRecord.breg_Run_Id__c, 'Run id should come from the batch job');
        System.assertEquals(UserInfo.getUserId(), executionRecord.breg_User__c, 'Execution record should track the current user');
        System.assertEquals('UnitTestBatch', executionRecord.breg_Job_Name__c, 'Execution record should store the job name');
        System.assertEquals(2, executionRecord.breg_Quarter__c, 'Execution record should store the batch quarter');
        System.assertEquals(2026, executionRecord.breg_Year__c, 'Execution record should store the batch year');
        System.assertEquals(BREGBaseBatchJob.EXECUTION_STATUS_ERROR, executionRecord.breg_Execution_Status__c, 'Execution status should come from summary data');
        System.assertEquals(true, executionRecord.breg_Is_Preview_Mode__c, 'Preview mode should come from summary data');
        System.assert(executionRecord.breg_Results__c.contains('processedCount'), 'Results JSON should include summary payload');
    }

    @IsTest
    static void testCreateBatchExecutionRecordDefaultsExecutionStatus() {
        TestBatchJob batchJob = new TestBatchJob(false);
        Map<String, Object> summaryData = new Map<String, Object>{ 'processedCount' => 1 };

        breg_Batch_Job_Execution__c executionRecord = batchJob.buildExecutionRecord('DefaultStatusJob', summaryData);

        System.assertEquals(BREGBaseBatchJob.EXECUTION_STATUS_SUCCESS, executionRecord.breg_Execution_Status__c, 'Blank execution status should default to success');
        System.assertEquals(false, executionRecord.breg_Is_Preview_Mode__c, 'Preview mode should default to false when absent');
    }
}