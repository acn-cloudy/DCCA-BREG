/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class CollectionAgencyRenewalTest {
    @TestSetup
    static void makeData(){
        Id COLARecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - COLA').getRecordTypeId();
        Id COLAXRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - COLAX').getRecordTypeId();

		//License Type
		LicenseType__c licenseType1 = new LicenseType__c();
		licenseType1.Name = 'COLA';
		licenseType1.Status__c = 'Active';
        licenseType1.LicenseTypeEffectiveDate__c = Date.today();

		LicenseType__c licenseType2 = new LicenseType__c();
		licenseType2.Name = 'COLAX';
		licenseType2.Status__c = 'Active';        
        licenseType2.LicenseTypeEffectiveDate__c = Date.today();

		LicenseType__c licenseType3 = new LicenseType__c();
		licenseType3.Name = 'COLXB';
		licenseType3.Status__c = 'Active';        
        licenseType3.LicenseTypeEffectiveDate__c = Date.today();

		LicenseType__c licenseType4 = new LicenseType__c();
		licenseType4.Name = 'COLB';
		licenseType4.Status__c = 'Active';        
        licenseType4.LicenseTypeEffectiveDate__c = Date.today();
		insert new List<LicenseType__c>{licenseType1, licenseType2, licenseType3, licenseType4};

		//Licenses
		List<License__c> licenseListToCreate = new List<License__c>();

		//Group for Active A
		License__c licenseMainA = new License__c();
		licenseMainA.Name = 'License A';
		licenseMainA.ActiveInactive__c = 'Active';
		licenseMainA.LicenseType__c = licenseType3.Id;
		licenseMainA.Status__c = 'C - Current, Valid & In Good Standing';
		licenseMainA.RecordTypeId = COLARecordTypeId;
		licenseListToCreate.add(licenseMainA);

		License__c licenseMainB = new License__c();
		licenseMainB.Name = 'License B';
		licenseMainB.ActiveInactive__c = 'Active';
		licenseMainB.LicenseType__c = licenseType4.Id;
		licenseMainB.Status__c = 'C - Current, Valid & In Good Standing';
		licenseMainB.RecordTypeId = COLAXRecordTypeId;
		licenseListToCreate.add(licenseMainB);

		License__c licenseEmployeeMainA = new License__c();
		licenseEmployeeMainA.Name = 'Employee License C';
		licenseEmployeeMainA.LicenseType__c = licenseType1.Id;
		licenseEmployeeMainA.Status__c = 'C - Current, Valid & In Good Standing';
		licenseEmployeeMainA.RecordTypeId = COLARecordTypeId;
		licenseListToCreate.add(licenseEmployeeMainA);

		License__c licenseEmployeeMainB = new License__c();
		licenseEmployeeMainB.Name = 'Employee License D';
		licenseEmployeeMainB.LicenseType__c = licenseType2.Id;
		licenseEmployeeMainB.Status__c = 'C - Current, Valid & In Good Standing';
		licenseEmployeeMainB.RecordTypeId = COLAXRecordTypeId;
		licenseListToCreate.add(licenseEmployeeMainB);
		insert licenseListToCreate;

		//Associated Licenses
		List<AssociatedLicense__c> associatedLicenseList = new List<AssociatedLicense__c>();

		//Group for Active A
		AssociatedLicense__c associatedLicenseA = new AssociatedLicense__c();
		associatedLicenseA.EntityLicense__c = licenseMainA.Id;
		associatedLicenseA.EmployeeLicense__c = licenseEmployeeMainB.Id;
        associatedLicenseA.EmploymentStatus__c = 'Employed';
		associatedLicenseList.add(associatedLicenseA);

		AssociatedLicense__c associatedLicenseB = new AssociatedLicense__c();
		associatedLicenseB.EntityLicense__c = licenseMainB.Id;
		associatedLicenseB.EmployeeLicense__c = licenseEmployeeMainA.Id;
        associatedLicenseB.EmploymentStatus__c = 'Employed';
		associatedLicenseList.add(associatedLicenseB);
		insert associatedLicenseList;

        //Accounts
        List<Account> accounts = new List<Account>();
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account acc = new Account();
        acc.Name = 'TEST123';
        acc.FEIN__c = '123';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();  
        insert acc;

        List<Application__c> applications = new List<Application__c>();
        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.CurrentLicense__c = licenseEmployeeMainA.Id;
        applicationRecord.LicenseType__c = licenseType1.Id;
        applicationRecord.Type__c = 'RNEW - Renewal';
        applicationRecord.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(applicationRecord);

        Application__c applicationRecord2 = new Application__c();
        applicationRecord2.Applicant__c = acc.Id;
        applicationRecord2.CurrentLicense__c = licenseEmployeeMainB.Id;
        applicationRecord2.LicenseType__c = licenseType2.Id;
        applicationRecord2.Type__c = 'RNEW - Renewal';
        applicationRecord2.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(applicationRecord2);

        Application__c applicationRecord4 = new Application__c();
        applicationRecord4.Applicant__c = acc.Id;
        applicationRecord4.CurrentLicense__c = licenseMainA.Id;
        applicationRecord4.LicenseType__c = licenseType3.Id;
        applicationRecord4.Type__c = 'RNEW - Renewal';
        applicationRecord4.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(applicationRecord4);

        Application__c applicationRecord5 = new Application__c();
        applicationRecord5.Applicant__c = acc.Id;
        applicationRecord5.CurrentLicense__c = licenseMainB.Id;
        applicationRecord5.LicenseType__c = licenseType4.Id;
        applicationRecord5.Type__c = 'RNEW - Renewal';
        applicationRecord5.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(applicationRecord5);
        
        insert applications;
    }

    @isTest
    static void test_doCOLBRenewals() {
        Test.startTest();
        // query license
        License__c license = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'COLB' LIMIT 1];
        Application__c application = [Select Id, Name from Application__c WHERE CurrentLicense__c =: license.Id LIMIT 1];

        CollectionAgencyRenewal.Input input = new CollectionAgencyRenewal.Input();
        input.inputLicense = license;
        input.inputApplication = application;
        CollectionAgencyRenewal.execute(new List<CollectionAgencyRenewal.Input>{input});
        Test.stopTest();
    }

    @isTest
    static void test_doCOLXBRenewals(){
        Test.startTest();
        // query license
        License__c license = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'COLXB' LIMIT 1];
        Application__c application = [Select Id, Name from Application__c WHERE CurrentLicense__c =: license.Id LIMIT 1];

        CollectionAgencyRenewal.Input input = new CollectionAgencyRenewal.Input();
        input.inputLicense = license;
        input.inputApplication = application;
        CollectionAgencyRenewal.execute(new List<CollectionAgencyRenewal.Input>{input});
        Test.stopTest();
    }

    @isTest
    static void test_doCOLARenewals() {
        Test.startTest();
        // query 
        List<String> licIds = new List<String>();
        List<License__c> licenses = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'COLA'];
        for(License__c lic:licenses){
            licIds.add(lic.Id);
        }
        List<Application__c> application = [Select Id, Name from Application__c WHERE CurrentLicense__c IN :licIds];

        CollectionAgencyRenewal.Input input = new CollectionAgencyRenewal.Input();
        input.inputLicense = licenses[0];
        input.inputApplication = application[0];
        CollectionAgencyRenewal.execute(new List<CollectionAgencyRenewal.Input>{input});
        Test.stopTest();
    }

    @isTest
    static void test_doCOLAXRenewals() {
        Test.startTest();
        // query 
        List<String> licIds = new List<String>();
        List<License__c> licenses = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'COLAX'];
        for(License__c lic:licenses){
            licIds.add(lic.Id);
        }
        List<Application__c> application = [Select Id, Name from Application__c WHERE CurrentLicense__c IN :licIds];

        CollectionAgencyRenewal.Input input = new CollectionAgencyRenewal.Input();
        input.inputLicense = licenses[0];
        input.inputApplication = application[0];
        CollectionAgencyRenewal.execute(new List<CollectionAgencyRenewal.Input>{input});
        Test.stopTest();
    }
}