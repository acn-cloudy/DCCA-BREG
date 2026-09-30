@IsTest
private class BREGCaseStatusHandlerCancAcquiredTest {
    private static final String SUBJECT_FOR_VALID_CASE  = 'DC-7 Valid Case';
    private static final String SUBJECT_FOR_INVALID_CASE = 'DC-7 Invalid Case';

    @TestSetup
    static void setup() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();
        Id caseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'DC-7 Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1',
            breg_Authorized_Shares_Count__c = 100
        );
        insert entity;

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DC-7',
            breg_Suffix_Code__c = 'D1',
            breg_Entity_Type__c = 'D1'
        );
        insert formConfig;

        Case validCase = new Case(
            Subject = SUBJECT_FOR_VALID_CASE,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRtId,
            breg_Entity__c = entity.Id,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'DC-7',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Cancelled_Shares_Class_Series__c = 'Common',
            breg_Cancelled_Shares_Count__c = 20,
            breg_Remaining_Shares_Class_Series__c = 'Common',
            breg_Remaining_Shares_Count__c = 80
        );

        Case invalidCase = new Case(
            Subject = SUBJECT_FOR_INVALID_CASE,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRtId,
            breg_Entity__c = entity.Id,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'DC-7',
            breg_Form_Configuration__c = formConfig.Id
        );

        insert new List<Case>{ validCase, invalidCase };
    }

    @IsTest
    static void testCompletedValidationRequiresShareFields() {
        Case invalidCase = [
            SELECT Id, breg_Entity__c, breg_Name_of_the_Entity__c, breg_Effective_Date__c, breg_Form_Code__c,
                   breg_Form_Configuration__c, breg_Form_Configuration__r.breg_Business_Process__c,
                   breg_Form_Configuration__r.breg_Transaction_Code__c, breg_Transaction_Code__c,
                   breg_Remaining_Shares_Class_Series__c, breg_Remaining_Shares_Count__c,
                   breg_Cancelled_Shares_Class_Series__c, breg_Cancelled_Shares_Count__c,
                   breg_Entity__r.Name
            FROM Case
            WHERE Subject = :SUBJECT_FOR_INVALID_CASE
            LIMIT 1
        ];

        Test.startTest();
        try {
            new BREGCaseStatusHandlerCancAcquiredShares().handleStatusChange(new List<Case>{ invalidCase }, 'Completed', true, false);
            System.assert(false, 'Completed validation should throw when share fields are missing');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException ex) {
            System.assert(ex.getMessage().contains('Cancelled Shares Class/Series'), 'Expected the missing cancelled shares field to be reported first');
        }
        Test.stopTest();
    }

    @IsTest
    static void testReceivedCreatesTransactionAndCompletedUpdatesEntityShares() {
        Case validCase = [
            SELECT Id, Status, breg_Entity__c, breg_Name_of_the_Entity__c, breg_Effective_Date__c, breg_Form_Code__c,
                   breg_Form_Configuration__c, breg_Form_Configuration__r.breg_Business_Process__c,
                 breg_Form_Configuration__r.breg_Transaction_Code__c, breg_Transaction_Code__c,
                   breg_Remaining_Shares_Class_Series__c, breg_Remaining_Shares_Count__c,
                   breg_Cancelled_Shares_Class_Series__c, breg_Cancelled_Shares_Count__c,breg_TN_TM_SM__c,
                   breg_Entity__r.Name, breg_File_Suffix__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = :SUBJECT_FOR_VALID_CASE
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerCancAcquiredShares().handleStatusChange(new List<Case>{ validCase }, 'Received', false, true);
        new BREGCaseStatusHandlerCancAcquiredShares().handleStatusChange(new List<Case>{ validCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedEntity = [
            SELECT breg_Authorized_Shares_Count__c
            FROM Account
            WHERE Id = :validCase.breg_Entity__c
            LIMIT 1
        ];
        System.assertEquals(80, updatedEntity.breg_Authorized_Shares_Count__c, 'Completed action should update the entity authorized shares count');

        breg_Transaction__c transactionRecord = [
            SELECT breg_Case__c, breg_Account__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :validCase.Id
            LIMIT 1
        ];
        System.assertEquals(validCase.Id, transactionRecord.breg_Case__c, 'Transaction should be linked to the case');
        System.assertEquals(validCase.breg_Entity__c, transactionRecord.breg_Account__c, 'Transaction should link the entity account');
        System.assertEquals('C', transactionRecord.breg_Status__c, 'Completed should update transaction status to C after Received created it');
    }
}