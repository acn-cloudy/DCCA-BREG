@isTest
private class BREGCaseStatusHandlerCRATerminationTest {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String K6_ENTITY_TYPE = 'K6';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String G6_ENTITY_TYPE = 'G6';
    private static final String TRANSACTION_CODE_TERM = 'CRT';

    @TestSetup
    static void setupTestData() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-13'
        );
        insert formConfig;

        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Account entity = new Account(Name = 'Test Entity', RecordTypeId = accountRecordTypeId, breg_Entity_Type__c = 'D1');
        Account llpEntity = new Account(Name = 'Test LLP', RecordTypeId = accountRecordTypeId, breg_Entity_Type__c = K5_ENTITY_TYPE);
        insert new List<Account>{ entity, llpEntity };

        Account gpEntity = new Account(
            Name = 'Test GP',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = G5_ENTITY_TYPE,
            ParentId = llpEntity.Id
        );
        insert gpEntity;

        // Create CRA accounts - Individual, Non-Registered Entity, and Registered Entity
        Account craIndividual = makeCRAAccount('Test CRA Individual', 'Individual', '123 St');

        Account craNonRegistered = makeCRAAccount('Test CRA Non-Registered', 'Entity', '456 St');

        Account craRegistered = makeCRAAccount('Test CRA Registered', 'Entity', '789 St');

        insert new List<Account>{ craIndividual, craNonRegistered, craRegistered };

        // Create Account Affiliations for CRA role
        breg_Account_Affiliation__c craAffiliation1 = new breg_Account_Affiliation__c(
            breg_Entity__c = craIndividual.Id,
            breg_Role__c = 'CRA',
            breg_Type__c = 'Individual'
        );

        breg_Account_Affiliation__c craAffiliation2 = new breg_Account_Affiliation__c(
            breg_Entity__c = craNonRegistered.Id,
            breg_Role__c = 'CRA',
            breg_Type__c = null
        );

        breg_Account_Affiliation__c craAffiliation3 = new breg_Account_Affiliation__c(
            breg_Entity__c = craRegistered.Id,
            breg_Role__c = 'CRA',
            breg_Type__c = 'Entity'
        );

        // Create CRA affiliation with null breg_Entity__c to test fallback to case.breg_Entity__c
        breg_Account_Affiliation__c craAffiliation4 = new breg_Account_Affiliation__c(
            breg_Entity__c = null,
            breg_Role__c = 'CRA',
            breg_Type__c = 'Individual'
        );

        insert new List<breg_Account_Affiliation__c>{ craAffiliation1, craAffiliation2, craAffiliation3, craAffiliation4 };

        // Create entities with agent affiliations
        Account entityWithAgent = new Account(
            Name = 'Test Entity With Agent',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Good_Standing__c = true
        );

        Account entityMergedOut = new Account(
            Name = 'Test Entity Merged Out',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Merged (M)',
            breg_Good_Standing__c = true
        );

        insert new List<Account>{ entityWithAgent, entityMergedOut };

        // Create agent affiliations
        // breg_Entity__c = Entity Account, breg_Account__c = CRA Account (agent)
        breg_Account_Affiliation__c agentAffiliation1 = new breg_Account_Affiliation__c(
            breg_Entity__c = entityWithAgent.Id,
            breg_Account__c = craIndividual.Id,
            breg_Role__c = 'Agent',
            breg_Start_Date__c = Date.today().addDays(-30)
        );

        breg_Account_Affiliation__c agentAffiliation2 = new breg_Account_Affiliation__c(
            breg_Entity__c = entityMergedOut.Id,
            breg_Account__c = craIndividual.Id,
            breg_Role__c = 'Agent',
            breg_Start_Date__c = Date.today().addDays(-30)
        );

        insert new List<breg_Account_Affiliation__c>{ agentAffiliation1, agentAffiliation2 };

        // Create cases
        Case caseWithEntity = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '001'
        );

        Case caseLLP = new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = llpEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '002'
        );

        Case caseForTerminationIndividual = new Case(
            Subject = 'Test Case 3 - Individual CRA',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = craIndividual.Id
        );

        Case caseForTerminationNonRegistered = new Case(
            Subject = 'Test Case 4 - Non-Registered CRA',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = craNonRegistered.Id
        );

        Case caseForTerminationRegistered = new Case(
            Subject = 'Test Case 5 - Registered CRA',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = craRegistered.Id
        );

        Case caseForTerminationWithFallback = new Case(
            Subject = 'Test Case 6 - CRA with Fallback',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-13',
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = craIndividual.Id
        );

        insert new List<Case>{
            caseWithEntity,
            caseLLP,
            caseForTerminationIndividual,
            caseForTerminationNonRegistered,
            caseForTerminationRegistered,
            caseForTerminationWithFallback
        };

        // Link CRA affiliations to cases
        craAffiliation1.breg_Case__c = caseForTerminationIndividual.Id;
        craAffiliation2.breg_Case__c = caseForTerminationNonRegistered.Id;
        craAffiliation3.breg_Case__c = caseForTerminationRegistered.Id;
        craAffiliation4.breg_Case__c = caseForTerminationWithFallback.Id;
        update new List<breg_Account_Affiliation__c>{ craAffiliation1, craAffiliation2, craAffiliation3, craAffiliation4 };
    }

    @isTest
    static void testValidateEntityIsLinked() {
        Case testCase = [SELECT Id, breg_Entity__c FROM Case WHERE Subject = 'Test Case 1' LIMIT 1];

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        // Test with valid entity
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(true, 'Should not fail entity validation when entity is linked');
        }

        // Test with null entity
        Case caseNoEntity = testCase.clone(false, true);
        caseNoEntity.breg_Entity__c = null;
        caseNoEntity.Id = null;
        insert caseNoEntity;

        try {
            handler.handleStatusChange(new List<Case>{ caseNoEntity }, 'Approved', true, false);
            System.assert(false, 'Should throw exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(true, 'Error message should indicate entity is not linked');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateEntityTransactions() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case 1'
            LIMIT 1
        ];
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity' LIMIT 1];

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT
                Id,
                breg_Case__c,
                breg_Account__c,
                breg_Transaction_Code__c,
                breg_File_Number__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Status__c,
                breg_Date__c,
                breg_Received_Date__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :entity.Id
        ];

        Date orgToday = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertEquals(1, transactions.size(), 'Transaction should be created for entity');
        System.assertEquals(entity.Id, transactions[0].breg_Account__c, 'Transaction should be linked to entity account');
        System.assertEquals(TRANSACTION_CODE_TERM, transactions[0].breg_Transaction_Code__c, 'Transaction code should be TERM');
        System.assertEquals(testCase.Id, transactions[0].breg_Case__c, 'Transaction should be linked to the case');
        System.assertEquals(testCase.breg_Effective_Date__c, transactions[0].breg_Effective_Date__c, 'Effective date should match');
        System.assertEquals(testCase.breg_Form_Code__c, transactions[0].breg_Form_Code__c, 'Form code should match');
        System.assertEquals('R', transactions[0].breg_Status__c, 'Transaction status should be Received');
        System.assertEquals(orgToday, transactions[0].breg_Date__c, 'Transaction date should be today');
    }

    @isTest
    static void testCreateGPTransactionsForLLP() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case 2'
            LIMIT 1
        ];
        Account llpEntity = [SELECT Id FROM Account WHERE Name = 'Test LLP' LIMIT 1];
        Account gpEntity = [SELECT Id FROM Account WHERE Name = 'Test GP' LIMIT 1];

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> llpTransactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, breg_File_Number__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :llpEntity.Id
        ];

        System.assertEquals(1, llpTransactions.size(), 'Transaction should be created for LLP entity');
        System.assertEquals(TRANSACTION_CODE_TERM, llpTransactions[0].breg_Transaction_Code__c, 'LLP transaction code should be TERM');
        System.assertEquals('R', llpTransactions[0].breg_Status__c, 'LLP transaction status should be Received');

        List<breg_Transaction__c> gpTransactions = [
            SELECT
                Id,
                breg_Case__c,
                breg_Account__c,
                breg_Transaction_Code__c,
                breg_File_Number__c,
                breg_Status__c,
                breg_Date__c,
                breg_Received_Date__c,
                breg_Effective_Date__c,
                breg_Form_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :gpEntity.Id
        ];

        Date orgToday = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertEquals(1, gpTransactions.size(), 'Transaction should be created for GP account');
        System.assertEquals(gpEntity.Id, gpTransactions[0].breg_Account__c, 'Transaction should be linked to GP account');
        System.assertEquals(TRANSACTION_CODE_TERM, gpTransactions[0].breg_Transaction_Code__c, 'Transaction code should be TERM');
        System.assertEquals(testCase.Id, gpTransactions[0].breg_Case__c, 'Transaction should be linked to the case');
        System.assertEquals('R', gpTransactions[0].breg_Status__c, 'GP transaction status should be Received');
        System.assertEquals(orgToday, gpTransactions[0].breg_Date__c, 'Transaction date should be today');
        System.assertEquals(testCase.breg_Effective_Date__c, gpTransactions[0].breg_Effective_Date__c, 'Effective date should match');
        System.assertEquals(testCase.breg_Form_Code__c, gpTransactions[0].breg_Form_Code__c, 'Form code should match');
    }

    @isTest
    static void testTerminateCRAIndividual() {
        Case testCase = [
            SELECT Id, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'Test Case 3 - Individual CRA'
            LIMIT 1
        ];
        Account craAccount = [
            SELECT Id, breg_Entity_Status__c, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Name = 'Test CRA Individual'
            LIMIT 1
        ];

        System.assertEquals(true, craAccount.breg_BRIM_CRA_FL__c, 'CRA flag should be true initially');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedCRA = [
            SELECT breg_Entity_Status__c, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Id = :craAccount.Id
        ];
        System.assertEquals(false, updatedCRA.breg_BRIM_CRA_FL__c, 'Individual CRA should be terminated');
    }

    @isTest
    static void testTerminateCRANonRegistered() {
        Case testCase = [
            SELECT Id, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'Test Case 4 - Non-Registered CRA'
            LIMIT 1
        ];
        Account craAccount = [
            SELECT Id, breg_Entity_Status__c, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Name = 'Test CRA Non-Registered'
            LIMIT 1
        ];

        System.assertEquals(true, craAccount.breg_BRIM_CRA_FL__c, 'CRA flag should be true initially');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedCRA = [
            SELECT breg_Entity_Status__c, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Id = :craAccount.Id
        ];
        System.assertEquals(false, updatedCRA.breg_BRIM_CRA_FL__c, 'Non-Registered Entity CRA should be terminated');
    }

    @isTest
    static void testTerminateCRARegistered() {
        Case testCase = [
            SELECT Id, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'Test Case 5 - Registered CRA'
            LIMIT 1
        ];
        Account craAccount = [
            SELECT Id, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Name = 'Test CRA Registered'
            LIMIT 1
        ];

        System.assertEquals(true, craAccount.breg_BRIM_CRA_FL__c, 'CRA flag should be true initially');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedCRA = [
            SELECT breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Id = :craAccount.Id
        ];
        System.assertEquals(false, updatedCRA.breg_BRIM_CRA_FL__c, 'Registered Entity CRA flag should be set to false');
    }

    @isTest
    static void testTerminateCRAClearsRegistrantAddress() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Test Case 5 - Registered CRA'
            LIMIT 1
        ];
        Account craAccount = [
            SELECT
                Id,
                breg_Registrant_Address__Street__s,
                breg_Registrant_Address_Street_2__c,
                breg_Registrant_Address__City__s,
                breg_Registrant_Address__StateCode__s,
                breg_Registrant_Address__PostalCode__s,
                breg_Registrant_Address__CountryCode__s
            FROM Account
            WHERE Name = 'Test CRA Registered'
            LIMIT 1
        ];

        System.assertNotEquals(null, craAccount.breg_Registrant_Address__Street__s, 'Street should be populated in setup data');
        System.assertNotEquals(null, craAccount.breg_Registrant_Address_Street_2__c, 'Street 2 should be populated in setup data');
        System.assertNotEquals(null, craAccount.breg_Registrant_Address__City__s, 'City should be populated in setup data');
        System.assertNotEquals(null, craAccount.breg_Registrant_Address__StateCode__s, 'State should be populated in setup data');
        System.assertNotEquals(null, craAccount.breg_Registrant_Address__PostalCode__s, 'Postal code should be populated in setup data');
        System.assertNotEquals(null, craAccount.breg_Registrant_Address__CountryCode__s, 'Country should be populated in setup data');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedCRA = [
            SELECT
                breg_Registrant_Address__Street__s,
                breg_Registrant_Address_Street_2__c,
                breg_Registrant_Address__City__s,
                breg_Registrant_Address__StateCode__s,
                breg_Registrant_Address__PostalCode__s,
                breg_Registrant_Address__CountryCode__s
            FROM Account
            WHERE Id = :craAccount.Id
        ];

        System.assertEquals(null, updatedCRA.breg_Registrant_Address__Street__s, 'Street should be cleared on CRA termination');
        System.assertEquals(null, updatedCRA.breg_Registrant_Address_Street_2__c, 'Street 2 should be cleared on CRA termination');
        System.assertEquals(null, updatedCRA.breg_Registrant_Address__City__s, 'City should be cleared on CRA termination');
        System.assertEquals(null, updatedCRA.breg_Registrant_Address__StateCode__s, 'State should be cleared on CRA termination');
        System.assertEquals(null, updatedCRA.breg_Registrant_Address__PostalCode__s, 'Postal code should be cleared on CRA termination');
        System.assertEquals(null, updatedCRA.breg_Registrant_Address__CountryCode__s, 'Country should be cleared on CRA termination');
    }

    @isTest
    static void testTerminateCRAUpdatesAssociatedEntities() {
        Case testCase = [
            SELECT Id, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'Test Case 3 - Individual CRA'
            LIMIT 1
        ];
        Account entityWithAgent = [
            SELECT Id, breg_Good_Standing__c
            FROM Account
            WHERE Name = 'Test Entity With Agent'
            LIMIT 1
        ];
        Account entityMergedOut = [
            SELECT Id, breg_Good_Standing__c
            FROM Account
            WHERE Name = 'Test Entity Merged Out'
            LIMIT 1
        ];

        System.assertEquals(true, entityWithAgent.breg_Good_Standing__c, 'Entity should be in good standing initially');
        System.assertEquals(true, entityMergedOut.breg_Good_Standing__c, 'Merged out entity should be in good standing initially');

        breg_Account_Affiliation__c agentAff = [
            SELECT Id, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :entityWithAgent.Id AND breg_Role__c = 'Agent'
            LIMIT 1
        ];
        System.assertEquals(null, agentAff.breg_End_Date__c, 'Agent affiliation should not have end date');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedEntity = [
            SELECT breg_Good_Standing__c
            FROM Account
            WHERE Id = :entityWithAgent.Id
        ];
        System.assertEquals(false, updatedEntity.breg_Good_Standing__c, 'Entity should not be in good standing after CRA termination');

        Account updatedMergedOut = [
            SELECT breg_Good_Standing__c
            FROM Account
            WHERE Id = :entityMergedOut.Id
        ];
        System.assertEquals(true, updatedMergedOut.breg_Good_Standing__c, 'Merged out entity should remain in good standing');

        breg_Account_Affiliation__c updatedAff = [
            SELECT breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :agentAff.Id
            LIMIT 1
        ];
        System.assertEquals(testCase.breg_Effective_Date__c, updatedAff.breg_End_Date__c, 'Agent affiliation end date should be set to effective date');

        // Verify merged out entity's agent affiliation is not updated
        breg_Account_Affiliation__c mergedOutAff = [
            SELECT breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :entityMergedOut.Id AND breg_Role__c = 'Agent'
            LIMIT 1
        ];
        System.assertEquals(null, mergedOutAff.breg_End_Date__c, 'Merged out entity agent affiliation should not have end date');
    }

    @isTest
    static void testTerminateCRAWithFallbackToCaseEntity() {
        // Test that when CRA affiliation has null breg_Entity__c, it uses case.breg_Entity__c
        Case testCase = [
            SELECT Id, breg_Effective_Date__c, breg_Entity__c
            FROM Case
            WHERE Subject = 'Test Case 6 - CRA with Fallback'
            LIMIT 1
        ];
        Account craAccount = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
            LIMIT 1
        ];

        System.assertEquals('Active (A)', craAccount.breg_Entity_Status__c, 'CRA should be active initially');

        BREGCaseStatusHandlerCRATermination handler = new BREGCaseStatusHandlerCRATermination();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedCRA = [
            SELECT breg_Entity_Status__c, breg_BRIM_CRA_FL__c
            FROM Account
            WHERE Id = :craAccount.Id
        ];

        System.assertEquals(
            false,
            updatedCRA.breg_BRIM_CRA_FL__c,
            'CRA flag should be set to true using case.breg_Entity__c when affiliation.breg_Entity__c is null'
        );
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;
    }

    private static Account makeCRAAccount(String name, String registrantType, String street) {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        return new Account(
            Name = name,
            RecordTypeId = recordTypeId,
            breg_BRIM_CRA_FL__c = true,
            breg_Registrant_Type__c = registrantType,
            breg_Entity_Status__c = 'Active (A)',
            breg_Entity_Type__c = 'D1',
            breg_Formation_State__c = 'HI',
            breg_Registrant_Address__Street__s = street,
            breg_Registrant_Address_Street_2__c = 'Suite 200',
            breg_Registrant_Address__City__s = 'City',
            breg_Registrant_Address__StateCode__s = 'HI',
            breg_Registrant_Address__PostalCode__s = '12345',
            breg_Registrant_Address__CountryCode__s = 'US',
            BillingStreet = street,
            BillingCity = 'City',
            BillingStateCode = 'HI',
            BillingPostalCode = '12345',
            BillingCountryCode = 'US'
        );
    }
}