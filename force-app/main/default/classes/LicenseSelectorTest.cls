@isTest
private class LicenseSelectorTest {
    @isTest
    static void test_getLicenses() {
        Test.startTest();
        LicenseSelector.getLicenses(new List<String>{'TEST'});
        Test.stopTest();
    }

    @isTest
    static void test_getLicensesByLicenseTypeId() {
        Test.startTest();
        LicenseSelector.getLicensesByLicenseTypeId('Test', 'Test');
        Test.stopTest();
    }

    @isTest
    static void test_getRequirementsByLicenseIds() {
        Test.startTest();
        LicenseSelector.getRequirementsByLicenseIds(new List<String>{'TEST'});
        Test.stopTest();
    }

    @isTest
    static void test_getLicenseByLicenseTypeStatusAndLicensee() {
        Test.startTest();
        LicenseSelector.getLicenseByLicenseTypeStatusAndLicensee('TEST', new List<String>{'TEST'}, 'TEST');
        Test.stopTest();
    }

    @isTest
    static void test_getLicensesByLicenseTypeAndLicenseeAndStatus() {
        Test.startTest();
        LicenseSelector.getLicensesByLicenseTypeAndLicenseeAndStatus('TEST', 'TEST', new List<String>{'TEST'});
        Test.stopTest();
    }

    @isTest
    static void test_getLicenseQueryLocator() {
        Test.startTest();
        LicenseSelector.getLicenseQueryLocator('License__c', 'Name', 'Name != null');
        Test.stopTest();
    }

    @isTest
    static void test_getLicensesAddressChangeDetails() {
        Test.startTest();
        LicenseSelector.getLicensesAddressChangeDetails(new Set<String>{'TEST'});
        Test.stopTest();
    }
}