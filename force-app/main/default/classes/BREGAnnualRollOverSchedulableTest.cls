@IsTest
private class BREGAnnualRollOverSchedulableTest {
    // -------------------------------------------------------------------------
    // ✅ TEST 1: Execute the schedulable and verify batch is enqueued
    // -------------------------------------------------------------------------
    @IsTest
    static void testExecuteSchedulable() {
        Test.startTest();
        BREGAnnualRollOverSchedulable schedulable = new BREGAnnualRollOverSchedulable();
        schedulable.execute(null);
        Test.stopTest();

        // Verify the batch job ran by checking AsyncApexJob
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'BREGAnnualRollOverJob' AND JobType = 'BatchApex'
        ];
        System.assert(!jobs.isEmpty(), 'BREGAnnualRollOverJob batch should have been enqueued');
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 2: Schedule daily with specific hour and minute
    // -------------------------------------------------------------------------
    @IsTest
    static void testScheduleDailyWithParams() {
        Test.startTest();
        BREGAnnualRollOverSchedulable.scheduleDaily(8, 30);
        Test.stopTest();

        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'BREG Annual RollOver - Daily check'
        ];
        System.assertEquals(1, scheduledJobs.size(), 'One scheduled job should exist');
        System.assertEquals('0 30 8 * * ? *', scheduledJobs[0].CronExpression, 'CRON expression should match hour=8, minute=30');
    }

    // -------------------------------------------------------------------------
    // ✅ TEST 3: Schedule daily with default midnight params
    // -------------------------------------------------------------------------
    @IsTest
    static void testScheduleDailyDefault() {
        Test.startTest();
        BREGAnnualRollOverSchedulable.scheduleDaily();
        Test.stopTest();

        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'BREG Annual RollOver - Daily check'
        ];
        System.assertEquals(1, scheduledJobs.size(), 'One scheduled job should exist');
        System.assertEquals('0 0 0 * * ? *', scheduledJobs[0].CronExpression, 'CRON expression should default to midnight');
    }
}