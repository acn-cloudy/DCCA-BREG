/*
 * Created on 9/28/2018.
 * Author chris.loyola@pacificpointcorp.com
 */
@IsTest
private class TransactionPaymentAmtCalculatorTest {
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
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        insert pymt;
    }

    @IsTest
    static void calculateTest() {
        Transaction__c trn = [SELECT Id FROM Transaction__c][0];
        TransactionPaymentAmtCalculator.calculate(new List<Id>{trn.Id});

        Transaction__c trnUpdated = [SELECT Id, PaymentAmount__c FROM Transaction__c WHERE Id = :trn.Id];
        System.assert(trnUpdated.PaymentAmount__c == 1);
    }

    @IsTest
    static void calculateOnUpdateStatusTest() {
        
        pymt__PaymentX__c pymt = [Select Id, pymt__Status__c, Transaction__c from pymt__PaymentX__c limit 1];
        Test.startTest();
        pymt.pymt__Status__c = 'Completed';
        update pymt;
        Test.stopTest();

        Transaction__c trnUpdated = [SELECT Id, PaymentAmount__c FROM Transaction__c WHERE Id = :pymt.Transaction__c];
        System.assert(trnUpdated.PaymentAmount__c == 1);
    }

    @IsTest
    static void calculateOnUpdatePaymentAmountTest() {
        Account acct = [Select Id from Account limit 1];
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
        pymt.pymt__Status__c = 'Pending';
        pymt.Name = 'test';
        insert pymt;
        Test.startTest();
        pymt.pymt__Amount__c = 2;
        update pymt;
        pymt.pymt__Status__c = 'Completed';
        update pymt;

        Test.stopTest();

        Transaction__c trnUpdated = [SELECT Id, PaymentAmount__c FROM Transaction__c WHERE Id = :pymt.Transaction__c];
        System.assert(trnUpdated.PaymentAmount__c == 2);
    }

    @IsTest
    static void calculateOnDeleteTest() {
        pymt__PaymentX__c pymt = [Select Id, pymt__Status__c, Transaction__c from pymt__PaymentX__c limit 1];

        Test.startTest();
        delete pymt;
        Test.stopTest();

        Transaction__c trnUpdated = [SELECT Id, PaymentAmount__c FROM Transaction__c WHERE Id = :pymt.Transaction__c];
        System.assert(trnUpdated.PaymentAmount__c <= 0);
    }
}