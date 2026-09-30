/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*
* Test Class for LicenseUpdateTransactionRecords
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-CZ042320 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Chris Zhuang - Pacificpoint
* @created 04/23/20
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class LicenseUpdateTransactionRecordsTest {
	@isTest
	static void testLicenseUpdateTransactionRecords(){
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
        
		License__c licenseDummy = new License__c();
        licenseDummy.Licensee__c = accountDummy.Id;
        licenseDummy.Application__c = applicationDummy.Id;
		insert licenseDummy;
	}
}