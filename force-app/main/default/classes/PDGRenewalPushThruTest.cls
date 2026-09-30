@isTest
private class PDGRenewalPushThruTest {

    @TestSetup
    static void makeData(){
        Id RecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - GD/PD').getRecordTypeId();
        
		//License Type
		LicenseType__c licenseType2 = new LicenseType__c();
		licenseType2.Name = 'GD';
		licenseType2.Status__c = 'Active';        
        licenseType2.LicenseTypeEffectiveDate__c = Date.today();
        licenseType2.DurationofLicenseInMonths__c   =  10;

		LicenseType__c licenseType3 = new LicenseType__c();
		licenseType3.Name = 'PD';
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
		licenseMainA.RecordTypeId = RecordTypeId;
        licenseMainA.ThisLicenseRenewed__c = true;
		licenseListToCreate.add(licenseMainA);

		License__c licenseMainB = new License__c();
		licenseMainB.Name = 'License B';
		licenseMainB.ActiveInactive__c = 'Active';
		licenseMainB.LicenseType__c = licenseType3.Id;
		licenseMainB.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
		licenseMainB.RecordTypeId = RecordTypeId;
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
        DataBase.executeBatch(new PDGRenewalPushThru(), 200);
        Test.stopTest();
    }
}