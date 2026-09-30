public with sharing class BREGR7ExpirationBatch extends BREGBaseBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    private final String STATUS_EXPIRED = 'Expired (E)';
    private final String STATUS_CANCELLED = 'Cancelled (C)';
    private final String STATUS_REVOKED = 'Revoked (R)';
    private static Map<String, String> STATUS_TRANS_CODE_MAP = new Map<String, String>{ 'Expired (E)' => 'EXP' };

    // Preview reason constants
    private static final String REASON_EXPIRATION_DATE_PASSED = 'Expiration date passed';
    private static final String REASON_HAS_PENDING_RENEWAL = 'Has pending renewal';

    // Tracking variables
    private Integer processedCount = 0;
    private Integer expiredCount = 0;
    private Integer skippedCount = 0;
    private Integer transactionCount = 0;
    private Integer errorCount = 0;
    private Integer unchangedCount = 0;

    public BREGR7ExpirationBatch() {
        super();
    }

    public BREGR7ExpirationBatch(Boolean isPreview) {
        super(isPreview);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Name,
                    breg_Entity_Type__c,
                    breg_Expiration_Date__c,
                    breg_Entity_Status__c,
                    breg_File_Suffix__c,
                    breg_R7_Expiration_Status_Preview__c,
                    breg_R7_Expiration_Status_Preview_Date__c,
                    breg_R7_Expiration_Status_Preview_Reason__c
                FROM Account
                WHERE
                    breg_Entity_Type__c = :ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
                    AND breg_Expiration_Date__c <= :today
                    AND breg_Expiration_Date__c != NULL
                    AND breg_Entity_Status__c != :STATUS_EXPIRED
                    AND breg_Entity_Status__c != :STATUS_CANCELLED
                    AND breg_Entity_Status__c != :STATUS_REVOKED
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (SObject sObj : scope) {
            accountIds.add(sObj.Id);
            processedCount++;
        }

        Set<Id> accountsWithPendingRenewals = getAccountsWithPendingRenewals(accountIds);
        List<Account> accountsToUpdate = new List<Account>();
        List<breg_Transaction__c> transactionsToInsert = new List<breg_Transaction__c>();

        for (SObject sObj : scope) {
            Account acc = (Account) sObj;
            Boolean hasPending = accountsWithPendingRenewals.contains(acc.Id);
            String newStatus = STATUS_EXPIRED;
            String previewReason = REASON_EXPIRATION_DATE_PASSED;

            if (hasPending) {
                previewReason = REASON_HAS_PENDING_RENEWAL;
            }

            if (isPreview) {
                // In preview mode, set preview fields
                acc.breg_R7_Expiration_Status_Preview__c = newStatus;
                acc.breg_R7_Expiration_Status_Preview_Reason__c = previewReason;
                acc.breg_R7_Expiration_Status_Preview_Date__c = DateTime.now();
                accountsToUpdate.add(acc);

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
                if (acc.breg_Entity_Status__c != newStatus) {
                    String originalStatus = acc.breg_Entity_Status__c;
                    acc.breg_Entity_Status__c = newStatus;
                    acc.breg_End_Date__c = Date.today();
                    accountsToUpdate.add(acc);
                    transactionsToInsert.add(createTransaction(acc));
                    expiredCount++;
                } else {
                    unchangedCount++;
                }
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] saveResults = Database.update(accountsToUpdate, false);
                Integer successCount = 0;
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        for (Database.Error err : sr.getErrors()) {
                            logs.add('Update error: ' + err.getMessage());
                        }
                    }
                }
                String statusType = isPreview ? 'preview' : 'expired status';
                System.debug('✅ Updated ' + successCount + ' R7 accounts to ' + statusType + '.');
            } catch (Exception e) {
                errorCount += accountsToUpdate.size();
                System.debug('❌ Error updating accounts: ' + e.getMessage());
                logs.add('Error updating accounts: ' + e.getMessage());
            }
        }

        // Only create transactions in execute mode
        if (!isPreview && !transactionsToInsert.isEmpty()) {
            try {
                insert transactionsToInsert;
                transactionCount += transactionsToInsert.size();
                System.debug('✅ Created ' + transactionsToInsert.size() + ' expiration transactions.');
            } catch (Exception e) {
                System.debug('❌ Error creating transactions: ' + e.getMessage());
                logs.add('Error creating transactions: ' + e.getMessage());
            }
        }
    }

    private Set<Id> getAccountsWithPendingRenewals(Set<Id> accountIds) {
        Set<Id> accountsWithPendingRenewals = new Set<Id>();

        List<Case> pendingRenewalCases = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Entity__c IN :accountIds AND breg_Is_Renewal__c = TRUE AND Status = 'Pending Submission'
        ];

        for (Case renewalCase : pendingRenewalCases) {
            accountsWithPendingRenewals.add(renewalCase.breg_Entity__c);
        }

        return accountsWithPendingRenewals;
    }

    public void finish(Database.BatchableContext bc) {
        // Create Batch Job Execution record to track batch results
        try {
            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGR7ExpirationBatch');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('processedCount', this.processedCount);
            counts.put('expiredCount', this.expiredCount);
            counts.put('skippedCount', this.skippedCount);
            counts.put('unchangedCount', this.unchangedCount);
            counts.put('transactionCount', this.transactionCount);
            counts.put('errorCount', this.errorCount);
            counts.put('totalProcessed', this.expiredCount + this.skippedCount + this.unchangedCount);
            summaryData.put('counts', counts);

            // Processing metadata
            summaryData.put('entityType', ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE);
            summaryData.put('statusTransition', 'Various -> ' + STATUS_EXPIRED);
            summaryData.put('processingDate', Date.today().format());

            // Add logs if any
            if (!logs.isEmpty()) {
                summaryData.put('logs', logs);
            }

            summaryData.put(SUMMARY_KEY_EXECUTION_STATUS, this.errorCount > 0 ? EXECUTION_STATUS_ERROR : EXECUTION_STATUS_SUCCESS);
            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGR7ExpirationBatch', summaryData);

            // Set legacy count fields for this specific job
            jobRecord.breg_Total_Count__c = this.processedCount;

            insert jobRecord;

            String mode = isPreview ? 'PREVIEW' : 'EXECUTE';
            System.debug(
                '🏁 BREGR7ExpirationBatch completed (' +
                    mode +
                    '). Processed: ' +
                    processedCount +
                    ', Expired: ' +
                    expiredCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Unchanged: ' +
                    unchangedCount +
                    ', Transactions Created: ' +
                    transactionCount +
                    ', Errors: ' +
                    errorCount
            );
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
            String mode = isPreview ? 'PREVIEW' : 'EXECUTE';
            System.debug(
                '🏁 BREGR7ExpirationBatch completed (' +
                    mode +
                    '). Processed: ' +
                    processedCount +
                    ', Expired: ' +
                    expiredCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Unchanged: ' +
                    unchangedCount +
                    ', Transactions Created: ' +
                    transactionCount +
                    ', Errors: ' +
                    errorCount
            );
        }
    }

    private breg_Transaction__c createTransaction(Account acc) {
        return BREGTransactionUtils.buildBaseTransactionForAccount(acc, STATUS_TRANS_CODE_MAP.get(acc.breg_Entity_Status__c), Date.today(), Date.today(), 'C');
    }
}