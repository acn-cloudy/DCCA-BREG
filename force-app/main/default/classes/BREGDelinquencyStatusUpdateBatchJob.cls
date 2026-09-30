public with sharing class BREGDelinquencyStatusUpdateBatchJob extends BREGBaseBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    // Constructor parameters
    public Boolean calculateOne { get; set; }
    public Boolean calculateTwo { get; set; }

    // Status constants
    private static final String STATUS_ACTIVE = 'Active (A)';
    private static final String STATUS_1_YEAR_DELINQUENT = 'Annual report 1 yr delinquent (1)';
    private static final String STATUS_2_YEAR_DELINQUENT = 'Annual report 2 yr delinquent (2)';

    // Manual action constants
    private static final String MANUAL_ACTION_AUTO = 'Auto';
    private static final String MANUAL_ACTION_INCLUDE = 'Include';
    private static final String MANUAL_ACTION_EXCLUDE = 'Exclude';

    // Preview reason constants
    private static final String REASON_NO_AGENT = 'No active agent';
    private static final String REASON_BOUNCED_CHECK = 'Bounced check';
    private static final String REASON_BANKRUPTCY = 'Bankruptcy';
    private static final String REASON_OTHER = 'Other';
    private static final List<String> EXCLUDED_ENTITY_TYPES = System.Label.BREG_Excluded_Entities_From_Rollover_Job != null
        ? new List<String>(System.Label.BREG_Excluded_Entities_From_Rollover_Job.split(','))
        : new List<String>();

    private static final String CREATE_AND_SEND_DOCUMENT_WORKFLOW = 'BREG Generate and Send Document for Account';
    private static breg_Docusign_Settings__c settings = breg_Docusign_Settings__c.getOrgDefaults();
    public static Integer currentScopeSize = (settings != null && settings.Minimum_Batch_Size__c != null) ? settings.Minimum_Batch_Size__c.intValue() : 30;
    public List<Id> accountsIds = new List<Id>();

    // Processing logs
    // Inherited from BREGBaseBatchJob: logs, batchJobId, isPreview

    // Status change counters
    public Integer status1Count { get; set; }
    public Integer status2Count { get; set; }
    public Integer unchangedCount { get; set; }
    public Integer skippedCount { get; set; }
    public Map<String, Integer> skipReasons { get; set; }

    public BREGDelinquencyStatusUpdateBatchJob() {
        super();
        this.calculateOne = false;
        this.calculateTwo = false;
        this.status1Count = 0;
        this.status2Count = 0;
        this.unchangedCount = 0;
        this.skippedCount = 0;
        this.skipReasons = new Map<String, Integer>();
    }

    public BREGDelinquencyStatusUpdateBatchJob(Boolean calculateOne, Boolean calculateTwo, Boolean isPreview) {
        super(isPreview);
        this.calculateOne = calculateOne;
        this.calculateTwo = calculateTwo;
        this.status1Count = 0;
        this.status2Count = 0;
        this.unchangedCount = 0;
        this.skippedCount = 0;
        this.skipReasons = new Map<String, Integer>();
    }

    /**
     * Query all entities in statuses A, 1, 2, and B (Bounced Check)
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.batchJobId = bc.getJobId();
        Set<String> statusValues = new Set<String>{ STATUS_ACTIVE, STATUS_1_YEAR_DELINQUENT, STATUS_2_YEAR_DELINQUENT };

        String soql =
            'SELECT Id, Name, breg_Entity_Status__c, breg_Certified_Register_Agent__c, ' +
            'breg_Incorporation_Date__c, ' +
            'breg_Delinquency_Status_Preview__c, breg_Delinquency_Status_Preview_Reason__c, ' +
            'breg_Delinquency_Status_Preview_Date__c, breg_Delinquency_Notice_Date__c, ' +
            'breg_Delinquency_Due_Date__c, breg_Delinquency_Manual_Action__c, breg_Annuals_Due_Date__c, ' +
            'breg_Execution_Date__c, breg_Bounced_Check__c ' +
            'FROM Account ' +
            'WHERE (breg_Entity_Status__c IN :statusValues OR breg_Bounced_Check__c = true)' +
            ' AND RecordType.DeveloperName = \'BREG_Account\' AND breg_Entity_Type__c NOT IN :EXCLUDED_ENTITY_TYPES AND CALENDAR_QUARTER(breg_Incorporation_Date__c) = :quarter';

        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Account> accounts = (List<Account>) scope;
        Map<Id, List<breg_Annual__c>> annualsByAccount = getAnnualsForAccounts(accounts);
        Map<Id, breg_Account_Affiliation__c> agentsByAccount = getAgentsForAccounts(accounts);

        Date today = Date.today();
        Date quarterStartDate = getQuarterStartDateForDate(today);
        Date previousQuarterStartDate = quarterStartDate.addMonths(-3);
        Date twoQuartersAgoStartDate = quarterStartDate.addMonths(-6);

        List<Account> accountsToUpdate = new List<Account>();
        Set<Id> workflowCandidateIds = new Set<Id>();

        for (Account account : accounts) {
            try {
                Boolean hasActiveAgent = agentsByAccount.containsKey(account.Id) != null;

                List<breg_Annual__c> accountAnnuals = annualsByAccount.get(account.Id);
                if (accountAnnuals == null) {
                    accountAnnuals = new List<breg_Annual__c>();
                }

                Boolean isCurrentlyDelinquent = isCurrentlyDelinquent(account, accountAnnuals, previousQuarterStartDate, twoQuartersAgoStartDate);
                Integer consecutiveMissedAnnuals = 0;
                String newStatus = account.breg_Entity_Status__c;
                String previewReason = REASON_OTHER;
                String manualAction = account.breg_Delinquency_Manual_Action__c;
                Boolean shouldProcess = false;

                if (isBouncedCheckDueDatePassed(account)) {
                    newStatus = STATUS_2_YEAR_DELINQUENT;
                    previewReason = REASON_BOUNCED_CHECK;
                    shouldProcess = true;
                } else if (account.breg_Bounced_Check__c == true) {
                    shouldProcess = false;
                } else if (manualAction == MANUAL_ACTION_EXCLUDE) {
                    shouldProcess = false;
                } else if (manualAction == MANUAL_ACTION_INCLUDE) {
                    shouldProcess = true;
                    consecutiveMissedAnnuals = 0;
                } else if (isCurrentlyDelinquent) {
                    shouldProcess = true;
                    consecutiveMissedAnnuals = getConsecutiveMissedAnnuals(account, accountAnnuals);
                } else {
                    shouldProcess = false;
                }

                if (shouldProcess && account.breg_Bounced_Check__c == false) {
                    newStatus = determineNewStatus(account, consecutiveMissedAnnuals, hasActiveAgent);
                    previewReason = determinePreviewReason(account, consecutiveMissedAnnuals, hasActiveAgent);
                }

                if (shouldProcess) {
                    if (isPreview) {
                        account.breg_Delinquency_Status_Preview__c = newStatus;
                        account.breg_Delinquency_Status_Preview_Reason__c = previewReason;
                        account.breg_Delinquency_Status_Preview_Date__c = DateTime.now();
                        if (newStatus != account.breg_Entity_Status__c) {
                            if (newStatus == STATUS_1_YEAR_DELINQUENT) {
                                status1Count++;
                            } else if (newStatus == STATUS_2_YEAR_DELINQUENT) {
                                status2Count++;
                            }
                        } else {
                            unchangedCount++;
                        }
                    } else {
                        if (account.breg_Entity_Status__c != newStatus) {
                            account.breg_Entity_Status__c = newStatus;
                            account.breg_Execution_Date__c = Date.today();
                            if (newStatus == STATUS_2_YEAR_DELINQUENT) {
                                account.breg_Delinquency_Notice_Date__c = Date.today();
                                account.breg_Delinquency_Due_Date__c = Date.today().addDays(30);
                                workflowCandidateIds.add(account.Id);
                            }

                            // Increment status change counters
                            if (newStatus == STATUS_1_YEAR_DELINQUENT) {
                                status1Count++;
                                account.breg_Good_Standing__c = false;
                                account.breg_Annuals_Due_Date__c = account.breg_Annuals_Due_Date__c != null ? account.breg_Annuals_Due_Date__c.addYears(1) : null;
                            } else if (newStatus == STATUS_2_YEAR_DELINQUENT) {
                                status2Count++;
                                account.breg_Good_Standing__c = false;
                                account.breg_Annuals_Due_Date__c = account.breg_Annuals_Due_Date__c != null ? account.breg_Annuals_Due_Date__c.addYears(1) : null;
                            }
                        } else {
                            // Record was processed but status unchanged
                            unchangedCount++;
                        }
                    }

                    accountsToUpdate.add(account);
                }
            } catch (Exception e) {
                logs.add('Error processing Account "' + account.Name + '": ' + e.getMessage());
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            try {
                BREGAccountTriggerHandler.skipDocusignWorkflow = true;
                Database.SaveResult[] saveResults = Database.update(accountsToUpdate, false);
                Set<Id> successfullyUpdatedIds = new Set<Id>();

                for (Integer index = 0; index < saveResults.size(); index++) {
                    if (saveResults[index].isSuccess()) {
                        successfullyUpdatedIds.add(accountsToUpdate[index].Id);
                    } else {
                        for (Database.Error dmlError : saveResults[index].getErrors()) {
                            logs.add(
                                'Error updating account "' +
                                    accountsToUpdate[index].Name +
                                    '": ' +
                                    dmlError.getStatusCode() +
                                    ' - ' +
                                    dmlError.getMessage()
                            );
                        }
                    }
                }
                if (!isPreview) {
                    processNotCompletedAnnuals(accountsToUpdate);
                }

                for (Id accountId : workflowCandidateIds) {
                    if (successfullyUpdatedIds.contains(accountId)) {
                        accountsIds.add(accountId);
                        if (!isPreview && accountsIds.size() == currentScopeSize) {
                            String params = '<recordIds>' + String.join(accountsIds, ',') + '</recordIds>';
                            startWorkflowAsync(CREATE_AND_SEND_DOCUMENT_WORKFLOW, null, params);
                            accountsIds = new List<Id>();
                        }
                    }
                }
            } catch (Exception e) {
                logs.add('Error updating accounts: ' + e.getMessage());
                accountsIds = new List<Id>();
            }
        }
    }

    /**
     * Returns the day the quarter starts for the given date
     */
    public Date getQuarterStartDateForDate(Date inputDate) {
        Integer month = inputDate.month();
        Integer year = inputDate.year();
        Date quarterStartDate;
        if (month >= 1 && month <= 3) {
            quarterStartDate = Date.newInstance(year, 1, 1);
        } else if (month >= 4 && month <= 6) {
            quarterStartDate = Date.newInstance(year, 4, 1);
        } else if (month >= 7 && month <= 9) {
            quarterStartDate = Date.newInstance(year, 7, 1);
        } else {
            quarterStartDate = Date.newInstance(year, 10, 1);
        }
        return quarterStartDate;
    }

    /**
     * Checks if the entity is currently delinquent (missed last 2 quarters)
     */
    public Boolean isCurrentlyDelinquent(Account entity, List<breg_Annual__c> annuals, Date previousQuarterStartDate, Date twoQuartersAgoStartDate) {
        if (entity.breg_Incorporation_Date__c != null) {
            Date registrationDate = entity.breg_Incorporation_Date__c;
            Date today = Date.today();
            Date oneYearAgo = today.addYears(-1);
            if (registrationDate >= oneYearAgo) {
                return false;
            }
        }

        if (annuals == null || annuals.isEmpty()) {
            return true;
        }

        Boolean hasPreviousQuarterFiling = false;
        Boolean hasTwoQuartersAgoFiling = false;

        for (breg_Annual__c annual : annuals) {
            if (annual.breg_Filing_Date__c != null) {
                Date filingDate = annual.breg_Filing_Date__c;
                if (filingDate >= previousQuarterStartDate) {
                    hasPreviousQuarterFiling = true;
                }
                if (filingDate >= twoQuartersAgoStartDate && filingDate < previousQuarterStartDate) {
                    hasTwoQuartersAgoFiling = true;
                }
            }
        }

        return (!hasPreviousQuarterFiling && !hasTwoQuartersAgoFiling);
    }

    /**
     * Returns the quarter number (1-4) for a given month
     */
    private Integer getQuarterForMonth(Integer month) {
        if (month >= 1 && month <= 3) {
            return 1;
        } else if (month >= 4 && month <= 6) {
            return 2;
        } else if (month >= 7 && month <= 9) {
            return 3;
        } else {
            return 4;
        }
    }

    /**
     * Counts consecutive missed annuals over 3 years
     * Returns 0, 1, 2, or 3
     */
    public Integer getConsecutiveMissedAnnuals(Account entity, List<breg_Annual__c> annuals) {
        if (annuals == null || annuals.isEmpty()) {
            Date registrationDate = entity.breg_Incorporation_Date__c;
            Date today = Date.today();
            if (registrationDate != null && registrationDate >= today.addYears(-3)) {
                return 2;
            }
            return 3;
        }

        Integer currentYear = Date.today().year();
        Set<Integer> filedYears = new Set<Integer>();
        for (breg_Annual__c annual : annuals) {
            if (annual.breg_Filing_Date__c != null) {
                filedYears.add(annual.breg_Filing_Date__c.year());
            }
        }

        Integer consecutiveMissed = 0;
        for (Integer i = 1; i < 3; i++) {
            Integer checkYear = currentYear - i;
            if (!filedYears.contains(checkYear)) {
                consecutiveMissed++;
            } else {
                break;
            }
        }

        return Math.min(consecutiveMissed, 3);
    }

    /**
     * Checks if an active agent is available for the entity
     */
    public Boolean isActiveAgentAvailable(Account entity, Map<Id, breg_Account_Affiliation__c> agentsByAccount) {
        if (entity.breg_Certified_Register_Agent__c == null) {
            return false;
        }
        breg_Account_Affiliation__c agent = agentsByAccount.get(entity.breg_Certified_Register_Agent__c);
        if (agent == null) {
            return false;
        }
        Boolean hasActiveAccount = (agent.breg_Account__c != null && agent.breg_Account__r.breg_Entity_Status__c == STATUS_ACTIVE);
        return hasActiveAccount;
    }

    /**
     * Get annuals for the last 3 years for the given accounts
     */
    private Map<Id, List<breg_Annual__c>> getAnnualsForAccounts(List<Account> accounts) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        Date startDate = Date.today().addYears(-3);
        Date endDate = Date.today();

        List<breg_Annual__c> annuals = [
            SELECT Id, breg_Account__c, breg_Filing_Year__c, breg_Status__c, breg_Filing_Date__c
            FROM breg_Annual__c
            WHERE
                breg_Account__c IN :accountIds
                AND breg_Filing_Date__c >= :startDate
                AND breg_Filing_Date__c <= :endDate
                AND (breg_Status__c = 'P'
                OR breg_Status__c = 'H'
                OR breg_Status__c = 'NR')
            ORDER BY breg_Account__c, breg_Filing_Date__c DESC
            LIMIT 10000
        ];

        Map<Id, List<breg_Annual__c>> annualsByAccount = new Map<Id, List<breg_Annual__c>>();
        for (breg_Annual__c annual : annuals) {
            if (!annualsByAccount.containsKey(annual.breg_Account__c)) {
                annualsByAccount.put(annual.breg_Account__c, new List<breg_Annual__c>());
            }
            annualsByAccount.get(annual.breg_Account__c).add(annual);
        }

        return annualsByAccount;
    }

    private static void processNotCompletedAnnuals(List<Account> accounts) {
        Date endDate = Date.today();

        List<breg_Annual__c> annuals = [
            SELECT Id, breg_Account__c, breg_Filing_Year__c, breg_Status__c, breg_Filing_Date__c
            FROM breg_Annual__c
            WHERE
                breg_Account__c IN :accounts
                AND breg_Filing_Date__c <= :endDate
                AND breg_Status__c != 'P'
                AND breg_Status__c != 'H'
                AND breg_Status__c != 'D'
                AND breg_Status__c != 'NR'
            LIMIT 10000
        ];

        for (breg_Annual__c annual : annuals) {
            annual.breg_Status__c = 'D';
        }

        if (annuals.size() > 0) {
            Database.SaveResult[] saveResults = Database.update(annuals, false);
            for (Integer index = 0; index < saveResults.size(); index++) {
                if (!saveResults[index].isSuccess()) {
                    for (Database.Error dmlError : saveResults[index].getErrors()) {
                        System.debug('Error updating annual "' + annuals[index].Id + '": ' + dmlError.getStatusCode() + ' - ' + dmlError.getMessage());
                    }
                }
            }
        }
    }

    /**
     * Get agent information for the given accounts
     */
    private Map<Id, breg_Account_Affiliation__c> getAgentsForAccounts(List<Account> accounts) {
        List<breg_Account_Affiliation__c> agents = [
            SELECT Id, breg_Role__c, breg_End_Date__c, breg_Start_Date__c, breg_Account__c, breg_Account__r.breg_Entity_Status__c, breg_Entity__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :accounts AND breg_Role__c = 'Agent' AND breg_End_Date__c = NULL AND breg_Status__c != 'I'
        ];

        Map<Id, breg_Account_Affiliation__c> agentsByAccount = new Map<Id, breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c agent : agents) {
            agentsByAccount.put(agent.breg_Entity__c, agent);
        }

        return agentsByAccount;
    }

    /**
     * Determine the new status based on current status, consecutive missed annuals, and manual actions
     */
    private String determineNewStatus(Account entity, Integer consecutiveMissedAnnuals, Boolean hasActiveAgent) {
        String currentStatus = entity.breg_Entity_Status__c;
        String manualAction = entity.breg_Delinquency_Manual_Action__c ?? MANUAL_ACTION_AUTO;
        String newStatus = currentStatus;

        switch on manualAction {
            when 'Exclude' {
                newStatus = currentStatus;
            }
            when 'Include' {
                newStatus = STATUS_2_YEAR_DELINQUENT;
            }
            when 'Auto' {
                if (!hasActiveAgent) {
                    newStatus = STATUS_2_YEAR_DELINQUENT;
                } else if (consecutiveMissedAnnuals == 1 || consecutiveMissedAnnuals == 2) {
                    newStatus = STATUS_1_YEAR_DELINQUENT;
                } else if (consecutiveMissedAnnuals >= 3) {
                    newStatus = STATUS_2_YEAR_DELINQUENT;
                } else if (currentStatus == STATUS_2_YEAR_DELINQUENT) {
                    newStatus = STATUS_2_YEAR_DELINQUENT;
                }
            }
        }

        return newStatus;
    }

    /**
     * Determine the preview reason based on consecutive missed annuals, agent status, and manual actions
     */
    private String determinePreviewReason(Account entity, Integer consecutiveMissedAnnuals, Boolean hasActiveAgent) {
        String manualAction = entity.breg_Delinquency_Manual_Action__c ?? MANUAL_ACTION_AUTO;
        String previewReason;

        switch on manualAction {
            when 'Exclude' {
                previewReason = null;
            }
            when 'Include' {
                previewReason = REASON_OTHER;
            }
            when 'Auto' {
                if (!hasActiveAgent) {
                    previewReason = REASON_NO_AGENT;
                } else if (consecutiveMissedAnnuals >= 3) {
                    previewReason = REASON_OTHER;
                } else if (consecutiveMissedAnnuals >= 1) {
                    previewReason = REASON_OTHER;
                }
            }
        }

        return previewReason;
    }

    /**
     * Check if the entity has a bounced check status and the final due date to clear it is in the past
     */
    private Boolean isBouncedCheckDueDatePassed(Account entity) {
        if (entity.breg_Bounced_Check__c == false) {
            return false;
        }
        if (entity.breg_Delinquency_Due_Date__c != null && entity.breg_Delinquency_Due_Date__c < Date.today()) {
            return true;
        }
        return false;
    }

    /**
     * Finish method for batch processing
     */
    public void finish(Database.BatchableContext bc) {
        // Create Batch Job Execution record to track batch results
        try {
            if (!isPreview && !accountsIds.isEmpty()) {
                String params = '<recordIds>' + String.join(accountsIds, ',') + '</recordIds>';
                startWorkflowAsync(CREATE_AND_SEND_DOCUMENT_WORKFLOW, null, params);
                accountsIds = new List<Id>();
            }

            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGDelinquencyStatusUpdateBatchJob');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('status1Count', this.status1Count);
            counts.put('status2Count', this.status2Count);
            counts.put('unchangedCount', this.unchangedCount);
            counts.put('skippedCount', this.skippedCount);
            counts.put('totalProcessed', this.status1Count + this.status2Count + this.unchangedCount + this.skippedCount);
            summaryData.put('counts', counts);
            summaryData.put('currentYear', this.year);
            summaryData.put('currentQuarter', this.quarter);

            Date delinqNotice = this.delinquencyNoticeDate;
            Date delinqDue = this.delinquencyDueDate;
            if (delinqNotice == null) {
                delinqNotice = getQuarterStartDateForDate(Date.today());
            }
            if (delinqDue == null) {
                delinqDue = getQuarterStartDateForDate(Date.today()).addMonths(3).addDays(-1);
            }
            summaryData.put('delinquencyNoticeDate', delinqNotice);
            summaryData.put('delinquencyDueDate', delinqDue);

            summaryData.put(SUMMARY_KEY_EXECUTION_STATUS, !logs.isEmpty() ? EXECUTION_STATUS_ERROR : EXECUTION_STATUS_SUCCESS);
            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGDelinquencyStatusUpdateBatchJob', summaryData);

            // Add specific fields for this job
            jobRecord.breg_Status_1_Count__c = this.status1Count;
            jobRecord.breg_Status_2_Count__c = this.status2Count;
            jobRecord.breg_Total_Count__c = this.status1Count + this.status2Count + this.unchangedCount + this.skippedCount;
            jobRecord.breg_Delinquency_Notice_Date__c = delinqNotice;
            jobRecord.breg_Delinquency_Due_Date__c = delinqDue;

            insert jobRecord;

            System.debug(
                'BREGDelinquencyStatusUpdateBatch completed. Status 1 Count: ' +
                    status1Count +
                    ', Status 2 Count: ' +
                    status2Count +
                    ', Total logs: ' +
                    logs.size()
            );
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
        }
    }

    public static void startWorkflowAsync(String workflowName, Id recordId, String params) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, params, 'BREGDelinquencyStatusUpdateBatchJob', false));
        }
    }
}