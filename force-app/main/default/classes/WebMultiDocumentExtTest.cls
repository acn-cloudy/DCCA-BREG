@isTest
private class WebMultiDocumentExtTest {
    private static testMethod void testController() {
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
        Notification__c record = new Notification__c();
        record.RecordId__c = dummyLT.Id;
        insert record;
        Test.setCurrentPageReference(new PageReference('Page.WebMultiPDF')); 
        System.currentPageReference().getParameters().put('queryIds', record.Id);
    WebMultiDocumentExt ext = new WebMultiDocumentExt();
    }
}