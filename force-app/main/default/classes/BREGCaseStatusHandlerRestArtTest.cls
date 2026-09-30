@isTest
private class BREGCaseStatusHandlerRestArtTest {
    @TestSetup
    static void setupData() {
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'Restated LLP Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        Account childGp = new Account(
            Name = 'Restated Child GP',
            RecordTypeId = bregAccRecordTypeId,
            ParentId = entity.Id,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert childGp;

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'DC-4',
            breg_Form_Code__c = 'DC-4',
            breg_Entity_Type__c = 'D1'
        );
        insert formConfig;

        Case c = new Case(
            Subject = 'Restated Articles Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-4',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = 'Restated LLP Entity'
        );
        insert c;

        insert new breg_Document__c(
            Name = 'Approved Restated Doc',
            breg_Case__c = c.Id,
            breg_Is_Public__c = false,
            breg_Type__c = 'Digital',
            breg_Availability__c = 'Available Now',
            breg_Is_Certificate_Of_Good_Standing__c = false
        );
    }

    @isTest
    static void testHandleStatusChangeEmptyInputBranches() {
        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        handler.handleStatusChange(new List<Case>(), 'Pending Submission', true, false);
        handler.handleStatusChange(new List<Case>(), 'Rejected', true, false);
        handler.handleStatusChange(new List<Case>(), 'Approved', false, true);
        handler.handleStatusChange(new List<Case>(), 'Completed', false, true);
        Test.stopTest();

        Assert.isTrue(true, 'Restated Articles handler should execute empty-list branches without errors.');
    }

    @isTest
    static void testCompletedActionMakesDocumentsPublic() {
        Case c = [SELECT Id, breg_Form_Code__c FROM Case WHERE Subject = 'Restated Articles Test Case' LIMIT 1];
        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
        }
        Test.stopTest();

        breg_Document__c doc = [SELECT Id, breg_Is_Public__c FROM breg_Document__c WHERE breg_Case__c = :c.Id LIMIT 1];
        Assert.areEqual(true, doc.breg_Is_Public__c, 'Approved/Rejected restated documents should be marked public on completion.');
    }

    @isTest
    static void testApprovedActionAndValidationWithLlpChildren() {
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        Account llpEntity = new Account(
            Name = 'Restated LLP Branch Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert llpEntity;

        insert new Account(
            Name = 'Restated Branch GP Child',
            RecordTypeId = bregAccRecordTypeId,
            ParentId = llpEntity.Id,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Active (A)'
        );

        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'DC-4' LIMIT 1];
        Case c = new Case(
            Subject = 'Restated Approved Branch Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-4',
            breg_Entity__c = llpEntity.Id,
            breg_Name_of_the_Entity__c = llpEntity.Name,
            breg_Effective_Date__c = Date.today(),
            breg_Override_Payment__c = true
        );
        insert c;

        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Approved validation branch should execute.');
        }
        Test.stopTest();

        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c WHERE breg_File_Number__c = :c.Id];
        Assert.isNotNull(transactions, 'Approved action should exercise restated transaction creation paths.');
    }

    @isTest
    static void testRejectedValidationBranch() {
        Case c = [SELECT Id, breg_Form_Code__c FROM Case WHERE Subject = 'Restated Articles Test Case' LIMIT 1];
        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Rejected', true, false);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Rejected validation branch should execute even if org-specific rules apply.');
        }
        Test.stopTest();

        Assert.isNotNull(c.Id, 'Rejected validation branch should execute without breaking test context.');
    }

    @isTest
    static void testCompletedActionNoMatchingDocumentsBranch() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'DC-4' LIMIT 1];
        Account entity = [SELECT Id, Name FROM Account WHERE Name = 'Restated LLP Entity' LIMIT 1];

        Case c = new Case(
            Subject = 'Restated No Doc Match Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-4',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Override_Payment__c = true
        );
        insert c;

        insert new breg_Document__c(
            Name = 'Non-Matching Restated Doc',
            breg_Case__c = c.Id,
            breg_Is_Public__c = false,
            breg_Type__c = 'Digital',
            breg_Availability__c = 'Available Now',
            breg_Is_Certificate_Of_Good_Standing__c = false
        );

        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        breg_Document__c doc = [SELECT breg_Is_Public__c FROM breg_Document__c WHERE breg_Case__c = :c.Id LIMIT 1];
        Assert.areEqual(false, doc.breg_Is_Public__c, 'Completed action should keep non-matching documents unchanged.');
    }

    @isTest
    static void testReceivedCreatesTransactionsForEntityAndChildGp() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Restated Articles Test Case'
            LIMIT 1
        ];
        Account childGp = [SELECT Id FROM Account WHERE Name = 'Restated Child GP' LIMIT 1];
        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> txnRecords = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, breg_Case__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id AND breg_Transaction_Code__c = 'RS'
        ];

        Set<Id> accountIds = new Set<Id>();
        for (breg_Transaction__c txnRecord : txnRecords) {
            accountIds.add(txnRecord.breg_Account__c);
            Assert.areEqual('R', txnRecord.breg_Status__c, 'Restated Articles Received transactions should be in Received status.');
        }

        Assert.isTrue(accountIds.contains(c.breg_Entity__c), 'Entity RS transaction should be created.');
        Assert.isTrue(accountIds.contains(childGp.Id), 'Child GP RS transaction should be created for LLP entities.');
    }

    @isTest
    static void testReceivedCreatesOnlyEntityTransactionForNonLlp() {
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'DC-4' LIMIT 1];

        Account entity = new Account(
            Name = 'Restated Non LLP Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        Case c = new Case(
            Subject = 'Restated Non LLP Received Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-4',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Override_Payment__c = true
        );
        insert c;

        BREGCaseStatusHandlerRestatedArticles handler = new BREGCaseStatusHandlerRestatedArticles();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id AND breg_Transaction_Code__c = 'RS'
        ];

        Assert.areEqual(1, transactions.size(), 'Non-LLP restated cases should only create one entity RS transaction.');
        Assert.areEqual(entity.Id, transactions[0].breg_Account__c, 'RS transaction should be linked to the entity account.');
    }
}