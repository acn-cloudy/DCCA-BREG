@IsTest
private class BREGCaseStatusHandlerAbandOfConvTest {
    private static final String CONVERSION_FORM_CODE = 'X-10';
    private static final String ABANDONMENT_FORM_CODE = 'X-15';
    private static final String ABANDONMENT_TRANSACTION_CODE = 'CV';

    @TestSetup
    static void setup() {
        insert new List<breg_Form_Configuration__c>{
            new breg_Form_Configuration__c(
                breg_Suffix_Code__c = CONVERSION_FORM_CODE,
                breg_Form_Code__c = CONVERSION_FORM_CODE,
                breg_Business_Process__c = 'Change'
            ),
            new breg_Form_Configuration__c(
                breg_Suffix_Code__c = ABANDONMENT_FORM_CODE,
                breg_Form_Code__c = ABANDONMENT_FORM_CODE,
                breg_Business_Process__c = 'Change'
            )
        };
    }

    @IsTest
    static void testCompletedBeforeParentEffectiveDateClosesConversionCase() {
        Account oldEntity = createEntity('Old Entity Before', 'OLD-ABAND-001', 'Converted (9)');
        Case parentCase = buildConversionParentCase(oldEntity);
        parentCase.Subject = 'Conversion Parent NEW-ABAND-001';
        parentCase.Status = 'Approved';
        parentCase.breg_New_Entity_Name__c = 'Before New Entity';
        parentCase.breg_File__c = 'NEW-ABAND-001';
        parentCase.breg_Effective_Date__c = Date.today().addDays(5);
        insertCaseWithoutTrigger(parentCase);

        Case childCase = buildAbandonmentCase(oldEntity, parentCase.Id);
        childCase.Subject = 'Abandonment Child NEW-ABAND-001';
        childCase.breg_New_Entity_Name__c = 'Before New Entity';
        childCase.breg_File__c = 'NEW-ABAND-001';
        childCase.breg_Effective_Date__c = Date.today();
        insertCaseWithoutTrigger(childCase);

        Case actionCase = getActionCase(childCase.Id);

        Test.startTest();
        new BREGCaseStatusHandlerAbandOfConversion().handleStatusChange(new List<Case>{ actionCase }, 'Completed', false, true);
        Test.stopTest();

        Case refreshedParent = [SELECT Status FROM Case WHERE Id = :parentCase.Id LIMIT 1];
        System.assertEquals('Rejected', refreshedParent.Status, 'Future-dated conversion parent should be closed as rejected');
    }

    @IsTest
    static void testCompletedAfterParentEffectiveDateCancelsNewEntity() {
        Account oldEntity = createEntity('Old Entity After', 'OLD-ABAND-002', 'Converted (9)');
        String newEntityName = 'After New Entity';
        String newEntityFile = 'NEW-ABAND-002';
        Account newEntity = createEntity(newEntityName, newEntityFile, 'Active (A)');
        Case parentCase = buildConversionParentCase(oldEntity);
        parentCase.Subject = 'Conversion Parent ' + newEntityFile;
        parentCase.Status = 'Completed';
        parentCase.breg_New_Entity_Name__c = newEntityName;
        parentCase.breg_File__c = newEntityFile;
        parentCase.breg_Effective_Date__c = Date.today().addDays(-1);
        insertCaseWithoutTrigger(parentCase);

        Case childCase = buildAbandonmentCase(oldEntity, parentCase.Id);
        childCase.Subject = 'Abandonment Child ' + newEntityFile;
        childCase.breg_New_Entity_Name__c = newEntityName;
        childCase.breg_File__c = newEntityFile;
        childCase.breg_Effective_Date__c = Date.today();
        insertCaseWithoutTrigger(childCase);

        Case actionCase = getActionCase(childCase.Id);

        Test.startTest();
        new BREGCaseStatusHandlerAbandOfConversion().handleStatusChange(new List<Case>{ actionCase }, 'Completed', false, true);
        Test.stopTest();

        Account refreshedNewEntity = [
            SELECT breg_Entity_Status__c
            FROM Account
            WHERE Id = :newEntity.Id
            LIMIT 1
        ];
        System.assertEquals('Cancelled (C)', refreshedNewEntity.breg_Entity_Status__c, 'New conversion entity should be cancelled after abandonment');
    }

