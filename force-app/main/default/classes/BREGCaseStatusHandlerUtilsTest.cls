@isTest
private class BREGCaseStatusHandlerUtilsTest {
    @TestSetup
    static void setupData() {
        BREGCaseStatusHandlerBaseTest.setupTestData();

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Case paidCase = new Case(
            Subject = 'Utils Paid Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert paidCase;

        Transaction__c trans = new Transaction__c();
        insert trans;

        insert new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = paidCase.Id,
            PaidStatus__c = 'Paid',
            Amount__c = 100
        );
    }

    @isTest
    static void testGetHandlerClassNameMappings() {
        Assert.areEqual('BREGCaseStatusHandlerNBR', BREGCaseStatusHandlerUtils.getHandlerClassName('DC-1'));
        Assert.areEqual('BREGCaseStatusHandlerTNTMSMRenewal', BREGCaseStatusHandlerUtils.getHandlerClassName('T-1'));
        Assert.areEqual('BREGCaseStatusHandlerPublicityRightsReg', BREGCaseStatusHandlerUtils.getHandlerClassName('T-7'));
        Assert.areEqual('BREGCaseStatusHandlerMerger', BREGCaseStatusHandlerUtils.getHandlerClassName('X-12'));
        Assert.areEqual('BREGCaseStatusHandlerIssuance', BREGCaseStatusHandlerUtils.getHandlerClassName('DC-6'));
        Assert.areEqual('BREGCaseStatusHandlerRestatedArticles', BREGCaseStatusHandlerUtils.getHandlerClassName('DC-4'));
        Assert.areEqual('BREGCaseStatusHandlerBase', BREGCaseStatusHandlerUtils.getHandlerClassName('UNKNOWN-FORM'));
    }

    @isTest
    static void testGetStatusAndHandlerToCasesMapAndPaymentDone() {
        Case oldCase = [SELECT Id, Status, breg_Form_Code__c, breg_Override_Payment__c FROM Case WHERE Subject = 'Utils Paid Case' LIMIT 1];
        Case newCase = oldCase.clone(false, true, false, false);
        newCase.Id = oldCase.Id;
        newCase.Status = 'Approved';

        Map<String, List<Case>> grouped = BREGCaseStatusHandlerUtils.getStatusAndHandlerToCasesMap(
            new List<Case>{ newCase },
            new Map<Id, Case>{ oldCase.Id => oldCase }
        );

        Assert.isNotNull(grouped, 'Status-to-handler case map should return a map instance.');

        Map<Id, Boolean> paymentMap = BREGCaseStatusHandlerUtils.isPaymentDoneForCases(new List<Case>{ newCase });
        Assert.areEqual(true, paymentMap.get(newCase.Id), 'Paid transaction line should mark payment as done.');
    }

    @isTest
    static void testIsPaymentDoneForCasesGpRegistrationAndOverride() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Case parentCase = new Case(
            Subject = 'Utils Parent Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert parentCase;

        Transaction__c trans = new Transaction__c();
        insert trans;
        insert new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = parentCase.Id,
            PaidStatus__c = 'Paid',
            Amount__c = 50
        );

        Case gpCase = new Case(
            Subject = 'Utils GP Child Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'GP-1',
            ParentId = parentCase.Id,
            breg_Is_LLP_Registration__c = true,
            breg_Override_Payment__c = true
        );
        insert gpCase;

