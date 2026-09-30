@isTest
public with sharing class MassScanningLicenceControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createDummyApplication();
    }
    
    public static testMethod void testRetrieveLicenseA1() {
        Test.startTest();
        List<License__c> records = [Select Id, Name from License__c ];
        List<String> licenseNumbers = (List<String> ) (new LicenseDomain(records)).getFieldValues('Name');
        String licenseNumberStr = String.join(licenseNumbers, ',');
        MassScanningLicenceController.retrieveLicense(licenseNumberStr,MassScanningLicenceController.A1, MassScanningLicenceController.ACTIVE);
    }

    public static testMethod void testRetrieveLicenseHC() {
        Test.startTest();
        List<License__c> records = [Select Id, Name from License__c ];
        List<String> licenseNumbers = (List<String> ) (new LicenseDomain(records)).getFieldValues('Name');
        String licenseNumberStr = String.join(licenseNumbers, ',');
        MassScanningLicenceController.retrieveLicense(licenseNumberStr,MassScanningLicenceController.HC, MassScanningLicenceController.ACTIVE);
    }
    public static testMethod void testRetrieveLicenseA3() {
        Test.startTest();
        List<License__c> records = [Select Id, Name from License__c ];
        List<String> licenseNumbers = (List<String> ) (new LicenseDomain(records)).getFieldValues('Name');
        String licenseNumberStr = String.join(licenseNumbers, ',');
        MassScanningLicenceController.retrieveLicense(licenseNumberStr,MassScanningLicenceController.A3, MassScanningLicenceController.ACTIVE);
        MassScanningLicenceController.getPickListValues();
    }
    public static testMethod void testSaveRenewalResult() {
        Test.startTest();
        List<License__c> records = [Select Id, Name from License__c ];
        List<Application__c> applications = [Select Id, Name from Application__c ];
        List<RenewalScanningResults__c> successRenewalScannedRes = new List<RenewalScanningResults__c> ();
        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = records.get(0).Name, License__c = records.get(0).Id, Status__c = 'Success', Comments__c = 'Application was created');
        successRenewalScannedRes.add(renewal);   
        
        MassScanningLicenceController.saveRenewalScannedResult(successRenewalScannedRes, new List<RenewalScanningResults__c>(), applications, records );
        MassScanningLicenceController.saveRenewalScannedResult(successRenewalScannedRes, new List<RenewalScanningResults__c>(), null, null );
        
    }
}