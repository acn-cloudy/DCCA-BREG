/*
 * ___________________________________________________________________________________
 * Test class for REST API for license Search
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL11012020 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.zhuang@pacificpointcorp.com
 * 
 * @created 11/01/2020
 * __________________________________________________________________________________
 */
@isTest
public class LicenseSearchRESTTest {
    /* Creating Test data class */
    @TestSetup
    static void createTestData() {
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        
        Account acc = new Account(Name = 'Test Account', External_Id__c = '4556');
        insert acc;
        
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;

        //License Type
		LicenseType__c licenseType = new LicenseType__c();
		licenseType.Name = 'RDS';
        licenseType.Status__c = 'Active';
        licenseType.Branch__c = true;
        insert licenseType;
      
        // dependent Licenses
        License__c dependentLicense = new License__c();
		dependentLicense.Name = 'License X';
		dependentLicense.ActiveInactive__c = 'Active';
        dependentLicense.LicenseType__c = licenseType.Id;
		dependentLicense.RecordTypeId = CTEntityRecordTypeId;
        insert dependentLicense;

		// Licenses
		List<License__c> licenseListToCreate = new List<License__c>();
		License__c licenseMainA = new License__c();
		licenseMainA.Name = 'License A';
		licenseMainA.ActiveInactive__c = 'Active';
        licenseMainA.DependentLicense__c = dependentLicense.Id;

        License__c licenseMainB = new License__c();
        licenseMainB.Name = 'License B';
        licenseMainB.Licensee__c = acc.Id;
		licenseMainB.ActiveInactive__c = 'Active';
        licenseMainB.DependentLicense__c = dependentLicense.Id;

        License__c licenseMainC = new License__c();
        licenseMainC.Name = 'License C';
        licenseMainC.LicenseName__c = 'License C';
		licenseMainC.ActiveInactive__c = 'Active';
        licenseMainC.DependentLicense__c = dependentLicense.Id;

        licenseListToCreate.add(licenseMainA);
        licenseListToCreate.add(licenseMainB);
        licenseListToCreate.add(licenseMainC);
        insert licenseListToCreate;

        AssociatedLicense__c al1 = new AssociatedLicense__c();
        al1.EmployeeLicense__c = licenseListToCreate[0].Id;
        al1.EntityLicense__c = licenseListToCreate[0].Id;
        insert al1;

        Classification__c cls = new Classification__c();
        cls.LicenseType__c = licenseType.id;
        insert cls;

        LicenseClassification__c lc1 = new LicenseClassification__c();
        lc1.License__c = licenseListToCreate[0].Id;
        lc1.Classification__c = cls.id;
        insert lc1;

        LicenseName__c ln1 = new LicenseName__c();
        ln1.License__c = licenseListToCreate[0].Id;
        insert ln1;

        InsuranceBond__c ib1 = new InsuranceBond__c();
        ib1.License__c = licenseListToCreate[0].Id;
        ib1.Status__c = 'Active';
        insert ib1;

        LicenseHistory__c ih1 = new LicenseHistory__c();
        ih1.License__c = licenseListToCreate[0].Id;
        ih1.TransactionType__c = 'LP - LICENSE REPEALED';
        insert ih1;
    }
  
    @isTest
    private static void test_LicenseSearchRESTSearch1() {
        LicenseSearchREST.JSONRequest testRequest = new LicenseSearchREST.JSONRequest();
        testRequest.SearchCriteria = 'License A';
        testRequest.SearchType = 1; 
        String appJson = JSON.serialize(testRequest);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/licenseSearch'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        LicenseSearchREST.doLicenseSearch();
        Test.stopTest();
    }

    @isTest
    private static void test_LicenseSearchRESTSearch2() {
        LicenseSearchREST.JSONRequest testRequest = new LicenseSearchREST.JSONRequest();
        testRequest.SearchCriteria = 'Test Account';
        testRequest.SearchType = 2; 
        String appJson = JSON.serialize(testRequest);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/licenseSearch'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        LicenseSearchREST.doLicenseSearch();
        Test.stopTest();
    }

    @isTest
    private static void test_LicenseSearchRESTSearch3() {
        LicenseSearchREST.JSONRequest testRequest = new LicenseSearchREST.JSONRequest();
        testRequest.SearchCriteria = 'License C';
        testRequest.SearchType = 3; 
        String appJson = JSON.serialize(testRequest);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/licenseSearch'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        LicenseSearchREST.doLicenseSearch();
        Test.stopTest();
    }
}