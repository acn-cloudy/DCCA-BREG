public abstract with sharing class BREGBaseBatchJob {
    // Common batch job properties
    public Boolean isPreview { get; set; }
    public List<String> logs { get; set; }
    public String batchJobId { get; set; }
    public integer quarter { get; set; }
    public integer year { get; set; }
    public Date indsNoticeDate { get; set; }
    public Date indsDueDate { get; set; }
    public Date delinquencyNoticeDate { get; set; }
    public Date delinquencyDueDate { get; set; }

    public static final String EXECUTION_STATUS_SUCCESS = 'Success';
    public static final String EXECUTION_STATUS_ERROR = 'Error';
    public static final String SUMMARY_KEY_EXECUTION_STATUS = 'executionStatus';
    public static final String SUMMARY_KEY_IS_PREVIEW_MODE = 'isPreviewMode';

    // Constructor
    public BREGBaseBatchJob() {
        this.isPreview = false;
        this.logs = new List<String>();
        setQuarterAndYear();
    }

    public BREGBaseBatchJob(Boolean isPreview) {
        this.isPreview = isPreview;
        this.logs = new List<String>();
        setQuarterAndYear();
    }
    /**
     * Helper method to create batch job execution records
     */
    protected breg_Batch_Job_Execution__c createBatchExecutionRecord(String jobName, Map<String, Object> summaryData) {
        String executionStatus = (String) summaryData.get(SUMMARY_KEY_EXECUTION_STATUS);
        if (String.isBlank(executionStatus)) {
            executionStatus = EXECUTION_STATUS_SUCCESS;
        }

        Boolean isPreviewMode = false;
        Object previewVal = summaryData.get(SUMMARY_KEY_IS_PREVIEW_MODE);
        if (previewVal instanceof Boolean) {
            isPreviewMode = (Boolean) previewVal;
        }

        String resultsSummary = JSON.serializePretty(summaryData);

        breg_Batch_Job_Execution__c jobRecord = new breg_Batch_Job_Execution__c(
            breg_Run_Id__c = this.batchJobId,
            breg_Timestamp__c = DateTime.now(),
            breg_User__c = UserInfo.getUserId(),
            breg_Job_Name__c = jobName,
            breg_Results__c = resultsSummary,
            breg_Quarter__c = this.quarter,
            breg_Year__c = this.year,
            breg_Execution_Status__c = executionStatus,
            breg_Is_Preview_Mode__c = isPreviewMode
        );

        return jobRecord;
    }

    /**
     * Helper method to add execution mode to summary data
     */
    protected void addExecutionModeToSummary(Map<String, Object> summaryData) {
        summaryData.put('executionMode', isPreview ? 'Preview' : 'Live');
        summaryData.put(SUMMARY_KEY_IS_PREVIEW_MODE, isPreview);
        summaryData.put('timestamp', DateTime.now().format());
    }

    protected void setQuarterAndYear() {
        Date today = Date.today();
        if (this.quarter == null) {
            this.quarter = ((today.month() - 1) / 3) + 1;
        }
        if (this.year == null) {
            this.year = today.year();
        }
    }
}