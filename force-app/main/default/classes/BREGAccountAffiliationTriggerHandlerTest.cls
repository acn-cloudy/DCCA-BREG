@IsTest
private class BREGAccountAffiliationTriggerHandlerTest {
    private static final String ENTITY_NAME = 'Affiliation Test Entity';
    private static final String PREVIOUS_ENTITY_NAME = 'Existing Agent Entity';
    private static final String NEW_ENTITY_NAME = 'New Agent Entity';
    private static final String RELATED_AGENT_ENTITY_NAME = 'Agent Entity';
    private static final String PREVIOUS_APPLICANT_NAME = 'Existing Applicant Entity';
    private static final String DUPLICATE_APPLICANT_NAME_1 = 'Incoming Applicant Entity 1';
    private static final String DUPLICATE_APPLICANT_NAME_2 = 'Incoming Applicant Entity 2';
    private static final String TRANSACTION_BUSINESS_NAME = 'Affiliation Update Test';
    private static final String TRANSACTION_ADDRESS_NAME = 'Test Transaction Address';

    @TestSetup
    static void setupData() {
        Account entity = BREGTestDataFactory.createEntityAccounts(1)[0];
        entity.Name = ENTITY_NAME;
        update entity;

        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        Case caseRecord = BREGTestDataFactory.createRegistrationCases(new List<breg_Form_Configuration__c>{ forms[0] })[0];
        caseRecord.Subject = 'Affiliation Test Registration Case';
        update caseRecord;

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Agent',
                breg_Type__c = 'Entity',
                breg_Status__c = 'A',
                breg_Entity_Name__c = PREVIOUS_ENTITY_NAME,
                breg_Address__Street__s = '123 Old St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2024, 1, 1)
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = caseRecord.Id,
                breg_Role__c = 'New Agent',
                breg_Type__c = 'Entity',
                breg_Status__c = 'A',
                breg_Entity_Name__c = NEW_ENTITY_NAME,
                breg_Address__Street__s = '456 New St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2025, 1, 15)
            ),
            new breg_Account_Affiliation__c(
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Agent',
                breg_Type__c = 'Entity',
                breg_Status__c = 'A',
                breg_Entity_Name__c = RELATED_AGENT_ENTITY_NAME,
                breg_Address__Street__s = '123 Main St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2024, 1, 1)
            )
        };

        breg_Transaction__c transactionRecord = new breg_Transaction__c(breg_Business_Name__c = TRANSACTION_BUSINESS_NAME);
        insert transactionRecord;

        breg_Account_Affiliation__c relatedAffiliation = [
            SELECT Id
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c = :RELATED_AGENT_ENTITY_NAME
            LIMIT 1
        ];

        insert new breg_Transaction_Address__c(
            Name = TRANSACTION_ADDRESS_NAME,
            BREG_Transaction__c = transactionRecord.Id,
            breg_Account__c = entity.Id,
            breg_Account_Affiliation__c = relatedAffiliation.Id,
            breg_Start_Date__c = Date.newInstance(2024, 1, 1)
        );

        breg_TN_TM_SM__c tnTmSm = new breg_TN_TM_SM__c(Name = 'Trigger Test TNTMSM');
        insert tnTmSm;

        insert new breg_Account_Affiliation__c(
            breg_TN_TM_SM__c = tnTmSm.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Entity',
            breg_Status__c = 'A',
            breg_Entity_Name__c = PREVIOUS_APPLICANT_NAME,
            breg_Address__Street__s = '10 Prior St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.newInstance(2024, 2, 1)
        );

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Role__c = 'Applicant',
                breg_Type__c = 'Entity',
                breg_Status__c = 'A',
                breg_Entity_Name__c = DUPLICATE_APPLICANT_NAME_1,
                breg_Address__Street__s = '11 Incoming St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2025, 3, 1)
            ),
            new breg_Account_Affiliation__c(
                breg_Role__c = 'Applicant',
                breg_Type__c = 'Entity',
                breg_Status__c = 'A',
                breg_Entity_Name__c = DUPLICATE_APPLICANT_NAME_2,
                breg_Address__Street__s = '12 Incoming St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2025, 3, 1)
            )
        };
    }

    @IsTest
    static void testBeforeUpdateSetsEndDateOnPreviousEntityAffiliation() {
        Account entity = [
            SELECT Id
            FROM Account
            WHERE Name = :ENTITY_NAME
            LIMIT 1
        ];
        breg_Account_Affiliation__c newAffiliation = [
            SELECT Id, breg_Entity__c, breg_Start_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c = :NEW_ENTITY_NAME
            LIMIT 1
        ];

        newAffiliation.breg_Entity__c = entity.Id;
        update newAffiliation;

        breg_Account_Affiliation__c updatedPreviousAffiliation = [
            SELECT breg_End_Date__c, breg_Bypass_Validation_Token__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c = :PREVIOUS_ENTITY_NAME
            LIMIT 1
        ];

        System.assertEquals(newAffiliation.breg_Start_Date__c, updatedPreviousAffiliation.breg_End_Date__c, 'Previous affiliation should end when the new affiliation is linked');
        System.assertNotEquals(null, updatedPreviousAffiliation.breg_Bypass_Validation_Token__c, 'Previous affiliation should receive a bypass token when auto-updated');
    }

    @IsTest
    static void testAfterUpdateSetsEndDateOnRelatedTransactionAddresses() {
        breg_Account_Affiliation__c affiliation = [
            SELECT Id, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c = :RELATED_AGENT_ENTITY_NAME
            LIMIT 1
        ];

        Date endDate = Date.today();
        affiliation.breg_End_Date__c = endDate;
        update affiliation;

        breg_Transaction_Address__c updatedTransactionAddress = [
            SELECT breg_End_Date__c
            FROM breg_Transaction_Address__c
            WHERE Name = :TRANSACTION_ADDRESS_NAME
            LIMIT 1
        ];

        System.assertEquals(endDate, updatedTransactionAddress.breg_End_Date__c, 'Related transaction addresses should inherit the affiliation end date');
    }

    @IsTest
    static void testBeforeUpdateDedupesPreviousAffiliationUpdates() {
        Id tnTmSmId = [
            SELECT Id
            FROM breg_TN_TM_SM__c
            WHERE Name = 'Trigger Test TNTMSM'
            LIMIT 1
        ].Id;

        List<breg_Account_Affiliation__c> incomingApplicants = [
            SELECT Id, breg_TN_TM_SM__c, breg_Start_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c IN :new Set<String>{ DUPLICATE_APPLICANT_NAME_1, DUPLICATE_APPLICANT_NAME_2 }
        ];

        for (breg_Account_Affiliation__c affiliation : incomingApplicants) {
            affiliation.breg_TN_TM_SM__c = tnTmSmId;
        }

        Test.startTest();
        update incomingApplicants;
        Test.stopTest();

        breg_Account_Affiliation__c previousApplicant = [
            SELECT breg_End_Date__c, breg_Status__c, breg_Bypass_Validation_Token__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity_Name__c = :PREVIOUS_APPLICANT_NAME
            LIMIT 1
        ];

        System.assertEquals(Date.newInstance(2025, 3, 1), previousApplicant.breg_End_Date__c, 'Previous applicant should be end-dated once.');
        System.assertEquals('I', previousApplicant.breg_Status__c, 'Previous applicant should be marked inactive.');
        System.assertNotEquals(null, previousApplicant.breg_Bypass_Validation_Token__c, 'Previous applicant should receive a bypass token.');
    }
}