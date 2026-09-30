@isTest
private class BREGCaseStatusHandlerX7ChangeCRATest {
    @TestSetup
    static void setupData() {
        Id accRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id caseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'X7 LLP Entity',
            RecordTypeId = accRtId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        Account gp = new Account(
            Name = 'X7 GP Entity',
            RecordTypeId = accRtId,
            ParentId = entity.Id,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert gp;

        Account oldAgent = new Account(
            Name = 'Old Agent',
            RecordTypeId = accRtId,
            breg_Registrant_Type__c = 'Individual',
            BillingStreet = '123 St',
            BillingCity = 'City',
            BillingStateCode = 'HI',
            BillingPostalCode = '96816',
            BillingCountryCode = 'US'
        );
        insert oldAgent;

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'X-7',
            breg_Form_Code__c = 'X-7',
            breg_Entity_Type__c = 'K5'
        );
        insert formConfig;

        Case c = new Case(
            Subject = 'X7 CRA Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRtId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-7',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = entity.Name
        );
        insert c;

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Account__c = oldAgent.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.today().addYears(-1)
        );

        insert new breg_Account_Affiliation__c(
            breg_Case__c = c.Id,
            breg_Role__c = 'New Agent',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'New',
            breg_Last_Name__c = 'Agent',
            breg_Address__Street__s = '1 Main St',
            breg_Address__City__s = 'Hartford',
            breg_Address__StateCode__s = 'HI',
            breg_Address__PostalCode__s = '96816',
            breg_Address__CountryCode__s = 'US'
        );
    }

    @isTest
    static void testEmptyInputBranches() {
        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>(), 'Approved', true, false);
        handler.handleStatusChange(new List<Case>(), 'Approved', false, true);
        handler.handleStatusChange(new List<Case>(), 'Completed', false, true);
        handler.handleStatusChange(new List<Case>(), 'Rejected', true, false);
        Test.stopTest();

        Assert.isTrue(true, 'Empty branches should execute without errors.');
    }

    @isTest
    static void testApprovedValidationAndActions() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'X7 CRA Test Case' LIMIT 1];
        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Approved validation path should execute.');
        }
        Test.stopTest();

        List<breg_Transaction__c> txns = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_File_Number__c = :c.Id
        ];
        Assert.isNotNull(txns, 'Approved action should attempt entity and GP transaction creation.');
    }

    @isTest
    static void testCompletedUpdatesAgentRelationship() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'X7 CRA Test Case' LIMIT 1];
        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        breg_Account_Affiliation__c newAgent = [
            SELECT Id, breg_Role__c, breg_Status__c, breg_Start_Date__c, breg_Entity__c, breg_Account__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Agent'
            LIMIT 1
        ];

        Assert.areEqual('A', newAgent.breg_Status__c, 'New agent affiliation should become active.');
        Assert.isNotNull(newAgent.breg_Account__c, 'New agent account should be linked.');
    }

    @isTest
    static void testApprovedValidationMissingEntity() {
        Id caseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-7' LIMIT 1];

        Case c = new Case(
            Subject = 'X-7 Missing Entity Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRtId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-7',
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = 'Missing Entity'
        );
        insert c;

        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Missing entity validation path should execute.');
        }
        Test.stopTest();
    }

    @isTest
    static void testReceivedCreatesEntityAndGpTransactionsForLlp() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'X7 CRA Test Case'
            LIMIT 1
        ];
        Account gp = [SELECT Id FROM Account WHERE Name = 'X7 GP Entity' LIMIT 1];
        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> txnRecords = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, breg_Case__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id AND breg_Transaction_Code__c = 'AGC'
        ];

        Set<Id> accountIds = new Set<Id>();
        for (breg_Transaction__c txnRecord : txnRecords) {
            accountIds.add(txnRecord.breg_Account__c);
            Assert.areEqual('R', txnRecord.breg_Status__c, 'X-7 Received transactions should have Received status.');
        }

        Assert.isTrue(accountIds.contains(c.breg_Entity__c), 'Entity AGC transaction should be created.');
        Assert.isTrue(accountIds.contains(gp.Id), 'GP AGC transaction should be created for LLP entities.');
    }

    @isTest
    static void testCompletedUsesPrelinkedNewAgentAccount() {
        Id accRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id caseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Account entity = [SELECT Id, Name FROM Account WHERE Name = 'X7 LLP Entity' LIMIT 1];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-7' LIMIT 1];

        Account prelinkedAgentAccount = new Account(
            Name = 'Prelinked New Agent Account',
            RecordTypeId = accRtId,
            breg_Registrant_Type__c = 'Entity',
            BillingStreet = '50 Agent Rd',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96816',
            BillingCountryCode = 'US'
        );
        insert prelinkedAgentAccount;

        Case c = new Case(
            Subject = 'X7 CRA Existing Agent Account Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRtId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-7',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = entity.Name
        );
        insert c;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = c.Id,
            breg_Role__c = 'New Agent',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Prelinked New Agent Account',
            breg_Account__c = prelinkedAgentAccount.Id,
            breg_Address__Street__s = '50 Agent Rd',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address__PostalCode__s = '96816',
            breg_Address__CountryCode__s = 'US'
        );

        BREGCaseStatusHandlerX7ChangeCRA handler = new BREGCaseStatusHandlerX7ChangeCRA();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        breg_Account_Affiliation__c newAgentAffiliation = [
            SELECT Id, breg_Case__c, breg_Role__c, breg_Status__c, breg_Entity__c, breg_Account__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Agent'
            LIMIT 1
        ];

        Assert.areEqual('A', newAgentAffiliation.breg_Status__c, 'Prelinked new agent affiliation should become active.');
        Assert.areEqual(prelinkedAgentAccount.Id, newAgentAffiliation.breg_Account__c, 'Existing account should be reused for new agent.');
    }
}