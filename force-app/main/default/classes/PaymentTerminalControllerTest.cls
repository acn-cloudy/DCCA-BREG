@isTest
private class PaymentTerminalControllerTest {
    public static testMethod void testUpdatePayment() {
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
        
        PaymentTerminalController.updatePayment(JSON.serialize(pymt));
    }
    public static testMethod void testUpdateTempPayment() {
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
        PaymentTerminalController.updateTempPayment(trn.Id, 'Cash', 'Test Memo');

    }
    public static testMethod void testValidateTransaction() {
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
        Transaction__c tran = [Select Id, TotalAmount__c, PaymentAmount__c, Status__c from Transaction__c limit 1];
        try{
            PaymentTerminalController.validateTransaction(tran.Id);
        } catch (Exception ex) {

        }
        tran.TotalAmount__c = 60;
        tran.PaymentAmount__c = 50;
        tran.Status__c = 'Pending';
        update tran;
        try{
            PaymentTerminalController.validateTransaction(tran.Id);
        } catch (Exception ex) {
            
        }
    }
}