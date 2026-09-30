/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*
* Test Class for LicenseCreateRecords
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-IC071819 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Irene Cahilo - Pacificpoint
* @created 07/18/19
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class LicenseCreateRecordsTest {
	@isTest
	static void testLicenseCreateTransRecords(){
		Account accountDummy = new Account();
		accountDummy.Name = 'Dummy';
		insert accountDummy;

		License__c licenseDummy = new License__c();
		licenseDummy.Licensee__c = accountDummy.Id;
		insert licenseDummy;
	}

	@isTest
	static void testLicenseCreateReqRecords(){
		Account accountDummy = new Account();
		accountDummy.Name = 'Dummy';
		insert accountDummy;

		LicenseType__c licenseTypeDummy = new LicenseType__c();
		insert licenseTypeDummy;

		Classification__c classificationDummy = new Classification__c();
		classificationDummy.Name = 'Classification Test';
		classificationDummy.LicenseType__c = licenseTypeDummy.Id;
		insert classificationDummy;


		Application__c applicationDummy = new Application__c();
		applicationDummy.Type__c = 'ADDC - Additional Class';
		insert applicationDummy;

		LicenseTypeRequirements__c ltrDummy = new LicenseTypeRequirements__c();
		ltrDummy.LicenseType__c = licenseTypeDummy.Id;
		ltrDummy.Classification__c = classificationDummy.Id;
		
		insert ltrDummy;

		License__c licenseDummy = new License__c();
		licenseDummy.Licensee__c = accountDummy.Id;
		licenseDummy.LicenseType__c = licenseDummy.Id;
		licenseDummy.Application__c = applicationDummy.Id;
		insert licenseDummy;

	}
}