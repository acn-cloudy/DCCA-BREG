@isTest
private class BREGAgentSearchBatchTest {

    private static Id getPrimaryAgentSearchListId() {
        return [
            SELECT Id
            FROM breg_Agent_Search_List__c
            WHERE breg_Search_Value__c = 'Test' AND breg_Search_Type__c = 'active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ].Id;
    }

    @TestSetup
    static void testSetup() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account agentAccount = new Account(
            Name = 'Test Agent',
            RecordTypeId = bregAccRecordType,
            breg_Entity_Status__c = 'Active (A)'
        );
        insert agentAccount;

        Account entityAccount = new Account(
            Name = 'Test Entity Corp',
            RecordTypeId = bregAccRecordType,
            breg_File__c = 'F12345',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entityAccount;

        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entityAccount.Id,
            breg_Role__c = 'Agent',
            breg_Start_Date__c = Date.today().addYears(-1),
            breg_Status__c = 'A',
            breg_First_Name__c = 'Test',
            breg_Last_Name__c = 'Agent'

        );
        insert affiliation;

        breg_Agent_Search_List__c agentSearchList = new breg_Agent_Search_List__c(
            breg_Search_Value__c = 'Test',
            breg_Search_Type__c = 'active',
            breg_Total_Agent_Records__c = 1,
            breg_Total_Business_Records__c = 1,
            breg_Total_Price__c = 2.05,
            breg_Agent_Account_Ids__c = agentAccount.Id
        );
        insert agentSearchList;

        BREGTestDataFactory.createTransactionLineForAgentSearch(agentSearchList.Id);
    }

    @isTest
    static void testBatchExecution() {
        Id agentSearchListId = getPrimaryAgentSearchListId();

        Test.startTest();
        Database.executeBatch(new BREGAgentSearchBatch(new List<Id>{ agentSearchListId }), 200);
        Test.stopTest();

        List<breg_Agent_Search_Result__c> results = [
            SELECT Id FROM breg_Agent_Search_Result__c WHERE breg_Agent_Search_List__c = :agentSearchListId
        ];
        Assert.areEqual(1, results.size(), 'Agent Search Result should be created');

        List<breg_Document__c> documents = [SELECT Id FROM breg_Document__c];
        Assert.areEqual(1, documents.size(), 'Document should be created');

        TransactionLine__c transLine = [
            SELECT breg_Document__c FROM TransactionLine__c WHERE breg_Agent_Search_List__c = :agentSearchListId LIMIT 1
        ];
        Assert.isNotNull(transLine.breg_Document__c, 'TransactionLine should be linked to a Document');
    }

    @isTest
    static void testRunBatchInvocable() {
        Id agentSearchListId = getPrimaryAgentSearchListId();

        Test.startTest();
        BREGAgentSearchBatch.runBatch(new List<Id>{ agentSearchListId });
        Test.stopTest();

        List<breg_Agent_Search_Result__c> results = [
            SELECT Id FROM breg_Agent_Search_Result__c WHERE breg_Agent_Search_List__c = :agentSearchListId
        ];
        Assert.areEqual(1, results.size(), 'Agent Search Result should be created via invocable');
    }

    @isTest
    static void testBatchWithNoAffiliations() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account noAffAgent = new Account(
            Name = 'No Affiliation Agent',
            RecordTypeId = bregAccRecordType,
            breg_Entity_Status__c = 'Active (A)'
        );
        insert noAffAgent;

        breg_Agent_Search_List__c emptySearchList = new breg_Agent_Search_List__c(
            breg_Search_Value__c = 'None',
            breg_Search_Type__c = 'all',
            breg_Total_Agent_Records__c = 0,
            breg_Total_Business_Records__c = 0,
            breg_Total_Price__c = 0,
            breg_Agent_Account_Ids__c = noAffAgent.Id
        );
        insert emptySearchList;
        BREGTestDataFactory.createTransactionLineForAgentSearch(emptySearchList.Id);

        Test.startTest();
        Database.executeBatch(new BREGAgentSearchBatch(new List<Id>{ emptySearchList.Id }), 200);
        Test.stopTest();

        List<breg_Agent_Search_Result__c> results = [
            SELECT Id
            FROM breg_Agent_Search_Result__c
            WHERE breg_Agent_Search_List__c = :emptySearchList.Id
        ];
        Assert.areEqual(1, results.size(), 'Agent Search Result should be created even with zero records');
    }
}