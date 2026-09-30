@isTest
public class BREGCaseStatusHandlerODCTest {

    @testSetup
    static void setupData() {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account accForReceived = new Account(
            Name = 'ODC Entity Received',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );

        Account accForApproved = new Account(
            Name = 'ODC Entity Approved',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );

        Account accForCompleted = new Account(
            Name = 'ODC Entity Completed',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );

        Account accForPending = new Account(
            Name = 'ODC Entity Pending',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );

        insert new List<Account>{
            accForReceived,
            accForApproved,
            accForCompleted,
            accForPending
        };

        Case receivedCase = new Case(
            Subject = 'ODC Received',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForReceived.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert receivedCase;

        insert new Case(
            Subject = 'ODC Approved',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForApproved.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Is_Manager_Managed__c = true,
            breg_Number_of_initial_members__c = 3
        );

        insert new Case(
            Subject = 'ODC Completed',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForCompleted.Id,
            breg_Is_Manager_Managed__c = true,
            breg_Number_of_initial_members__c = 3,
            breg_Effective_Date__c = Date.today()
        );

        insert new Case(
            Subject = 'ODC Pending',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForPending.Id,
            breg_Effective_Date__c = Date.today()
        );

        Transaction__c trn = new Transaction__c(
            Account__c = accForReceived.Id,
            breg_Case__c = receivedCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert trn;

        TransactionLine__c tl = new TransactionLine__c(
            Transaction__c = trn.Id,
            Amount__c = 20,
            breg_Case__c = receivedCase.Id,
            PaidStatus__c = 'Paid'
        );
        insert tl;
    }

    @isTest
    static void testHandleStatusChange_Received_CreatesOdcTransaction() {
        Case c = [
            SELECT
                Id,
                Status,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Name_of_the_Entity__c,
                breg_File_Suffix__c,
                breg_Form_Configuration__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = 'ODC Received'
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
        ];

        Test.startTest();
        new BREGCaseStatusHandlerODC().handleStatusChange(
            new List<Case>{ c },
            'Received',
            false,
            true
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
        ];

        System.assert(
            afterCount > beforeCount,
            'Received status should create an ODC transaction'
        );
    }

    @isTest
    static void testHandleStatusChange_Approved_UpdatesEntity() {
        Case c = [
            SELECT
                Id,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Is_Manager_Managed__c,
                breg_Number_of_initial_members__c,
                breg_Form_Code__c,
                breg_Name_of_the_Entity__c,
                breg_File_Suffix__c,
                breg_Form_Configuration__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'ODC Approved'
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Test.startTest();
        new BREGCaseStatusHandlerODC().handleStatusChange(
            new List<Case>{ c },
            'Approved',
            false,
            true
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Account updatedAcc = [
            SELECT
                Id,
                breg_Management_Type__c,
                breg_Number_of_initial_members__c
            FROM Account
            WHERE Id = :c.breg_Entity__c
            LIMIT 1
        ];

        System.assertEquals(
            beforeCount,
            afterCount,
            'Completed status should not create an ODC transaction'
        );
        System.assertEquals(
            'Manager Managed',
            updatedAcc.breg_Management_Type__c,
            'Completed status should update management type on entity'
        );
        System.assertEquals(
            Decimal.valueOf(3),
            updatedAcc.breg_Number_of_initial_members__c,
            'Completed status should update number of initial members on entity'
        );
    }

    @isTest
    static void testHandleStatusChange_Completed_DoesNotCreateOdcTransaction() {
        Case c = [
            SELECT
                Id,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Name_of_the_Entity__c,
                breg_File_Suffix__c,
                breg_Form_Configuration__c,
                breg_Received_Date_Formula__c,
                breg_Number_of_initial_members__c,
                breg_Is_Manager_Managed__c
            FROM Case
            WHERE Subject = 'ODC Completed'
            LIMIT 1
        ];

        Integer beforeTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Test.startTest();
        new BREGCaseStatusHandlerODC().handleStatusChange(
            new List<Case>{ c },
            'Completed',
            false,
            true
        );
        Test.stopTest();

        Integer afterTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        System.assertEquals(
            beforeTxnCount,
            afterTxnCount,
            'Completed status should not create an ODC transaction'
        );
    }

    @isTest
    static void testHandleStatusChange_OtherStatus_DoesNothing() {
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'ODC Pending'
            LIMIT 1
        ];

        Integer beforeTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Test.startTest();
        new BREGCaseStatusHandlerODC().handleStatusChange(
            new List<Case>{ c },
            'Pending',
            false,
            true
        );
        Test.stopTest();

        Integer afterTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        System.assertEquals(
            beforeTxnCount,
            afterTxnCount,
            'Pending status should not create an ODC transaction'
        );
    }
}