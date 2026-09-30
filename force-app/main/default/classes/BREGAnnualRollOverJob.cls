public class BREGAnnualRollOverJob extends BREGBaseBatchJob implements Database.Batchable<sObject>, Database.Stateful {
    // -------------------------------------------------------------------------
    // CONSTANTS
    // -------------------------------------------------------------------------
    private static final Set<String> VALID_ENTITY_STATUSES = new Set<String>{
        'Active (A)',
        'Annual report 1 yr delinquent (1)'
        // 'Annual report 2 yr delinquent (2)'  // BREG-4779 - Exclude 2 year delinquent from rollover
    };

    // Tracking variables
    private Integer processedCount = 0;
    private Integer createdCount = 0;
    private Integer skippedCount = 0;
    private Integer errorCount = 0;

    // Cache current year and quarter for reuse
    private DateTime referenceDateTime = DateTime.now();
    public Boolean isScheduled = false;
    public BREGAnnualRollOverJob() {
        super();
    }

    public BREGAnnualRollOverJob(Boolean isPreview) {
        super();
        this.isPreview = isPreview;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Check if job should run today
        if (isScheduled && (isJobScheduledToRunOnReferenceDate() == false)) {
            System.debug('⚠️ BREG_Annuals_Batch: Job_Start_Date__c does not match the reference date. Job will not run.');
            // Return an empty query to gracefully exit
            return Database.getQueryLocator([SELECT Id FROM Account WHERE Id = NULL]);
        }
        List<String> excludedEntityTypes = System.Label.BREG_Excluded_Entities_From_Rollover_Job != null
            ? new List<String>(System.Label.BREG_Excluded_Entities_From_Rollover_Job.split(','))
            : new List<String>();

        excludedEntityTypes.addAll(new List<String>{ ConstantsHelper.G5_ENTITY_TYPE, ConstantsHelper.G6_ENTITY_TYPE }); // Always exclude G5 and G6 entity types

        return Database.getQueryLocator(
            [
                SELECT Id, Name, breg_Incorporation_Date__c, breg_Entity_Type__c, ParentId, Parent.breg_Entity_Type__c
                FROM Account
                WHERE
                    breg_Entity_Status__c IN :VALID_ENTITY_STATUSES
                    AND breg_Incorporation_Date__c != NULL
                    AND RecordType.DeveloperName = 'BREG_Account'
                    AND breg_Entity_Type__c NOT IN :excludedEntityTypes
                    AND CALENDAR_QUARTER(breg_Incorporation_Date__c) = :quarter
            ]
        );
    }
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<breg_Annual__c> annualsToInsert = new List<breg_Annual__c>();
        List<breg_Test_Annual__c> testAnnualsToInsert = new List<breg_Test_Annual__c>();
        Map<Id, breg_Annual__c> existingAnnualsByAccountMap = getExistingAnnualsByAccountMap(scope);
        Map<Id, List<Account>> parentIdToChildAccountsMap = getParentIdToChildAccountsMap(scope);
        String referenceYear = String.valueOf(referenceDateTime.date().year());
        String nextYear = String.valueOf(referenceDateTime.date().addYears(1).year());
        for (Account acc : scope) {
            processedCount++;
            String accountId = acc.Id;

            breg_Annual__c existingAnnual = existingAnnualsByAccountMap.get(accountId);

            List<Account> childAccounts = parentIdToChildAccountsMap.get(accountId) ?? new List<Account>();
            List<Account> allAccountsForAnnual = new List<Account>{ acc };
            allAccountsForAnnual.addAll(childAccounts);
            processedCount += childAccounts.size(); // Increment processed count for child accounts as well
            // Get the first day of the quarter based on the incorporation date
            // Check if an annual record for the same year already exists
            if (existingAnnual != null || acc.breg_Incorporation_Date__c.year() >= Integer.valueOf(referenceYear)) {
                skippedCount += 1 + childAccounts.size(); // Increment skipped count for parent and child accounts
                continue;
            }
            Integer incorporationQuarter = getQuarterFromDate(acc.breg_Incorporation_Date__c);
            Date quarterStartDate = getFirstDayOfQuarter(Integer.valueOf(referenceYear), incorporationQuarter);
            String fillingYear = acc.breg_Incorporation_Date__c.year() >= Integer.valueOf(referenceYear) ? nextYear : referenceYear;
            Date filingDate = acc.breg_Incorporation_Date__c.year() >= Integer.valueOf(referenceYear) ? quarterStartDate.addYears(1) : quarterStartDate;
            if (isPreview) {
                testAnnualsToInsert.addAll(generateTestAnnuals(allAccountsForAnnual, fillingYear, filingDate));
            } else {
                annualsToInsert.addAll(generateAnnuals(allAccountsForAnnual, fillingYear, filingDate));
            }
        }

        if (!annualsToInsert.isEmpty()) {
            try {
                insert annualsToInsert;
                createdCount += annualsToInsert.size();
                System.debug('✅ Inserted ' + annualsToInsert.size() + ' new breg_Annual__c records.');
            } catch (Exception e) {
                errorCount += annualsToInsert.size();
                System.debug('❌ Error inserting annuals: ' + e.getMessage());
            }
        }

        if (isPreview && !testAnnualsToInsert.isEmpty()) {
            try {
                insert testAnnualsToInsert;
                createdCount += testAnnualsToInsert.size();
                System.debug('✅ Inserted ' + testAnnualsToInsert.size() + ' new breg_Test_Annual__c records.');
            } catch (Exception e) {
                errorCount += testAnnualsToInsert.size();
                System.debug('❌ Error inserting test annuals: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Create Batch Job Execution record to track batch results
        try {
            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGAnnualRollOverJob');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('processedCount', this.processedCount);
            counts.put('createdCount', this.createdCount);
            counts.put('skippedCount', this.skippedCount);
            counts.put('errorCount', this.errorCount);
            counts.put('totalProcessed', this.processedCount);
            summaryData.put('counts', counts);

            // Additional metadata
            summaryData.put('referenceDateTime', this.referenceDateTime.format());
            summaryData.put('currentYear', this.year);
            summaryData.put('currentQuarter', this.quarter);

            summaryData.put(SUMMARY_KEY_EXECUTION_STATUS, this.errorCount > 0 ? EXECUTION_STATUS_ERROR : EXECUTION_STATUS_SUCCESS);
            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGAnnualRollOverJob', summaryData);

            // Set legacy count fields for this specific job
            jobRecord.breg_Total_Count__c = this.processedCount;

            insert jobRecord;

            System.debug(
                '🏁 BREG_Annuals_Batch completed. Processed: ' +
                    processedCount +
                    ', Created: ' +
                    createdCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Errors: ' +
                    errorCount
            );
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
            System.debug(
                '🏁 BREG_Annuals_Batch completed. Processed: ' +
                    processedCount +
                    ', Created: ' +
                    createdCount +
                    ', Skipped: ' +
                    skippedCount +
                    ', Errors: ' +
                    errorCount
            );
        }
    }

    /**
     * Helper method: Checks if job should run today.
     */
    /**
     * Helper method: Checks if there is at least one setting record
     * whose Job_Start_Date__c (DateTime) has the same Date as today.
     */
    private Map<Id, breg_Annual__c> getExistingAnnualsByAccountMap(List<Account> accounts) {
        String referenceYear = String.valueOf(referenceDateTime.date().year());
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(isLLPAccount(acc) && acc.ParentId != null && isGPAccount(acc.Parent) ? acc.ParentId : acc.Id);
        }

        Map<Id, breg_Annual__c> annualsByAccountMap = new Map<Id, breg_Annual__c>();
        List<breg_Annual__c> existingAnnuals = [
            SELECT Id, breg_Account__c, breg_Filing_Year__c
            FROM breg_Annual__c
            WHERE (breg_Account__c IN :accountIds OR breg_Account__r.ParentId IN :accountIds) AND breg_Filing_Year__c = :referenceYear
        ];

        for (breg_Annual__c annual : existingAnnuals) {
            annualsByAccountMap.put(annual.breg_Account__c, annual);
        }

        return annualsByAccountMap;
    }

    private Map<Id, List<Account>> getParentIdToChildAccountsMap(List<Account> accounts) {
        Map<Id, List<Account>> parentIdToChildrenMap = new Map<Id, List<Account>>();

        List<Account> llpAccounts = new List<Account>();
        for (Account acc : accounts) {
            if (isLLPAccount(acc)) {
                llpAccounts.add(acc);
            }
        }
        List<Account> childAccounts = [
            SELECT Id, ParentId
            FROM Account
            WHERE ParentId IN :llpAccounts AND breg_Entity_Type__c IN (:ConstantsHelper.G5_ENTITY_TYPE, :ConstantsHelper.G6_ENTITY_TYPE)
        ];
        for (Account acc : childAccounts) {
            if (!parentIdToChildrenMap.containsKey(acc.ParentId)) {
                parentIdToChildrenMap.put(acc.ParentId, new List<Account>());
            }
            parentIdToChildrenMap.get(acc.ParentId).add(acc);
        }
        return parentIdToChildrenMap;
    }

    private List<breg_Test_Annual__c> generateTestAnnuals(List<Account> accounts, String filingYear, Date filingDate) {
        List<breg_Test_Annual__c> testAnnuals = new List<breg_Test_Annual__c>();
        for (Account acc : accounts) {
            breg_Test_Annual__c testAnnual = new breg_Test_Annual__c();
            testAnnual.breg_Account__c = acc.Id;
            testAnnual.breg_Filing_Year__c = filingYear;
            testAnnual.breg_Filing_Date__c = filingDate;
            testAnnuals.add(testAnnual);
        }
        return testAnnuals;
    }

    private List<breg_Annual__c> generateAnnuals(List<Account> accounts, String filingYear, Date filingDate) {
        List<breg_Annual__c> annuals = new List<breg_Annual__c>();
        for (Account acc : accounts) {
            breg_Annual__c annual = new breg_Annual__c();
            annual.breg_Account__c = acc.Id;
            annual.breg_Filing_Year__c = filingYear;
            annual.breg_Filing_Date__c = filingDate;
            annuals.add(annual);
        }
        return annuals;
    }

    private Boolean isJobScheduledToRunOnReferenceDate() {
        List<BREG_Annuals_Rollover_Job_Settings__mdt> settings = [
            SELECT breg_Job_Start_Date__c
            FROM BREG_Annuals_Rollover_Job_Settings__mdt
            WHERE breg_Job_Start_Date__c != NULL
        ];

        system.debug('referenceDateTime.format=' + referenceDateTime.formatGmt('yyyy-MM-dd'));
        system.debug('referenceDateTime.=' + referenceDateTime);

        for (BREG_Annuals_Rollover_Job_Settings__mdt s : settings) {
            System.debug('s.breg_Job_Start_Date__c.format=' + s.breg_Job_Start_Date__c.formatGmt('yyyy-MM-dd'));
            if (s.breg_Job_Start_Date__c.formatGmt('yyyy-MM-dd') == referenceDateTime.formatGmt('yyyy-MM-dd')) {
                return true;
            }
        }
        return false;
    }

    /**
     * Helper method: Gets the quarter (1-4) for a given date based on the month.
     * January 1 - March 31 = Q1
     * April 1 - June 30 = Q2
     * July 1 - September 30 = Q3
     * October 1 - December 31 = Q4
     */
    private Integer getQuarterFromDate(Date iDate) {
        if (iDate == null)
            return null;
        return ((iDate.month() - 1) / 3) + 1;
    }

    private Boolean isLLPAccount(Account acc) {
        return (acc.breg_Entity_Type__c == ConstantsHelper.K5_ENTITY_TYPE || acc.breg_Entity_Type__c == ConstantsHelper.K6_ENTITY_TYPE);
    }

    private Boolean isGPAccount(Account acc) {
        return (acc.breg_Entity_Type__c == ConstantsHelper.G5_ENTITY_TYPE || acc.breg_Entity_Type__c == ConstantsHelper.G6_ENTITY_TYPE);
    }

    /**
     * Helper method: Gets the first day of the specified quarter for the given year.
     */
    private Date getfirstDayOfQuarter(Integer year, Integer quarter) {
        Integer firstMonth;
        Integer firstDay;

        switch on quarter {
            when 1 {
                firstMonth = 1;
                firstDay = 1;
            }
            when 2 {
                firstMonth = 4;
                firstDay = 1;
            }
            when 3 {
                firstMonth = 7;
                firstDay = 1;
            }
            when 4 {
                firstMonth = 10;
                firstDay = 1;
            }
            when else {
                throw new IllegalArgumentException('Invalid quarter: ' + quarter + '. Quarter must be 1, 2, 3, or 4.');
            }
        }

        return Date.newInstance(year, firstMonth, firstDay);
    }
}