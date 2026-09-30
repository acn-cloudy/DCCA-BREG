/**
 * Scheduled job that runs at the end of each month to generate DBEDT Report records.
 *
 * Generates:
 * - Monthly reports for all months
 * - Quarterly reports when month end is also quarter end
 * - Annual reports (Calendar Year + Fiscal Year) when month end is also year end
 *
 * Scheduling:
 * To schedule this job, use the following cron expression to run on the last day of each month at 23:55:
 *
 * String cronExpression = '0 55 23 L * ?';
 * BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
 * System.schedule('DBEDT Report Scheduler', cronExpression, scheduler);
 *
 * Note: The job will only execute if the current date is the last day of the month.
 *
 */
public with sharing class BREGDBEDTReportScheduler implements Schedulable {
    private static final String DOMESTIC_LLC = 'Domestic LLC';
    private static final String DOMESTIC_LLP = 'Domestic LLP';
    private static final String DOMESTIC_CORP = 'Domestic Corporation';
    private static final String NON_DOMESTIC_LLC = 'Non-Domestic LLC';
    private static final String NON_DOMESTIC_LLP = 'Non-Domestic LLP';
    private static final String NON_DOMESTIC_CORP = 'Non-Domestic Corporation';
    private static final String PARTNERSHIP = 'Partnership';

    private static final String ACTIVE_STATUS = 'Active (A)';

    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Terminated (T)',
        'Cancelled (C)',
        'Dissolved (D)',
        'Merged (M)',
        'Converted (9)',
        'Expired (E)',
        'Inv. Dissolved (7)',
        'Inv. Cancelled (X)',
        'Inv. Revoked (R)'
    };

    private static final String PERIOD_MONTHLY = 'Monthly';
    private static final String PERIOD_QUARTERLY = 'Quarterly';
    private static final String PERIOD_ANNUAL_CALENDAR = 'Annual Calendar';
    private static final String PERIOD_ANNUAL_FISCAL = 'Annual Fiscal';

    private static final Set<String> DOMESTIC_LLC_CODES = new Set<String>{ 'C5' };
    private static final Set<String> DOMESTIC_LLP_CODES = new Set<String>{ 'K5', 'Q5' };
    private static final Set<String> DOMESTIC_CORP_CODES = new Set<String>{ 'D1', 'D2', 'D9', 'P1', 'S1', 'A1', 'A2', 'C1', 'C2' };
    private static final Set<String> NON_DOMESTIC_LLC_CODES = new Set<String>{ 'C6' };

    private static final Set<String> NON_DOMESTIC_LLP_CODES = new Set<String>{ 'K6', 'Q6' };

    private static final Set<String> NON_DOMESTIC_CORP_CODES = new Set<String>{ 'F1', 'F2' };

    private static final Set<String> PARTNERSHIP_CODES = new Set<String>{ 'G5', 'G6', 'L5', 'L6' };

    private Boolean skipLastDayOfMonthCheck = false;
    private Date customReportDate;

    /**
     * Default constructor
     */
    public BREGDBEDTReportScheduler() {
        this.skipLastDayOfMonthCheck = false;
        this.customReportDate = null;
    }

    /**
     * Constructor with option to skip last day of month check
     * Use from Developer Console for testing:
     *
     * BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler(true);
     * scheduler.execute(null);
     *
     */
    public BREGDBEDTReportScheduler(Boolean skipLastDayCheck) {
        this.skipLastDayOfMonthCheck = skipLastDayCheck;
        this.customReportDate = null;
    }

    /**
     * Constructor with custom report date and option to skip last day of month check.
     * Use to generate reports for a specific date (e.g. 2025 year-end):
     *
     * BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler(Date.newInstance(2025, 12, 31), true);
     * scheduler.execute(null);
     *
     */
    public BREGDBEDTReportScheduler(Date reportDate, Boolean skipLastDayCheck) {
        this.customReportDate = reportDate;
        this.skipLastDayOfMonthCheck = skipLastDayCheck;
    }

    /**
     * Execute method called by the scheduler
     * Runs at 11:55 PM on the last day of the month
     * Generates report for the current month (e.g., Jan 1-31 when run on Jan 31)
     */
    public void execute(SchedulableContext ctx) {
        Date reportDate = customReportDate != null ? customReportDate : Date.today();

        if (!skipLastDayOfMonthCheck && !Test.isRunningTest() && !isLastDayOfMonth(reportDate)) {
            return;
        }

        Boolean isQuarterEnd = isEndOfQuarter(reportDate);
        Boolean isYearEnd = isEndOfYear(reportDate);
        Boolean isFiscalYearEnd = isEndOfFiscalYear(reportDate);

        generateAllReports(reportDate, isQuarterEnd, isYearEnd, isFiscalYearEnd);
    }
    /**
     * Generate all required reports
     * Uses individual queries per entity type (7 types × 3 queries = 21 per period)
     * Begin_Active_Count comes from previous period, reducing queries
     */
    private void generateAllReports(Date reportDate, Boolean isQuarterEnd, Boolean isYearEnd, Boolean isFiscalYearEnd) {
        Date monthlyBegin = reportDate.toStartOfMonth();
        Date monthlyEnd = reportDate;
        generateReportForPeriod(monthlyBegin, monthlyEnd, PERIOD_MONTHLY);

        if (isQuarterEnd) {
            Integer quarter = getQuarter(reportDate);
            Date quarterBegin = getQuarterStartDate(reportDate.year(), quarter);
            Date quarterEnd = reportDate;
            generateReportForPeriod(quarterBegin, quarterEnd, PERIOD_QUARTERLY);
        }

        if (isYearEnd) {
            Date yearBegin = Date.newInstance(reportDate.year(), 1, 1);
            Date yearEnd = reportDate;
            generateReportForPeriod(yearBegin, yearEnd, PERIOD_ANNUAL_CALENDAR);
        }

        if (isFiscalYearEnd) {
            Date fiscalYearBegin = Date.newInstance(reportDate.year() - 1, 7, 1);
            Date fiscalYearEnd = reportDate;
            generateReportForPeriod(fiscalYearBegin, fiscalYearEnd, PERIOD_ANNUAL_FISCAL);
        }
    }

    /**
     * Generate report records for a given period
     * Uses 3 queries per entity type (Begin_Active_Count comes from previous period)
     * 7 entity types × 3 queries = 21 queries per period
     */
    private void generateReportForPeriod(Date periodBegin, Date periodEnd, String periodType) {
        List<breg_DBEDT_Report__c> reportsToUpsert = new List<breg_DBEDT_Report__c>();

        List<String> dbedtEntityTypes = new List<String>{
            DOMESTIC_LLC,
            DOMESTIC_LLP,
            DOMESTIC_CORP,
            NON_DOMESTIC_LLC,
            NON_DOMESTIC_LLP,
            NON_DOMESTIC_CORP,
            PARTNERSHIP
        };

        Map<String, Decimal> previousEndCounts = getPreviousPeriodEndCounts(periodBegin, periodType);

        for (String dbedtEntityType : dbedtEntityTypes) {
            Decimal beginActiveCount = previousEndCounts.get(dbedtEntityType);
            if (beginActiveCount == null) {
                beginActiveCount = calculateBeginActiveCount(dbedtEntityType, periodBegin);
            }

            Decimal newlyFormedCount = calculateNewlyFormedCount(dbedtEntityType, periodBegin, periodEnd);
            Decimal disMergeCount = calculateDisMergeCount(dbedtEntityType, periodBegin, periodEnd);
            Decimal endActiveCount = calculateEndActiveCount(dbedtEntityType, periodEnd);

            Decimal calculatedEnd = beginActiveCount + newlyFormedCount - disMergeCount;
            if (calculatedEnd != endActiveCount) {
                System.debug(
                    LoggingLevel.WARN,
                    'Formula validation failed for ' +
                        dbedtEntityType +
                        ' period ' +
                        periodBegin +
                        ' to ' +
                        periodEnd +
                        ': Begin(' +
                        beginActiveCount +
                        ') + Newly(' +
                        newlyFormedCount +
                        ') - DisMerge(' +
                        disMergeCount +
                        ') = ' +
                        calculatedEnd +
                        ' but End_Active_Count = ' +
                        endActiveCount
                );
            }

            String uniqueKey = generateUniqueKey(dbedtEntityType, periodBegin, periodEnd, periodType);
            String reportName = generateReportName(dbedtEntityType, periodEnd, periodType);
            breg_DBEDT_Report__c report = new breg_DBEDT_Report__c(
                Name = reportName,
                breg_DBEDT_Unique_Key__c = uniqueKey,
                breg_DBEDT_Entity_Type__c = dbedtEntityType,
                breg_Period_Begin_Date__c = periodBegin,
                breg_Period_End_Date__c = periodEnd,
                breg_Begin_Active_Count__c = beginActiveCount,
                breg_Newly_Formed_Count__c = newlyFormedCount,
                breg_Dis_Merge_Count__c = disMergeCount,
                breg_End_Active_Count__c = endActiveCount
            );

            reportsToUpsert.add(report);
        }

        if (!reportsToUpsert.isEmpty()) {
            Schema.SObjectField uniqueKeyField = breg_DBEDT_Report__c.breg_DBEDT_Unique_Key__c;
            Database.UpsertResult[] results = Database.upsert(reportsToUpsert, uniqueKeyField, false);

            for (Integer index = 0; index < results.size(); index++) {
                if (!results[index].isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'Failed to upsert DBEDT Report: ' + results[index].getErrors());
                }
            }
        }
    }

    /**
     * Get previous period's End_Active_Count values
     */
    private Map<String, Decimal> getPreviousPeriodEndCounts(Date currentPeriodBegin, String periodType) {
        Map<String, Decimal> endCounts = new Map<String, Decimal>();
        Date previousPeriodEnd = currentPeriodBegin.addDays(-1);
        Date previousPeriodBegin;

        if (periodType == PERIOD_MONTHLY) {
            previousPeriodBegin = previousPeriodEnd.toStartOfMonth();
        } else if (periodType == PERIOD_QUARTERLY) {
            Integer quarter = getQuarter(previousPeriodEnd);
            previousPeriodBegin = getQuarterStartDate(previousPeriodEnd.year(), quarter);
        } else {
            if (periodType == PERIOD_ANNUAL_CALENDAR) {
                previousPeriodBegin = Date.newInstance(previousPeriodEnd.year() - 1, 1, 1);
                previousPeriodEnd = Date.newInstance(previousPeriodEnd.year() - 1, 12, 31);
            } else {
                previousPeriodBegin = Date.newInstance(currentPeriodBegin.year() - 1, 7, 1);
                previousPeriodEnd = Date.newInstance(currentPeriodBegin.year(), 6, 30);
            }
        }

        List<breg_DBEDT_Report__c> previousReports = [
            SELECT breg_DBEDT_Entity_Type__c, breg_End_Active_Count__c
            FROM breg_DBEDT_Report__c
            WHERE breg_Period_Begin_Date__c = :previousPeriodBegin AND breg_Period_End_Date__c = :previousPeriodEnd
            LIMIT 10000
        ];

        for (breg_DBEDT_Report__c report : previousReports) {
            if (report.breg_End_Active_Count__c != null) {
                endCounts.put(report.breg_DBEDT_Entity_Type__c, report.breg_End_Active_Count__c);
            }
        }

        return endCounts;
    }

    /**
     * Calculate Begin_Active_Count: Active entities at the beginning of the period
     */
    private Decimal calculateBeginActiveCount(String dbedtEntityType, Date periodBegin) {
        Set<String> accountEntityTypes = getAccountEntityTypesForDBEDTType(dbedtEntityType);

        Integer count = [
            SELECT COUNT()
            FROM Account
            WHERE
                breg_Entity_Type__c IN :accountEntityTypes
                AND breg_Entity_Status__c = :ACTIVE_STATUS
                AND (breg_Incorporation_Date__c <= :periodBegin
                OR breg_Incorporation_Date__c = NULL)
                AND (breg_Date_of_dissol_cancel_revoc_term__c > :periodBegin
                OR breg_Date_of_dissol_cancel_revoc_term__c = NULL)
        ];

        return Decimal.valueOf(count);
    }

    /**
     * Calculate Newly_Formed_Count: Entities formed within the period
     */
    private Decimal calculateNewlyFormedCount(String dbedtEntityType, Date periodBegin, Date periodEnd) {
        Set<String> accountEntityTypes = getAccountEntityTypesForDBEDTType(dbedtEntityType);

        Integer count = [
            SELECT COUNT()
            FROM Account
            WHERE breg_Entity_Type__c IN :accountEntityTypes AND breg_Incorporation_Date__c >= :periodBegin AND breg_Incorporation_Date__c <= :periodEnd
        ];

        return Decimal.valueOf(count);
    }

    /**
     * Calculate Dis_Merge_Count: Entities that became inactive/closed during the period
     * Uses breg_Date_of_dissol_cancel_revoc_term__c as the closed date
     * Status must be in: Terminated (T), Cancelled (C), Dissolved (D), Merged (M), Converted (9), Expired (E), Inv. Dissolved (7), Inv. Cancelled (X)
     */
    private Decimal calculateDisMergeCount(String dbedtEntityType, Date periodBegin, Date periodEnd) {
        Set<String> accountEntityTypes = getAccountEntityTypesForDBEDTType(dbedtEntityType);

        Integer count = [
            SELECT COUNT()
            FROM Account
            WHERE
                breg_Entity_Type__c IN :accountEntityTypes
                AND breg_Entity_Status__c IN :CLOSED_STATUSES
                AND breg_Date_of_dissol_cancel_revoc_term__c != NULL
                AND breg_Date_of_dissol_cancel_revoc_term__c >= :periodBegin
                AND breg_Date_of_dissol_cancel_revoc_term__c <= :periodEnd
                AND (breg_Incorporation_Date__c <= :periodBegin
                OR breg_Incorporation_Date__c = NULL)
        ];

        return Decimal.valueOf(count);
    }

    /**
     * Calculate End_Active_Count: Active entities at the end of the period
     */
    private Decimal calculateEndActiveCount(String dbedtEntityType, Date periodEnd) {
        Set<String> accountEntityTypes = getAccountEntityTypesForDBEDTType(dbedtEntityType);

        Integer count = [
            SELECT COUNT()
            FROM Account
            WHERE
                breg_Entity_Type__c IN :accountEntityTypes
                AND breg_Entity_Status__c = :ACTIVE_STATUS
                AND (breg_Incorporation_Date__c <= :periodEnd
                OR breg_Incorporation_Date__c = NULL)
                AND (breg_Date_of_dissol_cancel_revoc_term__c > :periodEnd
                OR breg_Date_of_dissol_cancel_revoc_term__c = NULL)
        ];

        return Decimal.valueOf(count);
    }

    /**
     * Map DBEDT Entity Type to Account Entity Types
     * Returns the set of entity type codes for the given DBEDT entity type
     */
    private Set<String> getAccountEntityTypesForDBEDTType(String dbedtEntityType) {
        Map<String, Set<String>> entityTypeMap = new Map<String, Set<String>>{
            DOMESTIC_LLC => DOMESTIC_LLC_CODES,
            DOMESTIC_LLP => DOMESTIC_LLP_CODES,
            DOMESTIC_CORP => DOMESTIC_CORP_CODES,
            NON_DOMESTIC_LLC => NON_DOMESTIC_LLC_CODES,
            NON_DOMESTIC_LLP => NON_DOMESTIC_LLP_CODES,
            NON_DOMESTIC_CORP => NON_DOMESTIC_CORP_CODES,
            PARTNERSHIP => PARTNERSHIP_CODES
        };

        return entityTypeMap.containsKey(dbedtEntityType) ? entityTypeMap.get(dbedtEntityType) : new Set<String>();
    }

    /**
     * Generate unique key for report record
     * Format examples:
     * - Monthly: 2024M01_Domestic_LLC
     * - Quarterly: 2024Q1_Partnership
     * - Annual Calendar: 2024Y_Domestic_LLC
     * - Annual Fiscal: 2024FY_Domestic_LLC
     */
    private String generateUniqueKey(String entityType, Date periodBegin, Date periodEnd, String periodType) {
        String year = String.valueOf(periodEnd.year());
        String entityTypeFormatted = entityType.replace(' ', '_');
        String prefix;

        if (periodType == PERIOD_MONTHLY) {
            String month = String.valueOf(periodEnd.month());
            if (month.length() == 1) {
                month = '0' + month;
            }
            prefix = year + 'M' + month;
        } else if (periodType == PERIOD_QUARTERLY) {
            Integer quarter = getQuarter(periodEnd);
            prefix = year + 'Q' + quarter;
        } else if (periodType == PERIOD_ANNUAL_CALENDAR) {
            prefix = year + 'Y';
        } else {
            prefix = year + 'FY';
        }

        return prefix + '_' + entityTypeFormatted;
    }

    /**
     * Generate report name
     * Format examples:
     * - Monthly: DBEDT 2024-01 - Domestic LLC
     * - Quarterly: DBEDT 2024 Q1 - Partnership
     * - Annual Calendar: DBEDT 2024 Annual - Domestic LLC
     * - Annual Fiscal: DBEDT 2024 Fiscal - Domestic LLC
     */
    private String generateReportName(String entityType, Date periodEnd, String periodType) {
        String year = String.valueOf(periodEnd.year());
        String periodPart;

        if (periodType == PERIOD_MONTHLY) {
            String month = String.valueOf(periodEnd.month());
            if (month.length() == 1) {
                month = '0' + month;
            }
            periodPart = year + '-' + month;
        } else if (periodType == PERIOD_QUARTERLY) {
            Integer quarter = getQuarter(periodEnd);
            periodPart = year + ' Q' + quarter;
        } else if (periodType == PERIOD_ANNUAL_CALENDAR) {
            periodPart = year + ' Annual';
        } else {
            periodPart = year + ' Fiscal';
        }

        return 'DBEDT ' + periodPart + ' - ' + entityType;
    }

    /**
     * Check if date is the last day of the month
     */
    @TestVisible
    private Boolean isLastDayOfMonth(Date dateValue) {
        Date lastDayOfMonth = dateValue.toStartOfMonth().addMonths(1).addDays(-1);
        return dateValue == lastDayOfMonth;
    }

    /**
     * Check if date is end of quarter
     */
    private Boolean isEndOfQuarter(Date dateValue) {
        Integer month = dateValue.month();
        return month == 3 || month == 6 || month == 9 || month == 12;
    }

    /**
     * Check if date is end of year (December)
     */
    private Boolean isEndOfYear(Date dateValue) {
        return dateValue.month() == 12;
    }

    /**
     * Check if date is end of fiscal year (June)
     */
    private Boolean isEndOfFiscalYear(Date dateValue) {
        return dateValue.month() == 6;
    }

    /**
     * Get quarter number (1-4) for a date
     */
    private Integer getQuarter(Date dateValue) {
        Integer month = dateValue.month();
        Integer quarter = 4;
        if (month <= 3) {
            quarter = 1;
        } else if (month <= 6) {
            quarter = 2;
        } else if (month <= 9) {
            quarter = 3;
        }
        return quarter;
    }

    /**
     * Get quarter start date
     */
    private Date getQuarterStartDate(Integer year, Integer quarter) {
        Integer month = (quarter - 1) * 3 + 1;
        return Date.newInstance(year, month, 1);
    }
}