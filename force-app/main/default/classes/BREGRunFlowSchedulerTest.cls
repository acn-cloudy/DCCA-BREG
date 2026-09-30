@IsTest
private class BREGRunFlowSchedulerTest {
    @IsTest
    static void testExecuteSchedulable() {
        Test.startTest();
        BREGRunFlowScheduler schedulable = new BREGRunFlowScheduler();
        schedulable.execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testScheduleJob() {
        String cronExpression = '0 0 0 15 3 ? 2099';
        String jobName = 'BREGRunFlowScheduler Test';

        Test.startTest();
        String jobId = System.schedule(jobName, cronExpression, new BREGRunFlowScheduler());
        Test.stopTest();

        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, scheduledJobs.size(), 'One scheduled job should exist');
        System.assertEquals(cronExpression, scheduledJobs[0].CronExpression, 'CRON expression should match');
    }
}