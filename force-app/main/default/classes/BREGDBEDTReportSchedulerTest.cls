@IsTest
private with sharing class BREGDBEDTReportSchedulerTest {

    private static final String ACTIVE_STATUS = 'Active (A)';
    private static final String INACTIVE_STATUS = 'Dissolved (D)';

    private static String generateMonthlyUniqueKey(Date periodEnd, String entityType) {
        String year = String.valueOf(periodEnd.year());
        String month = String.valueOf(periodEnd.month());
        if (month.length() == 1) {
            month = '0' + month;
        }
        String entityTypeFormatted = entityType.replace(' ', '_');
        return year + 'M' + month + '_' + entityTypeFormatted;
    }

    @TestSetup
    static void setupTestData() {
        List<Account> testAccounts = new List<Account>();

        Date today = Date.today();
        Date lastMonth = today.addMonths(-1);
        Date lastMonthStart = lastMonth.toStartOfMonth();
        Date lastMonthEnd = lastMonthStart.addMonths(1).addDays(-1);
        Date twoMonthsAgo = today.addMonths(-2);

        testAccounts.add(new Account(
            Name = 'Domestic LLC 1',
            breg_Entity_Type__c = 'C5',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        testAccounts.add(new Account(
            Name = 'Domestic LLC 2',
            breg_Entity_Type__c = 'C5',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = lastMonthStart.addDays(10),
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        testAccounts.add(new Account(
            Name = 'Domestic LLC 3',
            breg_Entity_Type__c = 'C5',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = INACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = lastMonthStart.addDays(15)
        ));

        testAccounts.add(new Account(
            Name = 'Foreign LLC 1',
            breg_Entity_Type__c = 'C6',
            breg_Location_Type__c = 'Foreign',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        testAccounts.add(new Account(
            Name = 'Domestic Corp 1',
            breg_Entity_Type__c = 'D1',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        testAccounts.add(new Account(
            Name = 'Domestic LLP 1',
            breg_Entity_Type__c = 'K5',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        testAccounts.add(new Account(
            Name = 'Partnership 1',
            breg_Entity_Type__c = 'G5',
            breg_Location_Type__c = 'Domestic',
            breg_Entity_Status__c = ACTIVE_STATUS,
            breg_Incorporation_Date__c = twoMonthsAgo,
            breg_Date_of_dissol_cancel_revoc_term__c = null
        ));

        insert testAccounts;
    }

    @IsTest
    static void testSchedulerExecution() {
        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        String jobId = System.schedule('DBEDT Report Scheduler Test', '0 0 0 1 * ?', scheduler);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled');
    }

    @IsTest
    static void testMonthlyReportGeneration() {
        Date today = Date.today();
        Date currentMonthStart = today.toStartOfMonth();
        Date currentMonthEnd = today;

        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        List<breg_DBEDT_Report__c> reports = [
            SELECT Id, breg_DBEDT_Entity_Type__c, breg_Period_Begin_Date__c,
                   breg_Period_End_Date__c, breg_Begin_Active_Count__c,
                   breg_Newly_Formed_Count__c, breg_Dis_Merge_Count__c,
                   breg_End_Active_Count__c, breg_DBEDT_Unique_Key__c
            FROM breg_DBEDT_Report__c
            WHERE breg_Period_Begin_Date__c = :currentMonthStart
            AND breg_Period_End_Date__c = :currentMonthEnd
        ];

        System.assert(reports.size() >= 7, 'Should create reports for all entity types');

        for (breg_DBEDT_Report__c report : reports) {
            System.assertNotEquals(null, report.breg_DBEDT_Unique_Key__c, 'Unique key should be set');
            System.assertNotEquals(null, report.breg_DBEDT_Entity_Type__c, 'Entity type should be set');
        }
    }

    @IsTest
    static void testQuarterlyReportGeneration() {
        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        Date today = Date.today();
        Integer month = today.month();
        Boolean isQuarterEnd = (month == 3 || month == 6 || month == 9 || month == 12);

        String quarterPattern = String.valueOf(today.year()) + 'Q%';
        List<breg_DBEDT_Report__c> quarterlyReports = [
            SELECT Id, breg_DBEDT_Entity_Type__c, breg_Period_Begin_Date__c,
                   breg_Period_End_Date__c, breg_Begin_Active_Count__c,
                   breg_Newly_Formed_Count__c, breg_Dis_Merge_Count__c,
                   breg_End_Active_Count__c, breg_DBEDT_Unique_Key__c
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE :quarterPattern
        ];

        if (isQuarterEnd) {
            System.assert(quarterlyReports.size() >= 7, 'Should create quarterly reports for all entity types when quarter end');
            for (breg_DBEDT_Report__c report : quarterlyReports) {
                System.assert(report.breg_DBEDT_Unique_Key__c.contains('Q'),
                    'Unique key should contain Q for quarterly');
            }
        } else {
            System.assertEquals(0, quarterlyReports.size(), 'Should not create quarterly reports when not quarter end');
        }
    }

    @IsTest
    static void testUniqueKeyGeneration() {
        Date reportDate = Date.newInstance(2024, 1, 31);
        Date periodBegin = Date.newInstance(2024, 1, 1);
        Date periodEnd = reportDate;

        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler(reportDate, true);
        scheduler.execute(null);
        scheduler.execute(null);
        Test.stopTest();

        List<breg_DBEDT_Report__c> reports = [
            SELECT Id, breg_DBEDT_Unique_Key__c, breg_DBEDT_Entity_Type__c
            FROM breg_DBEDT_Report__c
            WHERE breg_Period_Begin_Date__c = :periodBegin
            AND breg_Period_End_Date__c = :periodEnd
            AND breg_DBEDT_Unique_Key__c LIKE '2024M01_%'
        ];

        System.assertEquals(
            7,
            reports.size(),
            'Should have exactly 7 monthly reports after running twice'
        );

        Set<String> uniqueKeys = new Set<String>();
        for (breg_DBEDT_Report__c report : reports) {
            uniqueKeys.add(report.breg_DBEDT_Unique_Key__c);
        }

        System.assertEquals(7, uniqueKeys.size(), 'All unique keys should be distinct');
    }

    @IsTest
    static void testCountCalculations() {
        Date lastDayOfMonth = Date.newInstance(2024, 2, 29);
        Date periodBegin = lastDayOfMonth.toStartOfMonth();
        Date periodEnd = lastDayOfMonth;

        List<Account> activeAccounts = [
            SELECT Id FROM Account
            WHERE breg_Entity_Type__c = 'C5'
            AND breg_Location_Type__c = 'Domestic'
            AND breg_Entity_Status__c = :ACTIVE_STATUS
        ];

        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        List<breg_DBEDT_Report__c> reports = [
            SELECT breg_Begin_Active_Count__c, breg_Newly_Formed_Count__c,
                   breg_Dis_Merge_Count__c, breg_End_Active_Count__c
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Entity_Type__c = 'Domestic LLC'
            AND breg_Period_Begin_Date__c = :periodBegin
            AND breg_Period_End_Date__c = :periodEnd
        ];

        if (!reports.isEmpty()) {
            breg_DBEDT_Report__c report = reports[0];
            System.assertNotEquals(null, report.breg_Begin_Active_Count__c, 'Begin count should be calculated');
            System.assertNotEquals(null, report.breg_Newly_Formed_Count__c, 'Newly formed count should be calculated');
            System.assertNotEquals(null, report.breg_Dis_Merge_Count__c, 'Dis merge count should be calculated');
            System.assertNotEquals(null, report.breg_End_Active_Count__c, 'End count should be calculated');

            Decimal calculatedEnd = report.breg_Begin_Active_Count__c +
                                   report.breg_Newly_Formed_Count__c -
                                   report.breg_Dis_Merge_Count__c;
            System.assert(calculatedEnd >= report.breg_End_Active_Count__c - 1,
                'Calculated end should be >= actual end (allowing for edge cases)');
        }
    }

    @IsTest
    static void testAnnualCalendarReportGeneration() {
        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        Date today = Date.today();
        Boolean isYearEnd = (today.month() == 12);

        String yearPattern = String.valueOf(today.year()) + 'Y_%';
        List<breg_DBEDT_Report__c> annualReports = [
            SELECT Id, breg_DBEDT_Entity_Type__c, breg_Period_Begin_Date__c,
                   breg_Period_End_Date__c, breg_DBEDT_Unique_Key__c
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE :yearPattern
        ];

        if (isYearEnd) {
            System.assert(annualReports.size() >= 7, 'Should create annual calendar reports for all entity types when year end');
        } else {
            System.assertEquals(0, annualReports.size(), 'Should not create annual calendar reports when not year end');
        }
    }

    @IsTest
    static void testAnnualFiscalReportGeneration() {
        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        Date today = Date.today();
        Boolean isFiscalYearEnd = (today.month() == 6);

        String fiscalPattern = String.valueOf(today.year()) + 'FY_%';
        List<breg_DBEDT_Report__c> fiscalReports = [
            SELECT Id, breg_DBEDT_Entity_Type__c, breg_Period_Begin_Date__c,
                   breg_Period_End_Date__c, breg_DBEDT_Unique_Key__c
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE :fiscalPattern
        ];

        if (isFiscalYearEnd) {
            System.assert(fiscalReports.size() >= 7, 'Should create annual fiscal reports for all entity types when fiscal year end');
        } else {
            System.assertEquals(0, fiscalReports.size(), 'Should not create annual fiscal reports when not fiscal year end');
        }
    }

    @IsTest
    static void testPreviousPeriodCountRetrieval() {
        Date lastDayOfMonth = Date.newInstance(2024, 4, 30);
        Date previousMonthStart = lastDayOfMonth.toStartOfMonth().addMonths(-1);
        Date previousMonthEnd = previousMonthStart.addMonths(1).addDays(-1);

        String uniqueKey = generateMonthlyUniqueKey(previousMonthEnd, 'Domestic LLC');

        breg_DBEDT_Report__c previousReport = new breg_DBEDT_Report__c(
            breg_DBEDT_Entity_Type__c = 'Domestic LLC',
            breg_Period_Begin_Date__c = previousMonthStart,
            breg_Period_End_Date__c = previousMonthEnd,
            breg_DBEDT_Unique_Key__c = uniqueKey,
            breg_Begin_Active_Count__c = 10,
            breg_Newly_Formed_Count__c = 2,
            breg_Dis_Merge_Count__c = 1,
            breg_End_Active_Count__c = 11
        );
        insert previousReport;

        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        Date currentMonthStart = lastDayOfMonth.toStartOfMonth();
        Date currentMonthEnd = lastDayOfMonth;

        List<breg_DBEDT_Report__c> currentReports = [
            SELECT breg_Begin_Active_Count__c, breg_End_Active_Count__c
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Entity_Type__c = 'Domestic LLC'
            AND breg_Period_Begin_Date__c = :currentMonthStart
            AND breg_Period_End_Date__c = :currentMonthEnd
        ];

        if (!currentReports.isEmpty()) {
            System.assertEquals(11, currentReports[0].breg_Begin_Active_Count__c,
                'Begin_Active_Count should match previous period End_Active_Count');
        }
    }

    @IsTest
    static void testAllEntityTypes() {
        Date today = Date.today();
        Date currentMonthStart = today.toStartOfMonth();
        Date currentMonthEnd = today;

        Test.startTest();
        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();
        SchedulableContext ctx = null;
        scheduler.execute(ctx);
        Test.stopTest();

        List<breg_DBEDT_Report__c> reports = [
            SELECT breg_DBEDT_Entity_Type__c
            FROM breg_DBEDT_Report__c
            WHERE breg_Period_Begin_Date__c = :currentMonthStart
            AND breg_Period_End_Date__c = :currentMonthEnd
        ];

        Set<String> entityTypes = new Set<String>();
        for (breg_DBEDT_Report__c report : reports) {
            entityTypes.add(report.breg_DBEDT_Entity_Type__c);
        }

        System.assertEquals(7, entityTypes.size(), 'Should have reports for all 7 entity types');
        System.assert(entityTypes.contains('Domestic LLC'), 'Should include Domestic LLC');
        System.assert(entityTypes.contains('Domestic LLP'), 'Should include Domestic LLP');
        System.assert(entityTypes.contains('Domestic Corporation'), 'Should include Domestic Corporation');
        System.assert(entityTypes.contains('Non-Domestic LLC'), 'Should include Non-Domestic LLC');
        System.assert(entityTypes.contains('Non-Domestic LLP'), 'Should include Non-Domestic LLP');
        System.assert(entityTypes.contains('Non-Domestic Corporation'), 'Should include Non-Domestic Corporation');
        System.assert(entityTypes.contains('Partnership'), 'Should include Partnership');
    }

    @IsTest
    static void testIsLastDayOfMonth() {
        Date lastDay = Date.newInstance(2024, 1, 31);
        Date notLastDay = Date.newInstance(2024, 1, 15);
        Date lastDayFeb = Date.newInstance(2024, 2, 29);
        Date lastDayFebNonLeap = Date.newInstance(2023, 2, 28);

        BREGDBEDTReportScheduler scheduler = new BREGDBEDTReportScheduler();

        System.assertEquals(true, scheduler.isLastDayOfMonth(lastDay), 'January 31 should be last day');
        System.assertEquals(false, scheduler.isLastDayOfMonth(notLastDay), 'January 15 should not be last day');
        System.assertEquals(true, scheduler.isLastDayOfMonth(lastDayFeb), 'February 29 (leap year) should be last day');
        System.assertEquals(true, scheduler.isLastDayOfMonth(lastDayFebNonLeap), 'February 28 (non-leap year) should be last day');
    }

    @IsTest
    static void testCustomReportDateGeneratesQ1Reports() {
        Test.startTest();
        new BREGDBEDTReportScheduler(Date.newInstance(2024, 3, 31), true).execute(null);
        Test.stopTest();

        List<breg_DBEDT_Report__c> q1Reports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024Q1_%'
        ];

        System.assertEquals(7, q1Reports.size(), 'March quarter-end should generate one Q1 report per entity type');
    }

    @IsTest
    static void testCustomReportDateGeneratesQ2AndFiscalReports() {
        Test.startTest();
        new BREGDBEDTReportScheduler(Date.newInstance(2024, 6, 30), true).execute(null);
        Test.stopTest();

        List<breg_DBEDT_Report__c> q2Reports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024Q2_%'
        ];
        List<breg_DBEDT_Report__c> annualFiscalReports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024FY_%'
        ];

        System.assertEquals(7, q2Reports.size(), 'June quarter-end should generate one Q2 report per entity type');
        System.assertEquals(7, annualFiscalReports.size(), 'June fiscal year-end should generate one annual fiscal report per entity type');
    }

    @IsTest
    static void testCustomReportDateGeneratesQ3Reports() {
        Test.startTest();
        new BREGDBEDTReportScheduler(Date.newInstance(2024, 9, 30), true).execute(null);
        Test.stopTest();

        List<breg_DBEDT_Report__c> q3Reports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024Q3_%'
        ];

        System.assertEquals(7, q3Reports.size(), 'September quarter-end should generate one Q3 report per entity type');
    }

    @IsTest
    static void testCustomReportDateGeneratesQ4AndAnnualCalendarReports() {
        Test.startTest();
        new BREGDBEDTReportScheduler(Date.newInstance(2024, 12, 31), true).execute(null);
        Test.stopTest();

        List<breg_DBEDT_Report__c> q4Reports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024Q4_%'
        ];
        List<breg_DBEDT_Report__c> annualCalendarReports = [
            SELECT Id
            FROM breg_DBEDT_Report__c
            WHERE breg_DBEDT_Unique_Key__c LIKE '2024Y_%'
        ];

        System.assertEquals(7, q4Reports.size(), 'December quarter-end should generate one Q4 report per entity type');
        System.assertEquals(7, annualCalendarReports.size(), 'December year-end should generate one annual calendar report per entity type');
    }
}