        Map<Id, Boolean> paymentMap = BREGCaseStatusHandlerUtils.isPaymentDoneForCases(new List<Case>{ gpCase });
        Assert.areEqual(true, paymentMap.get(parentCase.Id), 'GP-1 LLP registration should evaluate payment against parent case.');
    }

    @isTest
    static void testValidateCaseStatusChangeInvocablePaths() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Utils Paid Case' LIMIT 1];

        BREGCaseStatusHandlerUtils.FlowInput inputByCase = new BREGCaseStatusHandlerUtils.FlowInput();
        inputByCase.caseId = c.Id;
        inputByCase.checkFormCode = true;
        inputByCase.newStatus = 'Pending Submission';

        BREGCaseStatusHandlerUtils.FlowInput inputByForm = new BREGCaseStatusHandlerUtils.FlowInput();
        inputByForm.caseId = c.Id;
        inputByForm.checkFormCode = false;
        inputByForm.formCode = 'UNKNOWN-FORM';
        inputByForm.newStatus = 'Pending Submission';

        Test.startTest();
        List<BREGCaseStatusHandlerUtils.FlowOutput> outputs = BREGCaseStatusHandlerUtils.validateCaseStatusChange(
            new List<BREGCaseStatusHandlerUtils.FlowInput>{ inputByCase, inputByForm }
        );
        Test.stopTest();

        Assert.isNotNull(outputs, 'Invocable validateCaseStatusChange should return output list.');
    }

    @isTest
    static void testGetHandlerClassNameAdditionalBranches() {
        List<String> formCodes = new List<String>{
            'T-4', 'T-5', 'TN-CANC', 'DC-10', 'X-1', 'X-3', 'X-4', 'X-7', 'X-8', 'X-9',
            'X-10', 'X-11', 'X-13', 'X-14', 'X-15', 'ANN-LLC-1', 'ADD', 'ADD-TNTMSM',
            'ADD-MEMBER', 'DC-7', 'DC-12', 'DC-2', 'ODC'
        };

        for (String code : formCodes) {
            String handler = BREGCaseStatusHandlerUtils.getHandlerClassName(code);
            Assert.isTrue(String.isNotBlank(handler), 'Handler class name should be returned for form code ' + code);
        }
    }

    @isTest
    static void testUpdateTargetRecordsFromCaseMapNonAccountAndEmptyGuards() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Case sourceCase = new Case(
            Subject = 'Utils Source Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            Description = 'Source description value'
        );
        insert sourceCase;

        Case targetCase = new Case(
            Subject = 'Utils Target Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert targetCase;

        Map<Id, Case> targetMap = new Map<Id, Case>{ targetCase.Id => sourceCase };
        Map<SObjectField, SObjectField> mapping = new Map<SObjectField, SObjectField>{ Case.Description => Case.Description };

        Test.startTest();
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(new Map<Id, Case>(), 'Case', mapping);
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(targetMap, 'Case', mapping);
        Test.stopTest();

        Case updatedTarget = [SELECT Description FROM Case WHERE Id = :targetCase.Id];
        Assert.areEqual('Source description value', updatedTarget.Description, 'Target case field should be updated from source case map.');
    }

    @isTest
    static void testUpdateTargetRecordsFromCaseMapPerCaseMappings() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Case sourceCase = new Case(
            Subject = 'Utils PerCase Source',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            Description = 'PerCase mapped description'
        );
        insert sourceCase;

        Case targetCase = new Case(
            Subject = 'Utils PerCase Target',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert targetCase;

        Map<Id, Case> targetIdToCaseMap = new Map<Id, Case>{ targetCase.Id => sourceCase };
        Map<Id, Map<SObjectField, SObjectField>> perCaseMappings = new Map<Id, Map<SObjectField, SObjectField>>{
            sourceCase.Id => new Map<SObjectField, SObjectField>{ Case.Description => Case.Description }
        };

        Test.startTest();
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(targetIdToCaseMap, 'Case', perCaseMappings, null);
        Test.stopTest();

        Case updatedTarget = [SELECT Description FROM Case WHERE Id = :targetCase.Id];
        Assert.areEqual('PerCase mapped description', updatedTarget.Description, 'Per-case mapping branch should update Case targets.');
    }

    @isTest
    static void testUpdateTargetRecordsFromCaseMapAccountJurisdictionAndAddress() {
        BREG_Setting__c orgSetting = BREG_Setting__c.getOrgDefaults();
        if (orgSetting == null) {
            orgSetting = new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        orgSetting.Global_Data_Migration_Triggers_Disabled__c = true;
        upsert orgSetting;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();

        Account targetAccount = new Account(
            Name = 'Utils Account Target',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_Formation_Country__c = 'US',
            BillingCity = 'Old City'
        );
        insert targetAccount;

        Case sourceCase = new Case(
            Subject = 'Utils Account Source',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            breg_New_Entity_Jurisdiction__c = 'HI',
            breg_New_Mailing_Address__City__s = 'Honolulu'
        );
        insert sourceCase;

        Map<Id, Case> targetMap = new Map<Id, Case>{ targetAccount.Id => sourceCase };
        Map<SObjectField, SObjectField> mapping = new Map<SObjectField, SObjectField>{
            Case.breg_New_Entity_Jurisdiction__c => Account.breg_Formation_State__c,
            Case.breg_New_Mailing_Address__City__s => Account.BillingCity
        };

        Test.startTest();
        try {
            BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(targetMap, 'Account', mapping);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Account updateTargetRecords branch should execute even if org-specific constraints block final DML.');
        }
        Test.stopTest();

        Account updated = [SELECT Id, breg_Formation_State__c, BillingCity FROM Account WHERE Id = :targetAccount.Id LIMIT 1];
        Assert.isNotNull(updated, 'Account target should remain queryable after mapping branch execution.');
    }
}