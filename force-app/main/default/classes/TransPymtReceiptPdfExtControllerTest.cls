@IsTest
public with sharing class TransPymtReceiptPdfExtControllerTest {
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

        pymt__PaymentX__c dummyPayment = new pymt__PaymentX__c();
        dummyPayment.Name = '123131';
        dummyPayment.Transaction__c = dummyTrans.Id;
        insert dummyPayment;

        TransactionLine__c dummyTL = new TransactionLine__c();
        dummyTL.Transaction__c = dummyTrans.Id;
        dummyTL.CashierCode__c = dummyCashierCode.Id;
        dummyTL.Account__c = dummyAccount.Id;
        dummyTL.Payment__c = dummyPayment.Id;
        insert dummyTL;
        
        Test.startTest();
        PageReference pg = Page.TransactionPaymentReceiptPdf;
        Test.setCurrentPage(pg);
        pg.getParameters().put('Id', String.valueOf(dummyTrans.Id));
        ApexPages.StandardController sc = new ApexPages.StandardController(dummyPayment);
        TransactionPymtReceiptPdfExtController extCtrl = new TransactionPymtReceiptPdfExtController(sc);
        Assert.areEqual(2, extCtrl.getTransactionLineCountByPayment(dummyPayment));
        Assert.areEqual(1, extCtrl.getTransactionLinesByPay(dummyPayment).size());
    }
}