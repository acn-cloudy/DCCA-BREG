/*
 * Created on 9/5/2018.
 * Author chris.loyola@pacificpointcorp.com
 */
@IsTest
private class PaymentReceiptPdfExtControllerTest {
    private static testmethod void testSetPaymentRecord() {
        RecordTypeInfo accountBusinessAccount = Account.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account dummyAccount = new Account();
        dummyAccount.Name = 'Dummy Account Incorporation Incorporated';
        dummyAccount.RecordTypeId = accountBusinessAccount.getRecordTypeId();
        insert dummyAccount;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Name = 'Dummy Cashier Code Name - TestTestTestTestTestTestTestTestTestTest';
        dummyCashierCode.Amount__c = 10.00;
        dummyCashierCode.CashierCode__c = 'DUM';
        insert dummyCashierCode;

        Transaction__c dummyTrans = new Transaction__c();
        dummyTrans.Account__c = dummyAccount.Id;
        dummyTrans.TransactionType__c = 'Payment';
        insert dummyTrans;

        TransactionLine__c dummyTL = new TransactionLine__c();
        dummyTL.Transaction__c = dummyTrans.Id;
        dummyTL.CashierCode__c = dummyCashierCode.Id;
        dummyTL.Account__c = dummyAccount.Id;
        insert dummyTL;

        pymt__PaymentX__c dummyPayment = new pymt__PaymentX__c();
        dummyPayment.Name = '123131';
        dummyPayment.Transaction__c = dummyTrans.Id;
        insert dummyPayment;  
        Test.startTest();
        PaymentReceiptPdfExtController extCtrl = new PaymentReceiptPdfExtController();
        extCtrl.setPaymentRecord(dummyPayment);
    }

    @IsTest
    static void controllerTest() {
        RecordTypeInfo accountBusinessAccount = Account.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account dummyAccount = new Account();
        dummyAccount.Name = 'Dummy Account Incorporation Incorporated';
        dummyAccount.RecordTypeId = accountBusinessAccount.getRecordTypeId();
        insert dummyAccount;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Name = 'Dummy Cashier Code Name - TestTestTestTestTestTestTestTestTestTest';
        dummyCashierCode.Amount__c = 10.00;
        dummyCashierCode.CashierCode__c = 'DUM';
        insert dummyCashierCode;

        Transaction__c dummyTrans = new Transaction__c();
        dummyTrans.Account__c = dummyAccount.Id;
        dummyTrans.TransactionType__c = 'Payment';
        insert dummyTrans;

        TransactionLine__c dummyTL = new TransactionLine__c();
        dummyTL.Transaction__c = dummyTrans.Id;
        dummyTL.CashierCode__c = dummyCashierCode.Id;
        dummyTL.Account__c = dummyAccount.Id;
        insert dummyTL;

        pymt__PaymentX__c dummyPayment = new pymt__PaymentX__c();
        dummyPayment.Name = '123131';
        dummyPayment.Transaction__c = dummyTrans.Id;
        insert dummyPayment;
        Test.startTest();
        PageReference pg = Page.PaymentReceiptPdf;
        Test.setCurrentPage(pg);
        pg.getParameters().put('Id', String.valueOf(dummyPayment.Id));
        ApexPages.StandardController sc = new ApexPages.StandardController(dummyPayment);
        PaymentReceiptPdfExtController extCtrl = new PaymentReceiptPdfExtController(sc);
        System.assert(!extCtrl.getTransactionLines().isEmpty());
        System.assert(extCtrl.getTransactionAccounts().isEmpty());

        Transaction__c dummyTrans2 = new Transaction__c();
        dummyTrans2.Account__c = dummyAccount.Id;
        dummyTrans2.TransactionType__c = 'Group';
        insert dummyTrans2;

        Transaction__c dummyTrans3 = new Transaction__c();
        dummyTrans3.Account__c = dummyAccount.Id;
        dummyTrans3.TransactionType__c = 'Payment';
        dummyTrans3.TransactionGroup__c = dummyTrans2.Id;
        insert dummyTrans3;

        pymt__PaymentX__c dummyPayment2 = new pymt__PaymentX__c();
        dummyPayment2.Name = '123131';
        dummyPayment2.Transaction__c = dummyTrans2.Id;
        insert dummyPayment2;

        TransactionLine__c dummyTL2 = new TransactionLine__c();
        dummyTL2.Transaction__c = dummyTrans2.Id;
        dummyTL2.CashierCode__c = dummyCashierCode.Id;
        dummyTL2.Account__c = dummyAccount.Id;
        insert dummyTL2;

        TransactionLine__c dummyTL3 = new TransactionLine__c();
        dummyTL3.Transaction__c = dummyTrans3.Id;
        dummyTL3.CashierCode__c = dummyCashierCode.Id;
        dummyTL3.Account__c = dummyAccount.Id;
        insert dummyTL3;
        
        PageReference pg2 = Page.PaymentReceiptPdf;
        Test.setCurrentPage(pg2);
        pg.getParameters().put('Id', String.valueOf(dummyPayment2.Id));
        ApexPages.StandardController sc2 = new ApexPages.StandardController(dummyPayment2);
        PaymentReceiptPdfExtController extCtrl2 = new PaymentReceiptPdfExtController(sc2);
        
        System.assert(!extCtrl2.getGroupedTransactionLines().isEmpty());
    }
}