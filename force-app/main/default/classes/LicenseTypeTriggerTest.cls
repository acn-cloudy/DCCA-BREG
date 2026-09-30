@isTest
public with sharing class LicenseTypeTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        List<License__c> licenses =  [Select Id, FlaggedforAudit__c from License__c] ;
        for(License__c license: licenses) {
            license.FlaggedforAudit__c = true;
        }
        update licenses;

        List<LicenseType__c> licenseTypes = [Select Id, ResetAudit__c from LicenseType__c];

        for(LicenseType__c licneseType: licenseTypes) {
            licneseType.ResetAudit__c = false;
        }

        update licenseTypes;
    }

    @isTest
    static void testResetLicenseAuditFlag() {
        test.startTest();
        List<LicenseType__c> licenseTypes = [Select Id, ResetAudit__c from LicenseType__c Where ResetAudit__c = false];
        for (LicenseType__c record : licenseTypes) {
            record.ResetAudit__c = true;
        }
        update licenseTypes;
        test.stopTest();
    }

}