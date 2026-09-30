@isTest
private class BatchChargeBackTest {
    @isTest
    private static void testExecuteBatch() {
        pymt__PaymentX__c payment = TestDataFactory.createDummyChargebackPayment();
        payment.DIsputedCharge__c = true;
        payment.ChargebackDate__c = Date.today().addDays(-1);
        insert payment;
        Database.executeBatch(new BatchChargeBack(), 200);
    }
    @isTest
    private static void testSchedule() {
        Test.startTest();
        BatchChargeBack scheduler = new BatchChargeBack();
        String sch = '0 0 23 * * ?';
        System.schedule('testBatchChargeBack', sch, scheduler);
        Test.stopTest();
    }
}