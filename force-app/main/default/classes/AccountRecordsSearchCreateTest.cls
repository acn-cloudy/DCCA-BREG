@isTest
public with sharing class AccountRecordsSearchCreateTest {
    public static testMethod void testSearchAccountByBPID() {
        Account businessAcc = TestDataFactory.createBusinessAccount();
        insert businessAcc;
        AccountRecordsSearchCreate.searchAccountByBPID(null, 'Business Account', businessAcc.Name, businessAcc.FEIN__c);

    }
    public static testMethod void testLoadAccount() {
        Account businessAcc = TestDataFactory.createBusinessAccount();
        insert businessAcc;
        AccountRecordsSearchCreate.loadAccount(businessAcc.Id, 'PVL Business Account Layout');
    }
    public static testMethod void testGetFieldSet() {
        AccountRecordsSearchCreate.getFieldSet('WizardMatchingRecords', 'License__c');
    }
    public static testMethod void testCreateAccount() {
        Account businessAcc = TestDataFactory.createBusinessAccount();
        AccountRecordsSearchCreate.createAccount(JSON.serialize(businessAcc), 'BusinessAccount');
    }
}