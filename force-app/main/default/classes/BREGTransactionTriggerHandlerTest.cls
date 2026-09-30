@isTest
public with sharing class BREGTransactionTriggerHandlerTest {
    @isTest
    static void beforeInsert_businessNameSet_searchNamePopulated() {
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = 'The Acme & Sons, LLC');

        Test.startTest();
        insert txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.areEqual('ACME SONS LLC', result.breg_Search_Name__c, 'Search name should be cleaned on insert');
    }

    @isTest
    static void beforeInsert_blankBusinessName_searchNameBlank() {
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = null);

        Test.startTest();
        insert txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.isNull(result.breg_Search_Name__c, 'Search name should be null when business name is null');
    }

    @isTest
    static void beforeInsert_longBusinessName_searchNameTruncatedTo255() {
        String longName = 'A'.repeat(300);
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = longName);

        Test.startTest();
        insert txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.isTrue(result.breg_Search_Name__c.length() <= 255, 'Search name should be truncated to 255 characters');
    }

    @isTest
    static void beforeUpdate_businessNameChanged_searchNameUpdated() {
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = 'Original Name LLC');
        insert txn;

        txn.breg_Business_Name__c = 'Updated Name Inc.';

        Test.startTest();
        update txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.areEqual('UPDATED NAME INC', result.breg_Search_Name__c, 'Search name should update when business name changes');
    }

    @isTest
    static void beforeUpdate_businessNameUnchanged_searchNameNotModified() {
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = 'Stable Name LLC');
        insert txn;

        breg_Transaction__c inserted = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        String originalSearchName = inserted.breg_Search_Name__c;

        txn.breg_Description__c = 'Updated description only';

        Test.startTest();
        update txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.areEqual(originalSearchName, result.breg_Search_Name__c, 'Search name should not change when business name is unchanged');
    }

    @isTest
    static void beforeUpdate_longBusinessNameChanged_searchNameTruncated() {
        breg_Transaction__c txn = new breg_Transaction__c(breg_Business_Name__c = 'Short Name');
        insert txn;

        txn.breg_Business_Name__c = 'B'.repeat(300);

        Test.startTest();
        update txn;
        Test.stopTest();

        breg_Transaction__c result = [SELECT breg_Search_Name__c FROM breg_Transaction__c WHERE Id = :txn.Id];
        Assert.isTrue(result.breg_Search_Name__c.length() <= 255, 'Search name should be truncated to 255 on update');
    }
}