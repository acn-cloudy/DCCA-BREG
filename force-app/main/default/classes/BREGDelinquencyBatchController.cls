public with sharing class BREGDelinquencyBatchController {

    @AuraEnabled
    public static BatchJobResult runDelinquencyBatch(Boolean isPreview) {
        try {
            if (isPreview == null) {
                return new BatchJobResult(false, null, 'Preview flag is required');
            }

            BREGDelinquencyStatusUpdateBatchJob batchJob = new BREGDelinquencyStatusUpdateBatchJob(
                false,
                false,
                isPreview
            );

            Id jobId = Database.executeBatch(batchJob, 200);

            return new BatchJobResult(true, jobId, null);

        } catch (Exception e) {
            return new BatchJobResult(false, null, e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static ReportUrls getReportUrls() {
        try {
            List<Report> reports = [
                SELECT Id, DeveloperName
                FROM Report
                WHERE DeveloperName IN ('Delinquency_Status_Preview_Report_1rb', 'Delinquency_Status_Distribution_Report_ikE')
            ];

            ReportUrls urls = new ReportUrls();

            for (Report r : reports) {
                String reportUrl = '/lightning/r/Report/' + r.Id + '/view';
                if (r.DeveloperName == 'Delinquency_Status_Preview_Report_1rb') {
                    urls.previewReportUrl = reportUrl;
                } else if (r.DeveloperName == 'Delinquency_Status_Distribution_Report_ikE') {
                    urls.regularReportUrl = reportUrl;
                }
            }

            return urls;

        } catch (Exception e) {
            return new ReportUrls();
        }
    }

    public class BatchJobResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id jobId { get; set; }
        @AuraEnabled public String error { get; set; }

        public BatchJobResult(Boolean success, Id jobId, String error) {
            this.success = success;
            this.jobId = jobId;
            this.error = error;
        }
    }

    public class ReportUrls {
        @AuraEnabled public String previewReportUrl { get; set; }
        @AuraEnabled public String regularReportUrl { get; set; }

        public ReportUrls() {
            this.previewReportUrl = '';
            this.regularReportUrl = '';
        }
    }
}