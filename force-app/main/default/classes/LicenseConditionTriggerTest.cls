@isTest
public with sharing class LicenseConditionTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense(); 
    }
    public static testMethod void testLicenseConditions() {
        License__c record = [Select Id from License__c where DependentLicense__c != null limit 1];
        LicenseConditions__c licenseCondition = new LicenseConditions__c();
        licenseCondition.License__c = record.Id;
        insert licenseCondition;
        licenseCondition.RMEandEntity__c = true;
        update licenseCondition;
        delete licenseCondition;

    }
    public static testMethod void testCreateRecord() {
        License__c record = [Select Id from License__c where DependentLicense__c != null limit 1];
        LicenseConditions__c licenseCondition = new LicenseConditions__c();
        licenseCondition.License__c = record.Id;
        licenseCondition.RMEandEntity__c = true;
        insert licenseCondition; 
        
    }
}