/**
 * @description Scheduled batch job to clean up old log records (CALL-691 bulk-safe rewrite).
 * Runs as a child-first, two-stage batch so per-transaction delete cost is a chosen
 * constant regardless of parent fanout:
 *   Stage 1 (CASE_LOGS): deletes util_closer_Case_Log__c children of past-retention parents.
 *   Stage 2 (BATCH_LOGS): chained from Stage 1's finish, deletes now-childless parents.
 * Deleted rows are hard-deleted via Database.emptyRecycleBin per successful chunk so
 * large runs do not flood the shared Recycle Bin.
 */
public with sharing class util_closer_LogCleanupBatch
    implements Database.Batchable<SObject>, Database.RaisesPlatformEvents, Schedulable {

    /**
     * @description The two deletion stages. Stage 1 runs first; Stage 2 is chained
     * from its finish so parents are only deleted after their children are gone.
     */
    public enum Stage { CASE_LOGS, BATCH_LOGS }

    private static final Integer DEFAULT_RETENTION_DAYS = 90;
    private static final Integer STALE_LOG_HOURS = 24;

    // Fixed by the CALL-691 design (ticket, 2026-08-04): every execute() deletes at most
    // this many rows. Deliberately not settings-driven — Batch_Size__c tunes the
    // CaseStatus job, and coupling the two jobs' tuning was rejected.
    @TestVisible
    private static final Integer SCOPE_SIZE = 2000;

    // Test seam: chaining Database.executeBatch from finish() throws in test context,
    // so tests assert this flag instead of observing the real chain.
    @TestVisible
    private static Boolean stage2Enqueued = false;

    // Test seam: AsyncApexJob.NumberOfErrors cannot be fabricated in test context,
    // so tests use this to exercise the error-email path in the final finish.
    @TestVisible
    private static Integer totalErrorsOverride;

    private Stage runStage;

    // Computed once in the Stage-1 constructor and passed to Stage 2, so both stages
    // agree on "past retention" across a long run.
    @TestVisible
    private DateTime cutoff;

    private Id stage1JobId;

    /**
     * @description Default constructor uses settings for retention days.
     */
    public util_closer_LogCleanupBatch() {
        this(util_closer_SettingsService.getLogRetentionDays());
    }

    /**
     * @description Constructor with explicit retention days for testing.
     * @param retentionDays Number of days to retain logs.
     */
    public util_closer_LogCleanupBatch(Integer retentionDays) {
        Integer days = retentionDays != null && retentionDays > 0
            ? retentionDays
            : DEFAULT_RETENTION_DAYS;
        this.runStage = Stage.CASE_LOGS;
        this.cutoff = DateTime.now().addDays(-days);
    }

    /**
     * @description Stage-aware constructor used to chain Stage 2 from Stage 1's finish.
     * @param stage The stage to run.
     * @param cutoff The retention cutoff computed by Stage 1.
     * @param stage1JobId Stage 1's AsyncApexJob Id, for the final error check.
     */
    @TestVisible
    private util_closer_LogCleanupBatch(Stage stage, DateTime cutoff, Id stage1JobId) {
        this.runStage = stage;
        this.cutoff = cutoff;
        this.stage1JobId = stage1JobId;
    }

    /**
     * @description Schedulable execute method to run the cleanup batch.
     * @param sc The schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new util_closer_LogCleanupBatch(), SCOPE_SIZE);
    }

    /**
     * @description Start method queries the current stage's deletion candidates.
     * Both stages use "< :cutoff", which deliberately excludes parents with a null
     * Start_Time__c: unknown age means never delete.
     * @param bc The batchable context.
     * @return QueryLocator for the records to delete in this stage.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        util_closer_Logger.debug('LogCleanupBatch',
            'Starting ' + this.runStage + ' cleanup for logs older than ' + this.cutoff);

        if (this.runStage == Stage.CASE_LOGS) {
            return Database.getQueryLocator([
                SELECT Id
                FROM util_closer_Case_Log__c
                WHERE Batch_Log__r.Start_Time__c < :this.cutoff
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id
            FROM util_closer_Batch_Log__c
            WHERE Start_Time__c < :this.cutoff
        ]);
    }

    /**
     * @description Execute method deletes one chunk of the current stage's records.
     * No try/catch around the delete: a failing chunk must surface (it rolls back only
     * itself, increments AsyncApexJob.NumberOfErrors, fires BatchApexErrorEvent, and the
     * batch continues with the remaining chunks). Its rows are retried on the next run.
     * @param bc The batchable context.
     * @param scope Records to delete in this chunk.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        util_closer_Logger.debug('LogCleanupBatch',
            this.runStage + ': deleting up to ' + scope.size() + ' records');

        if (this.runStage == Stage.CASE_LOGS) {
            List<util_closer_Case_Log__c> caseLogs = new List<util_closer_Case_Log__c>();
            for (SObject record : scope) {
                caseLogs.add((util_closer_Case_Log__c) record);
            }
            util_closer_LogDataAccess.deleteCaseLogs(caseLogs);
            purgeDeleted(caseLogs);
            return;
        }

        // Stage 2 cascade guard: skip any parent that still has children — deleting it
        // would cascade the exact unbounded transaction this job exists to remove
        // (e.g. children surviving a failed Stage-1 chunk). Skipped parents are simply
        // retried on the next run.
        List<util_closer_Batch_Log__c> childlessParents = filterChildlessParents(scope);
        if (childlessParents.isEmpty()) {
            return;
        }
        util_closer_LogDataAccess.deleteBatchLogs(childlessParents);
        purgeDeleted(childlessParents);
    }

    /**
     * @description Finish method. Stage 1 chains Stage 2 unconditionally — finish()
     * runs even after failed chunks, and the Stage-2 childless guard makes that safe.
     * Stage 2 (the final finish) preserves the existing stale-log marking, then sends
     * one error email if any chunk in either stage failed.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        if (this.runStage == Stage.CASE_LOGS) {
            stage2Enqueued = true;
            // Chaining from finish() throws in test context; Stage 2 is tested by
            // constructing it directly.
            if (!Test.isRunningTest()) {
                Database.executeBatch(
                    new util_closer_LogCleanupBatch(Stage.BATCH_LOGS, this.cutoff, bc.getJobId()),
                    SCOPE_SIZE);
            }
            return;
        }

        util_closer_Logger.debug('LogCleanupBatch', 'Cleanup batch completed: ' + bc.getJobId());

        // Mark stale "Running" logs as Failed
        markStaleBatchLogsFailed();

        sendErrorEmailIfAnyChunksFailed(bc.getJobId());
    }

    /**
     * @description Filters a Stage-2 chunk down to parents with no surviving children,
     * using one aggregate query over the chunk's parent Ids.
     * @param scope The Stage-2 chunk of util_closer_Batch_Log__c records.
     * @return Parents safe to delete (no children remain).
     */
    private List<util_closer_Batch_Log__c> filterChildlessParents(List<SObject> scope) {
        Set<Id> parentIds = new Map<Id, SObject>(scope).keySet();
        Set<Id> parentsWithChildren = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Batch_Log__c parentId
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c IN :parentIds
            GROUP BY Batch_Log__c
        ]) {
            parentsWithChildren.add((Id) ar.get('parentId'));
        }

        List<util_closer_Batch_Log__c> childless = new List<util_closer_Batch_Log__c>();
        for (SObject parent : scope) {
            if (!parentsWithChildren.contains(parent.Id)) {
                childless.add((util_closer_Batch_Log__c) parent);
            }
        }
        return childless;
    }

    /**
     * @description Hard-deletes the just-deleted chunk from the Recycle Bin. Runs in its
     * own try/catch: a purge failure must not fail a successful delete — unpurged rows
     * self-heal via the Recycle Bin's ~15-day auto-purge.
     * @param deletedRecords The records deleted earlier in this execute call.
     */
    private void purgeDeleted(List<SObject> deletedRecords) {
        try {
            util_closer_LogDataAccess.purgeFromRecycleBin(
                new List<Id>(new Map<Id, SObject>(deletedRecords).keySet()));
        } catch (Exception ex) {
            util_closer_Logger.error('LogCleanupBatch - purgeDeleted', ex);
        }
    }

    /**
     * @description Sums NumberOfErrors across both stages' jobs and sends one error
     * email via the existing NotificationService if any chunk failed. The job can no
     * longer report success while silently doing nothing.
     * @param stage2JobId The final (Stage 2) AsyncApexJob Id.
     */
    private void sendErrorEmailIfAnyChunksFailed(Id stage2JobId) {
        try {
            Set<Id> jobIds = new Set<Id>{ stage2JobId };
            if (this.stage1JobId != null) {
                jobIds.add(this.stage1JobId);
            }

            Integer totalErrors = 0;
            List<String> details = new List<String>();
            for (AsyncApexJob job : [
                SELECT Id, NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus
                FROM AsyncApexJob
                WHERE Id IN :jobIds
            ]) {
                totalErrors += job.NumberOfErrors == null ? 0 : job.NumberOfErrors;
                details.add('Job ' + job.Id + ': ' + job.NumberOfErrors + ' of ' +
                    job.TotalJobItems + ' chunks failed' +
                    (String.isBlank(job.ExtendedStatus) ? '' : ' — ' + job.ExtendedStatus));
            }

            if (totalErrorsOverride != null) {
                totalErrors = totalErrorsOverride;
            }

            if (totalErrors > 0) {
                util_closer_NotificationService.sendErrorNotification(
                    'Log cleanup completed with ' + totalErrors + ' failed chunk(s)',
                    'Failed chunks roll back only themselves; their rows are retried on the ' +
                        'next run. Details: ' + String.join(details, ' | '),
                    null);
            }
        } catch (Exception ex) {
            util_closer_Logger.error('LogCleanupBatch - sendErrorEmailIfAnyChunksFailed', ex);
        }
    }

    /**
     * @description Identifies and marks stale "Running" batch logs as Failed.
     * A batch log is considered stale if it's been "Running" for more than 24 hours.
     */
    private void markStaleBatchLogsFailed() {
        try {
            List<util_closer_Batch_Log__c> staleLogs = util_closer_LogDataAccess.queryStaleBatchLogs(STALE_LOG_HOURS);

            if (staleLogs.isEmpty()) {
                return;
            }

            util_closer_Logger.debug('LogCleanupBatch',
                'Found ' + staleLogs.size() + ' stale batch logs to mark as failed');

            for (util_closer_Batch_Log__c log : staleLogs) {
                log.Status__c = 'Failed';
                log.End_Time__c = DateTime.now();
                log.Error_Summary__c = 'Batch log marked as failed - was running for more than ' +
                    STALE_LOG_HOURS + ' hours without completion.';
            }

            update staleLogs;
        } catch (Exception ex) {
            util_closer_Logger.error('LogCleanupBatch - markStaleBatchLogsFailed', ex);
        }
    }

    /**
     * @description Schedules the cleanup batch to run daily at 3 AM.
     * @return The scheduled job Id.
     */
    public static String scheduleDaily() {
        return scheduleDaily('0 0 3 * * ?');
    }

    /**
     * @description Schedules the cleanup batch with a custom cron expression.
     * @param cronExpression The cron expression for scheduling.
     * @return The scheduled job Id.
     */
    public static String scheduleDaily(String cronExpression) {
        String jobName = 'util_closer_LogCleanupBatch';

        // Abort existing job if present
        List<CronTrigger> existingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];

        if (!existingJobs.isEmpty()) {
            System.abortJob(existingJobs[0].Id);
        }

        return System.schedule(jobName, cronExpression, new util_closer_LogCleanupBatch());
    }
}