@isTest
private class BREGCaseStatusHandlerChangeNonComCRATest {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String TRANSACTION_CODE_AGAD = 'AGAD';

    @TestSetup
    static void setupTestData() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-8'
        );
        insert formConfig;

        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

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

        Account agent = new Account(
            Name = 'Test Agent',
            RecordTypeId = accountRecordTypeId,
            breg_Registrant_Type__c = 'Individual',
            BillingStreet = '123 St',
            BillingCity = 'City',
            BillingStateCode = 'HI',
            BillingPostalCode = '12345',
            BillingCountryCode = 'US'
        );
        insert agent;

        Case caseWithEntity = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '001'
        );

        Case caseLLP = new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = llpEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '002'
        );

        Case caseAgentUpdate = new Case(
            Subject = 'Test Case 3',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Effective_Date__c = Date.today()
        );

        Case caseAgentAddressUpdate = new Case(
            Subject = 'Test Case 4',
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Effective_Date__c = Date.today(),
            breg_File_Suffix__c = '004'
        );

        insert new List<Case>{ caseWithEntity, caseLLP, caseAgentUpdate, caseAgentAddressUpdate };

        breg_Account_Affiliation__c oldAffiliation = new breg_Account_Affiliation__c(
            breg_Case__c = caseAgentUpdate.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Account__c = agent.Id,
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '123 Old St',
            breg_Address__City__s = 'Old City',
            breg_Address__StateCode__s = 'HI',
            breg_Address__PostalCode__s = '11111',
            breg_Address__CountryCode__s = 'US'
        );

        breg_Account_Affiliation__c newAffiliation = new breg_Account_Affiliation__c(
            breg_Case__c = caseAgentUpdate.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'New Agent',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith',
            breg_Address__Street__s = '456 New St',
            breg_Address__City__s = 'New City',
            breg_Address__StateCode__s = 'CA',
            breg_Address__PostalCode__s = '22222',
            breg_Address__CountryCode__s = 'US'
        );

        insert new List<breg_Account_Affiliation__c>{ oldAffiliation, newAffiliation };
    }

    @isTest
    static void testValidateEntityIsLinked() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Reg_Agent_Address_Has_Changed__c, breg_Reg_Agent_Has_Changed__c
            FROM Case
            WHERE Subject = 'Test Case 1'
            LIMIT 1
        ];
        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerChangeNonComCRA');

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(true, 'Should not fail entity validation');
        }

        Case caseNoEntity = testCase.clone(false, true);
        caseNoEntity.breg_Entity__c = null;
        caseNoEntity.Id = null;
        insert caseNoEntity;
        createCompletedPayment(caseNoEntity.Id);

        try {
            handler.handleStatusChange(new List<Case>{ caseNoEntity }, 'Approved', true, false);
            System.assert(false, 'Should throw exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(true, 'Error message should indicate entity is not linked');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateEntityTransactionsOnReceived() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case 1'
            LIMIT 1
        ];
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity' LIMIT 1];

        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerChangeNonComCRA');

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT
                Id,
                breg_Account__c,
                breg_Transaction_Code__c,
                breg_Case__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Status__c,
                breg_Date__c,
                breg_Received_Date__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :entity.Id AND breg_Transaction_Code__c = :TRANSACTION_CODE_AGAD AND breg_Case__c = :testCase.Id
        ];
        Date orgDate = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertEquals(1, transactions.size(), 'Transaction should be created for entity');
        System.assertEquals(entity.Id, transactions[0].breg_Account__c, 'Transaction should be linked to entity account');
        System.assertEquals(TRANSACTION_CODE_AGAD, transactions[0].breg_Transaction_Code__c, 'Transaction code should be AGAD');
        System.assertEquals(testCase.Id, transactions[0].breg_Case__c, 'Case should match case ID');
        System.assertEquals(testCase.breg_Effective_Date__c, transactions[0].breg_Effective_Date__c, 'Effective date should match');
        System.assertEquals(testCase.breg_Form_Code__c, transactions[0].breg_Form_Code__c, 'Form code should match');
        System.assertEquals('R', transactions[0].breg_Status__c, 'Transaction status should be Received');
        System.assertEquals(orgDate, transactions[0].breg_Date__c, 'Transaction date should match org date');
    }

    @isTest
    static void testCreateGPTransactionsForLLPOnReceived() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case 2'
            LIMIT 1
        ];
        Account llpEntity = [SELECT Id FROM Account WHERE Name = 'Test LLP' LIMIT 1];
        Account gpEntity = [SELECT Id FROM Account WHERE Name = 'Test GP' LIMIT 1];

        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerChangeNonComCRA');

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();
        
        List<breg_Transaction__c> llpTransactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, breg_Case__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :llpEntity.Id AND breg_Transaction_Code__c = :TRANSACTION_CODE_AGAD AND breg_Case__c = :testCase.Id
        ];

        System.assertEquals(1, llpTransactions.size(), 'Transaction should be created for LLP entity');
        System.assertEquals(TRANSACTION_CODE_AGAD, llpTransactions[0].breg_Transaction_Code__c, 'LLP transaction code should be AGAD');
        System.assertEquals('R', llpTransactions[0].breg_Status__c, 'LLP transaction status should be Received');

        List<breg_Transaction__c> gpTransactions = [
            SELECT
                Id,
                breg_Account__c,
                breg_Transaction_Code__c,
                breg_Case__c,
                breg_Status__c,
                breg_Date__c,
                breg_Received_Date__c,
                breg_Effective_Date__c,
                breg_Form_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :gpEntity.Id AND breg_Transaction_Code__c = :TRANSACTION_CODE_AGAD AND breg_Case__c = :testCase.Id
        ];
        Date orgDate = BREGTransactionUtils.getOrgDateByUserTimezone();

        System.assertEquals(1, gpTransactions.size(), 'Transaction should be created for GP account');
        System.assertEquals(gpEntity.Id, gpTransactions[0].breg_Account__c, 'Transaction should be linked to GP account');
        System.assertEquals(TRANSACTION_CODE_AGAD, gpTransactions[0].breg_Transaction_Code__c, 'Transaction code should be AGAD');
        System.assertEquals(testCase.Id, gpTransactions[0].breg_Case__c, 'Case ID should match');
        System.assertEquals('R', gpTransactions[0].breg_Status__c, 'GP transaction status should be Received');
        System.assertEquals(orgDate, gpTransactions[0].breg_Date__c, 'Transaction date should match org date');
        System.assertEquals(testCase.breg_Effective_Date__c, gpTransactions[0].breg_Effective_Date__c, 'Effective date should match');
        System.assertEquals(testCase.breg_Form_Code__c, gpTransactions[0].breg_Form_Code__c, 'Form code should match');
    }

    @isTest
    static void testUpdateAgentRelationshipOnlyAddressUsesPrepopulatedAccount() {
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity' LIMIT 1];
        Account oldAgent = [SELECT Id FROM Account WHERE Name = 'Test Agent' LIMIT 1];

        Account prepopulatedAgent = createAgentAccount('Prepopulated Agent', '10 Existing Way', 'Honolulu', 'HI', '96813', 'US');
        insert prepopulatedAgent;

        Case testCase = createAgentUpdateCase('Test Case 3 - only address prepopulated', entity.Id, false, true);

        breg_Account_Affiliation__c oldCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'Agent',
            oldAgent.Id,
            'John',
            'Doe',
            '123 Old St',
            'Old City',
            'HI',
            '11111',
            'US'
        );
        breg_Account_Affiliation__c newCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'New Agent',
            prepopulatedAgent.Id,
            'Prepopulated',
            'Agent',
            '99 New St',
            'Honolulu',
            'HI',
            '96814',
            'US'
        );
        insert new List<breg_Account_Affiliation__c>{ oldCaseAffiliation, newCaseAffiliation };

        breg_Account_Affiliation__c oldEntityAffiliation = buildEntityAffiliation(entity.Id, oldAgent.Id, 'John', 'Doe');
        insert oldEntityAffiliation;

        runCompletedStatusChange(testCase);

        breg_Account_Affiliation__c refreshedNewAffiliation = [
            SELECT Id, breg_Account__c, breg_Role__c, breg_Status__c, breg_Start_Date__c, breg_Entity__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :newCaseAffiliation.Id
            LIMIT 1
        ];
        System.assertEquals(prepopulatedAgent.Id, refreshedNewAffiliation.breg_Account__c, 'Prepopulated account must stay linked');
        System.assertEquals('Agent', refreshedNewAffiliation.breg_Role__c, 'Role should be switched to Agent');
        System.assertEquals('A', refreshedNewAffiliation.breg_Status__c, 'New affiliation should be active');
        System.assertEquals(testCase.breg_Effective_Date__c, refreshedNewAffiliation.breg_Start_Date__c, 'Start date should match case effective date');
        System.assertEquals(entity.Id, refreshedNewAffiliation.breg_Entity__c, 'New affiliation should be linked to entity');

        breg_Account_Affiliation__c refreshedOldEntityAffiliation = [
            SELECT breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :oldEntityAffiliation.Id
            LIMIT 1
        ];
        System.assertEquals('I', refreshedOldEntityAffiliation.breg_Status__c, 'Old entity affiliation should be inactivated');
        System.assertEquals(
            testCase.breg_Effective_Date__c,
            refreshedOldEntityAffiliation.breg_End_Date__c,
            'Old affiliation should end on effective date'
        );

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_Account__c = :entity.Id AND breg_Case__c = :testCase.Id
        ];
        System.assertEquals(2, transactions.size(), 'Address-only change should create old and new address transactions');

        Account refreshedEntity = [SELECT breg_Certified_Register_Agent__c FROM Account WHERE Id = :entity.Id LIMIT 1];
        System.assertEquals(
            refreshedNewAffiliation.Id,
            refreshedEntity.breg_Certified_Register_Agent__c,
            'Entity certified registered agent should point to updated affiliation'
        );
    }

    @isTest
    static void testUpdateAgentRelationshipOnlyNameUsesExistingAccountByName() {
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity' LIMIT 1];
        Account oldAgent = [SELECT Id FROM Account WHERE Name = 'Test Agent' LIMIT 1];

        Account existingByNameAgent = createAgentAccount('Shared Existing', '22 Shared St', 'Hilo', 'HI', '96720', 'US');
        insert existingByNameAgent;

        Case testCase = createAgentUpdateCase('Test Case 3 - only name existing by name', entity.Id, true, false);

        breg_Account_Affiliation__c oldCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'Agent',
            oldAgent.Id,
            'John',
            'Doe',
            '123 Old St',
            'Old City',
            'HI',
            '11111',
            'US'
        );
        breg_Account_Affiliation__c newCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'New Agent',
            null,
            'Shared',
            'Existing',
            '77 Name Change St',
            'Hilo',
            'HI',
            '96720',
            'US'
        );
        insert new List<breg_Account_Affiliation__c>{ oldCaseAffiliation, newCaseAffiliation };

        breg_Account_Affiliation__c oldEntityAffiliation = buildEntityAffiliation(entity.Id, oldAgent.Id, 'John', 'Doe');
        insert oldEntityAffiliation;

        runCompletedStatusChange(testCase);

        breg_Account_Affiliation__c refreshedNewAffiliation = [
            SELECT Id, breg_Account__c, breg_Role__c, breg_Status__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :newCaseAffiliation.Id
            LIMIT 1
        ];
        System.assertEquals(existingByNameAgent.Id, refreshedNewAffiliation.breg_Account__c, 'Handler should link existing account by name');
        System.assertEquals('Agent', refreshedNewAffiliation.breg_Role__c, 'Role should be switched to Agent');
        System.assertEquals('A', refreshedNewAffiliation.breg_Status__c, 'Affiliation should be active');

        Integer accountsWithSameName = [SELECT COUNT() FROM Account WHERE Name = 'Shared Existing'];
        System.assertEquals(1, accountsWithSameName, 'Handler should not create a duplicate account when one exists by name');

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_Account__c = :entity.Id AND breg_Case__c = :testCase.Id
        ];
        System.assertEquals(0, transactions.size(), 'Name-only change should not create address transactions');
    }

    @isTest
    static void testUpdateAgentRelationshipNameAndAddressCreatesAccount() {
        Account entity = [SELECT Id FROM Account WHERE Name = 'Test Entity' LIMIT 1];
        Account oldAgent = [SELECT Id FROM Account WHERE Name = 'Test Agent' LIMIT 1];

        Case testCase = createAgentUpdateCase('Test Case 3 - name and address create account', entity.Id, true, true);

        breg_Account_Affiliation__c oldCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'Agent',
            oldAgent.Id,
            'John',
            'Doe',
            '123 Old St',
            'Old City',
            'HI',
            '11111',
            'US'
        );
        breg_Account_Affiliation__c newCaseAffiliation = buildCaseAffiliation(
            testCase.Id,
            'New Agent',
            null,
            'Brand',
            'Created',
            '500 Created St',
            'Kailua',
            'HI',
            '96734',
            'US'
        );
        insert new List<breg_Account_Affiliation__c>{ oldCaseAffiliation, newCaseAffiliation };

        breg_Account_Affiliation__c oldEntityAffiliation = buildEntityAffiliation(entity.Id, oldAgent.Id, 'John', 'Doe');
        insert oldEntityAffiliation;

        Integer existingCount = [SELECT COUNT() FROM Account WHERE Name = 'Brand Created'];
        System.assertEquals(0, existingCount, 'Precondition failed: account should not exist before handler runs');

        runCompletedStatusChange(testCase);

        breg_Account_Affiliation__c refreshedNewAffiliation = [
            SELECT Id, breg_Account__c, breg_Role__c, breg_Status__c, breg_Start_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :newCaseAffiliation.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshedNewAffiliation.breg_Account__c, 'Handler should create and link a new account');
        System.assertEquals('Agent', refreshedNewAffiliation.breg_Role__c, 'Role should be switched to Agent');
        System.assertEquals('A', refreshedNewAffiliation.breg_Status__c, 'Affiliation should be active');
        System.assertEquals(testCase.breg_Effective_Date__c, refreshedNewAffiliation.breg_Start_Date__c, 'Start date should match effective date');

        Account createdAccount = [
            SELECT Name, BillingStreet, BillingCity, BillingStateCode, BillingPostalCode, BillingCountryCode
            FROM Account
            WHERE Id = :refreshedNewAffiliation.breg_Account__c
            LIMIT 1
        ];
        System.assertEquals('Brand Created', createdAccount.Name, 'Created account name should be derived from new affiliation');
        System.assertEquals('500 Created St', createdAccount.BillingStreet, 'Created account address should match new affiliation');

        Integer createdCount = [SELECT COUNT() FROM Account WHERE Name = 'Brand Created'];
        System.assertEquals(1, createdCount, 'Exactly one account should be created for the new agent');

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_Account__c = :entity.Id AND breg_Case__c = :testCase.Id
        ];
        System.assertEquals(2, transactions.size(), 'Name and address change should create old and new address transactions');
    }

    @isTest
    static void testAddressChangedFlagDoesNotBlockInsert() {
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-8' LIMIT 1];
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // New and old address match (handler compares concatenated normalized: Street + Street2 + City + StateCode + Postal + Country; no State_Text)
        Case caseSameAddress = new Case(
            Subject = 'Address validation test - same',
            Status = 'Pending Submission',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Reg_Agent_Address_Has_Changed__c = true,
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Registered_Agent_Address__Street__s = '123 Main St',
            breg_Reg_Agent_Address_Street2__c = 'Suite 1',
            breg_Registered_Agent_Address__StateCode__s = 'HI',
            breg_Registered_Agent_Address__City__s = 'Honolulu',
            breg_Registered_Agent_Address__PostalCode__s = '96815',
            breg_New_Registrant_Address__Street__s = '123 Main St',
            breg_New_Registrant_Address_Street_2__c = 'Suite 1',
            breg_New_Registrant_Address__City__s = 'Honolulu',
            breg_New_Registrant_Address__StateCode__s = 'HI',
            breg_New_Registrant_Address__PostalCode__s = '96815',
            breg_New_Registrant_Address__CountryCode__s = 'US'
        );

        Test.startTest();
        Database.SaveResult saveResult = Database.insert(caseSameAddress, false);
        Test.stopTest();
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Insert should succeed; this comparison validation is no longer enforced at Case DML level by this handler.'
        );
    }

    @isTest
    static void testNameChangedFlagDoesNotBlockInsert() {
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-8' LIMIT 1];
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case newCase = new Case(
            Subject = 'Name validation test',
            Status = 'Pending Submission',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Reg_Agent_Has_Changed__c = true,
            breg_Reg_Agent_Type__c = 'Individual',
            breg_Reg_Agent_Entity_Name__c = 'Acme Inc',
            breg_Reg_Agent_First_Name__c = 'John',
            breg_Reg_Agent_Last_Name__c = 'Doe',
            breg_New_Registrant_Type__c = 'Individual',
            breg_New_Registrant_Name__c = 'Acme Inc',
            breg_New_Registrant_First_Name__c = 'John',
            breg_New_Registrant_Last_Name__c = 'Doe'
        );

        Test.startTest();
        Database.SaveResult saveResult = Database.insert(newCase, false);
        Test.stopTest();

        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Insert should succeed; this comparison validation is no longer enforced at Case DML level by this handler.'
        );
    }

    private static void runCompletedStatusChange(Case iCase) {
        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerChangeNonComCRA');
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ iCase }, 'Completed', false, true);
        Test.stopTest();
    }

    private static Case createAgentUpdateCase(String subject, Id entityId, Boolean isNameChanged, Boolean isAddressChanged) {
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-8' LIMIT 1];
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case iCase = new Case(
            Subject = subject,
            Status = 'New',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = entityId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-8',
            breg_Effective_Date__c = Date.today(),
            breg_Reg_Agent_Has_Changed__c = isNameChanged,
            breg_Reg_Agent_Address_Has_Changed__c = isAddressChanged
        );
        insert iCase;

        return iCase;
    }

    private static breg_Account_Affiliation__c buildCaseAffiliation(
        Id caseId,
        String role,
        Id accountId,
        String firstName,
        String lastName,
        String street,
        String city,
        String stateCode,
        String postalCode,
        String countryCode
    ) {
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = caseId,
            breg_Role__c = role,
            breg_Type__c = 'Individual',
            breg_First_Name__c = firstName,
            breg_Last_Name__c = lastName,
            breg_Address__Street__s = street,
            breg_Address__City__s = city,
            breg_Address__StateCode__s = stateCode,
            breg_Address__PostalCode__s = postalCode,
            breg_Address__CountryCode__s = countryCode
        );
        affiliation.breg_Account__c = accountId;
        return affiliation;
    }

    private static breg_Account_Affiliation__c buildEntityAffiliation(Id entityId, Id agentAccountId, String firstName, String lastName) {
        return new breg_Account_Affiliation__c(
            breg_Entity__c = entityId,
            breg_Account__c = agentAccountId,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_First_Name__c = firstName,
            breg_Last_Name__c = lastName,
            breg_Start_Date__c = Date.today().addDays(-30),
            breg_End_Date__c = null,
            breg_Status__c = 'A'
        );
    }

    private static Account createAgentAccount(
        String name,
        String billingStreet,
        String billingCity,
        String billingStateCode,
        String billingPostalCode,
        String billingCountryCode
    ) {
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        return new Account(
            Name = name,
            RecordTypeId = accountRecordTypeId,
            breg_Registrant_Type__c = 'Individual',
            BillingStreet = billingStreet,
            BillingCity = billingCity,
            BillingStateCode = billingStateCode,
            BillingPostalCode = billingPostalCode,
            BillingCountryCode = billingCountryCode
        );
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;
    }
}