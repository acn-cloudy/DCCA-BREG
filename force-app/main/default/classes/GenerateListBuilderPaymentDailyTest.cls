@isTest
private class GenerateListBuilderPaymentDailyTest {
    @isTest
    private static void testScheduled() {
        String CRON_EXP = '0 0 0 15 3 ? *';
        // Schedule the test job
        String jobId = System.schedule('GenerateListBuilderPaymentDaily', CRON_EXP, new GenerateListBuilderPaymentDaily());
        // Get the information from the CronTrigger API object 
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId]; 
        // Verify the job has not run 
        System.assertEquals(0, ct.TimesTriggered);     
    }    
}