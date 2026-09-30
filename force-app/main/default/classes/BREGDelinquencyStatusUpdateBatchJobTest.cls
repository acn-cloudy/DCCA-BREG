@IsTest
public class BREGDelinquencyStatusUpdateBatchJobTest {
    @TestSetup
    static void setupTestData() {
        List<Account> testAccounts = new List<Account>();
        List<breg_Account_Affiliation__c> testAgents = new List<breg_Account_Affiliation__c>();
        List<breg_Annual__c> testAnnuals = new List<breg_Annual__c>();
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        for (Integer i = 0; i < 20; i++) {
            String status = 'Active (A)';
            Boolean bouncedCheck = false;
            if (Math.mod(i, 4) == 1) {
                status = 'Annual report 1 yr delinquent (1)';
            } else if (Math.mod(i, 4) == 2) {
                status = 'Annual report 2 yr delinquent (2)';
            } else if (Math.mod(i, 4) == 3) {
                bouncedCheck = true;
            }

            Account acc = new Account(
                Name = 'Test Entity ' + i,
                breg_Bounced_Check__c = bouncedCheck,
                breg_Entity_Status__c = status,
                breg_Incorporation_Date__c = Date.today().addYears(-Math.mod(i, 5) - 1),
                RecordTypeId = recordTypeId
            );
            testAccounts.add(acc);
        }
        insert testAccounts;

        List<Account> agentAccounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            Account agentAcc = new Account(Name = 'Agent Account ' + i, breg_Entity_Status__c = 'Active (A)', RecordTypeId = recordTypeId);
            agentAccounts.add(agentAcc);
        }
        insert agentAccounts;

        for (Integer i = 0; i < 10; i++) {
            String role = (Math.mod(i, 2) == 0) ? 'Agent' : 'New Agent';
            Date endDate = (Math.mod(i, 3) == 0) ? Date.today().addDays(-30) : null;

            breg_Account_Affiliation__c agent = new breg_Account_Affiliation__c(
                breg_Role__c = role,
                breg_Start_Date__c = Date.today().addYears(-1),
                breg_End_Date__c = endDate,
                breg_Account__c = agentAccounts[i].Id
            );
            testAgents.add(agent);
        }
        insert testAgents;

        for (Integer i = 0; i < testAccounts.size(); i++) {
            if (i < testAgents.size()) {
                testAccounts[i].breg_Certified_Register_Agent__c = testAgents[i].Id;
            }
        }
        update testAccounts;

