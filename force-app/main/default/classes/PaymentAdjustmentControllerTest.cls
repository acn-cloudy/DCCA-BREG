@isTest
private class PaymentAdjustmentControllerTest {

    @isTest
    static void testGeneratePaymentAdjustment() {
        Transaction__c txn = new Transaction__c();
        insert txn;

        CashierCode__c cashier = new CashierCode__c(
            CashierCode__c = 'C001'
        );
        insert cashier;

        TransactionLine__c tl = new TransactionLine__c(
            Transaction__c = txn.Id,
            CashierCode__c = cashier.Id
        );
        insert tl;

        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            pymt__Payment_Type__c = 'Cash'
        );
        insert payment;

        CollectionsAllocation__c ca = new CollectionsAllocation__c(
            AmountAllocated__c = -100,
            TransactionLine__c = tl.Id,
            Payment__c = payment.Id,
            CutOffBatchDate__c = Date.today()
        );
        insert ca;

        Test.startTest();
        PaymentAdjustmentController.generatePaymentAdjustment(
            new List<String>{ 'test' }
        );
        Test.stopTest();
    }
}