@isTest
public with sharing class LicenseRequirementTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
    }
    public static testMethod void testLicenseRequirementTrigger() {
        License__c record = [Select Id from License__c limit 1];
        LicenseRequirements__c licenseRequirement = new LicenseRequirements__c();
        licenseRequirement.License__c = record.Id;
        licenseRequirement.IsDeficient__c = true;
        insert licenseRequirement;
        LicenseRequirements__c licenseRequirement2 = new LicenseRequirements__c();
        licenseRequirement2.License__c = record.Id;
        licenseRequirement2.IsDeficient__c = true;
        insert licenseRequirement2;
        licenseRequirement2.ParentLicenseRequirement__c = licenseRequirement.Id;
        licenseRequirement2.IsDeficient__c = false;
        update licenseRequirement2;
        List<String> licenseIds= new List<String>();
        licenseIds.add(record.Id);
        System.assert(LicenseRequirementsSelector.getLicenseRequirements(licenseIds) != null);
    }
    
}