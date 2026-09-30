public with sharing class PVLApplicationStatusFreshnessService {
    public static final String STATE_FRESH_ENOUGH = 'fresh_enough';
    public static final String STATE_STORED_ONLY = 'stored_only';
    public static final String STATE_BATCH_WINDOW = 'batch_window';
    public static final String STATE_DEPENDENCY_STALE_RISK = 'dependency_stale_risk';
    public static final String STATE_CLEANUP_RISK = 'cleanup_risk';

    public static final String POLICY_DELIVER_STATUS = 'deliver_status';
    public static final String POLICY_OFFER_TRANSFER = 'offer_transfer';
    public static final String POLICY_TEMPORARILY_UNAVAILABLE = 'temporarily_unavailable';

    private static final String STATUS_A1_RAW = 'A1 - Application Submitted, Awaiting Review';
    private static final String STATUS_A1_IVR = 'A1 - Awaiting Review';
    private static final String STATUS_A3 = 'A3 - Deficiency Notice Sent';
    private static final String STATUS_AP = 'AP - Application Pending Submittal by Applicant/Licensee';
    private static final Set<String> DEPENDENCY_SENSITIVE_STATUSES = new Set<String>{
        'D1 - Awaiting Dependency Review',
        'D2 - Dependency Review Complete',
        'L1 - Awaiting License Review'
    };
    private static final Set<String> RENEWAL_RESTORE_TYPES = new Set<String>{
        'RNEW - Renewal',
        'RSTR - Restore - No A/I Status',
        'RSTRA - Restore Active'
    };

    @TestVisible
    private static Boolean forceBatchWindowForTest = false;
    @TestVisible
    private static Boolean forceCleanupRiskForTest = false;
    @TestVisible
    private static Boolean forceRespondByOverdueForTest = false;

    public class Evaluation {
        public Id applicationId;
        public String sourceStatus;
        public String ivrStatus;
        public String messageKey;
        public String freshnessState;
        public String responsePolicy;
        public Datetime verifiedAt;
        public Datetime sourceStatusSystemModstamp;
        public Datetime lastRelevantJobCompletedAt;
        public List<String> reasonCodes = new List<String>();

        public IVR_Application_Status_Snapshot__c toSnapshot() {
            if (applicationId == null) {
                return null;
            }

            return new IVR_Application_Status_Snapshot__c(
                Application__c = applicationId,
                Application_Key__c = String.valueOf(applicationId),
                IVR_Status__c = ivrStatus,
                IVR_Status_Message_Key__c = messageKey,
                IVR_Status_Verified_At__c = verifiedAt,
                IVR_Response_Policy__c = responsePolicy,
                Freshness_State__c = freshnessState,
                Source_Status__c = sourceStatus,
                Source_Status_SystemModstamp__c = sourceStatusSystemModstamp,
                Last_Relevant_Job_Completed_At__c = lastRelevantJobCompletedAt,
                Reason_Codes__c = String.join(reasonCodes, ';')
            );
        }
    }

    public static Evaluation evaluate(Application__c applicationRecord) {
        return evaluate(applicationRecord, System.now());
    }

    public static Evaluation evaluate(Application__c applicationRecord, Datetime evaluatedAt) {
        Evaluation evaluation = baseEvaluation(applicationRecord, evaluatedAt);

        if (applicationRecord == null) {
            failClosed(evaluation, STATE_STORED_ONLY, POLICY_TEMPORARILY_UNAVAILABLE, 'APPLICATION_MISSING');
            return evaluation;
        }
        if (String.isBlank(applicationRecord.Status__c)) {
            failClosed(evaluation, STATE_STORED_ONLY, POLICY_OFFER_TRANSFER, 'STATUS_MISSING');
            return evaluation;
        }
        if (isCoreBatchWindow(evaluatedAt)) {
            failClosed(evaluation, STATE_BATCH_WINDOW, POLICY_TEMPORARILY_UNAVAILABLE, 'BATCH_WINDOW_ACTIVE');
            return evaluation;
        }
        if (isRespondByOverdue(applicationRecord)) {
            failClosed(evaluation, STATE_STORED_ONLY, POLICY_OFFER_TRANSFER, 'STATUS_NOT_IVR_ELIGIBLE');
            return evaluation;
        }
        if (isCleanupRisk(applicationRecord)) {
            failClosed(evaluation, STATE_CLEANUP_RISK, POLICY_OFFER_TRANSFER, 'CLEANUP_RISK');
            return evaluation;
        }
        if (isDependencyRisk(applicationRecord)) {
            failClosed(evaluation, STATE_DEPENDENCY_STALE_RISK, POLICY_OFFER_TRANSFER, 'DEPENDENCY_STALE_RISK');
            return evaluation;
        }
        if (!isMvpStatus(applicationRecord.Status__c)) {
            failClosed(evaluation, STATE_STORED_ONLY, POLICY_OFFER_TRANSFER, 'STATUS_NOT_IVR_ELIGIBLE');
            return evaluation;
        }

        evaluation.freshnessState = STATE_FRESH_ENOUGH;
        evaluation.responsePolicy = POLICY_DELIVER_STATUS;
        evaluation.reasonCodes.add('FRESH_ENOUGH');
        return evaluation;
    }

    public static void refreshSnapshots(List<Application__c> applications) {
        refreshSnapshots(applications, System.now());
    }

    public static void refreshSnapshots(List<Application__c> applications, Datetime evaluatedAt) {
        List<IVR_Application_Status_Snapshot__c> snapshots = new List<IVR_Application_Status_Snapshot__c>();
        for (Application__c applicationRecord : applications) {
            IVR_Application_Status_Snapshot__c snapshot = evaluate(applicationRecord, evaluatedAt).toSnapshot();
            if (snapshot != null) {
                snapshots.add(snapshot);
            }
        }

        if (!snapshots.isEmpty()) {
            upsert snapshots IVR_Application_Status_Snapshot__c.Application_Key__c;
        }
    }

    private static Evaluation baseEvaluation(Application__c applicationRecord, Datetime evaluatedAt) {
        Evaluation evaluation = new Evaluation();
        evaluation.verifiedAt = evaluatedAt;
        evaluation.lastRelevantJobCompletedAt = null;

        if (applicationRecord != null) {
            evaluation.applicationId = applicationRecord.Id;
            evaluation.sourceStatus = applicationRecord.Status__c;
            evaluation.ivrStatus = normalizeIvrStatus(applicationRecord.Status__c);
            evaluation.messageKey = messageKey(applicationRecord, evaluation.ivrStatus);
            evaluation.sourceStatusSystemModstamp = applicationRecord.SystemModstamp;
        }

        return evaluation;
    }

    private static void failClosed(Evaluation evaluation, String state, String policy, String reasonCode) {
        evaluation.freshnessState = state;
        evaluation.responsePolicy = policy;
        evaluation.reasonCodes.add(reasonCode);
    }

    private static String normalizeIvrStatus(String sourceStatus) {
        if (sourceStatus == STATUS_A1_RAW) {
            return STATUS_A1_IVR;
        }
        return sourceStatus;
    }

    private static String messageKey(Application__c applicationRecord, String ivrStatus) {
        if (applicationRecord == null || String.isBlank(ivrStatus)) {
            return null;
        }
        if (ivrStatus == STATUS_A3) {
            return applicationRecord.DeficiencyDueDate__c == null
                ? 'PVL_APP_STATUS_A3_NO_DUE_DATE'
                : 'PVL_APP_STATUS_A3_WITH_DUE_DATE';
        }
        if (ivrStatus == STATUS_A1_IVR) {
            return applicationRecord.ApplicationReceivedDate__c == null
                ? 'PVL_APP_STATUS_A1_NO_RECEIVED_DATE'
                : 'PVL_APP_STATUS_A1_WITH_RECEIVED_DATE';
        }
        return null;
    }

    private static Boolean isMvpStatus(String sourceStatus) {
        return sourceStatus == STATUS_A1_RAW || sourceStatus == STATUS_A1_IVR || sourceStatus == STATUS_A3;
    }

    private static Boolean isRespondByOverdue(Application__c applicationRecord) {
        return forceRespondByOverdueForTest ||
            applicationRecord.ApplicationRespondbyDate__c != null &&
            applicationRecord.ApplicationRespondbyDate__c < Date.today();
    }

    private static Boolean isCleanupRisk(Application__c applicationRecord) {
        return forceCleanupRiskForTest ||
            (
                applicationRecord.Status__c == STATUS_AP &&
                RENEWAL_RESTORE_TYPES.contains(applicationRecord.Type__c) &&
                applicationRecord.OnlineApplicationType__c == 'Online Renewal/Restore' &&
                applicationRecord.LastModifiedDate != null &&
                applicationRecord.LastModifiedDate < System.now().addDays(-7)
            );
    }

    private static Boolean isDependencyRisk(Application__c applicationRecord) {
        if (DEPENDENCY_SENSITIVE_STATUSES.contains(applicationRecord.Status__c)) {
            return true;
        }
        if (applicationRecord.DependencyRequired__c == true) {
            return true;
        }
        if (applicationRecord.DependentLicense__c != null || applicationRecord.DependentLicense2__c != null) {
            return true;
        }
        if (applicationRecord.DependentApplication__c != null) {
            return true;
        }
        if (applicationRecord.LicenseType__r != null) {
            if (
                applicationRecord.LicenseType__r.DependencyRequired__c == true ||
                applicationRecord.LicenseType__r.X2ndDependencyRequired__c == true ||
                applicationRecord.LicenseType__r.RequiresInsurance__c == true
            ) {
                return true;
            }
        }
        if (hasParentChangedAfterApplication(applicationRecord.CurrentLicense__r, applicationRecord.SystemModstamp)) {
            return true;
        }
        if (hasParentChangedAfterApplication(applicationRecord.DependentLicense__r, applicationRecord.SystemModstamp)) {
            return true;
        }
        if (hasParentChangedAfterApplication(applicationRecord.DependentLicense2__r, applicationRecord.SystemModstamp)) {
            return true;
        }
        if (hasParentChangedAfterApplication(applicationRecord.DependentApplication__r, applicationRecord.SystemModstamp)) {
            return true;
        }
        return false;
    }

    private static Boolean hasParentChangedAfterApplication(SObject parentRecord, Datetime applicationStamp) {
        if (parentRecord == null || applicationStamp == null) {
            return false;
        }
        Datetime parentStamp = (Datetime) parentRecord.get('SystemModstamp');
        return parentStamp != null && parentStamp > applicationStamp;
    }

    private static Boolean isCoreBatchWindow(Datetime evaluatedAt) {
        if (forceBatchWindowForTest) {
            return true;
        }

        Datetime hst = evaluatedAt.addHours(-10);
        Integer minutes = Integer.valueOf(hst.formatGmt('HH')) * 60 + Integer.valueOf(hst.formatGmt('mm'));
        Integer startMinutes = (23 * 60) + 55;
        Integer endMinutes = (4 * 60) + 30;
        return minutes >= startMinutes || minutes <= endMinutes;
    }
}