@isTest
public with sharing class PaymentXBatchSchedulerTest {
    public static testMethod void testSchedulerJob() {
        String cronExpr = '0 0 0 15 3 ? 2099';
        Test.startTest();
        PaymentXBatchScheduler abs= new PaymentXBatchScheduler();
        String jobId = System.schedule('myJobTestJobName', cronExpr, abs);
        abs.execute(null);
        Test.stopTest();
    }
}