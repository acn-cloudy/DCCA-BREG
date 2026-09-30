@isTest
public class BREGCreateTransactionTest {
    @testSetup
    static void setupData() {
        // Create test Account
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Test Transaction Account',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813'
        );
        insert testAccount;

        // Create test Case
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Transaction Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            AccountId = testAccount.Id
        );
        insert testCase;

        // Create test CashierCodes with different divisions
        List<CashierCode__c> cashierCodes = new List<CashierCode__c>();
        cashierCodes.add(
            new CashierCode__c(
                Name = 'Test Cashier Code 1',
                CashierCode__c = 'CC001',
                FeeCode__c = 'FEE001',
                Amount__c = 100.00,
                FormDescription__c = 'Test Fee 1',
                Description__c = 'Test Description 1',
                Division__c = 'BREG',
                Category__c = 'Filing'
            )
        );
        cashierCodes.add(
            new CashierCode__c(
                Name = 'Test Cashier Code 2',
                CashierCode__c = 'CC002',
                FeeCode__c = 'FEE002',
                Amount__c = 200.00,
                FormDescription__c = 'Test Fee 2',
                Description__c = 'Test Description 2',
                Division__c = 'BREG',
                Category__c = 'Processing'
            )
        );
        cashierCodes.add(
            new CashierCode__c(
                Name = 'Test Cashier Code 3',
                CashierCode__c = 'CC003',
                FeeCode__c = 'FEE003',
                Amount__c = 150.00,
                FormDescription__c = 'Test Fee 3',
                Description__c = 'Test Description 3',
                Division__c = 'BREG',
                Category__c = 'Filing'
            )
        );
        insert cashierCodes;

        // Create existing Transaction
        Transaction__c existingTransaction = new Transaction__c(
            Account__c = testAccount.Id,
            breg_Case__c = testCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert existingTransaction;

        // Create existing TransactionLines
        List<TransactionLine__c> existingLines = new List<TransactionLine__c>();
        existingLines.add(
            new TransactionLine__c(
                Transaction__c = existingTransaction.Id,
                CashierCode__c = cashierCodes[0].Id,
                Amount__c = 100.00,
                breg_Case__c = testCase.Id
            )
        );
        existingLines.add(
            new TransactionLine__c(
                Transaction__c = existingTransaction.Id,
                CashierCode__c = cashierCodes[1].Id,
                Amount__c = 200.00,
                breg_Case__c = testCase.Id
            )
        );
        insert existingLines;
    }

    @isTest
    static void testInitTransactionWithAccount() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        BREGCreateTransaction.TransactionWrapper result = BREGCreateTransaction.initTransaction(testAccount.Id);
        Test.stopTest();

        Date orgToday = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertNotEquals(null, result, 'TransactionWrapper should not be null');
        System.assertNotEquals(null, result.trns, 'Transaction should not be null');
        System.assertEquals(testAccount.Id, result.trns.Account__c, 'Transaction Account should match');
        System.assertEquals(orgToday, result.trns.Date__c, 'Transaction date should be today');
        System.assertEquals('New', result.trns.Status__c, 'Transaction status should be New');
        System.assertNotEquals(null, result.lines, 'Lines list should not be null');
        System.assertEquals(0, result.lines.size(), 'Lines list should be empty for new transaction');
        System.assertNotEquals(null, result.exampleLine, 'Example line should not be null');
    }

    @isTest
    static void testInitTransactionWithCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        BREGCreateTransaction.TransactionWrapper result = BREGCreateTransaction.initTransaction(testCase.Id);
        Test.stopTest();

        Date orgToday = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertNotEquals(null, result, 'TransactionWrapper should not be null');
        System.assertNotEquals(null, result.trns, 'Transaction should not be null');
        System.assertEquals(testCase.Id, result.trns.breg_Case__c, 'Transaction Case should match');
        System.assertEquals(orgToday, result.trns.Date__c, 'Transaction date should be today');
        System.assertEquals('New', result.trns.Status__c, 'Transaction status should be New');
        System.assertNotEquals(null, result.lines, 'Lines list should not be null');
        System.assertEquals(0, result.lines.size(), 'Lines list should be empty for new transaction');
        System.assertNotEquals(null, result.exampleLine, 'Example line should not be null');
    }

    @isTest
    static void testInitTransactionWithExistingTransaction() {
        Transaction__c existingTransaction = [SELECT Id FROM Transaction__c LIMIT 1];

        Test.startTest();
        BREGCreateTransaction.TransactionWrapper result = BREGCreateTransaction.initTransaction(existingTransaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'TransactionWrapper should not be null');
        System.assertNotEquals(null, result.trns, 'Transaction should not be null');
        System.assertEquals(existingTransaction.Id, result.trns.Id, 'Transaction ID should match');
        System.assertNotEquals(null, result.lines, 'Lines list should not be null');
        System.assertEquals(2, result.lines.size(), 'Lines list should contain 2 existing lines');
        System.assertNotEquals(null, result.exampleLine, 'Example line should not be null');
    }

    @isTest
    static void testGetSelectOptions() {
        Test.startTest();
        List<BREGCreateTransaction.PicklistVal> statusOptions = BREGCreateTransaction.getSelectOptions('Transaction__c', 'Status__c');
        Test.stopTest();

        System.assertNotEquals(null, statusOptions, 'Picklist values should not be null');
        System.assert(statusOptions.size() > 0, 'Picklist values should not be empty');
        for (BREGCreateTransaction.PicklistVal picklistVal : statusOptions) {
            System.assertNotEquals(null, picklistVal.value, 'Picklist value should not be null');
            System.assertNotEquals(null, picklistVal.label, 'Picklist label should not be null');
        }
    }

    @isTest
    static void testSaveTransactionWithNewLines() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        List<CashierCode__c> cashierCodes = [SELECT Id FROM CashierCode__c ORDER BY Name];

        // Create a new transaction
        Transaction__c newTransaction = new Transaction__c(
            breg_Case__c = testCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );

        // Create new transaction lines (not yet inserted)
        List<TransactionLine__c> newLines = new List<TransactionLine__c>();
        newLines.add(new TransactionLine__c(CashierCode__c = cashierCodes[0].Id, Amount__c = 100.00, AmountOverride__c = 120.00));
        newLines.add(new TransactionLine__c(CashierCode__c = cashierCodes[1].Id, Amount__c = 200.00, AmountOverride__c = null));

        String linesJson = JSON.serialize(newLines);

        Test.startTest();
        Id resultTransactionId = BREGCreateTransaction.saveTransaction(newTransaction, linesJson);
        Test.stopTest();

        System.assertNotEquals(null, resultTransactionId, 'Transaction ID should not be null');

        // Verify transaction was saved
        Transaction__c savedTransaction = [SELECT Id, Division__c FROM Transaction__c WHERE Id = :resultTransactionId];
        System.assertNotEquals(null, savedTransaction, 'Transaction should be saved');

        // Verify transaction lines were saved
        List<TransactionLine__c> savedLines = [
            SELECT Id, Amount__c, AmountOverride__c, breg_Unit_Price__c, breg_Case__c, breg_Type__c, Transaction__c, breg_Fee__c
            FROM TransactionLine__c
            WHERE Transaction__c = :resultTransactionId
            ORDER BY Amount__c
        ];
        System.assertEquals(2, savedLines.size(), 'Should have 2 transaction lines');

        // Verify amount override was applied
        System.assertEquals(120.00, savedLines[0].Amount__c, 'Amount should be set from AmountOverride');
        System.assertEquals(120.00, savedLines[0].breg_Unit_Price__c, 'Unit price should match amount');
        System.assertEquals(null, savedLines[0].AmountOverride__c, 'AmountOverride should be null after processing');

        // Verify regular amount
        System.assertEquals(200.00, savedLines[1].Amount__c, 'Amount should remain unchanged');
        System.assertEquals(200.00, savedLines[1].breg_Unit_Price__c, 'Unit price should match amount');

        // Verify all lines have Case and Transaction set
        for (TransactionLine__c line : savedLines) {
            System.assertEquals(testCase.Id, line.breg_Case__c, 'Case should be set on line');
            System.assertEquals(resultTransactionId, line.Transaction__c, 'Transaction should be set on line');
            // breg_Type__c may be null if form category is not configured
        }
    }

    @isTest
    static void testSaveTransactionWithExistingLines() {
        Transaction__c existingTransaction = [SELECT Id, breg_Case__c FROM Transaction__c LIMIT 1];
        List<TransactionLine__c> existingLines = [
            SELECT Id, CashierCode__c, Amount__c
            FROM TransactionLine__c
            WHERE Transaction__c = :existingTransaction.Id
        ];

        // Create mix of existing and new lines
        List<TransactionLine__c> mixedLines = new List<TransactionLine__c>();
        // Add existing line (should be skipped in insert)
        mixedLines.add(existingLines[0]);

        // Add new line
        CashierCode__c newCashierCode = [SELECT Id FROM CashierCode__c WHERE CashierCode__c = 'CC003' LIMIT 1];
        mixedLines.add(new TransactionLine__c(CashierCode__c = newCashierCode.Id, Amount__c = 150.00, AmountOverride__c = null));

        String linesJson = JSON.serialize(mixedLines);

        Test.startTest();
        Id resultTransactionId = BREGCreateTransaction.saveTransaction(existingTransaction, linesJson);
        Test.stopTest();

        System.assertEquals(existingTransaction.Id, resultTransactionId, 'Transaction ID should match');

        // Verify only new line was inserted
        List<TransactionLine__c> allLines = [
            SELECT Id
            FROM TransactionLine__c
            WHERE Transaction__c = :existingTransaction.Id
        ];
        System.assertEquals(3, allLines.size(), 'Should have 3 total lines (2 existing + 1 new)');
    }

    @isTest
    static void testGetCashierCodesWithSingleDivision() {
        // Update one cashier code to have BREG division
        CashierCode__c cc = [SELECT Id FROM CashierCode__c WHERE CashierCode__c = 'CC001' LIMIT 1];
        cc.Division__c = 'BREG';
        update cc;

        // Create test user with single division
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Division__c = 'BREG',
            Alias = 'tuser'
        );
        insert testUser;

        Test.startTest();
        List<CashierCode__c> results;
        System.runAs(testUser) {
            results = BREGCreateTransaction.getCashierCodes();
        }
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return cashier codes for BREG division');
    }

    @isTest
    static void testGetCashierCodesWithMultipleDivisions() {
        // Update cashier codes to have BREG division
        List<CashierCode__c> ccs = [SELECT Id FROM CashierCode__c LIMIT 2];
        for (CashierCode__c cc : ccs) {
            cc.Division__c = 'BREG';
        }
        update ccs;

        // Create test user with multiple divisions
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'MultiDiv',
            Email = 'testmultidiv@example.com',
            Username = 'testmultidiv' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Division__c = 'BREG',
            Alias = 'tmulti'
        );
        insert testUser;

        Test.startTest();
        List<CashierCode__c> results;
        System.runAs(testUser) {
            results = BREGCreateTransaction.getCashierCodes();
        }
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return cashier codes for BREG division');
    }

    @isTest
    static void testGetCashierCodesWithNoDivision() {
        // Create test user without division
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'NoDiv',
            Email = 'testnodiv@example.com',
            Username = 'testnodiv' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Division__c = null,
            Alias = 'tnodiv'
        );
        insert testUser;

        Test.startTest();
        List<CashierCode__c> results;
        System.runAs(testUser) {
            results = BREGCreateTransaction.getCashierCodes();
        }
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return 0 cashier codes when user has no division');
    }

    @isTest
    static void testPicklistValConstructor() {
        Schema.DescribeFieldResult fieldResult = Transaction__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();

        Test.startTest();
        BREGCreateTransaction.PicklistVal picklistVal = new BREGCreateTransaction.PicklistVal(picklistEntries[0]);
        Test.stopTest();

        System.assertNotEquals(null, picklistVal.value, 'Value should not be null');
        System.assertNotEquals(null, picklistVal.label, 'Label should not be null');
        System.assertEquals(picklistEntries[0].getValue(), picklistVal.value, 'Value should match picklist entry value');
        System.assertEquals(picklistEntries[0].getLabel(), picklistVal.label, 'Label should match picklist entry label');
    }

    @isTest
    static void testSaveTransactionWithZeroAmountOverride() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CashierCode__c cashierCode = [SELECT Id FROM CashierCode__c LIMIT 1];

        Transaction__c newTransaction = new Transaction__c(
            breg_Case__c = testCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );

        // Create line with zero override (should not be applied)
        List<TransactionLine__c> newLines = new List<TransactionLine__c>();
        newLines.add(new TransactionLine__c(CashierCode__c = cashierCode.Id, Amount__c = 100.00, AmountOverride__c = 0));

        String linesJson = JSON.serialize(newLines);

        Test.startTest();
        Id resultTransactionId = BREGCreateTransaction.saveTransaction(newTransaction, linesJson);
        Test.stopTest();

        List<TransactionLine__c> savedLines = [
            SELECT Id, Amount__c, AmountOverride__c
            FROM TransactionLine__c
            WHERE Transaction__c = :resultTransactionId
        ];

        System.assertEquals(1, savedLines.size(), 'Should have 1 transaction line');
        System.assertEquals(100.00, savedLines[0].Amount__c, 'Amount should remain unchanged when override is 0');
        System.assertEquals(0, savedLines[0].AmountOverride__c, 'AmountOverride should remain 0 (not applied)');
    }
}