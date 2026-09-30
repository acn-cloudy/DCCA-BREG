public with sharing class BREGTNTMSMExpirationBatch extends BREGBaseBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    private final String STATUS_EXPIRED = 'E';
    private final String STATUS_CANCELLED = 'C';
    private final String STATUS_REVOKED = 'R';
    private final List<String> TYPES = new List<String>{ 'Trade Name', 'Trademark', 'Service Mark' };
    private static Map<String, String> STATUS_TRANS_CODE_MAP = new Map<String, String>{ 'E' => 'EXP' };

    // Preview reason constants
    private static final String REASON_EXPIRATION_DATE_PASSED = 'Expiration date passed';
    private static final String REASON_HAS_PENDING_RENEWAL = 'Has pending renewal';

    // Tracking variables
    private Integer processedCount = 0;
    private Integer expiredCount = 0;
    private Integer skippedCount = 0;
    private Integer errorCount = 0;
    private Integer unchangedCount = 0;

    public BREGTNTMSMExpirationBatch() {
        super();
    }

    public BREGTNTMSMExpirationBatch(Boolean isPreview) {
        super(isPreview);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Name,
                    breg_Expiration_Date__c,
                    breg_Status__c,
                    breg_File_Suffix__c,
                    breg_Last_Renewal_Case__c,
                    breg_Last_Renewal_Case__r.Status,
                    breg_Last_Renewal_Case__r.breg_Is_Renewal__c,
                    breg_Status_Preview__c,
                    breg_Status_Preview_Date__c,
                    breg_Status_Preview_Reason__c
                FROM breg_TN_TM_SM__c
                WHERE
                    breg_Expiration_Date__c <= :today
                    AND breg_Type__c IN :TYPES
                    AND breg_Expiration_Date__c != NULL
                    AND breg_End_Date__c = NULL
                    AND breg_Status__c != :STATUS_EXPIRED
                    AND breg_Status__c != :STATUS_CANCELLED
                    AND breg_Status__c != :STATUS_REVOKED
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> tntmsmIds = new Set<Id>();
        for (SObject sObj : scope) {
            tntmsmIds.add(sObj.Id);
        }
        List<breg_TN_TM_SM__c> recordsToUpdate = new List<breg_TN_TM_SM__c>();
        Set<Id> tntmsmWithPendingRenewals = getTntmsmWithPendingRenewals(tntmsmIds);
        for (SObject sObj : scope) {
            breg_TN_TM_SM__c record = (breg_TN_TM_SM__c) sObj;
            processedCount++;

            Boolean hasPending = tntmsmWithPendingRenewals.contains(record.Id);
            String newStatus = STATUS_EXPIRED;
            String previewReason = REASON_EXPIRATION_DATE_PASSED;

            if (hasPending) {
                previewReason = REASON_HAS_PENDING_RENEWAL;
            }

            if (isPreview) {
                // In preview mode, set preview fields
                record.breg_Status_Preview__c = newStatus;
                record.breg_Status_Preview_Reason__c = previewReason;
                record.breg_Status_Preview_Date__c = DateTime.now();
                recordsToUpdate.add(record);

                if (hasPending) {
                    skippedCount++;
                } else {
                    expiredCount++;
                }
            } else {
                // In execute mode, skip records with pending renewal
                if (hasPending) {
                    skippedCount++;
                    continue;
                }

                // Update actual status
                if (record.breg_Status__c != newStatus) {
                    String originalStatus = record.breg_Status__c;
                    record.breg_Status__c = newStatus;
                    record.breg_End_Date__c = Date.today();
                    recordsToUpdate.add(record);
                    expiredCount++;
                } else {
                    unchangedCount++;
                }
            }
        }

        if (!recordsToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] saveResults = Database.update(recordsToUpdate, false);
                Integer successCount = 0;
                for (Integer index = 0; index < saveResults.size(); index++) {
                    if (saveResults[index].isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        for (Database.Error err : saveResults[index].getErrors()) {
                            logs.add('Update error for record "' + recordsToUpdate[index].Name + '": ' + err.getMessage());
                        }
                    }
                }
                String statusType = isPreview ? 'preview' : 'expired status';
                System.debug('✅ Updated ' + successCount + ' TN/TM/SM records to ' + statusType + '.');
            } catch (Exception e) {
                errorCount += recordsToUpdate.size();
                System.debug('❌ Error updating records: ' + e.getMessage());
                logs.add('Error updating records: ' + e.getMessage());
            }
        }
    }

    private Set<Id> getTntmsmWithPendingRenewals(Set<Id> tntmsmIds) {
        Set<Id> tntmsmWithPendingRenewals = new Set<Id>();

        List<Case> pendingRenewalCases = [
            SELECT Id, breg_TN_TM_SM__c
            FROM Case
            WHERE
                breg_TN_TM_SM__c IN :tntmsmIds
                AND Status IN ('Pending Submission', 'Received', 'Approved', 'Filing')
                AND breg_Form_Code__c IN ('T-1', 'T-2', 'T-3', 'T-7')
        ];

        for (Case renewalCase : pendingRenewalCases) {
            tntmsmWithPendingRenewals.add(renewalCase.breg_TN_TM_SM__c);
        }

        return tntmsmWithPendingRenewals;
    }

    public void finish(Database.BatchableContext bc) {
        // Create Batch Job Execution record to track batch results
        try {
            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGTNTMSMExpirationBatch');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('processedCount', this.processedCount);
            counts.put('expiredCount', this.expiredCount);
            counts.put('skippedCount', this.skippedCount);
            counts.put('unchangedCount', this.unchangedCount);
            counts.put('errorCount', this.errorCount);
            counts.put('totalProcessed', this.expiredCount + this.skippedCount + this.unchangedCount);
            summaryData.put('counts', counts);

            // Processing metadata
            summaryData.put('recordTypes', TYPES);
            summaryData.put('statusTransition', 'Various -> ' + STATUS_EXPIRED);
            summaryData.put('processingDate', Date.today().format());

            // Add logs if any
            if (!logs.isEmpty()) {
                summaryData.put('logs', logs);
            }

            summaryData.put(SUMMARY_KEY_EXECUTION_STATUS, this.errorCount > 0 ? EXECUTION_STATUS_ERROR : EXECUTION_STATUS_SUCCESS);
            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGTNTMSMExpirationBatch', summaryData);

            // Set legacy count fields for this specific job
            jobRecord.breg_Total_Count__c = this.processedCount;

            insert jobRecord;

            String mode = isPreview ? 'PREVIEW' : 'EXECUTE';
            System.debug(
                '🏁 BREGTNTMSMExpirationBatch completed (' +
                    mode +
                    '). Processed: ' +
                    processedCount +
                    ', Expired: ' +
                    expiredCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Unchanged: ' +
                    unchangedCount +
                    ', Errors: ' +
                    errorCount
            );
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
            String mode = isPreview ? 'PREVIEW' : 'EXECUTE';
            System.debug(
                '🏁 BREGTNTMSMExpirationBatch completed (' +
                    mode +
                    '). Processed: ' +
                    processedCount +
                    ', Expired: ' +
                    expiredCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Unchanged: ' +
                    unchangedCount +
                    ', Errors: ' +
                    errorCount
            );
        }
    }
}