@isTest
private class LicenseRMELoseBatchTest {
    @TestSetup
	static void setup() {
		Date todaysDate = Date.today();

		Account dummyAccount = new Account();
		dummyAccount.Name = 'Account Name';
		insert dummyAccount;
        DocGeneratorSettings__c  setting = new DocGeneratorSettings__c ();
        setting.Name = 'test';
        setting.DocumentType__c = 'Word';
        insert setting;
		LicenseType__c dummyLT = new LicenseType__c();
		dummyLT.StartofRenewalPeriod__c = todaysDate;
        dummyLT.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        dummyLT.StatusDuetoLossofDependent__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
         dummyLT.Entity__c = true;
         dummyLT.RMELosesEntityNotification__c  = setting.Id;
         dummyLt.EntityLosesRMENotification__c  = setting.Id;
		dummyLT.Status__c = 'Active';
		dummyLT.Name = 'Dummy License Type';
		insert dummyLT;
        
        
        License__c dummyEmployeeLicense = new License__c();
		dummyEmployeeLicense.Status__c = 'C - Current, Valid & In Good Standing';
        dummyEmployeeLicense.GenerateRMELosesEntityNotification__c = true;
		dummyEmployeeLicense.LicenseType__c = dummyLT.Id;
		dummyEmployeeLicense.Licensee__c = dummyAccount.Id;
        insert dummyEmployeeLicense;
        License__c dummyEmployeeLicense2 = new License__c();
		dummyEmployeeLicense2.Status__c = 'C - Current, Valid & In Good Standing';
        dummyEmployeeLicense2.GenerateEntityLosesRMENotification__c = true;
		dummyEmployeeLicense2.LicenseType__c = dummyLT.Id;
		dummyEmployeeLicense2.Licensee__c = dummyAccount.Id;
		insert dummyEmployeeLicense2;
    }
    @IsTest
	static void test_LicenseRMELose() {
        List<License__c> dummyEmployeeLicenseList = [SELECT Id, Status__c FROM License__c];
        LicenseType__c dummyLT = [SELECT Id, StatusDuetoLossofDependent__c FROM LicenseType__c LIMIT 1];
        Map<Id, String> employeeLicenseIdStatusMap = new  Map<Id, String>();
        for (License__c dummyEmployeeLicense : dummyEmployeeLicenseList) {
            employeeLicenseIdStatusMap.put(dummyEmployeeLicense.Id, dummyLT.StatusDuetoLossofDependent__c);
        }
        
        Test.StartTest();
		LicenseRMELoseBatch rmeLose = new LicenseRMELoseBatch();
		Database.executebatch(rmeLose);
		Test.StopTest();

        
        for(License__c dummyLicense: [SELECT Id, GenerateEntityLosesRMENotification__c, GenerateRMELosesEntityNotification__c FROM License__c]) {
            System.assertEquals(dummyLicense.GenerateEntityLosesRMENotification__c, false);
            System.assertEquals(dummyLicense.GenerateRMELosesEntityNotification__c, false);
        }
        
	}
    
}