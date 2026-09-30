@isTest
public with sharing class BREGTxnBusInfoTriggerHandlerTest {
    @isTest
    private static void testBeforeInsertPopulatesNSFields() {
        breg_Transaction_Business_Info__c record = new breg_Transaction_Business_Info__c(
            breg_Master_Name__c = 'Māhoe Industries LLC',
            breg_Xref_Name_1__c = 'The Beaut\u00E9 Spot',
            breg_Xref_Name_2__c = 'Save-A-Wish'
        );

        Test.startTest();
        insert record;
        Test.stopTest();

        breg_Transaction_Business_Info__c inserted = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM breg_Transaction_Business_Info__c
            WHERE Id = :record.Id
        ];
        Assert.areEqual('MAHOE INDUSTRIES LLC', inserted.breg_Search_Name_NS__c, 'Search Name NS should be normalized with spaces.');
        Assert.areEqual('BEAUTE SPOT', inserted.breg_Search_Xref_Name_1_NS__c, 'Xref 1 NS should be normalized with spaces.');
        Assert.areEqual('SAVE A WISH', inserted.breg_Search_Xref_Name_2_NS__c, 'Xref 2 NS should be normalized with spaces.');
    }

    @isTest
    private static void testBeforeUpdatePopulatesNSFieldsOnChange() {
        breg_Transaction_Business_Info__c record = new breg_Transaction_Business_Info__c(breg_Master_Name__c = 'Original Business');
        insert record;

        Test.startTest();
        record.breg_Master_Name__c = 'Ā\'ala Services LLC';
        record.breg_Xref_Name_1__c = 'Acme & Co.';
        update record;
        Test.stopTest();

        breg_Transaction_Business_Info__c updated = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c
            FROM breg_Transaction_Business_Info__c
            WHERE Id = :record.Id
        ];
        Assert.areEqual('AALA SERVICES LLC', updated.breg_Search_Name_NS__c, 'NS field should update when Master Name changes.');
        Assert.areEqual('ACME CO', updated.breg_Search_Xref_Name_1_NS__c, 'NS Xref 1 should update when source changes.');
    }

    @isTest
    private static void testBeforeInsertHandlesNullFields() {
        breg_Transaction_Business_Info__c record = new breg_Transaction_Business_Info__c();

        Test.startTest();
        insert record;
        Test.stopTest();

        breg_Transaction_Business_Info__c inserted = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM breg_Transaction_Business_Info__c
            WHERE Id = :record.Id
        ];
        Assert.isNull(inserted.breg_Search_Name_NS__c, 'Null Master Name should yield null NS field.');
        Assert.isNull(inserted.breg_Search_Xref_Name_1_NS__c, 'Null Xref 1 should yield null NS field.');
        Assert.isNull(inserted.breg_Search_Xref_Name_2_NS__c, 'Null Xref 2 should yield null NS field.');
    }
}