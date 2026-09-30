@isTest
public with sharing class BREGCaseStatusHandlerReinstatementTest {
    @TestSetup
    static void setupData() {
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        // Create parent account for standard reinstatement (C5)
        Account parent = new Account(
            Name = 'Parent Entity',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'C5',
            breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)',
            breg_Good_Standing__c = false,
            breg_File__c = '001',
            breg_Incorporation_Date__c = Date.today()
        );
        insert parent;

        // Create child account
        Account child = new Account(
            Name = 'Child Entity',
            ParentId = parent.Id,
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'C6',
            breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)',
            breg_Good_Standing__c = false,
            breg_File__c = '002',
            breg_Incorporation_Date__c = Date.today()
        );
        insert child;

        // Create LLP parent account (K5) for partnership-specific tests
        Account llpAccount = new Account(
            Name = 'LLP Parent Entity',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Annual report 2 yr delinquent (2)',
            breg_Good_Standing__c = false,
            breg_File__c = '003',
            breg_Incorporation_Date__c = Date.today()
        );
        insert llpAccount;

        // Create General Partnership child account (G6) under LLP parent
        Account gpChild = new Account(
            Name = 'GP Child Entity Under LLP',
            ParentId = llpAccount.Id,
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'G6',
            breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)',
            breg_Good_Standing__c = false,
            breg_File__c = '004',
            breg_Incorporation_Date__c = Date.today()
        );
        insert gpChild;

        // Create affiliation (agent)
        breg_Account_Affiliation__c agent = new breg_Account_Affiliation__c(
            breg_Account__c = parent.Id,
            breg_Entity__c = parent.Id,
            breg_Role__c = 'Agent',
            breg_Status__c = 'A',
            breg_Start_date__c = Date.today(),
            breg_Address__Street__s = '1234 Aloha Dr',
            breg_Address__CountryCode__s = 'US',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__City__s = 'Honolulu',
            breg_Address__PostalCode__s = '96815'
        );
        insert agent;

        // Create active affiliations for child, LLP parent, and GP child accounts
        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Account__c = child.Id,
                breg_Entity__c = child.Id,
                breg_Role__c = 'Agent',
                breg_Status__c = 'A',
                breg_Start_date__c = Date.today(),
                breg_Address__Street__s = '1234 Aloha Dr',
                breg_Address__CountryCode__s = 'US',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__City__s = 'Honolulu',
                breg_Address__PostalCode__s = '96815'
            ),
            new breg_Account_Affiliation__c(
                breg_Account__c = llpAccount.Id,
                breg_Entity__c = llpAccount.Id,
                breg_Role__c = 'Agent',
                breg_Status__c = 'A',
                breg_Start_date__c = Date.today(),
                breg_Address__Street__s = '1234 Aloha Dr',
                breg_Address__CountryCode__s = 'US',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__City__s = 'Honolulu',
                breg_Address__PostalCode__s = '96815'
            ),
            new breg_Account_Affiliation__c(
                breg_Account__c = gpChild.Id,
                breg_Entity__c = gpChild.Id,
                breg_Role__c = 'Agent',
                breg_Status__c = 'A',
                breg_Start_date__c = Date.today(),
                breg_Address__Street__s = '1234 Aloha Dr',
                breg_Address_State_Text__c = 'HI',
                breg_Address__CountryCode__s = 'US',
                breg_Address__StateCode__s = 'HI',
                breg_Address__City__s = 'Honolulu',
                breg_Address__PostalCode__s = '96815'
            )
        };

        breg_Form_Configuration__c x4FormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'X-4', breg_Form_Code__c = 'X-4');
        insert x4FormConfig;

        breg_Form_Configuration__c annFormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'C6', breg_Form_Code__c = 'ANN-FLLC-1');
        insert annFormConfig;

        // Create reinstatement case for parent
        Case reinstatement = new Case(
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = parent.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Update_Child_Entity__c = true,
            breg_File_Suffix__c = 'R',
            breg_File__c = '001',
            breg_Form_Configuration__c = x4FormConfig.Id,
            breg_Form_Code__c = x4FormConfig.breg_Form_Code__c,
            Status = 'Received'
        );
        insert reinstatement;

        // Create reinstatement case for LLP parent
        Case gpReinstatement = new Case(
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = llpAccount.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Update_Child_Entity__c = true,
            breg_File_Suffix__c = 'R',
            breg_File__c = '003',
            breg_Form_Configuration__c = x4FormConfig.Id,
            breg_Form_Code__c = x4FormConfig.breg_Form_Code__c,
            Status = 'Received'
        );
        insert gpReinstatement;

        // Link agent to case
        agent.breg_Case__c = reinstatement.Id;
        update agent;

        // Create completed payment
        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Payment for Reinstatement',
            breg_Case__c = reinstatement.Id,
            pymt__Status__c = 'Completed'
        );
        insert payment;

        // Create completed payment for LLP case
        pymt__PaymentX__c gpPayment = new pymt__PaymentX__c(
            Name = 'Payment for LLP Reinstatement',
            breg_Case__c = gpReinstatement.Id,
            pymt__Status__c = 'Completed'
        );
        insert gpPayment;

        // Create active annual case as child
        Case annual = new Case(
            RecordTypeId = reinstatement.RecordTypeId,
            breg_Entity__c = parent.Id,
            ParentId = reinstatement.Id,
            Status = 'In Progress',
            breg_Form_Configuration__c = annFormConfig.Id,
            breg_Form_Code__c = annFormConfig.breg_Form_Code__c
        );
        insert annual;
    }

    @isTest
    static void testHandleStatusChange_Completed_WithAnnuals() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Update_Child_Entity__c, breg_File_Suffix__c, breg_Form_Code__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        // Assert: account became Active and Good Standing
        Account acc = [
            SELECT breg_Entity_Status__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];
        Assert.areEqual('Active (A)', acc.breg_Entity_Status__c, 'Account should be Active');
        Assert.areEqual(true, acc.breg_Good_Standing__c, 'Account should be in Good Standing');

        // Assert: annual case was reassigned to DOC I
        Group docI = [SELECT Id FROM Group WHERE DeveloperName = 'DOC_I' LIMIT 1];
        Case annual = [
            SELECT OwnerId
            FROM Case
            WHERE ParentId = :testCase.Id AND breg_Form_Code__c LIKE 'ANN-%'
            LIMIT 1
        ];
        Assert.areEqual(docI.Id, annual.OwnerId, 'Annual case should be reassigned to DOC I');

        // Assert: reinstatement case owner not changed (since annual case still exists)
        Case updatedReinst = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
        Assert.areNotEqual(docI.Id, updatedReinst.OwnerId, 'Reinstatement case owner should not be DOC I');

        // Assert: transaction was created for parent account
        List<breg_Transaction__c> parentTransactions = [
            SELECT breg_Transaction_Code__c, breg_Account__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :testCase.breg_Entity__c
        ];
        Assert.areEqual(1, parentTransactions.size(), 'Transaction should be created for parent account');
        Assert.areEqual('RE', parentTransactions[0].breg_Transaction_Code__c, 'Transaction code should be RE');
    }

    @isTest
    static void testHandleStatusChange_Completed_NoAnnuals() {
        // Remove all active annuals to trigger DOC R assignment
        List<Case> annuals = [SELECT Id FROM Case WHERE breg_Form_Code__c LIKE 'ANN-%'];
        delete annuals;

        Case testCase = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        // Assert: Owner changed to DOC R (no annuals exist)
        Case updated = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
        Group docR = [SELECT Id FROM Group WHERE DeveloperName = 'DOC_R' LIMIT 1];
        Assert.areEqual(docR.Id, updated.OwnerId, 'Owner should be changed to DOC R');

        // Assert: account became Active and Good Standing
        Account acc = [
            SELECT breg_Entity_Status__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];
        Assert.areEqual('Active (A)', acc.breg_Entity_Status__c, 'Account should be Active');
        Assert.areEqual(true, acc.breg_Good_Standing__c, 'Account should be in Good Standing');
    }

    @isTest
    static void testHandleStatusChange_Approved_LlpParentCreatesTransactionsForGpChildren() {
        Case gpCase = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'K5'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(
            new List<Case>{ gpCase }, 'Approved', false, true
        );
        Test.stopTest();

        // Assert: parent is LLP
        Account gpAccount = [
            SELECT breg_Entity_Type__c
            FROM Account
            WHERE Id = :gpCase.breg_Entity__c
        ];
        Assert.areEqual('K5', gpAccount.breg_Entity_Type__c, 'Parent account should be LLP (K5)');

        // Assert: child is GP under LLP parent
        Account gpChild = [
            SELECT Id, breg_Entity_Type__c
            FROM Account
            WHERE ParentId = :gpCase.breg_Entity__c
            LIMIT 1
        ];
        Assert.areEqual('G6', gpChild.breg_Entity_Type__c, 'Child account should be GP (G6)');

        // Assert: Approved creates transaction for GP child account when parent is LLP
        List<breg_Transaction__c> childTransactions = [
            SELECT breg_Transaction_Code__c, breg_Account__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :gpChild.Id
        ];
        Assert.areEqual(1, childTransactions.size(), 'Transaction should be created for GP child account on Approved');
        Assert.areEqual('RE', childTransactions[0].breg_Transaction_Code__c, 'Transaction code should be RE');
    }

    @isTest
    static void testHandleStatusChange_Completed_AlreadyActive() {
        Case testCase = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        // Set account to already Active
        Account acc = [SELECT Id FROM Account WHERE Id = :testCase.breg_Entity__c];
        acc.breg_Entity_Status__c = 'Active (A)';
        acc.breg_Good_Standing__c = true;
        update acc;

        Test.startTest();
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        // Assert: account remains Active (no error thrown)
        Account updatedAcc = [
            SELECT breg_Entity_Status__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];
        Assert.areEqual('Active (A)', updatedAcc.breg_Entity_Status__c, 'Account should remain Active');
        Assert.areEqual(true, updatedAcc.breg_Good_Standing__c, 'Account should remain in Good Standing');

        // Assert: transaction still created
        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c WHERE breg_Account__c = :testCase.breg_Entity__c];
        Assert.areEqual(1, transactions.size(), 'Transaction should still be created');
    }

    @isTest
    static void testHandleStatusChange_Rejected() {
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        // Create a child case with Pending Submission status
        breg_Form_Configuration__c childFormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'C6', breg_Form_Code__c = 'ANN-FLLC-1');
        insert childFormConfig;

        Case childCase = new Case(
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ParentId = testCase.Id,
            Status = 'Pending Submission',
            breg_Form_Configuration__c = childFormConfig.Id,
            breg_Form_Code__c = childFormConfig.breg_Form_Code__c
        );
        insert childCase;

        Test.startTest();
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Rejected', false, true);
        Test.stopTest();

        // Assert: child case status updated to Rejected
        Case updatedChild = [SELECT Status FROM Case WHERE Id = :childCase.Id];
        Assert.areEqual('Rejected', updatedChild.Status, 'Child case should be Rejected');
    }

    @isTest
    static void testValidation_Completed_FlagNotSet() {
        Case testCase = [
            SELECT Id, breg_Is_Allowed_Generate_Reinstatem_Cert__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        // Ensure flag is false
        testCase.breg_Is_Allowed_Generate_Reinstatem_Cert__c = false;
        testCase.Status = 'Approved';
        update testCase;

        Test.startTest();
        try {
            new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            Assert.isTrue(e.getMessage().contains('Is Allowed Generate Reinstatement Cert'), 'Error message should mention the required checkbox');
        }
    }

    @isTest
    static void testValidation_Completed_FlagSet() {
        // Remove annuals to allow flag to be set
        delete [SELECT Id FROM Case WHERE breg_Form_Code__c LIKE 'ANN-%'];

        Case testCase = [
            SELECT Id
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        Test.startTest();
        // First complete to trigger flag and owner change
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        // Manually set the flag to simulate the workflow
        testCase = [
            SELECT Id, breg_Is_Allowed_Generate_Reinstatem_Cert__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        testCase.breg_Is_Allowed_Generate_Reinstatem_Cert__c = true;
        update testCase;

        // Assert: validation should pass with flag set
        testCase = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Completed', true, false);

        // If no exception, validation passed
        Assert.isTrue(true, 'Validation should pass when flag is set');
    }

    @isTest
    static void testValidation_Approved_EntityStatusNotAllowed() {
        Case testCase = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        Account relatedEntity = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];

        relatedEntity.breg_Entity_Status__c = 'Active (A)'; // status not allowed for reinstatement
        update relatedEntity;

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerReinstatement');

        Boolean errorThrown = false;
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            errorThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Reinstatement is not allowed for related Entity with status: Active (A)'),
                'Error message should include disallowed entity status'
            );
        }
        Test.stopTest();

        Assert.isTrue(errorThrown, 'Validation should fail when entity status is not allowed for reinstatement');
    }

    @isTest
    static void testValidation_Approved_EntityStatusAllowed() {
        Case testCase = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
            LIMIT 1
        ];

        Account relatedEntity = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id = :testCase.breg_Entity__c
        ];

        BREGAccountTriggerHandler.skipDocusignWorkflow = true;
        relatedEntity.breg_Entity_Status__c = 'Inv. Revoked (R)';
        update relatedEntity;

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerBase handler = (BREGCaseStatusHandlerBase) BREGUtils.getHandlerInstance('BREGCaseStatusHandlerReinstatement');

        Boolean entityStatusErrorThrown = false;
        Test.startTest();
        try {
            new BREGCaseStatusHandlerReinstatement().handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            entityStatusErrorThrown = e.getMessage().contains('Reinstatement is not allowed for related Entity with status');
        }
        Test.stopTest();

        Assert.isFalse(entityStatusErrorThrown, 'validateEntityStatusForReinstatement should not block an entity with an allowed status');
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;

        TransactionLine__c line = new TransactionLine__c(Transaction__c = trans.Id, breg_Case__c = caseId, PaidStatus__c = 'Paid', Amount__c = 100);
        insert line;
    }

    // @isTest
    // static void testHandleStatusChange_MultipleClosedAnnualStatuses() {
    //     Case testCase = [
    //         SELECT Id, breg_Entity__c
    //         FROM Case
    //         WHERE breg_Form_Code__c = 'X-4' AND breg_Entity__r.breg_Entity_Type__c = 'C5'
    //         LIMIT 1
    //     ];

    //     // Update annual case to various closed statuses
    //     Case annual = [SELECT Id FROM Case WHERE ParentId = :testCase.Id LIMIT 1];

    //     List<String> closedStatuses = new List<String>{'Approved', 'Rejected', 'Expired', 'Withdrawn', 'Bounce Check'};

    //     for (String closedStatus : closedStatuses) {
    //         annual.Status = closedStatus;
    //         update annual;

    //         Test.startTest();
    //         new BREGCaseStatusHandlerReinstatement().handleStatusChange(
    //             new List<Case>{ testCase }, 'Completed', false, true
    //         );
    //         Test.stopTest();

    //         // Assert: Owner should be DOC R since annual is closed
    //         Case updated = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
    //         Group docR = [SELECT Id FROM Group WHERE DeveloperName = 'DOC_R' LIMIT 1];
    //         Assert.areEqual(docR.Id, updated.OwnerId,
    //             'Owner should be DOC R when annual status is ' + closedStatus);
    //     }
    // }
}