/*
 * ___________________________________________________________________________________
 * Test Class for PaymentAutoCloserScheduler
 * __________________________________________________________________________________
 * PacPoint-CL031319 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/13/2019
 * __________________________________________________________________________________
 */
@IsTest
private class PaymentAutoCloserSchedulerTest {
    @TestSetup
    static void setup() {
        Account dummyAccount = new Account(Name = 'Test');
        insert dummyAccount;

        Contact dummyContact = new Contact(LastName = 'Test', AccountId = dummyAccount.Id);
        insert dummyContact;

        Transaction__c dummyTransaction = new Transaction__c(Account__c = dummyAccount.Id);
        insert dummyTransaction;

        CashierCode__c dummyCashierCode = new CashierCode__c(Description__c = 'Test', Amount__c = 1.00);
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c(
                PaidStatus__c = 'Paid',
                Transaction__c = dummyTransaction.Id,
                CashierCode__c = dummyCashierCode.Id);
        insert dummyTransactionLine;

        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.pymt__Status__c = 'Completed';
        insert payment;

        CollectionsAllocation__c col = new CollectionsAllocation__c();
        col.Payment__c = payment.Id;
        col.TransactionLine__c = dummyTransactionLine.Id;
        insert col;
    }

    @IsTest
    static void executeTest() {
        PaymentAutoCloserScheduler scheduler = new PaymentAutoCloserScheduler();
        scheduler.execute(null);

        List<pymt__PaymentX__c> payment = [SELECT Id FROM pymt__PaymentX__c WHERE CutOffBatchDate__c != null];
        List<CollectionsAllocation__c> col = [SELECT Id FROM CollectionsAllocation__c WHERE CutOffBatchDate__c != null];

        System.assert(payment.isEmpty());
        System.assert(col.isEmpty());
    }
}