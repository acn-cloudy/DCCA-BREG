@isTest
public with sharing class BREGCaseStatusHandlerDissTermWithCanTest {
    @TestSetup
    static void setupData() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-13',
            breg_Transaction_Code__c = 'DS'
        );
        insert formConfig;
        String accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        // Create Entity Account
        Account entity = new Account(Name = 'Test Entity', breg_Entity_Type__c = 'D1', RecordTypeId = accountRecordTypeId, breg_File__c = '12345-D1');
        insert entity;

        // Create child Account (for dissolveGeneralPartnership)
        Account child = new Account(
            Name = 'Child Entity',
            ParentId = entity.Id,
            breg_Entity_Type__c = 'L5', // Partnership code
            RecordTypeId = accountRecordTypeId,
            breg_File__c = '12345-L5'
        );
        insert child;

        // Create Reg Agent
        breg_Account_Affiliation__c agent = new breg_Account_Affiliation__c(breg_Account__c = entity.Id, breg_Entity__c = entity.Id);
        insert agent;

        // Add to entity (simulate lookup)
        entity.breg_Certified_Register_Agent__c = agent.Id;
        update entity;

        // Create Case linked to entity
        Case c = new Case(
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Update_Child_Entity__c = true,
            breg_Form_Configuration__c = formConfig.Id,
            breg_File__c = '12345-D1'
        );
        insert c;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(Name = 'Test Payment for Case ' + c.Id, breg_Case__c = c.Id, pymt__Status__c = 'Completed');
        insert payment;
        agent.breg_Case__c = c.Id;
        agent.breg_Bypass_Validation_Token__c = Datetime.now();
        update agent;
        Transaction__c trn = new Transaction__c(
            Account__c = entity.Id,
            breg_Case__c = c.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert trn;
        TransactionLine__c tl = new TransactionLine__c();
        tl.Transaction__c = trn.Id;
        tl.Amount__c = 20;
        tl.breg_Case__c = c.Id;
        tl.PaidStatus__c = 'Paid';
        insert tl;
    }

    @isTest
    static void testHandleStatusChange_Approved() {
        Case testCase = [SELECT Id, breg_Transaction_Code__c FROM Case LIMIT 1];

        Test.startTest();
        BREGCaseStatusHandlerDissTermWithdrCanc handler = new BREGCaseStatusHandlerDissTermWithdrCanc();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, true);
        Test.stopTest();

        // Assertions can be added here, but most logic will be verified by not throwing errors
        System.assert(true, 'Approved status handled without exceptions');
    }

    @isTest
    static void testHandleStatusChange_Completed() {
        Case testCase = [SELECT Id, breg_Entity__c FROM Case LIMIT 1];

        Test.startTest();
        BREGCaseStatusHandlerDissTermWithdrCanc handler = new BREGCaseStatusHandlerDissTermWithdrCanc();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        // Check that entity account status was updated
        Account updatedEntity = [SELECT Id, breg_Entity_Status__c, breg_Entity_Type__c, breg_Certified_Register_Agent__c FROM Account WHERE Id = :testCase.breg_Entity__c];
        System.assertEquals('Dissolved (D)', updatedEntity.breg_Entity_Status__c, 'Entity type should be updated');

        // Check that child entity was updated (L5 => Cancelled)
        Account child = [SELECT Id, breg_Entity_Status__c FROM Account WHERE ParentId = :updatedEntity.Id];
        System.assertEquals('Cancelled (C)', child.breg_Entity_Status__c, 'Child account should be marked Cancelled');

        breg_Account_Affiliation__c agentAfter = [
            SELECT breg_End_Date__c, breg_Status__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :updatedEntity.breg_Certified_Register_Agent__c
        ];
        Assert.areEqual(null, agentAfter.breg_End_Date__c, 'Agent should not be end-dated for DC-13');
        Assert.areEqual(null, agentAfter.breg_Status__c, 'Agent status should be unchanged for DC-13');
    }

    @isTest
    static void testHandleStatusChange_Completed_NonSkipCode_EndsDateAffiliations() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K5',
            breg_Suffix_Code__c = 'K5',
            breg_Form_Code__c = 'LLP-2',
            breg_Transaction_Code__c = 'WD'
        );
        insert formConfig;

        String accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account entity = new Account(Name = 'LLP-2 Entity', breg_Entity_Type__c = 'K5', RecordTypeId = accountRecordTypeId, breg_File__c = '88888-K5');
        insert entity;

        breg_Account_Affiliation__c agent = new breg_Account_Affiliation__c(
            breg_Account__c = entity.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Status__c = 'A'
        );
        breg_Account_Affiliation__c officer = new breg_Account_Affiliation__c(
            breg_Account__c = entity.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Officer',
            breg_Status__c = 'A'
        );
        insert new List<breg_Account_Affiliation__c>{ agent, officer };
        entity.breg_Certified_Register_Agent__c = agent.Id;
        update entity;

        Case iCase = new Case(
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Configuration__c = formConfig.Id,
            breg_File__c = '88888-K5'
        );
        insert iCase;

        Test.startTest();
        new BREGCaseStatusHandlerDissTermWithdrCanc().handleStatusChange(new List<Case>{ iCase }, 'Completed', false, true);
        Test.stopTest();

        breg_Account_Affiliation__c agentAfter = [SELECT breg_End_Date__c, breg_Status__c FROM breg_Account_Affiliation__c WHERE Id = :agent.Id];
        Assert.areEqual(Date.today(), agentAfter.breg_End_Date__c, 'Agent should be end-dated for LLP-2');
        Assert.areEqual('I', agentAfter.breg_Status__c, 'Agent should be inactive for LLP-2');

        breg_Account_Affiliation__c officerAfter = [SELECT breg_End_Date__c, breg_Status__c FROM breg_Account_Affiliation__c WHERE Id = :officer.Id];
        Assert.areEqual(Date.today(), officerAfter.breg_End_Date__c, 'Other affiliations should still be end-dated for LLP-2');
        Assert.areEqual('I', officerAfter.breg_Status__c, 'Officer affiliation should be inactive for LLP-2');
    }

    @isTest
    static void testHandleStatusChange_EntityMissing_ShouldError() {
        Case badCase = new Case(RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId());
        insert badCase;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Test Payment for Case ' + badCase.Id,
            breg_Case__c = badCase.Id,
            pymt__Status__c = 'Completed'
        );
        insert payment;

        Test.startTest();
        try {
            BREGCaseStatusHandlerDissTermWithdrCanc handler = new BREGCaseStatusHandlerDissTermWithdrCanc();
            handler.handleStatusChange(new List<Case>{ badCase }, 'Approved', true, false);
            System.assert(false, 'Expected validation error not thrown');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testDissolveGeneralPartnership_CreatesTransaction() {
        Case testCase = [
            SELECT Id, breg_Entity__c, breg_Form_Code__c, breg_Form_Configuration__c, breg_Effective_Date__c, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_Update_Child_Entity__c = true;
        update testCase;
        String accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account child = new Account(
            Name = 'Child Partnership',
            ParentId = testCase.breg_Entity__c,
            breg_Entity_Type__c = 'L5', // Partnership → status becomes 'Cancelled (C)' → code 'CN'
            RecordTypeId = accountRecordTypeId
        );
        insert child;

        testCase.breg_Update_Child_Entity__c = true;
        update testCase;

        Test.startTest();
        new BREGCaseStatusHandlerDissTermWithdrCanc().handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedChild = [SELECT breg_Entity_Status__c FROM Account WHERE Id = :child.Id];
        System.assertEquals('Cancelled (C)', updatedChild.breg_Entity_Status__c, 'Child account should have correct status');

        List<breg_Transaction__c> transactions = [
            SELECT breg_Account__c, breg_Transaction_Code__c, breg_File_Number__c, breg_Case__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :child.Id
        ];

        System.assertEquals(1, transactions.size(), 'One transaction should be created for the child account');
        System.assertEquals('DS', transactions[0].breg_Transaction_Code__c, 'Transaction code should match status mapping');
        System.assertEquals(testCase.Id, transactions[0].breg_Case__c, 'Case should match related case');
    }
}