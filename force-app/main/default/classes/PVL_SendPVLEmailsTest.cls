@isTest
private class PVL_SendPVLEmailsTest {
    private static testMethod void testSendPVLEmails() {
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

        CashierCode__c cc1 = new CashierCode__c();
        cc1.Description__c = 'test1 - 5';
        cc1.Name = 'cc1';

        CashierCode__c cc2 = new CashierCode__c();
        cc2.Description__c = 'test1';
        cc2.Name = 'cc1';

        insert new CashierCode__c[]{cc1, cc2};

        TransactionLine__c tl1 = new TransactionLine__c();
        tl1.CashierCode__c = cc1.Id;
        tl1.Transaction__c = trn.Id;
        tl1.Amount__c = 20;

        TransactionLine__c tl2 = new TransactionLine__c();
        tl2.CashierCode__c = cc2.Id;
        tl2.Transaction__c = trn.Id;
        tl2.Amount__c = 85;

        insert new TransactionLine__c[]{tl1, tl2};

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
        pymt.pymt__Billing_Email__c = 'testSample@test.com';
        insert pymt;
        Test.startTest();
        PVL_SendPVLEmails.sendPVLEmails(new List<Id> {pymt.Id});
    }
}