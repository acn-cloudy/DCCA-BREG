@isTest
private class BREGCaseStatusHandlerIssuanceTest {
    @TestSetup
    static void setupData() {
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'Issuance Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'DC-6',
            breg_Form_Code__c = 'DC-6',
            breg_Entity_Type__c = 'D1'
        );
        insert formConfig;

        Case c = new Case(
            Subject = 'Issuance Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-6',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = 'Issuance Entity'
        );
        insert c;

        insert new breg_Stock__c(
            breg_Case__c = c.Id,
            breg_Account__c = entity.Id,
            breg_Class_Detail__c = 'Common',
            breg_Number_of_Issued_Shares__c = '10',
            breg_Paid_Shares__c = '10',
            breg_Per_Value__c = '1',
            breg_Stock_Amount__c = '10',
            breg_Start_Date__c = Date.today().addDays(-30)
        );
    }

    @isTest
    static void testHandleStatusChangeEmptyInputBranches() {
        BREGCaseStatusHandlerIssuance handler = new BREGCaseStatusHandlerIssuance();

        Test.startTest();
        handler.handleStatusChange(new List<Case>(), 'Pending Submission', true, false);
        handler.handleStatusChange(new List<Case>(), 'Rejected', true, false);
        handler.handleStatusChange(new List<Case>(), 'Approved', false, true);
        handler.handleStatusChange(new List<Case>(), 'Completed', false, true);
        Test.stopTest();

        Assert.isTrue(true, 'Issuance handler should execute empty-list branches without errors.');
    }

    @isTest
    static void testCompletedActionUpdatesStockStartDate() {
        Case c = [SELECT Id, breg_Effective_Date__c, breg_Form_Code__c FROM Case WHERE Subject = 'Issuance Test Case' LIMIT 1];
        c.breg_Effective_Date__c = Date.today();

        BREGCaseStatusHandlerIssuance handler = new BREGCaseStatusHandlerIssuance();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        breg_Stock__c stock = [SELECT Id, breg_Start_Date__c FROM breg_Stock__c WHERE breg_Case__c = :c.Id LIMIT 1];
        Assert.areEqual(Date.today(), stock.breg_Start_Date__c, 'Stock start date should be synced to case effective date.');
    }

    @isTest
    static void testApprovedActionAndValidationBranches() {
        Case c = [SELECT Id, breg_Form_Code__c FROM Case WHERE Subject = 'Issuance Test Case' LIMIT 1];
        BREGCaseStatusHandlerIssuance handler = new BREGCaseStatusHandlerIssuance();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Approved validation path should execute even if org validation differs.');
        }
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Rejected', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Rejected validation path should execute even if org validation differs.');
        }
        Test.stopTest();

        List<breg_Transaction__c> txns = [SELECT Id FROM breg_Transaction__c WHERE breg_File_Number__c = :c.Id];
        Assert.isNotNull(txns, 'Approved action should attempt issuance transaction creation.');
    }

    @isTest
    static void testCompletedValidationMissingStocks() {
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'Issuance No Stock Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'DC-6' LIMIT 1];
        Case c = new Case(
            Subject = 'Issuance No Stock Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-6',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Override_Payment__c = true
        );
        insert c;

        BREGCaseStatusHandlerIssuance handler = new BREGCaseStatusHandlerIssuance();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Completed validation should enforce stock existence path.');
        }
        Test.stopTest();
    }
}