@isTest
private class PVL_ListBuilderReceiptControllerTest {
    private static testMethod void tesstController() {
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'H - License Generation';
        applicationRecord.Status__c = 'H1 - Awaiting Licensing';
        applicationRecord.IsApplicationTerminated__c = false;
        insert applicationRecord;

        applicationRecord.CompleteApplicationBy__c = System.today() - 1;
        update applicationRecord;

		Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 100.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = applicationRecord.Id;

        insert trn;
        FeeSchedule__c fs = new FeeSchedule__c();
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;
        Test.StartTest();
        ApexPages.StandardController controller = new ApexPages.StandardController(pymt);
        Test.setCurrentPageReference(new PageReference('Page.PVL_ListBuilderReceipt')); 
        String s_paymentDate = ''; 
        
        Datetime dt_paymentDate = System.now();
        s_paymentDate = dt_paymentDate.formatGMT('dd MMM yyyy');
        System.currentPageReference().getParameters().put('Id', pymt.Id);
        System.currentPageReference().getParameters().put('tranId', trn.Id);
        System.currentPageReference().getParameters().put('tranDate', s_paymentDate);
        PVL_ListBuilderReceiptController ctr = new PVL_ListBuilderReceiptController();
    }
}