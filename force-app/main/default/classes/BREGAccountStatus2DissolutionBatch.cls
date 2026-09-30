public with sharing class BREGAccountStatus2DissolutionBatch extends BREGBaseBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    // Configurable Constants
    public static final Set<String> ENTITY_TYPES_REVOKED = new Set<String>{ 'F1', 'F2', 'C6', 'K5', 'K6' };
    public static final Set<String> ENTITY_TYPES_CANCELLED = new Set<String>{ 'G5', 'G6', 'L5', 'L6', 'Q5', 'Q6' };
    public static final Set<String> ENTITY_TYPES_DISSOLVED = new Set<String>{ 'D1', 'D2', 'P1', 'A1', 'A2', 'C1', 'C2', 'D9', 'S1' };
    public static final Set<String> ENTITY_TYPES_TERMINATED = new Set<String>{ 'C5' };

    // Target Status values
    public static final String STATUS_REVOKED = 'Inv. Revoked (R)';
    public static final String STATUS_CANCELLED = 'Inv. Cancelled (X)';
    public static final String STATUS_DISSOLVED = 'Inv. Dissolved (7)';
    public static final String STATUS_TERMINATED = 'Adm. Terminated (V)';
    public static final String STATUS_2_YEAR_DELINQUENT = 'Annual report 2 yr delinquent (2)';
    public static final String TRANSACTION_CODE_INCN = 'INCN';
    public static final String TRANSACTION_CODE_INDBX = 'INDBX';
    public static final String TRANSACTION_CODE_INDS = 'INDS';
    public static final String TRANSACTION_CODE_INVR = 'INVR';

    @TestVisible
    private static Boolean enableDissolutionDecreeGenerationInTests = false;

    //public static final String STATUS_1_YEAR_DELINQUENT = 'Annual report 1 yr delinquent (1)';
    private static final List<String> DOMESTIC_ENTITY_TYPES = new List<String>{
        'A1',
        'A2',
        'C1',
        'C2',
        'D9',
        'G5',
        'C5',
        'Q5',
        'K5',
        'L5',
        'D2',
        'D1',
        'P1',
        'S1'
    };

    private static final List<String> EXCLUDED_ENTITY_TYPES = System.Label.BREG_Excluded_Entities_From_Rollover_Job != null
        ? new List<String>(System.Label.BREG_Excluded_Entities_From_Rollover_Job.split(','))
        : new List<String>();

    public Integer processedCount = 0;
    public Integer excludedCount = 0;
    public Integer forcedIncludedCount = 0;
    public Set<Id> processedAccountIds = new Set<Id>();

    public BREGAccountStatus2DissolutionBatch() {
        super();
    }

    public BREGAccountStatus2DissolutionBatch(Boolean isPreview) {
        super(isPreview);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String statusValue = STATUS_2_YEAR_DELINQUENT;
        String query =
            'SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, ' +
            'breg_ExcludedFromInvoluntaryDissolution__c, breg_IncludedToInvoluntaryDissolution__c, ' +
            'breg_Inv_Diss_Status_Preview__c, breg_Inv_Diss_Status_Preview_Date__c, ' +
            'breg_Inv_Diss_Status_Prev_Reason__c, breg_End_Date__c, ' +
            'breg_File__c, breg_File_Suffix__c ' +
            'FROM Account ' +
            'WHERE (breg_Entity_Status__c = :statusValue ' +
            'OR breg_IncludedToInvoluntaryDissolution__c = true) AND breg_Entity_Type__c NOT IN :EXCLUDED_ENTITY_TYPES  AND CALENDAR_QUARTER(breg_Incorporation_Date__c) = :quarter';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Account> accountsToUpdate = new List<Account>();
        Set<Id> accountsEligibleForDecree = new Set<Id>();

        for (SObject sObj : scope) {
            Account acc = (Account) sObj;
            if (acc.breg_ExcludedFromInvoluntaryDissolution__c) {
                excludedCount++;
                continue;
            }

            if (acc.breg_IncludedToInvoluntaryDissolution__c == true) {
                forcedIncludedCount++;
            }

            if (isPreview) {
                acc.breg_Inv_Diss_Status_Preview__c = getInvDissolvedStatus(acc);
                acc.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
                accountsToUpdate.add(acc);
            } else {
                if (acc.breg_Inv_Diss_Status_Preview_Date__c != Date.today()) {
                    acc.breg_Inv_Diss_Status_Prev_Reason__c =
                        'Status set to dissolved based on batch job execution. Previous preview date: ' + acc.breg_Inv_Diss_Status_Preview_Date__c;
                } else {
                    acc.breg_Entity_Status__c = getInvDissolvedStatus(acc);
                    acc.breg_Inv_Diss_Status_Prev_Reason__c = null;
                    acc.breg_Involuntary_Dissolution_Due_Date__c = indsDueDate;
                    acc.breg_Involuntary_Dissolution_Notice_Date__c = indsNoticeDate;
                    accountsEligibleForDecree.add(acc.Id);
                }
                accountsToUpdate.add(acc);
            }    
            processedCount++;
        }

        if (!accountsToUpdate.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(accountsToUpdate, false);
            List<Account> successfulAccounts = new List<Account>();
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    successfulAccounts.add(accountsToUpdate[i]);
                    if (accountsEligibleForDecree.contains(accountsToUpdate[i].Id)) {
                            processedAccountIds.add(accountsToUpdate[i].Id);
                    }
                } else {
                    for (Database.Error err : saveResults[i].getErrors()) {
                        String errMsg = 'Error updating account ' + accountsToUpdate[i].Id + ': ' + err.getMessage();
                        System.debug('❌ ' + errMsg);
                        //logs.add(errMsg);
                    }
                }
            }
            System.debug('✅ Updated ' + successfulAccounts.size() + ' of ' + accountsToUpdate.size() + ' accounts');
            if (!isPreview && !successfulAccounts.isEmpty()) {
                createTransactions(successfulAccounts);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch job finished. Processed: ' + processedCount + ', Excluded: ' + excludedCount + ', Forced Included: ' + forcedIncludedCount);
        // Create Batch Job Execution record to track batch results
        try {
            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGAccountStatus2DissolutionBatch');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('processedCount', this.processedCount);
            counts.put('excludedCount', this.excludedCount);
            counts.put('forcedIncludedCount', this.forcedIncludedCount);
            counts.put('totalRecords', this.processedCount + this.excludedCount);
            summaryData.put('counts', counts);
            summaryData.put('currentYear', this.year);
            summaryData.put('currentQuarter', this.quarter);

            // Add logs if any
            if (!logs.isEmpty()) {
                summaryData.put('logs', logs);
            }

            summaryData.put('involuntaryDissolutionNoticeDate', this.indsNoticeDate);
            summaryData.put('involuntaryDissolutionDueDate', this.indsDueDate);

            summaryData.put(SUMMARY_KEY_EXECUTION_STATUS, !logs.isEmpty() ? EXECUTION_STATUS_ERROR : EXECUTION_STATUS_SUCCESS);
            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGAccountStatus2DissolutionBatch', summaryData);

            // Set legacy count fields for this specific job
            jobRecord.breg_Total_Count__c = this.processedCount + this.excludedCount;
            jobRecord.breg_Involuntary_Dissolution_Notice_Date__c = this.indsNoticeDate;
            jobRecord.breg_Involuntary_Dissolution_Due_Date__c = this.indsDueDate;

            insert jobRecord;
            System.debug('✅ Batch Job Execution record created with ID: ' + jobRecord);

            try {
                List<Id> processedIds = new List<Id>();
                processedIds.addAll(this.processedAccountIds);
                String processedIdsPayload = JSON.serialize(processedIds);

                ContentVersion processedIdsFile = new ContentVersion(
                    Title = 'ProcessedAccountIds-' + String.valueOf(DateTime.now().getTime()),
                    PathOnClient = 'processedAccountIds.json',
                    VersionData = Blob.valueOf(processedIdsPayload),
                    FirstPublishLocationId = jobRecord.Id
                );
                insert processedIdsFile;
                System.debug('✅ Attached processedAccountIds file to batch execution record: ' + processedIdsFile.Id);
            } catch (Exception contentEx) {
                System.debug('Error creating processedAccountIds attachment: ' + contentEx.getMessage());
            }
            
            if (!isPreview && (!Test.isRunningTest() || enableDissolutionDecreeGenerationInTests)) {
                System.debug('ℹ️ Enqueueing dissolution decree generation...');
                System.enqueueJob(new DissolutionDecreeGenerationQueueable(this.processedAccountIds));
            }
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
        }
    }

    private class DissolutionDecreeGenerationQueueable implements Queueable, Database.AllowsCallouts {
        private Set<Id> accountIds;

        private DissolutionDecreeGenerationQueueable(Set<Id> accountIds) {
            this.accountIds = accountIds == null ? new Set<Id>() : new Set<Id>(accountIds);
        }

        public void execute(QueueableContext context) {
            if (accountIds.isEmpty()) {
                System.debug('No processed accounts found for decree generation. Skipping decree generation.');
                return;
            }

            List<Account> processedAccounts = [
                SELECT Id, Name, breg_Entity_Type__c, breg_Delinquency_Due_Date__c, breg_Involuntary_Dissolution_Notice_Date__c
                FROM Account
                WHERE Id IN :accountIds AND RecordType.DeveloperName = 'BREG_Account'
                ORDER BY Name
            ];
            BREGDecreeGeneration.generateDissolutionDecreeDocuments(processedAccounts);
        }
    }

    private String getInvDissolvedStatus(Account acc) {
        if (ENTITY_TYPES_REVOKED.contains(acc.breg_Entity_Type__c)) {
            return STATUS_REVOKED;
        } else if (ENTITY_TYPES_CANCELLED.contains(acc.breg_Entity_Type__c)) {
            return STATUS_CANCELLED;
        } else if (ENTITY_TYPES_DISSOLVED.contains(acc.breg_Entity_Type__c)) {
            return STATUS_DISSOLVED;
        } else if (ENTITY_TYPES_TERMINATED.contains(acc.breg_Entity_Type__c)) {
            return STATUS_TERMINATED;
        }
        return STATUS_DISSOLVED; // No change
    }

    private void createTransactions(List<Account> accounts) {
        List<BREG_Transaction__c> transactions = new List<BREG_Transaction__c>();
        for (Account acc : accounts) {
            if (
                acc.breg_Entity_Status__c != STATUS_DISSOLVED &&
                acc.breg_Entity_Status__c != STATUS_REVOKED &&
                acc.breg_Entity_Status__c != STATUS_CANCELLED &&
                acc.breg_Entity_Status__c != STATUS_TERMINATED
            ) {
                continue; // Only create transactions for accounts that were not previously in a dissolved/revoked/cancelled/terminated status
            }
            transactions.add(BREGTransactionUtils.buildBaseTransactionForAccount(acc, getTransactionCode(acc), Date.today(), Date.today(), 'C'));
        }
        if (!transactions.isEmpty()) {
            insert transactions;
            System.debug('✅ Created ' + transactions.size() + ' transaction records.');
        }
    }

    private String getTransactionCode(Account acc) {
        // Determine transaction code based on batch type or other logic
        if (ENTITY_TYPES_REVOKED.contains(acc.breg_Entity_Type__c)) {
            return TRANSACTION_CODE_INVR;
        } else if (ENTITY_TYPES_CANCELLED.contains(acc.breg_Entity_Type__c)) {
            return TRANSACTION_CODE_INCN;
        } else if (ENTITY_TYPES_DISSOLVED.contains(acc.breg_Entity_Type__c)) {
            return TRANSACTION_CODE_INDS;
        } else if (ENTITY_TYPES_TERMINATED.contains(acc.breg_Entity_Type__c)) {
            return TRANSACTION_CODE_INDBX;
        }
        return TRANSACTION_CODE_INDS; // No change
    }
}