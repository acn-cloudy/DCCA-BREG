/*
 * Created on 9/28/2018.
 * Author chris.loyla@pacificpointcorp.com
 */
@IsTest
private class PaymentTriggerTest {
    @TestSetup
    static void setup() {
        Account acct = new Account();
        acct.Name = 'Account Name';
        insert acct;

        Contact cnt = new Contact();
        cnt.FirstName = 'FName';
        cnt.LastName = 'Lname';
        cnt.AccountId = acct.Id;
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acct.Id;
        insert trn;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Amount__c = 1;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.Name = 'test';
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        pymt__PaymentX__c pymt2 = new pymt__PaymentX__c();
        pymt2.Transaction__c = trn.Id;
        pymt2.pymt__Amount__c = 1;
        pymt2.pymt__Payment_Type__c = 'Cash';
        pymt2.pymt__Date__c = Date.today();
        pymt2.pymt__Currency_ISO_Code__c = 'USD';
        pymt2.pymt__Transaction_Type__c = 'Payment';
        pymt2.Name = 'test';
        pymt2.pymt__Status__c = 'Pending';
        insert pymt2;
    }

    @IsTest
    static void calculateTransactionPaymentAmtOnInsertTest() {
        Transaction__c trn = [SELECT Id, PaymentAmount__c FROM Transaction__c][0];
        System.assert(trn.PaymentAmount__c == 1);
    }

    @IsTest
    static void calculateTransactionPaymentAmtOnUpdateTest() {
        pymt__PaymentX__c pymt = [SELECT Id FROM pymt__PaymentX__c WHERE pymt__Status__c = 'Pending'][0];
        pymt.pymt__Amount__c = 2;

        Test.startTest();
        update pymt;
        pymt.pymt__Status__c = 'Completed';
        update pymt;
        Test.stopTest();

        Transaction__c trn = [SELECT Id, PaymentAmount__c FROM Transaction__c][0];
        System.assert(trn.PaymentAmount__c == 3);
    }

    @IsTest
    static void calculateTransactionPaymentAmtOnDeleteTest() {
        Test.startTest();
        delete [SELECT Id FROM pymt__PaymentX__c];
        Test.stopTest();

        Transaction__c trn = [SELECT Id, PaymentAmount__c FROM Transaction__c][0];
        System.assertEquals(0, trn.PaymentAmount__c);
    }
}