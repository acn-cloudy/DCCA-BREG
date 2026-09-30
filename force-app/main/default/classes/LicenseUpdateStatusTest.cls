/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class
* - checkLicenseStatus : Find and set the status of Licenses with License Types Start of RenewalPerios = Today
* Covered for LicenseUpdateStatus
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Irene Cahilo - PacificPointCorp 
* @created      PacPoint-IC071819 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class LicenseUpdateStatusTest {
	@TestSetup
	static void setup() {
		Date todaysDate = Date.today();

		Account dummyAccount = new Account();
		dummyAccount.Name = 'Account Name';
		insert dummyAccount;

		LicenseType__c dummyLT = new LicenseType__c();
		dummyLT.StartofRenewalPeriod__c = todaysDate;
		dummyLT.Status__c = 'Active';
		dummyLT.Name = 'Dummy License Type';
		insert dummyLT;

		List<License__c> licenseList = new List<License__c>();

		License__c dummyLicense = new License__c();
		dummyLicense.Status__c = 'C - Current, Valid & In Good Standing';
		dummyLicense.LicenseType__c = dummyLT.Id;
		dummyLicense.Licensee__c = dummyAccount.Id;
		licenseList.add(dummyLicense);

		License__c dummyLicense2 = new License__c();
		dummyLicense2.Status__c = 'CR - Current/Next Renewal Paid';
		dummyLicense2.LicenseType__c = dummyLT.Id;
		dummyLicense2.Licensee__c = dummyAccount.Id;
		licenseList.add(dummyLicense2);

		License__c dummyLicense3 = new License__c();
		dummyLicense3.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
		dummyLicense3.LicenseType__c = dummyLT.Id;
		dummyLicense3.Licensee__c = dummyAccount.Id;
		licenseList.add(dummyLicense3);

		insert licenseList;
	}

	@IsTest
	static void licenseStatusUpdatesTest() {
		LicenseUpdateStatusScheduler scheduler = new LicenseUpdateStatusScheduler();
		scheduler.execute(null);

		List<String> updatedToStatuses = new List<String>();
		updatedToStatuses.add('R - Valid Thru Expiration Date, Subject To Renewal');
		updatedToStatuses.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');

		List<License__c> dummyLicenses = [SELECT Id, Status__c FROM License__c WHERE Status__c =: updatedToStatuses];

		//System.assertEquals(3, dummyLicenses.size());

	}
	public static testMethod void testFunction() {
		LicenseUpdateStatus.checkLicenseStatus();
		
		List<License__c> licenses = [Select Id, Status__c from License__c ];
		LicenseUpdateStatus.checkLicenseStatus(licenses);
	}

}