@IsTest
private class PVLApplicationStatusFreshnessServiceTest {
    private static Datetime nonBatchWindowTime() {
        Date today = Date.today();
        return Datetime.newInstanceGmt(today.year(), today.month(), today.day(), 22, 0, 0);
    }

    @IsTest
    static void a1ApplicationBuildsDeliverableFreshSnapshot() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('FreshA1', '808-555-0301', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'FreshA1');

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(
                PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                nonBatchWindowTime()
            );
        IVR_Application_Status_Snapshot__c snapshot = evaluation.toSnapshot();

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_FRESH_ENOUGH, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_DELIVER_STATUS, evaluation.responsePolicy);
        System.assertEquals('A1 - Awaiting Review', snapshot.IVR_Status__c);
        System.assertEquals('PVL_APP_STATUS_A1_WITH_RECEIVED_DATE', snapshot.IVR_Status_Message_Key__c);
        System.assertEquals(String.valueOf(applicationRecord.Id), snapshot.Application_Key__c);
    }

    @IsTest
    static void a3ApplicationBuildsDeliverableFreshSnapshot() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('FreshA3', '808-555-0302', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'FreshA3',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(30),
            null
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(
                PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                nonBatchWindowTime()
            );

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_FRESH_ENOUGH, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_DELIVER_STATUS, evaluation.responsePolicy);
        System.assertEquals('A3 - Deficiency Notice Sent', evaluation.ivrStatus);
        System.assertEquals('PVL_APP_STATUS_A3_WITH_DUE_DATE', evaluation.messageKey);
    }

    @IsTest
    static void respondByOverdueTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('OverdueFresh', '808-555-0303', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'OverdueFresh',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(-1),
            null
        );

        Application__c overdueApplication = withRespondByDate(
            PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
            Date.today().addDays(-1)
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(overdueApplication, nonBatchWindowTime());

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_STORED_ONLY, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('STATUS_NOT_IVR_ELIGIBLE'));
    }

    @IsTest
    static void nonMvpStatusTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('NonMvpFresh', '808-555-0304', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'NonMvpFresh',
            'B1 - To Board Awaiting Review',
            Date.today().addDays(30),
            null
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(
                PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                nonBatchWindowTime()
            );

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_STORED_ONLY, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('STATUS_NOT_IVR_ELIGIBLE'));
    }

    @IsTest
    static void missingStatusTransfers() {
        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(new Application__c(), nonBatchWindowTime());

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_STORED_ONLY, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('STATUS_MISSING'));
    }

    @IsTest
    static void batchWindowTemporarilyUnavailable() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('BatchWindow', '808-555-0305', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'BatchWindow');

        PVLApplicationStatusFreshnessService.forceBatchWindowForTest = true;
        try {
            PVLApplicationStatusFreshnessService.Evaluation evaluation =
                PVLApplicationStatusFreshnessService.evaluate(
                    PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                    System.now()
                );

            System.assertEquals(PVLApplicationStatusFreshnessService.STATE_BATCH_WINDOW, evaluation.freshnessState);
            System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_TEMPORARILY_UNAVAILABLE, evaluation.responsePolicy);
            System.assertEquals(true, evaluation.reasonCodes.contains('BATCH_WINDOW_ACTIVE'));
        } finally {
            PVLApplicationStatusFreshnessService.forceBatchWindowForTest = false;
        }
    }

    @IsTest
    static void dependencyRiskTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('DependencyRisk', '808-555-0306', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'DependencyRisk');
        update new LicenseType__c(
            Id = applicationRecord.LicenseType__c,
            DependencyRequired__c = true
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(
                PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                nonBatchWindowTime()
            );

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_DEPENDENCY_STALE_RISK, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('DEPENDENCY_STALE_RISK'));
    }

    @IsTest
    static void dependencySensitiveStatusTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('DependencyStatus', '808-555-0312', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'DependencyStatus',
            'D1 - Awaiting Dependency Review',
            Date.today().addDays(30),
            null
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(
                PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
                nonBatchWindowTime()
            );

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_DEPENDENCY_STALE_RISK, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('DEPENDENCY_STALE_RISK'));
    }

    @IsTest
    static void applicationDependencyFlagTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('DependencyFlag', '808-555-0313', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'DependencyFlag');
        Application__c queriedApplication = withDependencyRequired(
            PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id)
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(queriedApplication, nonBatchWindowTime());

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_DEPENDENCY_STALE_RISK, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('DEPENDENCY_STALE_RISK'));
    }

    @IsTest
    static void cleanupRiskTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('CleanupRisk', '808-555-0307', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'CleanupRisk',
            'AP - Application Pending Submittal by Applicant/Licensee',
            Date.today().addDays(30),
            null,
            'RNEW - Renewal',
            'Online Renewal/Restore'
        );

        Application__c staleApplication = withLastModifiedDate(
            PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id),
            System.now().addDays(-8)
        );

        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(staleApplication, nonBatchWindowTime());

        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_CLEANUP_RISK, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_OFFER_TRANSFER, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('CLEANUP_RISK'));
    }

    @IsTest
    static void nullApplicationFailsClosed() {
        PVLApplicationStatusFreshnessService.Evaluation evaluation =
            PVLApplicationStatusFreshnessService.evaluate(null, System.now().addHours(12));

        System.assertEquals(null, evaluation.toSnapshot());
        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_STORED_ONLY, evaluation.freshnessState);
        System.assertEquals(PVLApplicationStatusFreshnessService.POLICY_TEMPORARILY_UNAVAILABLE, evaluation.responsePolicy);
        System.assertEquals(true, evaluation.reasonCodes.contains('APPLICATION_MISSING'));
    }

    @IsTest
    static void upsertMaintainsOneCurrentSnapshotAndDoesNotMutateApplication() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('UpsertFresh', '808-555-0308', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'UpsertFresh');
        Application__c queriedApplication = PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id);
        String originalStatus = queriedApplication.Status__c;
        Datetime firstVerifiedAt = nonBatchWindowTime();

        PVLApplicationStatusFreshnessService.refreshSnapshots(new List<Application__c>{ queriedApplication }, firstVerifiedAt);
        PVLApplicationStatusFreshnessService.refreshSnapshots(
            new List<Application__c>{ PVLApplicationStatusTestFactory.queryApplicationForFreshness(applicationRecord.Id) },
            firstVerifiedAt.addMinutes(5)
        );

        List<IVR_Application_Status_Snapshot__c> snapshots = [
            SELECT Application__c, Application_Key__c, IVR_Status_Verified_At__c, Freshness_State__c
            FROM IVR_Application_Status_Snapshot__c
            WHERE Application__c = :applicationRecord.Id
        ];
        Application__c afterRefresh = [
            SELECT Status__c
            FROM Application__c
            WHERE Id = :applicationRecord.Id
        ];

        System.assertEquals(1, snapshots.size());
        System.assertEquals(String.valueOf(applicationRecord.Id), snapshots[0].Application_Key__c);
        System.assertEquals(firstVerifiedAt.addMinutes(5), snapshots[0].IVR_Status_Verified_At__c);
        System.assertEquals(PVLApplicationStatusFreshnessService.STATE_FRESH_ENOUGH, snapshots[0].Freshness_State__c);
        System.assertEquals(originalStatus, afterRefresh.Status__c);
    }

    @IsTest
    static void batchRefreshesBoundedApplicationScope() {
        Account includedAccount = PVLApplicationStatusTestFactory.createPersonAccount('BatchIn', '808-555-0309', '123456789');
        Application__c includedApplication = PVLApplicationStatusTestFactory.createApplication(includedAccount.Id, 'BatchIn');
        Account excludedAccount = PVLApplicationStatusTestFactory.createPersonAccount('BatchOut', '808-555-0310', '987656789');
        Application__c excludedApplication = PVLApplicationStatusTestFactory.createApplication(excludedAccount.Id, 'BatchOut');

        Test.startTest();
        Database.executeBatch(new PVLApplicationStatusSnapshotRefreshBatch(new Set<Id>{ includedApplication.Id }), 1);
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT count()
                FROM IVR_Application_Status_Snapshot__c
                WHERE Application__c = :includedApplication.Id
            ]
        );
        System.assertEquals(
            0,
            [
                SELECT count()
                FROM IVR_Application_Status_Snapshot__c
                WHERE Application__c = :excludedApplication.Id
            ]
        );
    }

    @IsTest
    static void schedulerQueuesSnapshotRefreshBatch() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('ScheduledFresh', '808-555-0311', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'ScheduledFresh');

        Test.startTest();
        new PVLAppStatusSnapshotRefreshScheduler().execute(null);
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT count()
                FROM IVR_Application_Status_Snapshot__c
                WHERE Application__c = :applicationRecord.Id
            ]
        );
    }

    @IsTest
    static void scheduleDaily0830HstReturnsJobId() {
        Test.startTest();
        String jobId = PVLAppStatusSnapshotRefreshScheduler.scheduleDaily0830Hst();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    private static Application__c withLastModifiedDate(Application__c applicationRecord, Datetime lastModifiedDate) {
        Map<String, Object> rawFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(applicationRecord));
        rawFields.put('LastModifiedDate', lastModifiedDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ'));
        return (Application__c) JSON.deserialize(JSON.serialize(rawFields), Application__c.class);
    }

    private static Application__c withRespondByDate(Application__c applicationRecord, Date respondByDate) {
        Map<String, Object> rawFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(applicationRecord));
        rawFields.put('ApplicationRespondbyDate__c', String.valueOf(respondByDate));
        return (Application__c) JSON.deserialize(JSON.serialize(rawFields), Application__c.class);
    }

    private static Application__c withDependencyRequired(Application__c applicationRecord) {
        Map<String, Object> rawFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(applicationRecord));
        rawFields.put('DependencyRequired__c', true);
        return (Application__c) JSON.deserialize(JSON.serialize(rawFields), Application__c.class);
    }
}