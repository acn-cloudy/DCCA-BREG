@isTest
public class BregCaseStatusHandlerRevocationTest {

    @testSetup
    static void setupData() {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account accNoAnnual = new Account(
            Name = 'Revocation Entity No Annual',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert accNoAnnual;

        Account accForApproved = new Account(
            Name = 'Revocation Entity Approved',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert accForApproved;

        Case completedCase = new Case(
            Subject = 'Revocation Completed',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accNoAnnual.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert completedCase;

        Case approvedCase = new Case(
            Subject = 'Revocation Approved',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForApproved.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert approvedCase;

        Case pendingCase = new Case(
            Subject = 'Revocation Pending',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = accForApproved.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert pendingCase;

        insert new breg_Transaction__c(
            breg_Account__c = accNoAnnual.Id,
            breg_Status__c = 'New',
            breg_Type__c = 'ANN'
        );
    }

    @isTest
    static void testHandleStatusChange_Completed_NoAnnuals_UpdatesEntityStatus() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c,
                   breg_Name_of_the_Entity__c, breg_File_Suffix__c, breg_Form_Configuration__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Revocation Completed'
            LIMIT 1
        ];

        Test.startTest();
        new BregCaseStatusHandlerRevocation().handleStatusChange(
            new List<Case>{ c },
            'Completed',
            false,
            true
        );
        Test.stopTest();

        Account updatedAcc = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id = :c.breg_Entity__c
        ];

        System.assertEquals(
            'Annual report 1 yr delinquent (1)',
            updatedAcc.breg_Entity_Status__c
        );

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        System.assert(!transactions.isEmpty());

        Boolean foundDelinquentAnnTransaction = false;
        for (breg_Transaction__c t : transactions) {
            if (t.breg_Status__c == 'D') {
                foundDelinquentAnnTransaction = true;
                break;
            }
        }

        System.assert(foundDelinquentAnnTransaction);
    }

    @isTest
    static void testHandleStatusChange_Approved_ExecutesAction() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c,
                   breg_Name_of_the_Entity__c, breg_File_Suffix__c, breg_Form_Configuration__c, breg_Received_Date_Formula__c, breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = 'Revocation Approved'
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Test.startTest();
        new BregCaseStatusHandlerRevocation().handleStatusChange(
            new List<Case>{ c },
            'Received',
            false,
            true
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        System.assert(afterCount > beforeCount);
    }

    @isTest
    static void testHandleStatusChange_OtherStatus_DoesNothing() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c,
                   breg_Name_of_the_Entity__c, breg_File_Suffix__c, breg_Form_Configuration__c
            FROM Case
            WHERE Subject = 'Revocation Pending'
            LIMIT 1
        ];

        Integer beforeTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        Test.startTest();
        new BregCaseStatusHandlerRevocation().handleStatusChange(
            new List<Case>{ c },
            'Pending',
            false,
            true
        );
        Test.stopTest();

        Account unchangedAcc = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id = :c.breg_Entity__c
        ];

        Integer afterTxnCount = [
            SELECT Count()
            FROM breg_Transaction__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];

        System.assertEquals(null, unchangedAcc.breg_Entity_Status__c);
        System.assertEquals(beforeTxnCount, afterTxnCount);
    }

    @isTest
    static void testUpdateCasesOwner() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Group q;
        System.runAs(u) {
            q = new Group(
                Name = 'Revocation Test Queue',
                DeveloperName = 'Revocation_Test_Queue',
                Type = 'Queue'
            );
            insert q;

            QueueSobject qs = new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'Case'
            );
            insert qs;
        }

        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account acc = new Account(
            Name = 'Queue Test Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert acc;

        Case c = new Case(
            Subject = 'Queue Owner Test',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert c;

        Test.startTest();
        BregCaseStatusHandlerRevocation.updateCasesOwner(
            new List<Case>{ c },
            'Revocation Test Queue'
        );
        Test.stopTest();

        Case updatedCase = [
            SELECT Id, OwnerId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(q.Id, updatedCase.OwnerId);
    }
}