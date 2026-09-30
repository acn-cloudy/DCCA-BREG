@isTest
private class LicenseTypeSelectorTest {

    @isTest
    static void test_getLicenseTypes() {        
        Test.startTest();
        LicenseTypeSelector.getLicenseTypes(new List<String>{'TEST'});
        Test.stopTest();
    }

    @isTest
    static void test_getLicenseTypes2() {        
        Test.startTest();
        LicenseTypeSelector.getLicenseTypes(new List<String>{'TEST'}, 'Person');
        Test.stopTest();
    }

    @isTest
    static void test_getLicenseTypesByIds() {        
        Test.startTest();
        LicenseTypeSelector.getLicenseTypesByIds(new List<String>{'TEST'});
        Test.stopTest();
    }

    @isTest
    static void test_getLicenseTypePeriods() {        
        Test.startTest();
        LicenseTypeSelector.getLicenseTypePeriods(new Set<String>{'TEST'});
        Test.stopTest();
    }
}