    @IsTest
    static void testReceivedCreatesAbandonmentTransaction() {
        Account oldEntity = createEntity('Old Entity Received', 'OLD-ABAND-003', 'Converted (9)');
        Case parentCase = buildConversionParentCase(oldEntity);
        parentCase.Subject = 'Conversion Parent NEW-ABAND-003';
        parentCase.Status = 'Approved';
        parentCase.breg_New_Entity_Name__c = 'Received New Entity';
        parentCase.breg_File__c = 'NEW-ABAND-003';
        parentCase.breg_Effective_Date__c = Date.today().addDays(2);
        insertCaseWithoutTrigger(parentCase);

        Case childCase = buildAbandonmentCase(oldEntity, parentCase.Id);
        childCase.Subject = 'Abandonment Child NEW-ABAND-003';
        childCase.breg_New_Entity_Name__c = 'Received New Entity';
        childCase.breg_File__c = 'NEW-ABAND-003';
        childCase.breg_Effective_Date__c = Date.today();
        insertCaseWithoutTrigger(childCase);

        Case actionCase = getActionCase(childCase.Id);

        Test.startTest();
        new BREGCaseStatusHandlerAbandOfConversion().handleStatusChange(new List<Case>{ actionCase }, 'Received', false, true);
        Test.stopTest();

        breg_Transaction__c transactionRecord = [
            SELECT breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :childCase.Id
            LIMIT 1
        ];
        System.assertEquals(childCase.Id, transactionRecord.breg_Case__c, 'Received action should create a transaction for the abandonment case');
        System.assertEquals(oldEntity.Id, transactionRecord.breg_Account__c, 'Received action should link the original entity');
        System.assertEquals('R', transactionRecord.breg_Status__c, 'Received action should create a received transaction');
    }

    private static Account createEntity(String name, String fileNumber, String entityStatus) {
        Account entity = new Account(
            Name = name,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId(),
            breg_File__c = fileNumber,
            breg_File_Suffix__c = 'C5',
            breg_Entity_Status__c = entityStatus
        );
        insert entity;
        return entity;
    }

    private static Case buildConversionParentCase(Account entity) {
        return new Case(
            Status = 'New',
            Origin = 'Phone',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = entity.Id,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Form_Code__c = CONVERSION_FORM_CODE,
            breg_Form_Configuration__c = getFormConfigId(CONVERSION_FORM_CODE)
        );
    }

    private static Case buildAbandonmentCase(Account entity, Id parentId) {
        return new Case(
            Status = 'New',
            Origin = 'Phone',
            ParentId = parentId,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = entity.Id,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Form_Code__c = ABANDONMENT_FORM_CODE,
            breg_Form_Configuration__c = getFormConfigId(ABANDONMENT_FORM_CODE)
        );
    }

    private static void insertCaseWithoutTrigger(Case caseRecord) {
        BREGBaseTriggerHandler.disableTrigger(BREGCaseTriggerHandler.class);
        try {
            insert caseRecord;
        } finally {
            BREGBaseTriggerHandler.enableTrigger(BREGCaseTriggerHandler.class);
        }
    }

    private static Case getActionCase(Id caseId) {
        return [
            SELECT
                Id,
                ParentId,
                breg_Entity__c,
                breg_Name_of_the_Entity__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_New_Entity_Name__c,
                breg_File__c,
                breg_Effective_Date__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    private static Id getFormConfigId(String formCode) {
        return [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = :formCode LIMIT 1].Id;
    }
}