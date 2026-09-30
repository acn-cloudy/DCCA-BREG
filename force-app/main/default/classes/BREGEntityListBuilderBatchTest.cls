@isTest
public with sharing class BREGEntityListBuilderBatchTest {

    @TestSetup
    static void testSetup() {

        BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createFeeSettings();
        BREGTestDataFactory.createEntityAccounts(5); // Create 5 test accounts
        //create an entity list
        BREGEntityListBuilderController.SearchInput input = new BREGEntityListBuilderController.SearchInput();
        input.recordTypes = new List<String>{'D1', 'Q5'};
        input.name = 'Acme';
        input.zipCodes = '12345';
        input.startDate = '2020-01-01';
        input.endDate = '2025-12-31';
        Id entityListId = BREGEntityListBuilderController.upsertList(input);

        BREGTestDataFactory.createTransactionLineForEntityList(entityListId);
    }

    @isTest
    static void testSearch() {
        Id entityListId = [SELECT Id FROM breg_Entity_List__c LIMIT 1].Id;
        Test.startTest();
        Database.executeBatch(new BREGEntityListBuilderBatch(new List<Id>{entityListId}), 200);
        Test.stopTest();
        Assert.isTrue([SELECT Id FROM breg_Entity_List_Result__c WHERE breg_Entity_List__c = :entityListId].size() == 1, 'Entity List Result should be created');
        Assert.isTrue([SELECT Id FROM breg_Document__c ].size() == 1, 'Document should be created');
    }

    @isTest
    static void testCsvEscapingFormatter() {
        Assert.areEqual('""', BREGEntityListBuilderBatch.formatCsvValueForTest(null), 'Null should be formatted as empty quoted value');
        Assert.areEqual('"Acme, Inc"', BREGEntityListBuilderBatch.formatCsvValueForTest('Acme, Inc'), 'Comma should be preserved inside quotes');
        Assert.areEqual('"He said ""Hello"""', BREGEntityListBuilderBatch.formatCsvValueForTest('He said "Hello"'), 'Inner quotes should be doubled');
        Assert.areEqual('"Line1 Line2 Line3"', BREGEntityListBuilderBatch.formatCsvValueForTest('Line1\r\nLine2\nLine3'), 'Line breaks should be normalized to spaces');
    }
}