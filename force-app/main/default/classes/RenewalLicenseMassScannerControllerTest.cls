@isTest
public with sharing class RenewalLicenseMassScannerControllerTest {
    @TestSetup
    static void makeData(){
        LicenseMassScannerControllerTest.setup();
    }
    public static testMethod void testGetStatusPickListEntries() {
        RenewalLicenseMassScannerController.getStatusPickListEntries();
        RenewalLicenseMassScannerController.getActiveInactivePickListEntries();
    }
    public static testMethod void testPrintResult() {
        LicenseMassScannerController.ScanResult scanResult = LicenseMassScannerController.scanCreate(new List<String>{'acc',
                                                                                                                'vcc'},
                Date.today(), 'Inactive', 'Yes', 'Partner', false);
        RenewalLicenseMassScannerController.printResult(JSON.serialize(scanResult));
    }
    public static testMethod void testScanResult() {
        List<License__c> licenseData = [Select Id, Name from License__c ];
        List<String> licenseNumbers = (List<String>)(new LicenseDomain(licenseData)).getFieldValues('Name');
        RenewalLicenseMassScannerController.scan(licenseNumbers, 'Active', 'HC - Application Completed');

    }
}