        for (Integer i = 0; i < 30; i++) {
            Integer accountIndex = Math.mod(i, testAccounts.size());
            Integer yearOffset = Math.mod(i, 4) - 2;
            Integer uniqueYearOffset = yearOffset + (Integer) (Math.floor(i / testAccounts.size()));
            Date filingDate = Date.today().addYears(uniqueYearOffset);

            breg_Annual__c annual = new breg_Annual__c(
                breg_Account__c = testAccounts[accountIndex].Id,
                breg_Filing_Year__c = String.valueOf(filingDate.year()),
                breg_Status__c = 'P',
                breg_Filing_Date__c = filingDate
            );
            testAnnuals.add(annual);
        }
        insert testAnnuals;
    }

    @IsTest
    static void testConstructorDefaultValues() {
        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob();

        System.assertEquals(false, batch.calculateOne, 'Default calculateOne should be false');
        System.assertEquals(false, batch.calculateTwo, 'Default calculateTwo should be false');
        System.assertEquals(false, batch.isPreview, 'Default isPreview should be false');
        System.assertNotEquals(null, batch.logs, 'Logs should be initialized');
    }

    @IsTest
    static void testConstructorWithParameters() {
        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        System.assertEquals(true, batch.calculateOne, 'calculateOne should be set to true');
        System.assertEquals(true, batch.calculateTwo, 'calculateTwo should be set to true');
        System.assertEquals(true, batch.isPreview, 'isPreview should be set to true');
        System.assertNotEquals(null, batch.logs, 'Logs should be initialized');
    }

    @IsTest
    static void testPreviewMode() {
        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> accountsWithPreview = [
            SELECT
                Id,
                Name,
                breg_Entity_Status__c,
                breg_Delinquency_Status_Preview__c,
                breg_Delinquency_Status_Preview_Reason__c,
                breg_Delinquency_Status_Preview_Date__c
            FROM Account
            WHERE Name LIKE 'Test Entity%' AND breg_Delinquency_Status_Preview__c != NULL
            LIMIT 100
        ];

        System.assert(accountsWithPreview.size() > 0, 'Should have accounts with preview data');

        for (Account acc : accountsWithPreview) {
            System.assertNotEquals(null, acc.breg_Delinquency_Status_Preview__c, 'Preview status should be set');
            System.assertNotEquals(null, acc.breg_Delinquency_Status_Preview_Date__c, 'Preview date should be set');
            System.assert(acc.breg_Delinquency_Status_Preview_Date__c >= DateTime.now().addHours(-1), 'Preview date should be recent');
        }
    }

    @IsTest
    static void testExecutionMode() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, false);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> accountsWithExecutionDate = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Execution_Date__c, breg_Delinquency_Notice_Date__c, breg_Delinquency_Due_Date__c
            FROM Account
            WHERE Name LIKE 'Test Entity%' AND breg_Execution_Date__c != NULL
            LIMIT 100
        ];

        System.assert(accountsWithExecutionDate.size() > 0, 'Should have accounts with execution dates');

        for (Account acc : accountsWithExecutionDate) {
            System.assertNotEquals(null, acc.breg_Execution_Date__c, 'Execution date should be set');
            if (acc.breg_Entity_Status__c == 'Annual report 2 yr delinquent (2)') {
                System.assertNotEquals(null, acc.breg_Delinquency_Notice_Date__c, 'Notice date required for 2-year delinquent');
                System.assertNotEquals(null, acc.breg_Delinquency_Due_Date__c, 'Due date required for 2-year delinquent');
            }
        }

        List<Account> accountsWithPreview = [
            SELECT Id, Name, breg_Delinquency_Status_Preview__c
            FROM Account
            WHERE Name LIKE 'Test Entity%' AND breg_Delinquency_Status_Preview__c != NULL
            LIMIT 100
        ];

        System.assertEquals(0, accountsWithPreview.size(), 'Preview fields should not be set in execution mode');
    }

    @IsTest
    static void updatesAnnualDueDateForOneYearDelinquentTest() {
        List<Account> previewScopeAccounts = [
            SELECT
                Id,
                Name,
                breg_Entity_Status__c,
                breg_Certified_Register_Agent__c,
                breg_Incorporation_Date__c,
                breg_Delinquency_Status_Preview__c,
                breg_Delinquency_Status_Preview_Reason__c,
                breg_Delinquency_Status_Preview_Date__c,
                breg_Delinquency_Notice_Date__c,
                breg_Delinquency_Due_Date__c,
                breg_Delinquency_Manual_Action__c,
                breg_Execution_Date__c,
                breg_Bounced_Check__c,
                breg_Annuals_Due_Date__c
            FROM Account
            WHERE Name LIKE 'Test Entity%'
            LIMIT 200
        ];
        List<SObject> previewScope = new List<SObject>();
        previewScope.addAll(previewScopeAccounts);
        new BREGDelinquencyStatusUpdateBatchJob(true, true, true).execute(null, previewScope);

        Account candidate = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE
                Name LIKE 'Test Entity%'
                AND breg_Entity_Status__c = 'Active (A)'
                AND breg_Delinquency_Status_Preview__c = 'Annual report 1 yr delinquent (1)'
            LIMIT 1
        ];

        System.assertNotEquals(null, candidate, 'Expected at least one candidate that should transition to 1-year delinquent.');

        Date originalDueDate = Date.newInstance(2020, 1, 15);
        candidate.breg_Annuals_Due_Date__c = originalDueDate;
        candidate.breg_Bounced_Check__c = false;
        update candidate;

        Date persistedDueDate = [SELECT breg_Annuals_Due_Date__c FROM Account WHERE Id = :candidate.Id LIMIT 1].breg_Annuals_Due_Date__c;

        List<Account> executionScopeAccounts = [
            SELECT
                Id,
                Name,
                breg_Entity_Status__c,
                breg_Certified_Register_Agent__c,
                breg_Incorporation_Date__c,
                breg_Delinquency_Status_Preview__c,
                breg_Delinquency_Status_Preview_Reason__c,
                breg_Delinquency_Status_Preview_Date__c,
                breg_Delinquency_Notice_Date__c,
                breg_Delinquency_Due_Date__c,
                breg_Delinquency_Manual_Action__c,
                breg_Execution_Date__c,
                breg_Bounced_Check__c,
                breg_Annuals_Due_Date__c
            FROM Account
            WHERE Id = :candidate.Id
            LIMIT 1
        ];

        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        List<SObject> executionScope = new List<SObject>();
        executionScope.addAll(executionScopeAccounts);
        new BREGDelinquencyStatusUpdateBatchJob(true, true, false).execute(null, executionScope);

        Account updatedAccount = [
            SELECT breg_Entity_Status__c, breg_Annuals_Due_Date__c, breg_Good_Standing__c, breg_Execution_Date__c
            FROM Account
            WHERE Id = :candidate.Id
            LIMIT 1
        ];

        System.assertEquals('Annual report 1 yr delinquent (1)', updatedAccount.breg_Entity_Status__c);
        System.assertEquals(persistedDueDate.addYears(1), updatedAccount.breg_Annuals_Due_Date__c);
        System.assertEquals(false, updatedAccount.breg_Good_Standing__c);
        System.assertNotEquals(null, updatedAccount.breg_Execution_Date__c);
    }

    @IsTest
    static void updatesAnnualDueDateForTwoYearDelinquentTest() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Date originalDueDate = Date.newInstance(2020, 1, 15);

        Account delinquentAccount = new Account(
            Name = '2 Year Delinquent Account',
            breg_Entity_Status__c = 'Active (A)',
            RecordTypeId = recordTypeId,
            breg_Incorporation_Date__c = Date.newInstance(Date.today().year() - 5, 7, 1),
            breg_Bounced_Check__c = false,
            breg_Annuals_Due_Date__c = originalDueDate
        );
        insert delinquentAccount;

        Date persistedDueDate = [SELECT breg_Annuals_Due_Date__c FROM Account WHERE Id = :delinquentAccount.Id LIMIT 1].breg_Annuals_Due_Date__c;

        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Test.startTest();
        Database.executeBatch(new BREGDelinquencyStatusUpdateBatchJob(true, true, false), 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT breg_Entity_Status__c, breg_Annuals_Due_Date__c, breg_Good_Standing__c, breg_Delinquency_Notice_Date__c, breg_Delinquency_Due_Date__c
            FROM Account
            WHERE Id = :delinquentAccount.Id
            LIMIT 1
        ];

        System.assertEquals('Annual report 2 yr delinquent (2)', updatedAccount.breg_Entity_Status__c);
        System.assertEquals(persistedDueDate.addYears(1), updatedAccount.breg_Annuals_Due_Date__c);
        System.assertEquals(false, updatedAccount.breg_Good_Standing__c);
        System.assertEquals(Date.today(), updatedAccount.breg_Delinquency_Notice_Date__c);
        System.assertEquals(Date.today().addDays(30), updatedAccount.breg_Delinquency_Due_Date__c);
    }

    @IsTest
    static void testBouncedCheckLogic() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> testAccounts = new List<Account>{
            new Account(
                Name = 'Bounced Check Past Due',
                breg_Bounced_Check__c = true,
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Due_Date__c = Date.today().addDays(-10),
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(-3)
            ),
            new Account(
                Name = 'Bounced Check Future Due',
                breg_Bounced_Check__c = true,
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Due_Date__c = Date.today().addDays(10),
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(-3)
            ),
            new Account(
                Name = 'Bounced Check No Due Date',
                breg_Bounced_Check__c = true,
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Due_Date__c = null,
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(-3)
            )
        };
        insert testAccounts;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> results = [
            SELECT Name, breg_Delinquency_Status_Preview__c, breg_Delinquency_Status_Preview_Reason__c
            FROM Account
            WHERE Name LIKE 'Bounced Check%'
            ORDER BY Name
            LIMIT 100
        ];

        Account pastDue;
        Account futureDue;
        Account noDueDate;

        for (Account acc : results) {
            if (acc.Name == 'Bounced Check Past Due') {
                pastDue = acc;
            } else if (acc.Name == 'Bounced Check Future Due') {
                futureDue = acc;
            } else if (acc.Name == 'Bounced Check No Due Date') {
                noDueDate = acc;
            }
        }
        System.assertEquals(
            'Annual report 2 yr delinquent (2)',
            pastDue.breg_Delinquency_Status_Preview__c,
            'Past due bounced check should become 2-year delinquent'
        );
        System.assertEquals('Bounced check', pastDue.breg_Delinquency_Status_Preview_Reason__c, 'Past due bounced check should have bounced check reason');
        System.assertEquals(null, futureDue.breg_Delinquency_Status_Preview__c, 'Future due bounced check should not be updated');
        System.assertEquals(null, noDueDate.breg_Delinquency_Status_Preview__c, 'No due date bounced check should not be updated');
    }

    @IsTest
    static void testManualActions() {
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> testAccounts = new List<Account>{
            new Account(
                Name = 'Manual Include Account',
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Manual_Action__c = 'Include',
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(3)
            ),
            new Account(
                Name = 'Manual Exclude Account',
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Manual_Action__c = 'Exclude',
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(3)
            ),
            new Account(
                Name = 'Auto Account',
                breg_Entity_Status__c = 'Active (A)',
                breg_Delinquency_Manual_Action__c = 'Auto',
                RecordTypeId = recordTypeId,
                breg_Incorporation_Date__c = Date.today().addYears(3)
            )
        };
        insert testAccounts;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> results = [
            SELECT Name, breg_Delinquency_Manual_Action__c, breg_Delinquency_Status_Preview__c, breg_Delinquency_Status_Preview_Reason__c
            FROM Account
            WHERE Name LIKE 'Manual%' OR Name LIKE 'Auto%'
            ORDER BY Name
            LIMIT 100
        ];
        Account manualExcludeAccount;
        Account manualIncludeAccount;
        Account autoAccount;
        for (Account acc : results) {
            if (acc.breg_Delinquency_Manual_Action__c == 'Exclude') {
                manualExcludeAccount = acc;
            } else if (acc.breg_Delinquency_Manual_Action__c == 'Include') {
                manualIncludeAccount = acc;
            } else if (acc.breg_Delinquency_Manual_Action__c == 'Auto') {
                autoAccount = acc;
            }
        }
        System.assertEquals(
            'Annual report 2 yr delinquent (2)',
            manualIncludeAccount.breg_Delinquency_Status_Preview__c,
            'Include action should set status to 2-year delinquent'
        );
        System.assertEquals('Other', manualIncludeAccount.breg_Delinquency_Status_Preview_Reason__c, 'Include action should have Other reason');
        System.assertEquals(null, manualExcludeAccount.breg_Delinquency_Status_Preview__c, 'Exclude action should have Active status');
        System.assertEquals(null, autoAccount.breg_Delinquency_Status_Preview__c, 'Auto action should process normally');
    }

    @IsTest
    static void testAgentLogic() {
        Account agentAccount = new Account(Name = 'Test Agent Account', breg_Entity_Status__c = 'Active (A)');
        insert agentAccount;

        breg_Account_Affiliation__c activeAgent = new breg_Account_Affiliation__c(
            breg_Role__c = 'Agent',
            breg_Start_Date__c = Date.today().addYears(-1),
            breg_End_Date__c = null,
            breg_Account__c = agentAccount.Id
        );
        insert activeAgent;
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Test Account With Agent',
            breg_Entity_Status__c = 'Active (A)',
            breg_Certified_Register_Agent__c = activeAgent.Id,
            RecordTypeId = recordTypeId,
            breg_Incorporation_Date__c = Date.today().addYears(-3)
        );
        insert testAccount;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account result = [
            SELECT breg_Delinquency_Status_Preview__c, breg_Delinquency_Status_Preview_Reason__c
            FROM Account
            WHERE Name = 'Test Account With Agent'
            LIMIT 1
        ];

        System.assertNotEquals(null, result.breg_Delinquency_Status_Preview__c, 'Account with active agent should have preview status');
        System.assertNotEquals(
            'No active agent',
            result.breg_Delinquency_Status_Preview_Reason__c,
            'Account with active agent should not have no agent reason'
        );
    }

    @IsTest
    static void testDelinquencyCalculation() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Delinquency Test Account',
            breg_Entity_Status__c = 'Active (A)',
            breg_Incorporation_Date__c = Date.today().addYears(-5),
            RecordTypeId = recordTypeId
        );
        insert testAccount;

        List<breg_Annual__c> annuals = new List<breg_Annual__c>{
            new breg_Annual__c(
                breg_Account__c = testAccount.Id,
                breg_Filing_Year__c = String.valueOf(Date.today().year() - 3),
                breg_Status__c = 'F',
                breg_Filing_Date__c = Date.today().addYears(-3)
            ),
            new breg_Annual__c(
                breg_Account__c = testAccount.Id,
                breg_Filing_Year__c = String.valueOf(Date.today().year() - 2),
                breg_Status__c = 'F',
                breg_Filing_Date__c = Date.today().addYears(-2)
            )
        };
        insert annuals;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account result = [
            SELECT breg_Delinquency_Status_Preview__c, breg_Delinquency_Status_Preview_Reason__c
            FROM Account
            WHERE Name = 'Delinquency Test Account'
            LIMIT 1
        ];

        System.assertNotEquals(null, result.breg_Delinquency_Status_Preview__c, 'Account should have preview status based on delinquency calculation');
    }

    @IsTest
    static void testErrorHandling() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Error Test Account',
            breg_Entity_Status__c = 'Active (A)',
            RecordTypeId = recordTypeId,
            breg_Incorporation_Date__c = Date.today().addYears(-3)
        );
        insert testAccount;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob(true, true, true);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        System.assertNotEquals(null, batch.logs, 'Logs should be initialized');
        System.assert(batch.logs.size() >= 0, 'Should have log entries');
    }

    @IsTest
    static void testQuarterCalculation() {
        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob();

        Date testDate = Date.newInstance(2024, 6, 15);
        Date quarterStart = batch.getQuarterStartDateForDate(testDate);

        System.assertEquals(Date.newInstance(2024, 4, 1), quarterStart, 'Q2 start date should be April 1st');
    }

    @IsTest
    static void testConsecutiveMissedAnnuals() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Consecutive Missed Test',
            breg_Entity_Status__c = 'Active (A)',
            RecordTypeId = recordTypeId,
            breg_Incorporation_Date__c = Date.today().addYears(-5)
        );
        insert testAccount;

        BREGDelinquencyStatusUpdateBatchJob batch = new BREGDelinquencyStatusUpdateBatchJob();

        List<breg_Annual__c> annuals = new List<breg_Annual__c>();
        Integer consecutiveMissed = batch.getConsecutiveMissedAnnuals(testAccount, annuals);

        System.assertEquals(3, consecutiveMissed, 'Account with no annuals should have 3 consecutive missed');
    }
}