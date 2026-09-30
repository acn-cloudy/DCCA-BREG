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
private class MotorVehicleIndustryRenewalPushThruTest {

    @TestSetup
    static void makeData(){
        Id MVBRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - MVB').getRecordTypeId();
        Id MVDRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - MVD').getRecordTypeId();

		//License Type
		LicenseType__c licenseType2 = new LicenseType__c();
		licenseType2.Name = 'MVB';
		licenseType2.Status__c = 'Active';        
        licenseType2.LicenseTypeEffectiveDate__c = Date.today();
        licenseType2.DurationofLicenseInMonths__c   =  10;

		LicenseType__c licenseType3 = new LicenseType__c();
		licenseType3.Name = 'MVD';
		licenseType3.Status__c = 'Active';        
        licenseType3.LicenseTypeEffectiveDate__c = Date.today();
        licenseType3.DurationofLicenseInMonths__c   =  10;
        insert new List<LicenseType__c>{licenseType2, licenseType3};

        Map<Id, String> ltLicensePeriod = new Map<Id, String>();
        for(LicenseType__c lt:[SELECT Id, PreviousLicensePeriod__c FROM LicenseType__c]){
            ltLicensePeriod.put(lt.Id, lt.PreviousLicensePeriod__c);
        }

		//Licenses
		List<License__c> licenseListToCreate = new List<License__c>();

		//Group for Active A
		License__c licenseMainA = new License__c();
		licenseMainA.Name = 'License A';
		licenseMainA.ActiveInactive__c = 'Active';
		licenseMainA.LicenseType__c = licenseType2.Id;
		licenseMainA.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
		licenseMainA.RecordTypeId = MVBRecordTypeId;
        licenseMainA.ThisLicenseRenewed__c = true;
		licenseListToCreate.add(licenseMainA);

		License__c licenseMainB = new License__c();
		licenseMainB.Name = 'License B';
		licenseMainB.ActiveInactive__c = 'Active';
		licenseMainB.LicenseType__c = licenseType3.Id;
		licenseMainB.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
		licenseMainB.RecordTypeId = MVDRecordTypeId;
        licenseMainB.ThisLicenseRenewed__c = true;
		licenseListToCreate.add(licenseMainB);

        insert licenseListToCreate;

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
        Application__c applicationRecord4 = new Application__c();
        applicationRecord4.Applicant__c = acc.Id;
        applicationRecord4.CurrentLicense__c = licenseMainA.Id;
        applicationRecord4.LicenseType__c = licenseType2.Id;
        applicationRecord4.Type__c = 'RNEW - Renewal';
        applicationRecord4.Status__c = 'D1 - Awaiting Dependency Review';
        applicationRecord4.LicensePeriodRNEW__c = ltLicensePeriod.get(licenseType2.Id);
        applications.add(applicationRecord4);

        Application__c applicationRecord5 = new Application__c();
        applicationRecord5.Applicant__c = acc.Id;
        applicationRecord5.CurrentLicense__c = licenseMainB.Id;
        applicationRecord5.LicenseType__c = licenseType3.Id;
        applicationRecord5.Type__c = 'RNEW - Renewal';
        applicationRecord5.Status__c = 'D1 - Awaiting Dependency Review';        
        applicationRecord4.LicensePeriodRNEW__c = ltLicensePeriod.get(licenseType3.Id);
        applications.add(applicationRecord5);
        
        insert applications;
    }

    @isTest
    static void test_processRecords(){
        Test.startTest();
        DataBase.executeBatch(new MotorVehicleIndustryRenewalPushThrough(), 200);
        Test.stopTest();
    }
}