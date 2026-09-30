/*
 * ___________________________________________________________________________________
 * Test class for PaymentDeduplicator
 * __________________________________________________________________________________
 * PacPoint-CL032919 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 3/29/2019
 * __________________________________________________________________________________
 */
@IsTest
private class PaymentDeduplicatorTest {
    @TestSetup
    static void setup() {
        Account dummyAccount = new Account(Name = 'Test');
        insert dummyAccount;

        Contact dummyContact = new Contact(LastName = 'Test', AccountId = dummyAccount.Id);
        insert dummyContact;

        Transaction__c dummyTransaction = new Transaction__c(Account__c = dummyAccount.Id,
                Status__c = 'New');
        insert dummyTransaction;
        Transaction__c tran = [Select Id, Name from Transaction__c where Id =: dummyTransaction.Id];
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.Name = tran.Name;
        payment.pymt__Amount__c = 1;
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Payment_Type__c = 'Cash';
        payment.Transaction__c = dummyTransaction.Id;
        insert payment;
    }

    @IsTest
    static void deduplicateTest() {
        Transaction__c dummyTransaction = [SELECT Id, Name FROM Transaction__c LIMIT 1];
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.Name = dummyTransaction.Name;
        payment.pymt__Amount__c = 1;
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Payment_Type__c = 'Cash';
        insert payment;

        payment.Transaction__c = dummyTransaction.Id;
        update payment;

        List<pymt__PaymentX__c> payments = [SELECT Id FROM pymt__PaymentX__c];
        System.assertEquals(1, payments.size());
    }
}