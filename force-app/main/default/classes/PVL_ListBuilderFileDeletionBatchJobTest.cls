@isTest
private class PVL_ListBuilderFileDeletionBatchJobTest {
    public static testMethod void testBatch() {
        	// Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;
        
		Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
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
        Test.startTest();
        Database.executeBatch(new PVL_ListBuilderFileDeletionBatchJob(), 200);

    }
}