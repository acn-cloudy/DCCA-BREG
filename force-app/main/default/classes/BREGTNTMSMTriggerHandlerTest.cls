@isTest
public with sharing class BREGTNTMSMTriggerHandlerTest {
    @isTest
    private static void testBeforeInsertPopulatesNSFields() {
        breg_TN_TM_SM__c record = new breg_TN_TM_SM__c(
            Name = 'Māhoe Trademark',
            breg_XREF_Name1__c = 'The Beaut\u00E9 Spot',
            breg_XREF_Name2__c = 'Save-A-Wish'
        );

        Test.startTest();
        insert record;
        Test.stopTest();

        breg_TN_TM_SM__c inserted = [
            SELECT breg_Search_Name__c, breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :record.Id
        ];
        Assert.areEqual('MAHOE TRADEMARK', inserted.breg_Search_Name__c, 'Search Name should be normalized with spaces.');
        Assert.areEqual('MAHOE TRADEMARK', inserted.breg_Search_Name_NS__c, 'Search Name NS should be normalized with spaces.');
        Assert.areEqual('BEAUTE SPOT', inserted.breg_Search_Xref_Name_1_NS__c, 'Xref 1 NS should be normalized with spaces.');
        Assert.areEqual('SAVE A WISH', inserted.breg_Search_Xref_Name_2_NS__c, 'Xref 2 NS should be normalized with spaces.');
    }

    @isTest
    private static void testBeforeUpdatePopulatesNSFieldsOnChange() {
        breg_TN_TM_SM__c record = new breg_TN_TM_SM__c(Name = 'Original Mark');
        insert record;

        Test.startTest();
        record.Name = 'Ā\'ala Services';
        record.breg_XREF_Name1__c = 'Acme & Co.';
        update record;
        Test.stopTest();

        breg_TN_TM_SM__c updated = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :record.Id
        ];
        Assert.areEqual('AALA SERVICES', updated.breg_Search_Name_NS__c, 'NS field should update when Name changes.');
        Assert.areEqual('ACME CO', updated.breg_Search_Xref_Name_1_NS__c, 'NS Xref 1 should update when source changes.');
    }

    @isTest
    private static void testBeforeInsertHandlesNullXrefFields() {
        breg_TN_TM_SM__c record = new breg_TN_TM_SM__c(Name = 'Simple Mark');

        Test.startTest();
        insert record;
        Test.stopTest();

        breg_TN_TM_SM__c inserted = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :record.Id
        ];
        Assert.areEqual('SIMPLE MARK', inserted.breg_Search_Name_NS__c, 'Search Name NS should be populated.');
        Assert.isNull(inserted.breg_Search_Xref_Name_1_NS__c, 'Null Xref 1 should yield null NS field.');
        Assert.isNull(inserted.breg_Search_Xref_Name_2_NS__c, 'Null Xref 2 should yield null NS field.');
    }

    @isTest
    private static void testUpdateRelatedAccountsAfterClosingMapsClosedStatuses() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'TNTMSM Account E', breg_Entity_Type__c = 'ZZ'),
            new Account(Name = 'TNTMSM Account C', breg_Entity_Type__c = 'ZZ'),
            new Account(Name = 'TNTMSM Account R', breg_Entity_Type__c = 'ZZ')
        };
        insert accounts;

        List<breg_TN_TM_SM__c> tntmsmRecords = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Name = 'Mark E', breg_Account__c = accounts[0].Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Name = 'Mark C', breg_Account__c = accounts[1].Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Name = 'Mark R', breg_Account__c = accounts[2].Id, breg_Status__c = 'A')
        };
        insert tntmsmRecords;

        Map<Id, breg_TN_TM_SM__c> oldMap = new Map<Id, breg_TN_TM_SM__c>([
            SELECT Id, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id IN :tntmsmRecords
        ]);

        List<breg_TN_TM_SM__c> newList = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Id = tntmsmRecords[0].Id, breg_Account__c = accounts[0].Id, breg_Status__c = 'E'),
            new breg_TN_TM_SM__c(Id = tntmsmRecords[1].Id, breg_Account__c = accounts[1].Id, breg_Status__c = 'C'),
            new breg_TN_TM_SM__c(Id = tntmsmRecords[2].Id, breg_Account__c = accounts[2].Id, breg_Status__c = 'R')
        };

        Test.startTest();
        BREGTNTMSMTriggerHandler.updateRelatedAccountsAfterClosing(newList, oldMap);
        Test.stopTest();

        Map<Id, Account> updatedAccounts = new Map<Id, Account>([
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id IN :accounts
        ]);

        Assert.areEqual('Expired (E)', updatedAccounts.get(accounts[0].Id).breg_Entity_Status__c, 'E status should map to Expired (E).');
        Assert.areEqual('Cancelled (C)', updatedAccounts.get(accounts[1].Id).breg_Entity_Status__c, 'C status should map to Cancelled (C).');
        Assert.areEqual('Inv. Revoked (R)', updatedAccounts.get(accounts[2].Id).breg_Entity_Status__c, 'R status should map to Inv. Revoked (R).');
    }

    @isTest
    private static void testUpdateRelatedAccountsAfterClosingSkipsNonClosedOrUnchangedStatuses() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'TNTMSM No Update 1', breg_Entity_Type__c = 'ZZ'),
            new Account(Name = 'TNTMSM No Update 2', breg_Entity_Type__c = 'ZZ')
        };
        insert accounts;

        List<breg_TN_TM_SM__c> tntmsmRecords = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Name = 'No Update Same Status', breg_Account__c = accounts[0].Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Name = 'No Update Non Closed', breg_Account__c = accounts[1].Id, breg_Status__c = 'A')
        };
        insert tntmsmRecords;

        Map<Id, breg_TN_TM_SM__c> oldMap = new Map<Id, breg_TN_TM_SM__c>([
            SELECT Id, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id IN :tntmsmRecords
        ]);

        List<breg_TN_TM_SM__c> newList = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Id = tntmsmRecords[0].Id, breg_Account__c = accounts[0].Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Id = tntmsmRecords[1].Id, breg_Account__c = accounts[1].Id, breg_Status__c = 'P')
        };

        Test.startTest();
        BREGTNTMSMTriggerHandler.updateRelatedAccountsAfterClosing(newList, oldMap);
        Test.stopTest();

        Map<Id, Account> updatedAccounts = new Map<Id, Account>([
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id IN :accounts
        ]);

        Assert.isNull(updatedAccounts.get(accounts[0].Id).breg_Entity_Status__c, 'Account should not update when status is unchanged.');
        Assert.isNull(updatedAccounts.get(accounts[1].Id).breg_Entity_Status__c, 'Account should not update when new status is not in closedStatuses.');
    }

    @isTest
    private static void testUpdateRelatedAccountsAfterClosingUpdatesOnlyZZAccounts() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'TNTMSM ZZ Account', breg_Entity_Type__c = 'ZZ'),
            new Account(Name = 'TNTMSM Non ZZ Account', breg_Entity_Type__c = 'D1')
        };
        insert accounts;

        List<breg_TN_TM_SM__c> tntmsmRecords = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Name = 'ZZ Mark', breg_Account__c = accounts[0].Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Name = 'Non ZZ Mark', breg_Account__c = accounts[1].Id, breg_Status__c = 'A')
        };
        insert tntmsmRecords;

        Map<Id, breg_TN_TM_SM__c> oldMap = new Map<Id, breg_TN_TM_SM__c>([
            SELECT Id, breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE Id IN :tntmsmRecords
        ]);

        List<breg_TN_TM_SM__c> newList = new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Id = tntmsmRecords[0].Id, breg_Account__c = accounts[0].Id, breg_Status__c = 'C'),
            new breg_TN_TM_SM__c(Id = tntmsmRecords[1].Id, breg_Account__c = accounts[1].Id, breg_Status__c = 'E')
        };

        Test.startTest();
        BREGTNTMSMTriggerHandler.updateRelatedAccountsAfterClosing(newList, oldMap);
        Test.stopTest();

        Map<Id, Account> updatedAccounts = new Map<Id, Account>([
            SELECT Id, breg_Entity_Status__c, breg_Entity_Type__c
            FROM Account
            WHERE Id IN :accounts
        ]);

        Assert.areEqual('Cancelled (C)', updatedAccounts.get(accounts[0].Id).breg_Entity_Status__c, 'ZZ account should be updated based on related TNTMSM status.');
        Assert.isNull(updatedAccounts.get(accounts[1].Id).breg_Entity_Status__c, 'Non-ZZ account should not be updated.');
    }
}