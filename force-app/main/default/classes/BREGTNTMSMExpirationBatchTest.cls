@IsTest
public with sharing class BREGTNTMSMExpirationBatchTest {
    @TestSetup
    static void setupTestData() {
        Date today = Date.today();
        Date pastDate = today.addDays(-10);
        Date futureDate = today.addDays(10);

        List<breg_TN_TM_SM__c> testRecords = new List<breg_TN_TM_SM__c>();

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Expire 1',
                breg_Expiration_Date__c = pastDate,
                breg_Status__c = 'A',
                breg_File_Suffix__c = 'TN',
                breg_Type__c = 'Trade Name'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Expire 2',
                breg_Expiration_Date__c = today,
                breg_Status__c = 'A',
                breg_File_Suffix__c = 'TM',
                breg_Type__c = 'Trademark'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Already Expired',
                breg_Expiration_Date__c = pastDate,
                breg_Status__c = 'E',
                breg_Type__c = 'Trade Name'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Already Cancelled',
                breg_Expiration_Date__c = pastDate,
                breg_Status__c = 'C',
                breg_Type__c = 'Trademark'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Future Expiration',
                breg_Expiration_Date__c = futureDate,
                breg_Status__c = 'A',
                breg_Type__c = 'Service Mark'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM No Expiration Date',
                breg_Expiration_Date__c = null,
                breg_Status__c = 'A',
                breg_Type__c = 'Trade Name'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM With Pending Renewal',
                breg_Expiration_Date__c = pastDate,
                breg_Status__c = 'A',
                breg_Type__c = 'Trademark'
            )
        );

        testRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Test TN_TM_SM Invalid Type',
                breg_Expiration_Date__c = pastDate,
                breg_Status__c = 'A',
                breg_Type__c = 'Publicity Rights Name'
            )
        );

        insert testRecords;

        breg_TN_TM_SM__c recordWithPendingRenewal = [
            SELECT Id
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM With Pending Renewal'
            LIMIT 1
        ];
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'ZZ',
            breg_Suffix_Code__c = 'T-1',
            breg_Form_Code__c = 'T-1',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert testFormConfig;
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case renewalCase = new Case(
            breg_TN_TM_SM__c = recordWithPendingRenewal.Id,
            Status = 'Pending Submission',
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            RecordTypeId = bregCaseRecordTypeId
        );
        insert renewalCase;
        recordWithPendingRenewal.breg_Last_Renewal_Case__c = renewalCase.Id;
        update recordWithPendingRenewal;
    }

    @IsTest
    static void testExpireRecords() {
        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        List<breg_TN_TM_SM__c> expiredRecords = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name IN ('Test TN_TM_SM Expire 1', 'Test TN_TM_SM Expire 2')
        ];

        for (breg_TN_TM_SM__c record : expiredRecords) {
            System.assertEquals('E', record.breg_Status__c, 'Record ' + record.Name + ' should be expired');
        }

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_TN_TM_SM__c, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c IN :expiredRecords
        ];

        System.assertEquals(2, transactions.size(), 'Should create 2 transactions for 2 expired records');

        for (breg_Transaction__c trans : transactions) {
            System.assertNotEquals(null, trans.breg_TN_TM_SM__c, 'Transaction should have TN_TM_SM');
            System.assertEquals('EXP', trans.breg_Transaction_Code__c, 'Transaction code should be EXP');
        }

        List<breg_TN_TM_SM__c> notExpiredRecords = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE
                Name IN (
                    'Test TN_TM_SM Already Cancelled',
                    'Test TN_TM_SM Future Expiration',
                    'Test TN_TM_SM No Expiration Date',
                    'Test TN_TM_SM With Pending Renewal',
                    'Test TN_TM_SM Invalid Type'
                )
        ];

        for (breg_TN_TM_SM__c record : notExpiredRecords) {
            System.assertNotEquals('E', record.breg_Status__c, 'Record ' + record.Name + ' should NOT be expired');
        }
    }

    @IsTest
    static void testExcludeAlreadyExpired() {
        breg_TN_TM_SM__c alreadyExpiredRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Already Expired'
            LIMIT 1
        ];

        String originalStatus = alreadyExpiredRecord.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :alreadyExpiredRecord.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Already expired record status should not change');
    }

    @IsTest
    static void testExcludeAlreadyCancelled() {
        breg_TN_TM_SM__c alreadyCancelledRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Already Cancelled'
            LIMIT 1
        ];

        String originalStatus = alreadyCancelledRecord.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :alreadyCancelledRecord.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Already cancelled record status should not change');
    }

    @IsTest
    static void testExcludePendingRenewal() {
        breg_TN_TM_SM__c recordWithPendingRenewal = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM With Pending Renewal'
            LIMIT 1
        ];

        String originalStatus = recordWithPendingRenewal.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :recordWithPendingRenewal.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Record with pending renewal should not be expired');

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c = :recordWithPendingRenewal.Id
        ];

        System.assertEquals(0, transactions.size(), 'No transaction should be created for record with pending renewal');
    }

    @IsTest
    static void testTransactionCreation() {
        breg_TN_TM_SM__c recordToExpire = [
            SELECT Id, Name, breg_File_Suffix__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Expire 1'
            LIMIT 1
        ];

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_TN_TM_SM__c, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c = :recordToExpire.Id
        ];

        System.assertEquals(1, transactions.size(), 'Should create 1 transaction for expired record');

        breg_Transaction__c iTransaction = transactions[0];
        System.assertEquals(recordToExpire.Id, iTransaction.breg_TN_TM_SM__c, 'Transaction should reference correct TN_TM_SM');
        System.assertEquals('EXP', iTransaction.breg_Transaction_Code__c, 'Transaction code should be EXP');
    }

    @IsTest
    static void testExcludeInvalidType() {
        breg_TN_TM_SM__c invalidTypeRecord = [
            SELECT Id, Name, breg_Status__c, breg_Type__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Invalid Type'
            LIMIT 1
        ];

        String originalStatus = invalidTypeRecord.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :invalidTypeRecord.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Record with invalid type should not be expired');

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c = :invalidTypeRecord.Id
        ];

        System.assertEquals(0, transactions.size(), 'No transaction should be created for record with invalid type');
    }

    @IsTest
    static void testEmptyScope() {
        delete [SELECT Id FROM breg_TN_TM_SM__c];

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<breg_TN_TM_SM__c> records = [SELECT Id FROM breg_TN_TM_SM__c];
        System.assertEquals(0, records.size(), 'No TN_TM_SM records should exist');

        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c];
        System.assertEquals(0, transactions.size(), 'No transactions should be created when no records are processed');
    }

    @IsTest
    static void testPreviewMode() {
        Date today = Date.today();
        Date pastDate = today.addDays(-10);

        breg_TN_TM_SM__c recordToPreview = [
            SELECT Id, Name, breg_Status__c, breg_Status_Preview__c, breg_Status_Preview_Reason__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Expire 1'
            LIMIT 1
        ];

        String originalStatus = recordToPreview.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch(true);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c, breg_Status_Preview__c, breg_Status_Preview_Reason__c, breg_Status_Preview_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :recordToPreview.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Actual status should not change in preview mode');
        System.assertEquals('E', updatedRecord.breg_Status_Preview__c, 'Preview status should be set to expired');
        System.assertEquals('Expiration date passed', updatedRecord.breg_Status_Preview_Reason__c, 'Preview reason should be expiration date passed');
        System.assertNotEquals(null, updatedRecord.breg_Status_Preview_Date__c, 'Preview date should be set');
    }

    @IsTest
    static void testPreviewModeWithPendingRenewal() {
        breg_TN_TM_SM__c recordWithPendingRenewal = [
            SELECT Id, Name, breg_Status__c, breg_Status_Preview__c, breg_Status_Preview_Reason__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM With Pending Renewal'
            LIMIT 1
        ];

        String originalStatus = recordWithPendingRenewal.breg_Status__c;

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch(true);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_Status__c, breg_Status_Preview__c, breg_Status_Preview_Reason__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :recordWithPendingRenewal.Id
        ];

        System.assertEquals(originalStatus, updatedRecord.breg_Status__c, 'Actual status should not change in preview mode');
        System.assertEquals('E', updatedRecord.breg_Status_Preview__c, 'Preview status should still be set to expired');
        System.assertEquals('Has pending renewal', updatedRecord.breg_Status_Preview_Reason__c, 'Preview reason should indicate pending renewal');
    }

    @IsTest
    static void testPreviewModeNoActualUpdates() {
        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch(true);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c];
        System.assertEquals(0, transactions.size(), 'No transactions should be created in preview mode');
    }

    @IsTest
    static void testExecuteModeCreatesTransactions() {
        breg_TN_TM_SM__c record1 = [
            SELECT Id, Name, breg_File_Suffix__c, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Expire 1'
            LIMIT 1
        ];

        breg_TN_TM_SM__c record2 = [
            SELECT Id, Name, breg_File_Suffix__c, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Expire 2'
            LIMIT 1
        ];

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch(false);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_TN_TM_SM__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            ORDER BY CreatedDate DESC
        ];

        System.assertEquals(2, transactions.size(), 'Should create transactions only for actual expiration');

        Set<Id> expiredRecordIds = new Set<Id>{ record1.Id, record2.Id };
        for (breg_Transaction__c trans : transactions) {
            System.assert(expiredRecordIds.contains(trans.breg_TN_TM_SM__c), 'Transaction should reference an expired record');
            System.assertEquals('EXP', trans.breg_Transaction_Code__c, 'Transaction code should be EXP');
        }
    }

    @IsTest
    static void testEndDateSetOnExpiration() {
        breg_TN_TM_SM__c recordToExpire = [
            SELECT Id, Name, breg_End_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Test TN_TM_SM Expire 1'
            LIMIT 1
        ];

        System.assertEquals(null, recordToExpire.breg_End_Date__c, 'End date should initially be null');

        Test.startTest();
        BREGTNTMSMExpirationBatch batch = new BREGTNTMSMExpirationBatch(false);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        breg_TN_TM_SM__c updatedRecord = [
            SELECT Id, Name, breg_End_Date__c, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :recordToExpire.Id
        ];

        System.assertEquals('E', updatedRecord.breg_Status__c, 'Status should be expired');
        System.assertEquals(Date.today(), updatedRecord.breg_End_Date__c, 'End date should be set to today');
    }
}