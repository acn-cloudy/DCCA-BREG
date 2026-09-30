@isTest
public with sharing class BREGAccountTriggerHandlerTest {
    private static Id getBregAccountRecordTypeId() {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
    }

    private static Id getNonBregAccountRecordTypeId() {
        for (RecordType rt : [
            SELECT Id, DeveloperName, IsPersonType
            FROM RecordType
            WHERE SObjectType = 'Account' AND IsActive = TRUE
        ]) {
            if (rt.DeveloperName != 'BREG_Account' && (rt.IsPersonType == null || rt.IsPersonType == false)) {
                return rt.Id;
            }
        }
        System.assert(false, 'No non-BREG Account record type found for negative test coverage');
        return null;
    }

    @TestSetup
    private static void prepareData() {
        Id bregAccountRecordTypeId = getBregAccountRecordTypeId();
        List<Account> testAccounts = new List<Account>{
            new Account(
                Name = 'Test Business Entity 1',
                RecordTypeId = bregAccountRecordTypeId,
                breg_File__c = '12345',
                breg_File_Suffix__c = 'ABC',
                breg_Entity_Status__c = 'Active (A)'
            ),
            new Account(
                Name = 'Test Business Entity 2',
                RecordTypeId = bregAccountRecordTypeId,
                breg_File__c = '12346',
                breg_File_Suffix__c = 'DEF',
                breg_Entity_Status__c = 'Active (A)'
            )
        };
        insert testAccounts;
    }

    @isTest
    private static void testCreateTransactionsForRelatedAccountsRevoked() {
        Account testAccount = [SELECT Id, breg_File_Suffix__c FROM Account WHERE Name = 'Test Business Entity 1' LIMIT 1];
        testAccount.breg_Entity_Status__c = 'Inv. Revoked (R)';

        Test.startTest();
        BREGAccountTriggerHandler.createTransactionsForRelatedAccounts(new List<Account>{ testAccount });
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_File_Suffix__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :testAccount.Id
        ];
        Assert.areEqual(1, transactions.size(), 'One transaction should be created for revoked status');
        Assert.areEqual('INVR', transactions[0].breg_Transaction_Code__c, 'Revoked status should map to INVR');
        Assert.areEqual(testAccount.breg_File_Suffix__c, transactions[0].breg_File_Suffix__c, 'File suffix should be copied from account');
    }

    @isTest
    private static void testCreateTransactionsForRelatedAccountsTerminatedCode() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Business Entity 2' LIMIT 1];
        testAccount.breg_Entity_Status__c = 'Adm. Terminated (V)';

        Test.startTest();
        BREGAccountTriggerHandler.createTransactionsForRelatedAccounts(new List<Account>{ testAccount });
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :testAccount.Id
        ];
        Assert.areEqual(1, transactions.size(), 'One transaction should be created for terminated status');
        Assert.areEqual('INDBX', transactions[0].breg_Transaction_Code__c, 'Terminated status should map to INDBX');
    }

    @isTest
    private static void testSyncManagementTypeOnInsertFromBoolean() {
        Account accountToNormalize = new Account(breg_Is_Manager_Managed__c = true);

        BREGAccountTriggerHandler.syncManagementType(new List<SObject>{ accountToNormalize }, null);

        Assert.areEqual(true, accountToNormalize.breg_Is_Manager_Managed__c, 'Boolean value should remain true');
        Assert.areEqual('Manager Managed', accountToNormalize.breg_Management_Type__c, 'Management type should sync from boolean');
    }

    @isTest
    private static void testSyncManagementTypeOnInsertFromType() {
        Account accountToNormalize = new Account(breg_Management_Type__c = 'Member Managed');

        BREGAccountTriggerHandler.syncManagementType(new List<SObject>{ accountToNormalize }, null);

        Assert.areEqual(false, accountToNormalize.breg_Is_Manager_Managed__c, 'Boolean should sync from management type');
        Assert.areEqual('Member Managed', accountToNormalize.breg_Management_Type__c, 'Management type should remain member managed');
    }

    @isTest
    private static void testSyncManagementTypeOnUpdateFromBoolean() {
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Business Entity 1' LIMIT 1].Id;
        Account oldAccount = new Account(Id = accountId, breg_Is_Manager_Managed__c = false, breg_Management_Type__c = 'Member Managed');
        Account newAccount = new Account(Id = accountId, breg_Is_Manager_Managed__c = true, breg_Management_Type__c = 'Member Managed');
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ accountId => oldAccount };

        BREGAccountTriggerHandler.syncManagementType(new List<SObject>{ newAccount }, oldMap);

        Assert.areEqual(true, newAccount.breg_Is_Manager_Managed__c, 'Boolean should remain true after normalization');
        Assert.areEqual('Manager Managed', newAccount.breg_Management_Type__c, 'Management type should sync from boolean on update');
    }

    @isTest
    private static void testSyncManagementTypeOnUpdateFromType() {
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Business Entity 2' LIMIT 1].Id;
        Account oldAccount = new Account(Id = accountId, breg_Is_Manager_Managed__c = false, breg_Management_Type__c = 'Member Managed');
        Account newAccount = new Account(Id = accountId, breg_Is_Manager_Managed__c = false, breg_Management_Type__c = 'Manager Managed');
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ accountId => oldAccount };

        BREGAccountTriggerHandler.syncManagementType(new List<SObject>{ newAccount }, oldMap);

        Assert.areEqual(true, newAccount.breg_Is_Manager_Managed__c, 'Boolean should sync from management type on update');
        Assert.areEqual('Manager Managed', newAccount.breg_Management_Type__c, 'Management type should be manager managed');
    }

    @isTest
    private static void testSyncManagementTypeSkipsNonAccountRecords() {
        Contact contactToNormalize = new Contact(LastName = 'Ignore');

        BREGAccountTriggerHandler.syncManagementType(new List<SObject>{ contactToNormalize }, null);

        Assert.isTrue(true, 'Method should ignore non-Account records without throwing exceptions');
    }

    @isTest
    private static void testBeforeInsertSetsDependentStateLabelForUSCO() {
        Account accountToInsert = new Account(
            Name = 'Colorado Test Entity',
            RecordTypeId = getBregAccountRecordTypeId(),
            breg_Formation_Country__c = 'US',
            breg_Formation_State__c = 'CO'
        );

        Map<String, String> dependentStateMap = BREGUtils.getStateLabelMapByCountry(new List<SObject>{ accountToInsert }, 'breg_Formation_Country__c');
        Assert.isTrue(dependentStateMap.containsKey('US.CO'), 'Dependent picklist map should contain key for US.CO');
        String expectedStateLabel = 'Colorado';

        insert accountToInsert;

        Account insertedAccount = [
            SELECT breg_Formation_State__c, breg_Formation_State_Label__c
            FROM Account
            WHERE Id = :accountToInsert.Id
        ];

        Assert.areEqual('CO', insertedAccount.breg_Formation_State__c, 'State code should be stored as CO.');
        Assert.isNotNull(dependentStateMap.get('US.CO'), 'Expected dependent label for US.CO should exist (e.g. Colorado).');
        Assert.areEqual(expectedStateLabel, insertedAccount.breg_Formation_State_Label__c, 'Trigger should populate dependent state label for US.CO.');
    }

    @isTest
    private static void testBeforeInsertSkipsLogicForNonBregRecordType() {
        Account nonBreg = new Account(
            Name = 'Non BREG Account Insert',
            RecordTypeId = getNonBregAccountRecordTypeId(),
            breg_Formation_Country__c = 'US',
            breg_Formation_State__c = 'CO',
            breg_Xref_Name_1__c = 'Insert Xref 1',
            breg_Xref_Name_2__c = 'Insert Xref 2'
        );

        Test.startTest();
        insert nonBreg;
        Test.stopTest();

        Account inserted = [
            SELECT breg_Search_Name__c, breg_Formation_Country_Label__c, breg_Formation_State_Label__c
            FROM Account
            WHERE Id = :nonBreg.Id
        ];

        Assert.areEqual(null, inserted.breg_Search_Name__c, 'Search Name should not be populated for non-BREG account');
        Assert.areEqual(null, inserted.breg_Formation_Country_Label__c, 'Country label should not be populated for non-BREG account');
        Assert.areEqual(null, inserted.breg_Formation_State_Label__c, 'State label should not be populated for non-BREG account');
    }

    @isTest
    private static void testBeforeUpdateSkipsLogicForNonBregRecordType() {
        Account nonBreg = new Account(Name = 'Non BREG Account Update', RecordTypeId = getNonBregAccountRecordTypeId());
        insert nonBreg;

        nonBreg.Name = 'Updated Non BREG Account';
        nonBreg.breg_Xref_Name_1__c = 'Update Xref 1';
        nonBreg.breg_Formation_Country__c = 'US';
        nonBreg.breg_Formation_State__c = 'HI';

        Test.startTest();
        update nonBreg;
        Test.stopTest();

        Account updated = [
            SELECT breg_Search_Name__c, breg_Formation_Country_Label__c, breg_Formation_State_Label__c
            FROM Account
            WHERE Id = :nonBreg.Id
        ];

        Assert.areEqual(null, updated.breg_Search_Name__c, 'Search Name should remain unchanged for non-BREG account');
        Assert.areEqual(null, updated.breg_Formation_Country_Label__c, 'Country label should remain unchanged for non-BREG account');
        Assert.areEqual(null, updated.breg_Formation_State_Label__c, 'State label should remain unchanged for non-BREG account');
    }

    private static void testBeforeInsertPopulatesNSSearchFields() {
        Account acc = new Account(Name = 'Ā\'ala Farms LLC', breg_Xref_Name_1__c = 'The Beaut\u00E9 Spot', breg_Xref_Name_2__c = 'Save-A-Wish');
        List<RecordType> bregAccountRecordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'BREG_Account' LIMIT 1];
        if (!bregAccountRecordTypes.isEmpty()) {
            acc.RecordTypeId = bregAccountRecordTypes[0].Id;
        }

        Test.startTest();
        insert acc;
        Test.stopTest();

        Account inserted = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        Assert.areEqual('AALA FARMS LLC', inserted.breg_Search_Name_NS__c, 'Search Name NS should be normalized with spaces.');
        Assert.areEqual('BEAUTE SPOT', inserted.breg_Search_Xref_Name_1_NS__c, 'Search Xref Name 1 NS should normalize.');
        Assert.areEqual('SAVE A WISH', inserted.breg_Search_Xref_Name_2_NS__c, 'Search Xref Name 2 NS should normalize.');
    }

    @isTest
    private static void testBeforeUpdatePopulatesNSSearchFieldsOnChange() {
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Business Entity 1' LIMIT 1];

        Test.startTest();
        acc.Name = 'Māhoe Industries LLC';
        acc.breg_Xref_Name_1__c = 'Acme & Co.';
        update acc;
        Test.stopTest();

        Account updated = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        Assert.areEqual('MAHOE INDUSTRIES LLC', updated.breg_Search_Name_NS__c, 'NS field should update when Name changes.');
        Assert.areEqual('ACME CO', updated.breg_Search_Xref_Name_1_NS__c, 'NS Xref 1 should update when source changes.');
    }
}