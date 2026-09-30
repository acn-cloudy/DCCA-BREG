@isTest
public class BREGCaseStatusHandlerTNTMSMCancelTest {

    @testSetup
    static void setupData() {
        Id bregAccountRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'BREG_Account'
            LIMIT 1
        ].Id;

        Account acc = new Account(
            Name = 'Test Business Account',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'L5' 
        );
        insert acc;

        breg_TN_TM_SM__c tnTmSm = new breg_TN_TM_SM__c(
            breg_Account__c = acc.Id,
            breg_Status__c = 'A'
        );
        insert tnTmSm;
    }

    @isTest
    static void testHandleStatusChange_Completed_UpdatesTNTMSMAndAccount() {
        Account acc = [
            SELECT Id, breg_End_Date__c, breg_Entity_Type__c, RecordTypeId
            FROM Account
            WHERE Name = 'Test Business Account'
            LIMIT 1
        ];

        breg_TN_TM_SM__c tnTmSm = [
            SELECT Id, breg_Account__c, breg_Status__c, breg_Cancellation_Date__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c = :acc.Id
            LIMIT 1
        ];

        Date effectiveDate = Date.today();

        Case testCase = new Case(
            Subject = 'TNTMSM Cancellation Test',
            Status = 'New',
            Origin = 'Web',
            breg_TN_TM_SM__c = tnTmSm.Id,
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = effectiveDate
        );
        insert testCase;

        Test.startTest();
        BREGCaseStatusHandlerTNTMSMCancel handler = new BREGCaseStatusHandlerTNTMSMCancel();
        handler.handleStatusChange(
            new List<Case>{ testCase },
            'Completed',
            false,
            true
        );
        Test.stopTest();

        breg_TN_TM_SM__c updatedTnTmSm = [
            SELECT Id, breg_Status__c, breg_Cancellation_Date__c, breg_Account__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :tnTmSm.Id
        ];

        Account updatedAcc = [
            SELECT Id, breg_End_Date__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('C', updatedTnTmSm.breg_Status__c);
        System.assertEquals(effectiveDate, updatedTnTmSm.breg_Cancellation_Date__c);
        System.assertEquals(effectiveDate, updatedAcc.breg_End_Date__c);
    }

    @isTest
    static void testHandleStatusChange_NotCompleted_DoesNothing() {
        Account acc = [
            SELECT Id, breg_End_Date__c, breg_Entity_Type__c, RecordTypeId
            FROM Account
            WHERE Name = 'Test Business Account'
            LIMIT 1
        ];

        breg_TN_TM_SM__c tnTmSm = [
            SELECT Id, breg_Account__c, breg_Status__c, breg_Cancellation_Date__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c = :acc.Id
            LIMIT 1
        ];

        Case testCase = new Case(
            Subject = 'TNTMSM Cancellation Test - No Action',
            Status = 'New',
            Origin = 'Web',
            breg_TN_TM_SM__c = tnTmSm.Id,
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert testCase;

        Test.startTest();
        BREGCaseStatusHandlerTNTMSMCancel handler = new BREGCaseStatusHandlerTNTMSMCancel();
        handler.handleStatusChange(
            new List<Case>{ testCase },
            'Pending',
            false,
            true
        );
        Test.stopTest();

        breg_TN_TM_SM__c unchangedTnTmSm = [
            SELECT Id, breg_Status__c, breg_Cancellation_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :tnTmSm.Id
        ];

        Account unchangedAcc = [
            SELECT Id, breg_End_Date__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('A', unchangedTnTmSm.breg_Status__c);
        System.assertEquals(null, unchangedTnTmSm.breg_Cancellation_Date__c);
        System.assertEquals(null, unchangedAcc.breg_End_Date__c);
    }

    @isTest
    static void testHandleStatusChange_Completed_NoEffectiveDate_OnlyStatusUpdated() {
        Account acc = [
            SELECT Id, breg_End_Date__c, breg_Entity_Type__c, RecordTypeId
            FROM Account
            WHERE Name = 'Test Business Account'
            LIMIT 1
        ];

        breg_TN_TM_SM__c tnTmSm = [
            SELECT Id, breg_Account__c, breg_Status__c, breg_Cancellation_Date__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c = :acc.Id
            LIMIT 1
        ];

        Case testCase = new Case(
            Subject = 'TNTMSM Cancellation Test - No Effective Date',
            Status = 'New',
            Origin = 'Web',
            breg_TN_TM_SM__c = tnTmSm.Id,
            breg_Entity__c = acc.Id
        );
        insert testCase;

        Test.startTest();
        BREGCaseStatusHandlerTNTMSMCancel handler = new BREGCaseStatusHandlerTNTMSMCancel();
        handler.handleStatusChange(
            new List<Case>{ testCase },
            'Completed',
            false,
            true
        );
        Test.stopTest();

        breg_TN_TM_SM__c updatedTnTmSm = [
            SELECT Id, breg_Status__c, breg_Cancellation_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :tnTmSm.Id
        ];

        Account updatedAcc = [
            SELECT Id, breg_End_Date__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('C', updatedTnTmSm.breg_Status__c);
        System.assertEquals(null, updatedTnTmSm.breg_Cancellation_Date__c);
        System.assertEquals(null, updatedAcc.breg_End_Date__c);
    }
}