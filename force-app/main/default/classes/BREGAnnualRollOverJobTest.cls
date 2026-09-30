@IsTest
private class BREGAnnualRollOverJobTest {
    // -------------------------------------------------------------------------
    // ✅ TEST 1: Run when Job_Start_Date__c matches today's date
    // -------------------------------------------------------------------------
    @IsTest
    static void testRunWithMatchingJobDate() {
        Date test_date = DateTime.valueOfGmt('2025-07-05 19:00:00').dateGmt();
        Date reference_date = DateTime.valueOfGmt('2026-07-01 19:00:00').dateGmt();

        // Create test Accounts via factory
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(3);

        accounts[0].breg_Entity_Status__c = 'Active (A)';
        accounts[1].breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)';
        accounts[2].breg_Entity_Status__c = 'Terminated (T)'; // Terminated (T)
        for (Account acc : accounts) {
            acc.breg_Incorporation_Date__c = test_date;
        }
        update accounts;
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob();
        job.quarter = 3;
        Test.startTest();
        Database.executeBatch(job, 100);
        Test.stopTest();

        List<breg_Annual__c> annuals = [SELECT breg_Account__c, breg_Filing_Year__c FROM breg_Annual__c];
        System.assertEquals(2, annuals.size(), 'Two annual records should be created');
        System.assertEquals(String.valueOf(reference_date.year()), annuals[0].breg_Filing_Year__c);
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 4: Prevent duplicate Annual creation for same year
    // -------------------------------------------------------------------------
    @IsTest
    static void testPreventDuplicateAnnuals() {
        Date reference_date = DateTime.valueOfGmt('2026-01-01 00:00:00').dateGmt();
        Date test_date = DateTime.valueOfGmt('2025-10-05 19:00:00').dateGmt();

        // Create one Account via factory
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(1);
        Account acc = accounts[0];
        acc.breg_Entity_Status__c = 'Active (A)';
        acc.breg_Incorporation_Date__c = test_date;
        update acc;

        // Pre-create an Annual record for this account/year to simulate existing data
        breg_Annual__c existingAnnual = new breg_Annual__c(breg_Account__c = acc.Id, breg_Filing_Year__c = String.valueOf(Date.today().year()));
        insert existingAnnual;

        // Run the batch — should NOT create a duplicate
        Test.startTest();
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob();
        job.quarter = 4; // Set quarter to match test date
        Database.executeBatch(job, 100);
        Test.stopTest();

        Integer count = [
            SELECT COUNT()
            FROM breg_Annual__c
            WHERE breg_Account__c = :acc.Id
        ];
        System.assertEquals(1, count, 'Should not create duplicate Annuals for same year');
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 5: Run when Job_Start_Date__c matches today's date
    // -------------------------------------------------------------------------
    @IsTest
    static void testRunWithMatchingJobDateTestAnnuals() {
        Date test_date = DateTime.valueOfGmt('2025-01-05 19:00:00').dateGmt();
        Date reference_date = DateTime.valueOfGmt('2026-01-01 19:00:00').dateGmt();

        // Create test Accounts via factory
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(3);

        accounts[0].breg_Entity_Status__c = 'Active (A)';
        accounts[1].breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)';
        accounts[2].breg_Entity_Status__c = 'Terminated (T)'; // Terminated (T)
        for (Account acc : accounts) {
            acc.breg_Incorporation_Date__c = test_date;
        }
        update accounts;

        Test.startTest();
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob(true);
        job.quarter = 1; // Set quarter to match test date
        Database.executeBatch(job, 100);
        Test.stopTest();

        List<breg_Test_Annual__c> annuals = [SELECT breg_Account__c, breg_Filing_Year__c FROM breg_Test_Annual__c];
        System.assertEquals(2, annuals.size(), 'Two annual records should be created');
        System.assertEquals(String.valueOf(reference_date.year()), annuals[0].breg_Filing_Year__c);
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 7: Skip entities formed in current quarter of current year
    // -------------------------------------------------------------------------
    @IsTest
    static void testSkipEntitiesFormedInCurrentQuarter() {
        DateTime referenceDateTime = DateTime.valueOfGmt('2026-02-01 02:00:00'); // Q1 2026
        Date formationDateInQ1 = Date.newInstance(2025, 2, 15); // Q1 of previous year
        Date formationDateInQ4PrevYear = Date.newInstance(2025, 10, 15); // Different quarter (Q4)
        System.debug('Formation Date in Q1: ' + formationDateInQ1);
        System.debug('Formation Date in Q4 Prev Year: ' + formationDateInQ4PrevYear);
        System.debug('Reference Date Time: ' + referenceDateTime);
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(2);
        accounts[0].breg_Entity_Status__c = 'Active (A)';
        accounts[0].breg_Incorporation_Date__c = formationDateInQ1;
        accounts[1].breg_Entity_Status__c = 'Active (A)';
        accounts[1].breg_Incorporation_Date__c = formationDateInQ4PrevYear;
        update accounts;

        Test.startTest();
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob();
        job.quarter = 1; // Set quarter to match test date
        Database.executeBatch(job, 100);
        Test.stopTest();

        List<breg_Annual__c> annuals = [SELECT breg_Account__c, breg_Filing_Date__c FROM breg_Annual__c ORDER BY breg_Filing_Date__c];
        System.assertEquals(1, annuals.size(), 'One annual should be created');
        // Filing date should be based on incorporation date quarter, not the job run quarter
        // Q1 incorporation (Feb 15) -> Filing date January 1
        // Q4 incorporation (Oct 15) -> Filing date October 1 - should be skipped since it's not in the same quarter as the job run
        System.assertEquals(Date.newInstance(2026, 1, 1), annuals[0].breg_Filing_Date__c, 'Q1 incorporation should have filing date of January 1');
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 8: Filing date based on incorporation date quarter
    // -------------------------------------------------------------------------
    @IsTest
    static void testFilingDateBasedOnIncorporationQuarter() {
        DateTime referenceDateTime = DateTime.valueOfGmt('2026-04-01 02:00:00'); // Q2 2026

        // Create accounts with incorporation dates in each quarter
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(4);
        accounts[0].breg_Entity_Status__c = 'Active (A)';
        accounts[0].breg_Incorporation_Date__c = Date.newInstance(2020, 2, 15); // Q1 -> due January 1
        accounts[1].breg_Entity_Status__c = 'Active (A)';
        accounts[1].breg_Incorporation_Date__c = Date.newInstance(2021, 5, 20); // Q2 -> due April 1
        accounts[2].breg_Entity_Status__c = 'Active (A)';
        accounts[2].breg_Incorporation_Date__c = Date.newInstance(2022, 8, 10); // Q3 -> due July 1
        accounts[3].breg_Entity_Status__c = 'Active (A)';
        accounts[3].breg_Incorporation_Date__c = Date.newInstance(2023, 11, 25); // Q4 -> due October 1
        update accounts;

        Test.startTest();
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob();
        job.quarter = 2; // Set quarter to match test date
        Database.executeBatch(job, 100);
        Test.stopTest();

        // Query annuals and verify filing dates match incorporation quarter
        Map<Id, breg_Annual__c> annualsByAccount = new Map<Id, breg_Annual__c>();
        for (breg_Annual__c annual : [SELECT breg_Account__c, breg_Filing_Date__c FROM breg_Annual__c]) {
            annualsByAccount.put(annual.breg_Account__c, annual);
        }

        System.assertEquals(1, annualsByAccount.size(), 'One annual should be created');

        System.assertEquals(
            Date.newInstance(2026, 4, 1),
            annualsByAccount.get(accounts[1].Id).breg_Filing_Date__c, //Second account is Q2 incorporation
            'Q2 incorporation should have filing date of April 1'
        );
    }
}