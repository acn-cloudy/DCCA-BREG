/**
 * Test class for BREGCaseStatusHandlerResignationCRA
 */
@isTest
private class BREGCaseStatusHandlerResignationCRATest {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String TRANSACTION_CODE_AGR = 'AGR';

    @TestSetup
    static void setupTestData() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-9'
        );
        insert formConfig;

        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Account entity = new Account(Name = 'Test Entity Corporation', RecordTypeId = accountRecordTypeId, breg_Entity_Type__c = 'D1');
        Account llpEntity = new Account(Name = 'Test LLP', RecordTypeId = accountRecordTypeId, breg_Entity_Type__c = K5_ENTITY_TYPE);
        insert new List<Account>{ entity, llpEntity };

        Account gpEntity = new Account(
            Name = 'Test GP',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = G5_ENTITY_TYPE,
            ParentId = llpEntity.Id
        );
        insert gpEntity;

        Account agent = new Account(
            Name = 'Test Agent',
            RecordTypeId = accountRecordTypeId,
            breg_Registrant_Type__c = 'Individual',
            breg_Entity_Status__c = 'Active (A)',
            BillingStreet = '123 St',
            BillingCity = 'City',
            BillingStateCode = 'NY',
            BillingPostalCode = '12345',
            BillingCountryCode = 'US'
        );
        insert agent;

        breg_Account_Affiliation__c agentAffiliation = new breg_Account_Affiliation__c(
            breg_Account__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Entity__c = agent.Id,
            breg_Start_Date__c = Date.today().addDays(-30),
            breg_Status__c = 'A',
            breg_Address__Street__s = '1234 Aloha Dr',
            breg_Address__CountryCode__s = 'US',
            breg_Address__StateCode__s = 'HI',
            breg_Address__City__s = 'Honolulu',
            breg_Address__PostalCode__s = '96815'
        );
        insert agentAffiliation;

        entity.breg_Certified_Register_Agent__c = agentAffiliation.Id;
        entity.breg_Good_Standing__c = true;
        entity.breg_Incorporation_Date__c = Date.today().addDays(-30);
        update entity;

        Case caseWithEntity = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-9',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '001'
        );

        Case caseLLP = new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = llpEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-9',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '002'
        );

        Case caseForDisassociation = new Case(
            Subject = 'Test Case 3',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-9',
            breg_Effective_Date__c = Date.today()
        );

        insert new List<Case>{ caseWithEntity, caseLLP, caseForDisassociation };
    }

    @isTest
    static void testValidateEffectiveDate() {
        Case testCase = [SELECT Id, breg_Effective_Date__c FROM Case WHERE Subject = 'Test Case 1' LIMIT 1];

        BREGCaseStatusHandlerResignationCRA handler = new BREGCaseStatusHandlerResignationCRA();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(!e.getMessage().contains('effective date'), 'Should not fail effective date validation when date is today');
        }

        Case caseNoDate = testCase.clone(false, true);
        caseNoDate.breg_Effective_Date__c = null;
        caseNoDate.Id = null;
        insert caseNoDate;

        try {
            handler.handleStatusChange(new List<Case>{ caseNoDate }, 'Completed', true, false);
            System.assert(false, 'Should throw exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('required field'), 'Error message should indicate effective date is required');
        }

        Case caseFutureDate = testCase.clone(false, true);
        caseFutureDate.breg_Effective_Date__c = Date.today().addDays(1);
        caseFutureDate.Id = null;
        insert caseFutureDate;

        try {
            handler.handleStatusChange(new List<Case>{ caseFutureDate }, 'Completed', true, false);
            System.assert(false, 'Should throw exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('effective date'), 'Error message should indicate effective date is in future');
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
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity Corporation' LIMIT 1];

        BREGCaseStatusHandlerResignationCRA handler = new BREGCaseStatusHandlerResignationCRA();

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
        System.assertEquals(TRANSACTION_CODE_AGR, transactions[0].breg_Transaction_Code__c, 'Transaction code should be AGR');
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

        BREGCaseStatusHandlerResignationCRA handler = new BREGCaseStatusHandlerResignationCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> llpTransactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, breg_File_Number__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :llpEntity.Id AND breg_Transaction_Code__c = :TRANSACTION_CODE_AGR AND breg_Case__c = :testCase.Id
        ];

        System.assertEquals(1, llpTransactions.size(), 'Transaction should be created for LLP entity');
        System.assertEquals(TRANSACTION_CODE_AGR, llpTransactions[0].breg_Transaction_Code__c, 'LLP transaction code should be AGR');
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
            WHERE breg_Account__c = :gpEntity.Id AND breg_Transaction_Code__c = :TRANSACTION_CODE_AGR AND breg_Case__c = :testCase.Id
        ];

        Date orgToday = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertEquals(1, gpTransactions.size(), 'Transaction should be created for GP account');
        System.assertEquals(gpEntity.Id, gpTransactions[0].breg_Account__c, 'Transaction should be linked to GP account');
        System.assertEquals(TRANSACTION_CODE_AGR, gpTransactions[0].breg_Transaction_Code__c, 'Transaction code should be AGR');
        System.assertEquals(testCase.Id, gpTransactions[0].breg_Case__c, 'Transaction should be linked to the case');
        System.assertEquals('R', gpTransactions[0].breg_Status__c, 'GP transaction status should be Received');
        System.assertEquals(orgToday, gpTransactions[0].breg_Date__c, 'Transaction date should be today');
        System.assertEquals(testCase.breg_Effective_Date__c, gpTransactions[0].breg_Effective_Date__c, 'Effective date should match');
        System.assertEquals(testCase.breg_Form_Code__c, gpTransactions[0].breg_Form_Code__c, 'Form code should match');
    }

    @isTest
    static void testDisassociateRegisteredAgent() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'Test Case 3'
            LIMIT 1
        ];
        Account entity = [
            SELECT Id, breg_Certified_Register_Agent__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];
        update entity; // To ensure we have the latest data and trigger any potential before update logic

        System.assertNotEquals(null, entity.breg_Certified_Register_Agent__c, 'Entity should have certified registered agent');

        breg_Account_Affiliation__c agentAff = [
            SELECT Id, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :entity.breg_Certified_Register_Agent__c
            LIMIT 1
        ];
        System.assertEquals(null, agentAff.breg_End_Date__c, 'Agent affiliation should not have end date');

        BREGCaseStatusHandlerResignationCRA handler = new BREGCaseStatusHandlerResignationCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        breg_Account_Affiliation__c updatedAff = [
            SELECT breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :agentAff.Id
            LIMIT 1
        ];
        System.assertEquals(testCase.breg_Effective_Date__c, updatedAff.breg_End_Date__c, 'Agent affiliation end date should be set to effective date');

        Account updatedEntity = [
            SELECT breg_Certified_Register_Agent__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :entity.Id
        ];
        System.assertEquals(null, updatedEntity.breg_Certified_Register_Agent__c, 'Entity certified registered agent should be cleared');
        System.assertEquals(false, updatedEntity.breg_Good_Standing__c, 'Entity should not be in good standing');
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;
    }
}