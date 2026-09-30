/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class
* Unit testing for EmployeeLicenseStatus
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class EmployeeLicenseStatusTest {
	@TestSetup
	static void setup() {
		Date todaysDate = Date.today();

		Account dummyAccount = new Account();
		dummyAccount.Name = 'Account Name';
		insert dummyAccount;

		LicenseType__c dummyLT = new LicenseType__c();
		dummyLT.StartofRenewalPeriod__c = todaysDate;
        dummyLT.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        dummyLT.StatusDuetoLossofDependent__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
     	dummyLT.Entity__c = true;
		dummyLT.Status__c = 'Active';
		dummyLT.Name = 'Dummy License Type';
		insert dummyLT;
	
        
        License__c dummyEmployeeLicense = new License__c();
		dummyEmployeeLicense.Status__c = 'C - Current, Valid & In Good Standing';
        dummyEmployeeLicense.EffectiveExpireDate__c = todaysDate.addDays(-29);
		dummyEmployeeLicense.LicenseType__c = dummyLT.Id;
		dummyEmployeeLicense.Licensee__c = dummyAccount.Id;
		insert dummyEmployeeLicense;
	}

	@IsTest
	static void test_EmployeeLicenseStatus() {
        List<License__c> dummyEmployeeLicenseList = [SELECT Id, Status__c FROM License__c];
        LicenseType__c dummyLT = [SELECT Id, StatusDuetoLossofDependent__c FROM LicenseType__c LIMIT 1];
        Map<Id, String> employeeLicenseIdStatusMap = new  Map<Id, String>();
        for (License__c dummyEmployeeLicense : dummyEmployeeLicenseList) {
            employeeLicenseIdStatusMap.put(dummyEmployeeLicense.Id, dummyLT.StatusDuetoLossofDependent__c);
        }
        
        Test.StartTest();
		EmployeeLicenseStatus employeeLicenseStatusBatch = new EmployeeLicenseStatus(employeeLicenseIdStatusMap);
        employeeLicenseStatusBatch.employeeLicenseIdStatusMap = employeeLicenseIdStatusMap;
		Database.executebatch(employeeLicenseStatusBatch);
		Test.StopTest();

		License__c dummyLicense = [SELECT Id, Status__c FROM License__c];
		System.assertEquals(dummyLicense.Status__c, dummyLT.StatusDuetoLossofDependent__c);
	}
}