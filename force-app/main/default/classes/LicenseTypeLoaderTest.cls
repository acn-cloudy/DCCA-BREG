@isTest
public with sharing class LicenseTypeLoaderTest {
    @TestSetup
    static void makeData(){
        LicenseType__c record = TestDataFactory.createLicenseTypes('Test Name');
        record.ApplicationRecordType__c = 'Test Type';

    }
    public static testMethod  void testLoadData () {
        System.assert(LicenseTypeLoader.getLicenseTypes( new List<String>{'Test Type'}) != null);

    }
}