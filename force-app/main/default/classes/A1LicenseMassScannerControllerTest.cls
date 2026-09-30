@isTest
public with sharing class A1LicenseMassScannerControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
    }
    public static testMethod void testScanResult() {
        List<License__c> licenseData = [Select Id, Name from License__c ];
        List<String> licenseNumbers = (List<String>)(new LicenseDomain(licenseData)).getFieldValues('Name');
        A1LicenseMassScannerController.ScanResult result = A1LicenseMassScannerController.scan(licenseNumbers, Date.today());

    }
    public static testMethod void testOtherMethods() {
        A1LicenseMassScannerController.getActiveInactivePickListEntries();
        A1LicenseMassScannerController.getStatusPickListEntries();
        A1LicenseMassScannerController.ScanResult scanResult = new A1LicenseMassScannerController.ScanResult();
        List<License__c> licenseData = [Select Id, Name from License__c ];
        A1LicenseMassScannerController.printResult(JSON.serialize(scanResult));
    }
    public static testMethod void testCommitScanResult() {
        A1LicenseMassScannerController.ScanResult scanResult = new A1LicenseMassScannerController.ScanResult();
        List<License__c> licenseData = [Select Id, Name from License__c ];
        scanResult.licensesToUpdate = licenseData;
        A1LicenseMassScannerController.commitScanResult(JSON.serialize(scanResult));
    }
}