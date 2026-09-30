public with sharing class PVLAppStatusSnapshotRefreshScheduler implements Schedulable {
    public static final String JOB_NAME = 'PVL Application Status Snapshot Refresh 08:30 HST';
    public static final String DAILY_0830_CRON = '0 30 8 * * ?';

    public void execute(SchedulableContext context) {
        Database.executeBatch(
            new PVLApplicationStatusSnapshotRefreshBatch(),
            PVLApplicationStatusSnapshotRefreshBatch.DEFAULT_BATCH_SIZE
        );
    }

    public static String scheduleDaily0830Hst() {
        return System.schedule(JOB_NAME, DAILY_0830_CRON, new PVLAppStatusSnapshotRefreshScheduler());
    }
}