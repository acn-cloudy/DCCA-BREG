@IsTest
public with sharing class BREGAccountStatus2DissolutionBatchTest {
    private static final String STATUS_2_YEAR_DELINQUENT = 'Annual report 2 yr delinquent (2)';
    private static final String STATUS_INV_DISSOLVED = 'Inv. Dissolved (7)';
    private static final String STATUS_INV_REVOKED = 'Inv. Revoked (R)';
    private static final String STATUS_INV_CANCELLED = 'Inv. Cancelled (X)';
    private static final String STATUS_ADM_TERMINATED = 'Adm. Terminated (V)';

    @TestSetup
    static void setupTestData() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> testAccounts = new List<Account>();

        // Dissolved entity type (D1)
        testAccounts.add(
            new Account(
                Name = 'Test Account To Process 1',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'D1',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        // Revoked entity type (F1)
        testAccounts.add(
            new Account(
                Name = 'Test Account To Process 2',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'F1',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        // Cancelled entity type (G5)
        testAccounts.add(
            new Account(
                Name = 'Test Account Cancelled Type',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'G5',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        // Terminated entity type (C5)
        testAccounts.add(
            new Account(
                Name = 'Test Account Terminated Type',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'C5',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        testAccounts.add(
            new Account(
                Name = 'Test Account Excluded',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'D2',
                breg_ExcludedFromInvoluntaryDissolution__c = true,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        testAccounts.add(
            new Account(
                Name = 'Test Account Status Only',
                breg_Entity_Status__c = STATUS_2_YEAR_DELINQUENT,
                breg_Entity_Type__c = 'A1',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = false,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        testAccounts.add(
            new Account(
                Name = 'Test Account Included Different Status',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = 'C1',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        testAccounts.add(
            new Account(
                Name = 'Test Account Included Already Dissolved',
                breg_Entity_Status__c = STATUS_INV_DISSOLVED,
                breg_Entity_Type__c = 'P1',
                breg_ExcludedFromInvoluntaryDissolution__c = false,
                breg_IncludedToInvoluntaryDissolution__c = true,
                breg_Incorporation_Date__c = Date.today().addYears(-2), // Ensure it falls within the current quarter
                RecordTypeId = bregAccRecordType
            )
        );

        insert testAccounts;
    }

    @IsTest
    static void testProcessAccountsPreviewMode() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch(true); // Preview mode
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Test Dissolved entity type (D1)
        Account dissolvedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, breg_Inv_Diss_Status_Preview__c, breg_Inv_Diss_Status_Preview_Date__c
            FROM Account
            WHERE Name = 'Test Account To Process 1'
        ];

        System.assertEquals(STATUS_2_YEAR_DELINQUENT, dissolvedAccount.breg_Entity_Status__c, 'Entity status should not change in preview mode');
        System.assertEquals(STATUS_INV_DISSOLVED, dissolvedAccount.breg_Inv_Diss_Status_Preview__c, 'D1 entity type should preview as Inv. Dissolved');
        System.assertEquals(Date.today(), dissolvedAccount.breg_Inv_Diss_Status_Preview_Date__c, 'Preview date should be today');

        // Test Revoked entity type (F1)
        Account revokedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, breg_Inv_Diss_Status_Preview__c
            FROM Account
            WHERE Name = 'Test Account To Process 2'
        ];

        System.assertEquals(STATUS_INV_REVOKED, revokedAccount.breg_Inv_Diss_Status_Preview__c, 'F1 entity type should preview as Inv. Revoked');

        // Test Cancelled entity type (G5)
        Account cancelledAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, breg_Inv_Diss_Status_Preview__c
            FROM Account
            WHERE Name = 'Test Account Cancelled Type'
        ];

        System.assertEquals(STATUS_INV_CANCELLED, cancelledAccount.breg_Inv_Diss_Status_Preview__c, 'G5 entity type should preview as Inv. Cancelled');

        // Test Terminated entity type (C5)
        Account terminatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, breg_Inv_Diss_Status_Preview__c
            FROM Account
            WHERE Name = 'Test Account Terminated Type'
        ];

        System.assertEquals(STATUS_ADM_TERMINATED, terminatedAccount.breg_Inv_Diss_Status_Preview__c, 'C5 entity type should preview as Adm. Terminated');
    }

    @IsTest
    static void testProcessAccountsLiveModeWithMatchingPreviewDate() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        // Set preview fields on test accounts
        List<Account> accountsToUpdate = [
            SELECT Id, breg_Entity_Type__c
            FROM Account
            WHERE Name IN ('Test Account To Process 1', 'Test Account To Process 2', 'Test Account Cancelled Type', 'Test Account Terminated Type')
        ];
        for (Account acc : accountsToUpdate) {
            if (acc.breg_Entity_Type__c == 'D1') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
            } else if (acc.breg_Entity_Type__c == 'F1') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_REVOKED;
            } else if (acc.breg_Entity_Type__c == 'G5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_CANCELLED;
            } else if (acc.breg_Entity_Type__c == 'C5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_ADM_TERMINATED;
            }
            acc.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        }
        update accountsToUpdate;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch(); // Live mode
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify Dissolved entity type (D1) - should create INDS transaction
        Account dissolvedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Inv_Diss_Status_Prev_Reason__c
            FROM Account
            WHERE Name = 'Test Account To Process 1'
        ];
        System.assertEquals(STATUS_INV_DISSOLVED, dissolvedAccount.breg_Entity_Status__c, 'D1 should be Inv. Dissolved');
        System.assertEquals(null, dissolvedAccount.breg_Inv_Diss_Status_Prev_Reason__c, 'Reason should be null when preview date matches');

        // Verify Revoked entity type (F1) - should create INVR transaction
        Account revokedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account To Process 2'
        ];
        System.assertEquals(STATUS_INV_REVOKED, revokedAccount.breg_Entity_Status__c, 'F1 should be Inv. Revoked');

        // Verify Cancelled entity type (G5) - should create INCN transaction
        Account cancelledAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Cancelled Type'
        ];
        System.assertEquals(STATUS_INV_CANCELLED, cancelledAccount.breg_Entity_Status__c, 'G5 should be Inv. Cancelled');

        // Verify Terminated entity type (C5) - should create INDBX transaction
        Account terminatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Terminated Type'
        ];
        System.assertEquals(STATUS_ADM_TERMINATED, terminatedAccount.breg_Entity_Status__c, 'C5 should be Adm. Terminated');

        // Verify transactions were created
        List<BREG_Transaction__c> transactions = [
            SELECT Id, breg_Transaction_Code__c, breg_Account__c, breg_File_Number__c, breg_File_Suffix__c
            FROM BREG_Transaction__c
            WHERE breg_Account__c IN (:dissolvedAccount.Id, :revokedAccount.Id, :cancelledAccount.Id, :terminatedAccount.Id)
        ];
        System.assertEquals(4, transactions.size(), 'Should create 4 transaction records');

        // Verify transaction codes
        Map<Id, String> transactionCodesByAccount = new Map<Id, String>();
        for (BREG_Transaction__c txn : transactions) {
            transactionCodesByAccount.put(txn.breg_Account__c, txn.breg_Transaction_Code__c);
        }

        System.assertEquals('INDS', transactionCodesByAccount.get(dissolvedAccount.Id), 'D1 should have INDS transaction code');
        System.assertEquals('INVR', transactionCodesByAccount.get(revokedAccount.Id), 'F1 should have INVR transaction code');
        System.assertEquals('INCN', transactionCodesByAccount.get(cancelledAccount.Id), 'G5 should have INCN transaction code');
        System.assertEquals('INDBX', transactionCodesByAccount.get(terminatedAccount.Id), 'C5 should have INDBX transaction code');
    }

    @IsTest
    static void testProcessAccountsLiveModeWithNonMatchingPreviewDate() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        // Set preview fields on test accounts with yesterday's date
        List<Account> accountsToUpdate = [
            SELECT Id
            FROM Account
            WHERE Name IN ('Test Account To Process 1', 'Test Account To Process 2')
        ];
        Date yesterdayDate = Date.today().addDays(-1);
        for (Account acc : accountsToUpdate) {
            acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
            acc.breg_Inv_Diss_Status_Preview_Date__c = yesterdayDate;
        }
        update accountsToUpdate;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch(); // Live mode
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> processedAccounts = [
            SELECT
                Id,
                Name,
                breg_Entity_Status__c,
                breg_Inv_Diss_Status_Preview__c,
                breg_Inv_Diss_Status_Preview_Date__c,
                breg_Inv_Diss_Status_Prev_Reason__c
            FROM Account
            WHERE Name IN ('Test Account To Process 1', 'Test Account To Process 2')
        ];

        System.assertEquals(2, processedAccounts.size(), 'Should have 2 accounts to process');

        for (Account acc : processedAccounts) {
            System.assertEquals(
                STATUS_2_YEAR_DELINQUENT,
                acc.breg_Entity_Status__c,
                'Account ' + acc.Name + ' entity status should not change when preview date does not match'
            );
            System.assert(
                acc.breg_Inv_Diss_Status_Prev_Reason__c != null &&
                acc.breg_Inv_Diss_Status_Prev_Reason__c.contains('Status set to dissolved based on batch job execution'),
                'Account ' + acc.Name + ' should have reason field populated'
            );
        }
    }

    @IsTest
    static void testExcludeAccounts() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Account excludedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Excluded'
            LIMIT 1
        ];

        String originalStatus = excludedAccount.breg_Entity_Status__c;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Id = :excludedAccount.Id
        ];

        System.assertEquals(originalStatus, updatedAccount.breg_Entity_Status__c, 'Excluded account status should not change');
    }

    @IsTest
    static void testProcessStatusOnly() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Account statusOnlyAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Status Only'
            LIMIT 1
        ];

        // Set preview fields to today's date
        statusOnlyAccount.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
        statusOnlyAccount.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        update statusOnlyAccount;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Inv_Diss_Status_Prev_Reason__c
            FROM Account
            WHERE Id = :statusOnlyAccount.Id
        ];

        System.assertEquals(
            STATUS_INV_DISSOLVED,
            updatedAccount.breg_Entity_Status__c,
            'Account with STATUS_2_YEAR_DELINQUENT should be processed even if included flag is false'
        );
        System.assertEquals(null, updatedAccount.breg_Inv_Diss_Status_Prev_Reason__c, 'Reason field should be null when preview date matches');
    }

    @IsTest
    static void testProcessIncludedDifferentStatus() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Account includedDifferentStatusAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Included Different Status'
            LIMIT 1
        ];

        // Set preview fields to today's date
        includedDifferentStatusAccount.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
        includedDifferentStatusAccount.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        update includedDifferentStatusAccount;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Inv_Diss_Status_Prev_Reason__c
            FROM Account
            WHERE Id = :includedDifferentStatusAccount.Id
        ];

        System.assertEquals(
            STATUS_INV_DISSOLVED,
            updatedAccount.breg_Entity_Status__c,
            'Account with included flag true should be processed even with different status'
        );
        System.assertEquals(null, updatedAccount.breg_Inv_Diss_Status_Prev_Reason__c, 'Reason field should be null when preview date matches');
    }

    @IsTest
    static void testProcessIncludedAlreadyDissolved() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        Account includedAlreadyDissolvedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test Account Included Already Dissolved'
            LIMIT 1
        ];

        // Set preview fields to today's date
        includedAlreadyDissolvedAccount.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
        includedAlreadyDissolvedAccount.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        update includedAlreadyDissolvedAccount;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c, breg_Inv_Diss_Status_Prev_Reason__c
            FROM Account
            WHERE Id = :includedAlreadyDissolvedAccount.Id
        ];

        System.assertEquals(
            STATUS_INV_DISSOLVED,
            updatedAccount.breg_Entity_Status__c,
            'Account with included flag true should be processed even if already dissolved'
        );
        System.assertEquals(null, updatedAccount.breg_Inv_Diss_Status_Prev_Reason__c, 'Reason field should be null when preview date matches');
    }

    @IsTest
    static void testBatchCounts() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        // Set preview fields to today's date for all accounts that should be processed
        List<Account> accountsToUpdate = [
            SELECT Id, breg_Entity_Type__c
            FROM Account
            WHERE
                Name IN (
                    'Test Account To Process 1',
                    'Test Account To Process 2',
                    'Test Account Status Only',
                    'Test Account Included Different Status',
                    'Test Account Included Already Dissolved',
                    'Test Account Cancelled Type',
                    'Test Account Terminated Type'
                )
        ];
        for (Account acc : accountsToUpdate) {
            // Set preview status based on entity type
            if (acc.breg_Entity_Type__c == 'F1') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_REVOKED;
            } else if (acc.breg_Entity_Type__c == 'G5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_CANCELLED;
            } else if (acc.breg_Entity_Type__c == 'C5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_ADM_TERMINATED;
            } else {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
            }
            acc.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        }
        update accountsToUpdate;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Id jobId = Database.executeBatch(batch, 200);
        Test.stopTest();

        // Check for dissolved accounts
        List<Account> dissolvedAccounts = [
            SELECT Id
            FROM Account
            WHERE
                breg_Entity_Status__c = :STATUS_INV_DISSOLVED
                AND Name IN (
                    'Test Account To Process 1',
                    'Test Account Status Only',
                    'Test Account Included Different Status',
                    'Test Account Included Already Dissolved'
                )
        ];
        System.assertEquals(4, dissolvedAccounts.size(), 'Should have 4 dissolved accounts');

        // Check for revoked accounts
        List<Account> revokedAccounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_INV_REVOKED AND Name = 'Test Account To Process 2'
        ];
        System.assertEquals(1, revokedAccounts.size(), 'Should have 1 revoked account');

        // Check for cancelled accounts
        List<Account> cancelledAccounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_INV_CANCELLED AND Name = 'Test Account Cancelled Type'
        ];
        System.assertEquals(1, cancelledAccounts.size(), 'Should have 1 cancelled account');

        // Check for terminated accounts
        List<Account> terminatedAccounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_ADM_TERMINATED AND Name = 'Test Account Terminated Type'
        ];
        System.assertEquals(1, terminatedAccounts.size(), 'Should have 1 terminated account');

        List<Account> excludedAccounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_2_YEAR_DELINQUENT AND Name = 'Test Account Excluded'
        ];

        System.assertEquals(1, excludedAccounts.size(), 'Should have 1 excluded account');
    }

    @IsTest
    static void testEmptyScope() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        delete [SELECT Id FROM Account WHERE breg_Entity_Status__c = :STATUS_2_YEAR_DELINQUENT];
        delete [SELECT Id FROM Account WHERE breg_IncludedToInvoluntaryDissolution__c = TRUE];

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_2_YEAR_DELINQUENT
        ];
        System.assertEquals(0, accounts.size(), 'No accounts with target status should exist');

        List<Account> dissolvedAccounts = [
            SELECT Id
            FROM Account
            WHERE breg_Entity_Status__c = :STATUS_INV_DISSOLVED
        ];
        System.assertEquals(0, dissolvedAccounts.size(), 'No dissolved accounts should exist after deleting all eligible accounts');
    }

    @IsTest
    static void testBatchJobExecutionRecordCreation() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        // Set preview fields to today's date for all accounts that should be processed
        List<Account> accountsToUpdate = [
            SELECT Id, breg_Entity_Type__c
            FROM Account
            WHERE
                Name IN (
                    'Test Account To Process 1',
                    'Test Account To Process 2',
                    'Test Account Status Only',
                    'Test Account Included Different Status',
                    'Test Account Included Already Dissolved',
                    'Test Account Cancelled Type',
                    'Test Account Terminated Type'
                )
        ];
        for (Account acc : accountsToUpdate) {
            // Set preview status based on entity type
            if (acc.breg_Entity_Type__c == 'F1') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_REVOKED;
            } else if (acc.breg_Entity_Type__c == 'G5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_CANCELLED;
            } else if (acc.breg_Entity_Type__c == 'C5') {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_ADM_TERMINATED;
            } else {
                acc.breg_Inv_Diss_Status_Preview__c = STATUS_INV_DISSOLVED;
            }
            acc.breg_Inv_Diss_Status_Preview_Date__c = Date.today();
        }
        update accountsToUpdate;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch();
        Id jobId = Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify batch job execution record was created
        List<breg_Batch_Job_Execution__c> jobRecords = [
            SELECT Id, breg_Job_Name__c, breg_Results__c, breg_Total_Count__c
            FROM breg_Batch_Job_Execution__c
            WHERE breg_Job_Name__c = 'BREGAccountStatus2DissolutionBatch'
        ];

        System.assertEquals(1, jobRecords.size(), 'Should have 1 batch job execution record');
        System.assertNotEquals(null, jobRecords[0].breg_Results__c, 'Results should not be null');

        // Parse and verify results JSON
        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(jobRecords[0].breg_Results__c);
        System.assertEquals('BREGAccountStatus2DissolutionBatch', results.get('jobName'), 'Job name should match');
        System.assertEquals('Live', results.get('executionMode'), 'Execution mode should be Live');

        Map<String, Object> counts = (Map<String, Object>) results.get('counts');
        System.assertNotEquals(null, counts, 'Counts should not be null');
        System.assertEquals(7, counts.get('processedCount'), 'Should have processed 7 accounts');
        System.assertEquals(1, counts.get('excludedCount'), 'Should have 1 excluded account');
        System.assertEquals(8, counts.get('totalRecords'), 'Total records should be 8');
    }

    @IsTest
    static void testNoTransactionCreationInPreviewMode() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        Test.startTest();
        BREGAccountStatus2DissolutionBatch batch = new BREGAccountStatus2DissolutionBatch(true); // Preview mode
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify no transactions were created in preview mode
        List<BREG_Transaction__c> transactions = [SELECT Id FROM BREG_Transaction__c];
        System.assertEquals(0, transactions.size(), 'No transactions should be created in preview mode');
    }
}