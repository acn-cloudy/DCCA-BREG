global with sharing class BREGAnnualRollOverSchedulable implements Schedulable {

    /**
     * Executes the BREGAnnualRollOverJob batch each time this Schedulable runs.
     */
    global void execute(SchedulableContext sc) {
        System.debug('🚀 Starting BREGAnnualRollOverJob batch (Daily Scheduled Run). Schedule in BREG_Annuals_Job_Settings__c');
        BREGAnnualRollOverJob job = new BREGAnnualRollOverJob();
        job.isScheduled = true;
        Database.executeBatch(job, 100);
    }

    /**
     * Utility method to schedule this job to run once per day at a specified time.
     * 
     * @param hour   The hour (0–23) when the job should run.
     * @param minute The minute (0–59) when the job should run.
     */
    public static void scheduleDaily(Integer hour, Integer minute) {
        String jobName = 'BREG Annual RollOver - Daily check';
        // Run every day at the specified time (default: midnight)
        String cronExp = '0 ' + minute + ' ' + hour + ' * * ? *';

        // Schedule the job
        System.schedule(jobName, cronExp, new BREGAnnualRollOverSchedulable());
        System.debug('✅ Scheduled: ' + jobName + ' | CRON: ' + cronExp);
    }

    /**
     * Overload convenience method: schedules the job at midnight (00:00) daily.
     */
    public static void scheduleDaily() {
        scheduleDaily(0, 0); // Default: midnight
    }
}