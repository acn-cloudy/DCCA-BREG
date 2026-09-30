/**
 * @description Test class for util_closer_LogCleanupBatch (CALL-691 child-first rewrite).
 * Covers both stages, the retention boundary, the Stage-2 cascade guard, hard delete,
 * scheduling, and the runner permission set.
 *
 * Test-context limits (deliberate): Test.stopTest() guarantees a single execute() cycle,
 * and chaining Database.executeBatch from finish() throws in test context — so Stage 2 is
 * tested by constructing it directly, and the chain is asserted via the stage2Enqueued
 * seam. Multi-chunk iteration, real chaining, and wall clock are provable only in live
 * runs (see the CALL-691 rollout plan in ops/log-cleanup/). Database.emptyRecycleBin's
 * physical purge is deferred in test context (ALL ROWS still sees the rows), so deletion
 * is asserted with plain COUNT() here and hard delete is proven by the DAL purge-result
 * test plus org-level ALL ROWS checks in the live devcc/migration/prod runs.
 */
@isTest
private class util_closer_LogCleanupBatch_Test {

    private static final String HV_PARENT_MARKER = '707HVPARENT000000X';

    @TestSetup
    static void setup() {
        // Settings with 90 day retention
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettingsWithLogging(true, 90);
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);

        // Aged parent for the high-volume test, seeded here because its 10,000 children
        // already consume the test method's entire 10,000-DML-rows/txn budget.
        // NOTE for other tests: this childless, past-retention parent exists in every
        // method — keep assertions Id-scoped.
        util_closer_Batch_Log__c hvParent = util_closer_TestDataFactory.createBatchLog('Completed', false);
        hvParent.Batch_Job_Id__c = HV_PARENT_MARKER;
        hvParent.Start_Time__c = DateTime.now().addDays(-100);
        insert hvParent;
    }

    private static util_closer_Batch_Log__c insertBatchLogAgedDays(Integer daysOld) {
        util_closer_Batch_Log__c log = util_closer_TestDataFactory.createBatchLog('Completed', false);
        log.Start_Time__c = DateTime.now().addDays(-daysOld);
        insert log;
        return log;
    }

    private static List<util_closer_Case_Log__c> insertChildren(Id parentId, Integer count) {
        List<util_closer_Case_Log__c> children =
            util_closer_TestDataFactory.createCaseLogs(parentId, count, 'Updated');
        insert children;
        return children;
    }

    private static util_closer_LogCleanupBatch newStage2(Id stage1JobId) {
        return new util_closer_LogCleanupBatch(
            util_closer_LogCleanupBatch.Stage.BATCH_LOGS,
            DateTime.now().addDays(-90),
            stage1JobId);
    }

    // ==================== Stage 1 ====================

    @isTest
    static void testStage1_HardDeletesOldChildren() {
        util_closer_Batch_Log__c oldLog = insertBatchLogAgedDays(100);
        insertChildren(oldLog.Id, 200);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000);
        Test.stopTest();

        Integer childCount = [
            SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id
        ];
        Integer parentCount = [
            SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :oldLog.Id
        ];

        Assert.areEqual(0, childCount,
            'Old children should be deleted (physical purge verified in live runs)');
        Assert.areEqual(1, parentCount,
            'Stage 1 must not touch the parent — Stage 2 owns parent deletion');
    }

    @isTest
    static void testStage1_RecentParentUntouched() {
        util_closer_Batch_Log__c oldLog = insertBatchLogAgedDays(100);
        insertChildren(oldLog.Id, 5);
        util_closer_Batch_Log__c recentLog = insertBatchLogAgedDays(10);
        insertChildren(recentLog.Id, 5);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000);
        Test.stopTest();

        Assert.areEqual(0,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id],
            'Children of the past-retention parent should be deleted');
        Assert.areEqual(5,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :recentLog.Id],
            'Children of the recent parent must survive (retention boundary)');
    }

    @isTest
    static void testStage1_NoEligibleChildren_CleanNoOp() {
        util_closer_Batch_Log__c recentLog = insertBatchLogAgedDays(10);
        insertChildren(recentLog.Id, 3);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000);
        Test.stopTest();

        Assert.areEqual(3,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :recentLog.Id],
            'A run with no eligible children must be a clean no-op');
        Assert.areEqual(true, util_closer_LogCleanupBatch.stage2Enqueued,
            'Stage 2 is still chained after an empty Stage 1');
    }

    @isTest
    static void testStage1_FinishFlagsStage2Chain() {
        util_closer_Batch_Log__c oldLog = insertBatchLogAgedDays(100);
        insertChildren(oldLog.Id, 3);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000);
        Test.stopTest();

        Assert.areEqual(true, util_closer_LogCleanupBatch.stage2Enqueued,
            'Stage 1 finish must chain Stage 2 (asserted via the test seam)');
    }

    // ==================== Stage 2 ====================

    @isTest
    static void testStage2_HardDeletesChildlessOldParents() {
        util_closer_Batch_Log__c oldLog = insertBatchLogAgedDays(100);

        Test.startTest();
        Database.executeBatch(newStage2(null), 2000);
        Test.stopTest();

        Assert.areEqual(0,
            [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :oldLog.Id],
            'Childless past-retention parent should be deleted by Stage 2');
    }

    @isTest
    static void testStage2_SkipsParentWithSurvivingChildren() {
        util_closer_Batch_Log__c oldLog = insertBatchLogAgedDays(100);
        insertChildren(oldLog.Id, 3);
        // Give the setup HV parent children too, so every parent in the Stage-2 chunk
        // still has children and the whole chunk is skipped (covers the empty-chunk return).
        util_closer_Batch_Log__c hvParent = [
            SELECT Id FROM util_closer_Batch_Log__c WHERE Batch_Job_Id__c = :HV_PARENT_MARKER
        ];
        insertChildren(hvParent.Id, 1);

        Test.startTest();
        Database.executeBatch(newStage2(null), 2000);
        Test.stopTest();

        Assert.areEqual(1,
            [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :oldLog.Id],
            'A parent still holding children must be skipped (cascade guard) and retried next run');
        Assert.areEqual(3,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id],
            'Surviving children must not be cascade-deleted');
    }

    @isTest
    static void testNullStartTimeParentIgnoredBothStages() {
        // Unknown age -> never delete: both stages' "< :cutoff" excludes null Start_Time__c.
        util_closer_Batch_Log__c nullTimeLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        nullTimeLog.Start_Time__c = null;
        insert nullTimeLog;
        insertChildren(nullTimeLog.Id, 3);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000); // Stage 1
        Database.executeBatch(newStage2(null), 2000);                     // Stage 2
        Test.stopTest();

        Assert.areEqual(1,
            [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :nullTimeLog.Id],
            'Null Start_Time__c parent must survive both stages');
        Assert.areEqual(3,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :nullTimeLog.Id],
            'Children of a null Start_Time__c parent must survive Stage 1');
    }

    // ==================== Final finish: stale marking + error email ====================

    @isTest
    static void testStage2Finish_MarksStaleRunningLogsFailed() {
        util_closer_Batch_Log__c staleLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        staleLog.Start_Time__c = DateTime.now().addHours(-48);
        staleLog.End_Time__c = null;
        insert staleLog;

        Test.startTest();
        Database.executeBatch(newStage2(null), 2000);
        Test.stopTest();

        util_closer_Batch_Log__c updated = [
            SELECT Status__c, Error_Summary__c, End_Time__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :staleLog.Id
        ];

        Assert.areEqual('Failed', updated.Status__c, 'Stale log should be marked as Failed');
        Assert.areNotEqual(null, updated.End_Time__c, 'End time should be set');
        Assert.isTrue(updated.Error_Summary__c.contains('24 hours'), 'Error summary should mention 24 hours');
    }

    @isTest
    static void testNoStaleLogs_RecentRunningLogUntouched() {
        util_closer_Batch_Log__c recentRunning = util_closer_TestDataFactory.createBatchLog('Running', false);
        recentRunning.Start_Time__c = DateTime.now().addMinutes(-30);
        recentRunning.End_Time__c = null;
        insert recentRunning;

        Test.startTest();
        Database.executeBatch(newStage2(null), 2000);
        Test.stopTest();

        util_closer_Batch_Log__c log = [
            SELECT Status__c FROM util_closer_Batch_Log__c WHERE Id = :recentRunning.Id
        ];
        Assert.areEqual('Running', log.Status__c,
            'Recent running log should not be marked as failed');
    }

    @isTest
    static void testStage2Finish_SendsErrorEmailWhenChunksFailed() {
        // NumberOfErrors cannot be fabricated in test context, so the failure total is
        // injected via the test seam to exercise the notification path end to end.
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettingsWithLogging(true, 90);
        settings.Error_Notification_Emails__c = 'ops@example.com';
        util_closer_SettingsService.mockSettings = settings;

        util_closer_LogCleanupBatch.totalErrorsOverride = 2;

        Test.startTest();
        // A syntactically valid AsyncApexJob Id that matches no row: exercises the
        // stage1JobId branch of the final error check without needing a real Stage-1 job.
        Database.executeBatch(newStage2(Id.valueOf('707000000000000AAA')), 2000);
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Status FROM AsyncApexJob
            WHERE ApexClass.Name = 'util_closer_LogCleanupBatch' AND JobType = 'BatchApex'
        ];
        Assert.areEqual(1, jobs.size(), 'The Stage-2 job should have run');
        Assert.areEqual('Completed', jobs[0].Status,
            'The error email path must not fail the final finish');
    }

    // ==================== High volume ====================

    @isTest
    static void testHighVolume_SingleChunkAt2000_NoLimits() {
        // Proves one execute() at the fixed scope size stays within governor limits
        // against a 10,000-child parent (prod max fanout is ~25,830, but per-chunk cost
        // is capped by scope, not fanout). Multi-chunk iteration (~300 chunks on the
        // prod backlog) is provable only in live runs — see the CALL-691 rollout plan.
        util_closer_Batch_Log__c hvParent = [
            SELECT Id FROM util_closer_Batch_Log__c WHERE Batch_Job_Id__c = :HV_PARENT_MARKER
        ];
        // 10,500 children total: 9,000 seeded here, 1,500 inside Test.startTest() —
        // the 10,000-DML-rows/txn limit makes a single-transaction 10k+ seed impossible.
        insertChildren(hvParent.Id, 9000);

        Test.startTest();
        insertChildren(hvParent.Id, 1500);
        List<util_closer_Case_Log__c> scope = [
            SELECT Id FROM util_closer_Case_Log__c WHERE Batch_Log__c = :hvParent.Id LIMIT 2000
        ];
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        batch.execute(null, scope);
        Test.stopTest();

        Assert.areEqual(8500,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :hvParent.Id],
            'Exactly the 2,000-row chunk should be deleted, with no LimitException');
    }

    // ==================== Constructors / settings ====================

    @isTest
    static void testConstructor_InvalidRetention_FallsBackTo90() {
        DateTime lowerBound = DateTime.now().addDays(-90).addMinutes(-2);
        DateTime upperBound = DateTime.now().addDays(-90).addMinutes(2);

        for (Integer invalidRetention : new List<Integer>{ null, 0, -10 }) {
            util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(invalidRetention);
            Assert.isTrue(batch.cutoff > lowerBound && batch.cutoff < upperBound,
                'Retention ' + invalidRetention + ' must fall back to 90 days; cutoff was ' + batch.cutoff);
        }
    }

    @isTest
    static void testRetentionDaysReadFromSettings() {
        util_closer_SettingsService.mockSettings =
            util_closer_TestDataFactory.createSettingsWithLogging(true, 30);

        util_closer_Batch_Log__c pastRetention = insertBatchLogAgedDays(40);
        insertChildren(pastRetention.Id, 2);
        util_closer_Batch_Log__c withinRetention = insertBatchLogAgedDays(20);
        insertChildren(withinRetention.Id, 2);

        Test.startTest();
        Database.executeBatch(new util_closer_LogCleanupBatch(), 2000); // default ctor reads settings
        Test.stopTest();

        Assert.areEqual(0,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :pastRetention.Id],
            '40-day children must be deleted under 30-day retention from settings');
        Assert.areEqual(2,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :withinRetention.Id],
            '20-day children must survive under 30-day retention from settings');
    }

    // ==================== Scheduling ====================

    @isTest
    static void testSchedulable_EnqueuesStage1Batch() {
        Test.startTest();
        new util_closer_LogCleanupBatch().execute((SchedulableContext) null);
        Test.stopTest();

        Integer jobCount = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'util_closer_LogCleanupBatch' AND JobType = 'BatchApex'
        ];
        Assert.isTrue(jobCount >= 1,
            'Schedulable execute must enqueue the Stage-1 batch job');
    }

    @isTest
    static void testScheduleDaily() {
        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        Assert.areEqual(1, jobs.size(), 'Job should be scheduled');
        Assert.areEqual('0 0 3 * * ?', jobs[0].CronExpression, 'Should use default cron');
    }

    @isTest
    static void testScheduleDaily_CustomCron() {
        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily('0 0 6 * * ?');
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        Assert.areEqual(1, jobs.size(), 'Job should be scheduled');
        Assert.areEqual('0 0 6 * * ?', jobs[0].CronExpression, 'Should use custom cron');
    }

    @isTest
    static void testScheduleDaily_ReplacesExisting() {
        util_closer_LogCleanupBatch.scheduleDaily('0 0 3 * * ?');

        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily('0 0 6 * * ?');
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        Assert.areEqual(1, jobs.size(), 'Should only have one scheduled job');
        Assert.areEqual('0 0 6 * * ?', jobs[0].CronExpression, 'Should use new cron');
    }

    // ==================== Runner permission set ====================

    @isTest
    static void testRunner_PermissionSet() {
        // Proves the two load-bearing claims about util_closer_CleanupJobRunner:
        // the runner can schedule the job, and the batch still deletes even though the
        // permission set grants zero delete permissions (batch DML is system mode).
        User runner = util_closer_TestDataFactory.createUserWithPermissionSet('util_closer_CleanupJobRunner');

        util_closer_Batch_Log__c oldLog;
        // Separate setup-object DML (User/PermissionSetAssignment) from log DML.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            oldLog = insertBatchLogAgedDays(100);
            insertChildren(oldLog.Id, 5);
        }

        System.runAs(runner) {
            Test.startTest();
            String cronId = util_closer_LogCleanupBatch.scheduleDaily();
            Assert.areNotEqual(null, cronId, 'Runner must be able to schedule the job');
            Database.executeBatch(new util_closer_LogCleanupBatch(90), 2000);
            Test.stopTest();
        }

        Assert.areEqual(0,
            [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id],
            'Batch submitted by the delete-permission-free runner must still delete (system-mode DML)');
    }
}