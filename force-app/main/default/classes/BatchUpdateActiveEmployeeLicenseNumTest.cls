@isTest
public with sharing class BatchUpdateActiveEmployeeLicenseNumTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }
    public static  testMethod void testBatch() {
        License__c entityLicense = [SELECT Id, Name from License__c WHERE Name = 'License A' Limit 1];
        List<Id> entityLicenseIds = new List<Id>();
        entityLicenseIds.add(entityLicense.Id);
        Database.executeBatch(new BatchUpdateActiveEmployeeLicenseNum(entityLicenseIds), 50);
    }

}