@IsTest
public with sharing class BREGR7ExpirationBatchTest {
    @TestSetup
    static void setupTestData() {
        Date today = Date.today();
        Date pastDate = today.addDays(-10);
        Date futureDate = today.addDays(10);
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        List<Account> testAccounts = new List<Account>();

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 Expire 1',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = pastDate,
                breg_Entity_Status__c = 'Active (A)',
                breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 Expire 2',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = today,
                breg_Entity_Status__c = 'Active (A)',
                breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 Already Expired',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = pastDate,
                breg_Entity_Status__c = 'Expired (E)'
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 Already Cancelled',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = pastDate,
                breg_Entity_Status__c = 'Cancelled (C)'
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 Future Expiration',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = futureDate,
                breg_Entity_Status__c = 'Active (A)'
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test Non-R7 Account',
                breg_Entity_Type__c = 'F1',
                breg_Expiration_Date__c = pastDate,
                breg_Entity_Status__c = 'Active (A)'
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 No Expiration Date',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = null,
                breg_Entity_Status__c = 'Active (A)'
            )
        );

        testAccounts.add(
            new Account(
                RecordTypeId = bregAccountRecordTypeId,
                Name = 'Test R7 With Pending Renewal',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Expiration_Date__c = pastDate,
                breg_Entity_Status__c = 'Active (A)',
                breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
            )
        );

        insert testAccounts;
    }

    @IsTest
    static void testExpireAccounts() {
        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> expiredAccounts = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name IN ('Test R7 Expire 1', 'Test R7 Expire 2')
        ];

        for (Account acc : expiredAccounts) {
            System.assertEquals('Expired (E)', acc.breg_Entity_Status__c, 'Account ' + acc.Name + ' should be expired');
        }

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c IN :expiredAccounts
        ];

        System.assertEquals(2, transactions.size(), 'Should create 2 transactions for 2 expired accounts');

        for (breg_Transaction__c trans : transactions) {
            System.assertNotEquals(null, trans.breg_Account__c, 'Transaction should have Account');
            System.assertEquals('EXP', trans.breg_Transaction_Code__c, 'Transaction code should be EXP');
        }

        List<Account> notExpiredAccounts = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name IN ('Test R7 Already Cancelled', 'Test R7 Future Expiration', 'Test Non-R7 Account', 'Test R7 No Expiration Date')
        ];

        for (Account acc : notExpiredAccounts) {
            System.assertNotEquals('Expired (E)', acc.breg_Entity_Status__c, 'Account ' + acc.Name + ' should NOT be expired');
        }
    }

    @IsTest
    static void testExcludeAlreadyExpired() {
        Account alreadyExpiredAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test R7 Already Expired'
            LIMIT 1
        ];

        String originalStatus = alreadyExpiredAccount.breg_Entity_Status__c;

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Id = :alreadyExpiredAccount.Id
        ];

        System.assertEquals(originalStatus, updatedAccount.breg_Entity_Status__c, 'Already expired account status should not change');
    }

    @IsTest
    static void testExcludeAlreadyCancelled() {
        Account alreadyCancelledAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test R7 Already Cancelled'
            LIMIT 1
        ];

        String originalStatus = alreadyCancelledAccount.breg_Entity_Status__c;

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Id = :alreadyCancelledAccount.Id
        ];

        System.assertEquals(originalStatus, updatedAccount.breg_Entity_Status__c, 'Already cancelled account status should not change');
    }

    @IsTest
    static void testTransactionCreation() {
        Account accountToExpire = [
            SELECT Id, Name, breg_File_Suffix__c
            FROM Account
            WHERE Name = 'Test R7 Expire 1'
            LIMIT 1
        ];

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :accountToExpire.Id
        ];

        System.assertEquals(1, transactions.size(), 'Should create 1 iTransaction for expired account');

        breg_Transaction__c iTransaction = transactions[0];
        System.assertEquals(accountToExpire.Id, iTransaction.breg_Account__c, 'Transaction should reference correct Account');
        System.assertEquals('EXP', iTransaction.breg_Transaction_Code__c, 'Transaction code should be EXP');
    }

    @IsTest
    static void testExcludePendingRenewal() {
        Account accountWithPendingRenewal = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test R7 With Pending Renewal'
            LIMIT 1
        ];

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Id = :accountWithPendingRenewal.Id
        ];

        System.assertEquals('Expired (E)', updatedAccount.breg_Entity_Status__c, 'Account should be expired when no pending renewal marker exists');

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_Account__c = :accountWithPendingRenewal.Id
        ];

        System.assertEquals(1, transactions.size(), 'A transaction should be created when account is expired');
    }

    @IsTest
    static void testPreviewMode() {
        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch(true);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> previewAccounts = [
            SELECT
                Id,
                Name,
                breg_Entity_Status__c,
                breg_R7_Expiration_Status_Preview__c,
                breg_R7_Expiration_Status_Preview_Reason__c,
                breg_R7_Expiration_Status_Preview_Date__c
            FROM Account
            WHERE Name IN ('Test R7 Expire 1', 'Test R7 Expire 2')
        ];

        System.assertEquals(2, previewAccounts.size(), 'Should find 2 accounts for preview');

        for (Account acc : previewAccounts) {
            System.assertEquals('Active (A)', acc.breg_Entity_Status__c, 'Actual status should remain unchanged in preview mode');
            System.assertEquals('Expired (E)', acc.breg_R7_Expiration_Status_Preview__c, 'Preview status should be set to Expired');
            System.assertEquals('Expiration date passed', acc.breg_R7_Expiration_Status_Preview_Reason__c, 'Preview reason should be set');
            System.assertNotEquals(null, acc.breg_R7_Expiration_Status_Preview_Date__c, 'Preview date should be set');
        }

        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c];
        System.assertEquals(0, transactions.size(), 'No transactions should be created in preview mode');
    }

    @IsTest
    static void testPreviewModeWithPendingRenewal() {
        Account accountWithPendingRenewal = [
            SELECT Id, Name, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Test R7 With Pending Renewal'
            LIMIT 1
        ];

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch(true);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, breg_Entity_Status__c, breg_R7_Expiration_Status_Preview__c, breg_R7_Expiration_Status_Preview_Reason__c
            FROM Account
            WHERE Id = :accountWithPendingRenewal.Id
        ];

        System.assertEquals('Active (A)', updatedAccount.breg_Entity_Status__c, 'Actual status should remain unchanged');
        System.assertEquals('Expired (E)', updatedAccount.breg_R7_Expiration_Status_Preview__c, 'Preview status should still be set in preview mode');
        System.assertEquals(
            'Expiration date passed',
            updatedAccount.breg_R7_Expiration_Status_Preview_Reason__c,
            'Preview reason should indicate expiration date passed'
        );
    }

    @IsTest
    static void testEmptyScope() {
        delete [SELECT Id FROM Account WHERE breg_Entity_Type__c = :ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE];

        Test.startTest();
        BREGR7ExpirationBatch batch = new BREGR7ExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Account> accounts = [SELECT Id FROM Account WHERE breg_Entity_Type__c = :ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE];
        System.assertEquals(0, accounts.size(), 'No R7 accounts should exist');

        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c];
        System.assertEquals(0, transactions.size(), 'No transactions should be created when no accounts are processed');
    }
}