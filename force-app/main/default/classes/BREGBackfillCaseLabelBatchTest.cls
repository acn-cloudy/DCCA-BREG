@isTest
private class BREGBackfillCaseLabelBatchTest {
    @TestSetup
    static void prepareData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFileNumberSequences();
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createRegistrationCases(forms);
    }

    @isTest
    static void executeBackfillBatchUpdatesMissingLabelsTest() {
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c form = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'New Business'
            LIMIT 1
        ];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Case c = new Case(
            Subject = 'Backfill Label Batch Test Case',
            Origin = 'Web',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            ContactId = testContact.Id,
            breg_Form_Configuration__c = form.Id,
            breg_Form_Code__c = form.breg_Form_Code__c,
            breg_Name_of_the_Entity__c = 'Backfill Label Batch Test Corporation',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__Street__s = '123 Test St',
            breg_Company_Address__PostalCode__s = '96813',
            breg_Entity_Jurisdiction__c = 'US',
            breg_Formation_State__c = 'HI',
            breg_New_Entity_Jurisdiction__c = 'US',
            breg_New_Formation_State__c = 'CO'
        );

        BREGBaseTriggerHandler.disableTrigger(BREGCaseTriggerHandler.class);
        try {
            insert c;
        } finally {
            BREGBaseTriggerHandler.enableTrigger(BREGCaseTriggerHandler.class);
        }

        Test.startTest();
        Database.executeBatch(new BREGBackfillCaseLabelBatch(), 200);
        Test.stopTest();

        Case updatedCase = [
            SELECT
                breg_Entity_Jurisdiction__c,
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State__c,
                breg_Formation_State_Label__c,
                breg_New_Entity_Jurisdiction__c,
                breg_New_Entity_Jurisdiction_Label__c,
                breg_New_Formation_State__c,
                breg_New_Formation_State_Label__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            'United States',
            updatedCase.breg_Entity_Jurisdiction_Label__c,
            'Jurisdiction label should be repopulated from picklist label or free text fallback'
        );
        System.assertEquals(
            'Hawaii',
            updatedCase.breg_Formation_State_Label__c,
            'Formation state label should be repopulated from picklist label or free text fallback'
        );
        System.assertEquals(
            'United States',
            updatedCase.breg_New_Entity_Jurisdiction_Label__c,
            'New entity jurisdiction label should be repopulated from picklist label or free text fallback'
        );
        System.assertEquals(
            'Colorado',
            updatedCase.breg_New_Formation_State_Label__c,
            'New formation state label should be repopulated from picklist label or free text fallback'
        );
    }
}