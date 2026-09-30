public with sharing class BREGBatchJobConfigurationController {
    @AuraEnabled(cacheable=true)
    public static List<BatchJobConfigurationWrapper> getBatchJobConfigurations() {
        Map<String, BREG_Batch_Job_Configuration__mdt> configurationsMap = BREG_Batch_Job_Configuration__mdt.getAll();
        List<BREG_Batch_Job_Configuration__mdt> configurations = new List<BREG_Batch_Job_Configuration__mdt>(configurationsMap.values());

        Set<String> jobClassNames = new Set<String>();
        Set<String> reportNames = new Set<String>();

        for (BREG_Batch_Job_Configuration__mdt config : configurations) {
            if (String.isNotBlank(config.Job_Class__c)) {
                jobClassNames.add(config.Job_Class__c);
            }
            if (String.isNotBlank(config.Cleanup_Job_Class__c)) {
                jobClassNames.add(config.Cleanup_Job_Class__c);
            }
            if (String.isNotBlank(config.Pre_Processing_Report__c)) {
                reportNames.add(config.Pre_Processing_Report__c);
            }
            if (String.isNotBlank(config.Post_Processing_Report__c)) {
                reportNames.add(config.Post_Processing_Report__c);
            }
        }

        Map<String, AsyncApexJob> latestJobsMap = getLatestJobExecutions(jobClassNames);
        Map<String, String> reportUrlMap = getReportUrls(reportNames);

        List<BatchJobConfigurationWrapper> wrappers = new List<BatchJobConfigurationWrapper>();
        for (BREG_Batch_Job_Configuration__mdt config : configurations) {
            AsyncApexJob latestJob = latestJobsMap.get(config.Job_Class__c);
            AsyncApexJob latestCleanupJob = latestJobsMap.get(config.Cleanup_Job_Class__c);
            if (latestCleanupJob != null && (latestJob == null || latestCleanupJob.CreatedDate > latestJob.CreatedDate)) {
                latestJob = latestCleanupJob;
            }
            wrappers.add(mapToWrapper(config, reportUrlMap, latestJob));
        }
        return wrappers;
    }

    @AuraEnabled
    public static ResponseWrapper runBatchJob(String requestJSON) {
        BatchJobRunRequest request = (BatchJobRunRequest) JSON.deserialize(requestJSON, BatchJobRunRequest.class);
        ResponseWrapper response = new ResponseWrapper();
        response.status = 'error';
        if (String.isBlank(request.jobClassName)) {
            response.message = 'Job class name is required';
            return response;
        }
        if (request.batchSize == null || request.batchSize <= 0) {
            request.batchSize = 200;
        }
        if (request.previewMode == null) {
            request.previewMode = false;
        }
        try {
            Type batchType = Type.forName(request.jobClassName);
            Object batchInstance = batchType.newInstance();
            if (!(batchInstance instanceof Database.Batchable<SObject>)) {
                response.message = 'Class does not implement Database.Batchable<SObject>: ' + request.jobClassName;
                return response;
            }
            if (batchInstance instanceof BREGBaseBatchJob) {
                BREGBaseBatchJob baseBatch = (BREGBaseBatchJob) batchInstance;
                baseBatch.isPreview = request.previewMode;
                baseBatch.quarter = String.isNotBlank(request.selectedQuarter) ? Integer.valueOf(request.selectedQuarter) : null;
                baseBatch.year = String.isNotBlank(request.selectedYear) ? Integer.valueOf(request.selectedYear) : null;
                baseBatch.indsNoticeDate = request.indsNoticeDate;
                baseBatch.indsDueDate = request.indsDueDate;
            }
            Id jobId = Database.executeBatch((Database.Batchable<SObject>) batchInstance, request.batchSize);
            response.status = 'success';
            response.message = 'Batch job started successfully';
            response.currentDateTime = DateTime.now().format();
            response.jobId = String.valueOf(jobId);
        } catch (Exception ex) {
            response.message = 'Error executing batch job: ' + ex.getMessage();
        }
        return response;
    }

    @AuraEnabled
    public static AsyncApexJob getJobInfo(String jobId) {
        if (String.isBlank(jobId)) {
            return null;
        }
        AsyncApexJob job = [
            SELECT
                CreatedDate,
                CompletedDate,
                JobItemsProcessed,
                NumberOfErrors,
                Status,
                TotalJobItems,
                FORMAT(CreatedDate) CreatedDateStr,
                FORMAT(CompletedDate) CompletedDateStr
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        return job;
    }

    @AuraEnabled
    public static List<breg_Batch_Job_Execution__c> getBatchJobResult(String jobClassName) {
        if (String.isBlank(jobClassName)) {
            return new List<breg_Batch_Job_Execution__c>();
        }
        List<breg_Batch_Job_Execution__c> jobExecutions = [
            SELECT
                breg_Timestamp__c,
                breg_User__c,
                breg_User__r.FirstName,
                breg_User__r.LastName,
                breg_Job_Name__c,
                breg_Results__c,
                breg_Execution_Status__c,
                breg_Total_Count__c,
                breg_Run_Id__c,
                FORMAT(breg_Timestamp__c) formattedTimestamp
            FROM breg_Batch_Job_Execution__c
            WHERE breg_Job_Name__c = :jobClassName
            ORDER BY breg_Timestamp__c DESC
            LIMIT 1
        ];
        return jobExecutions;
    }

    private static Map<String, String> getReportUrls(Set<String> reportNames) {
        Map<String, String> reportUrlMap = new Map<String, String>();
        if (reportNames.isEmpty()) {
            return reportUrlMap;
        }
        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :reportNames
            LIMIT 10000
        ];
        for (Report report : reports) {
            String reportUrl = '/lightning/r/Report/' + report.Id + '/view';
            reportUrlMap.put(report.DeveloperName, reportUrl);
        }
        return reportUrlMap;
    }

    private static Map<String, AsyncApexJob> getLatestJobExecutions(Set<String> jobClassNames) {
        Map<String, AsyncApexJob> latestJobsMap = new Map<String, AsyncApexJob>();

        if (jobClassNames.isEmpty()) {
            return latestJobsMap;
        }

        List<AsyncApexJob> allJobs = [
            SELECT Id, CreatedDate, CompletedDate, JobItemsProcessed, Status, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name IN :jobClassNames AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 10000
        ];

        for (AsyncApexJob job : allJobs) {
            String className = job.ApexClass.Name;
            if (!latestJobsMap.containsKey(className)) {
                latestJobsMap.put(className, job);
            }
        }

        return latestJobsMap;
    }

    private static BatchJobConfigurationWrapper mapToWrapper(
        BREG_Batch_Job_Configuration__mdt config,
        Map<String, String> reportUrlMap,
        AsyncApexJob latestJob
    ) {
        BatchJobConfigurationWrapper wrapper = new BatchJobConfigurationWrapper();
        wrapper.id = config.Id;
        wrapper.jobName = config.Job_Name__c;
        wrapper.jobClass = config.Job_Class__c;
        wrapper.jobDescription = config.Job_Description__c;
        wrapper.supportsPreviewMode = config.Supports_Preview_Mode__c != null ? config.Supports_Preview_Mode__c : false;
        wrapper.supportsYearSelect = config.Supports_Year_Select__c != null ? config.Supports_Year_Select__c : false;
        wrapper.supportsQuarterSelect = config.Supports_Quarter_Select__c != null ? config.Supports_Quarter_Select__c : false;
        wrapper.preProcessingReport = reportUrlMap.get(config.Pre_Processing_Report__c);
        wrapper.postProcessingReport = reportUrlMap.get(config.Post_Processing_Report__c);
        wrapper.batchSize = config.Batch_Size__c != null ? Integer.valueOf(config.Batch_Size__c) : 200;
        wrapper.resultFolderUrl = config.Result_Folder_URL__c;
        wrapper.cleanupJobClassName = config.Cleanup_Job_Class__c;

        if (latestJob != null) {
            wrapper.currentStatus = latestJob.Status;
            wrapper.currentJobId = String.valueOf(latestJob.Id);
            DateTime lastRunDate = latestJob.CompletedDate != null ? latestJob.CompletedDate : latestJob.CreatedDate;
            wrapper.lastRunDate = lastRunDate.format();
            if (latestJob.CompletedDate != null && latestJob.CreatedDate != null) {
                wrapper.lastDuration = calculateDuration(latestJob.CreatedDate, latestJob.CompletedDate);
            }
            wrapper.lastBatchesProcessed = latestJob.JobItemsProcessed;
        }

        return wrapper;
    }

    @TestVisible
    private static String calculateDuration(DateTime startDate, DateTime endDate) {
        if (startDate == null || endDate == null) {
            return null;
        }

        Long durationMs = endDate.getTime() - startDate.getTime();
        Long hours = durationMs / (1000 * 60 * 60);
        Long minutes = Math.mod(durationMs, (1000 * 60 * 60)) / (1000 * 60);
        Long seconds = Math.mod(durationMs, (1000 * 60)) / 1000;

        if (hours > 0) {
            return hours + 'h ' + minutes + 'm ' + seconds + 's';
        }
        if (minutes > 0) {
            return minutes + 'm ' + seconds + 's';
        }
        return seconds + 's';
    }

    public class BatchJobConfigurationWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String jobName;
        @AuraEnabled
        public String jobClass;
        @AuraEnabled
        public String jobDescription;
        @AuraEnabled
        public Boolean supportsPreviewMode;
        @AuraEnabled
        public Boolean supportsYearSelect;
        @AuraEnabled
        public Boolean supportsQuarterSelect;
        @AuraEnabled
        public String preProcessingReport;
        @AuraEnabled
        public String postProcessingReport;
        @AuraEnabled
        public Integer batchSize;
        @AuraEnabled
        public String lastRunDate;
        @AuraEnabled
        public String lastDuration;
        @AuraEnabled
        public Integer lastBatchesProcessed;
        @AuraEnabled
        public String currentStatus;
        @AuraEnabled
        public String currentJobId;
        @AuraEnabled
        public String resultFolderUrl;
        @AuraEnabled
        public String cleanupJobClassName;
    }

    public class ResponseWrapper {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String currentDateTime;
        @AuraEnabled
        public String jobId;
    }

    public class BatchJobRunRequest {
        @AuraEnabled
        public String jobClassName;
        @AuraEnabled
        public Integer batchSize;
        @AuraEnabled
        public Boolean previewMode;
        @AuraEnabled
        public String selectedQuarter;
        @AuraEnabled
        public String selectedYear;
        @AuraEnabled
        public Date indsNoticeDate;
        @AuraEnabled
        public Date indsDueDate;
    }
}