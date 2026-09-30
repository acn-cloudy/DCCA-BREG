/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Test class
 * Unit testing for GenerateSubscriberPayment
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhou - PacificPointCorp 
 *  @created      PacPoint-AZ081121
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
@isTest
private class GenerateSubscriberPaymentTest {
    @TestSetup
    static void makeData(){
        Account record = TestDatafactory.createBusinessAccount();
        record.PVLSubscriber__c = true;
        insert record;    
    }
    @isTest
    private static void testBatch() {
        Database.executeBatch(new GenerateSubscriberPayment(), 100);

    }

    @isTest
    private static void testScheduled() {
        String CRON_EXP = '0 0 0 15 3 ? *';
        // Schedule the test job
        String jobId = System.schedule('TestGenerateSubscribePayment', CRON_EXP, new GenerateSubscriberPayment());
        // Get the information from the CronTrigger API object 
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId]; 
        // Verify the job has not run 
        System.assertEquals(0, ct.TimesTriggered);     
    }
}