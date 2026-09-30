@IsTest
private class PVLApplicationStatusServiceTest {
    @IsTest
    static void deliversA1StatusFromAccountPhone() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A1', '808-555-0101', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'A1');
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('+18085550101', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('deliver_status', response.responsePolicy);
        System.assertEquals('A1_AWAITING_REVIEW', response.statusCategory);
        System.assertEquals('PVL_APP_STATUS_A1_WITH_RECEIVED_DATE', response.messageKey);
        System.assert(response.spokenMessage.contains('in queue for review'));
    }

    @IsTest
    static void deliversA3StatusFromAccountPhone() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A3', '808-555-0102', '223456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'A3',
            'A1 - Application Submitted, Awaiting Review',
            Date.today().addDays(30),
            null
        );
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A3 - Deficiency Notice Sent',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550102', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('A3_DEFICIENCY_NOTICE_SENT', response.statusCategory);
        System.assertEquals('PVL_APP_STATUS_A3_WITH_DUE_DATE', response.messageKey);
    }

    @IsTest
    static void applicationPhoneOnlyDoesNotMatch() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('AppPhoneOnly', null, '123456789');
        PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'AppPhoneOnly',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(30),
            '808-555-0103'
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550103', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('NO_ACCOUNT_MATCH', response.handoffReason);
    }

    @IsTest
    static void noAccountMatchTransfers() {
        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550201', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('NO_ACCOUNT_MATCH', response.handoffReason);
    }

    @IsTest
    static void multipleAccountMatchesTransfer() {
        PVLApplicationStatusTestFactory.createPersonAccount('Multi1', '808-555-0202', '123456789');
        PVLApplicationStatusTestFactory.createPersonAccount('Multi2', '808-555-0202', '987656789');

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550202', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('MULTIPLE_ACCOUNTS', response.handoffReason);
    }

    @IsTest
    static void zeroOpenApplicationsTransfers() {
        PVLApplicationStatusTestFactory.createPersonAccount('NoApp', '808-555-0203', '123456789');

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550203', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('NO_OPEN_APPLICATION', response.handoffReason);
    }

    @IsTest
    static void multipleOpenApplicationsTransfer() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('MultiApp', '808-555-0204', '123456789');
        PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'MultiApp1');
        PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'MultiApp2');

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550204', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('MULTIPLE_OPEN_APPLICATIONS', response.handoffReason);
    }

    @IsTest
    static void overdueRespondByTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('Overdue', '808-555-0205', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'Overdue',
            'A1 - Application Submitted, Awaiting Review',
            Date.today().addDays(-1),
            null
        );
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.forceRespondByOverdueForTest = true;
        PVLApplicationStatusService.ResponseEnvelope response;
        try {
            response = PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550205', '6789'));
        } finally {
            PVLApplicationStatusService.forceRespondByOverdueForTest = false;
        }

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('STATUS_NOT_IVR_ELIGIBLE', response.handoffReason);
    }

    @IsTest
    static void a3ExpiredApplicationRespondByTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A3Expired', '808-555-0212', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'A3Expired',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(-1),
            null
        );
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A3 - Deficiency Notice Sent',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.forceRespondByOverdueForTest = true;
        PVLApplicationStatusService.ResponseEnvelope response;
        try {
            response = PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550212', '6789'));
        } finally {
            PVLApplicationStatusService.forceRespondByOverdueForTest = false;
        }

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('STATUS_NOT_IVR_ELIGIBLE', response.handoffReason);
        System.assertEquals(null, response.messageKey);
        System.assertEquals(null, response.statusCategory);
    }

    @IsTest
    static void a3PastDeficiencyDueDateStillDeliversWhenApplicationRespondByCurrent() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A3PastNodDue', '808-555-0213', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'A3PastNodDue',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(30),
            null
        );
        applicationRecord.DeficiencyDueDate__c = Date.today().addDays(-1);
        update applicationRecord;
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A3 - Deficiency Notice Sent',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550213', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('A3_DEFICIENCY_NOTICE_SENT', response.statusCategory);
        System.assertEquals('PVL_APP_STATUS_A3_WITH_DUE_DATE', response.messageKey);
    }

    @IsTest
    static void a1WithoutReceivedDateUsesNoDateMessage() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A1NoReceived', '808-555-0214', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'A1NoReceived');
        applicationRecord.ApplicationReceivedDate__c = null;
        update applicationRecord;
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550214', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('PVL_APP_STATUS_A1_NO_RECEIVED_DATE', response.messageKey);
        System.assert(response.spokenMessage.contains('in queue for review'));
    }

    @IsTest
    static void a3WithoutDueDateUsesNoDueDateMessage() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('A3NoDue', '808-555-0215', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(
            accountRecord.Id,
            'A3NoDue',
            'A3 - Deficiency Notice Sent',
            Date.today().addDays(30),
            null
        );
        applicationRecord.DeficiencyDueDate__c = null;
        update applicationRecord;
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A3 - Deficiency Notice Sent',
            'deliver_status',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550215', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('PVL_APP_STATUS_A3_NO_DUE_DATE', response.messageKey);
        System.assertEquals(false, response.spokenMessage.contains('Please respond by'));
    }

    @IsTest
    static void missingSnapshotTemporarilyUnavailable() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('MissingSnap', '808-555-0206', '123456789');
        PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'MissingSnap');

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550206', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_TEMPORARILY_UNAVAILABLE, response.result);
        System.assertEquals('SNAPSHOT_NOT_FOUND', response.handoffReason);
    }

    @IsTest
    static void staleSnapshotTemporarilyUnavailable() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('StaleSnap', '808-555-0207', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'StaleSnap');
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_status',
            System.now().addHours(-37)
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550207', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_TEMPORARILY_UNAVAILABLE, response.result);
        System.assertEquals('SNAPSHOT_STALE', response.handoffReason);
    }

    @IsTest
    static void nonMvpSnapshotStatusTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('NonMvp', '808-555-0208', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'NonMvp');
        IVR_Application_Status_Snapshot__c snapshot = PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'B1 - To Board Awaiting Review',
            'deliver_status',
            System.now()
        );
        snapshot.Reason_Codes__c = 'NON_MVP_STATUS';
        update snapshot;

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550208', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('STATUS_NOT_IVR_ELIGIBLE', response.handoffReason);
        System.assertEquals(true, response.reasonCodes.contains('NON_MVP_STATUS'));
    }

    @IsTest
    static void limitedPolicyReturnsLimitedResult() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('Limited', '808-555-0209', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'Limited');
        IVR_Application_Status_Snapshot__c snapshot = PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_limited_status',
            System.now()
        );
        snapshot.Reason_Codes__c = 'LIMITED_DETAIL';
        update snapshot;

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550209', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_LIMITED_STATUS, response.result);
        System.assertEquals('deliver_limited_status', response.responsePolicy);
        System.assertEquals('PVL_APP_STATUS_LIMITED', response.messageKey);
        System.assertEquals(true, response.reasonCodes.contains('SNAPSHOT_POLICY_LIMITED'));
        System.assertEquals(true, response.reasonCodes.contains('LIMITED_DETAIL'));
    }

    @IsTest
    static void temporarilyUnavailablePolicyReturnsUnavailableResult() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('Unavailable', '808-555-0210', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'Unavailable');
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'temporarily_unavailable',
            System.now()
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550210', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_TEMPORARILY_UNAVAILABLE, response.result);
        System.assertEquals('SNAPSHOT_TEMPORARILY_UNAVAILABLE', response.handoffReason);
    }

    @IsTest
    static void offerTransferSnapshotPolicyPropagatesReasonCodes() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('PolicyTransfer', '808-555-0216', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'PolicyTransfer');
        IVR_Application_Status_Snapshot__c snapshot = PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'offer_transfer',
            System.now()
        );
        snapshot.Reason_Codes__c = 'POLICY_A; POLICY_B\nPOLICY_C';
        update snapshot;

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550216', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('SNAPSHOT_POLICY_TRANSFER', response.handoffReason);
        System.assertEquals(true, response.reasonCodes.contains('SNAPSHOT_POLICY_TRANSFER'));
        System.assertEquals(true, response.reasonCodes.contains('POLICY_A'));
        System.assertEquals(true, response.reasonCodes.contains('POLICY_B'));
        System.assertEquals(true, response.reasonCodes.contains('POLICY_C'));
    }

    @IsTest
    static void blankSnapshotPolicyTransfers() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('BlankPolicy', '808-555-0217', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'BlankPolicy');
        IVR_Application_Status_Snapshot__c snapshot = PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            null,
            System.now()
        );
        snapshot.Reason_Codes__c = 'POLICY_MISSING';
        update snapshot;

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550217', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('SNAPSHOT_POLICY_TRANSFER', response.handoffReason);
        System.assertEquals(true, response.reasonCodes.contains('POLICY_MISSING'));
    }

    @IsTest
    static void latestSnapshotIsUsedForStatusDecision() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount('LatestSnap', '808-555-0218', '123456789');
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'LatestSnap');
        insert new IVR_Application_Status_Snapshot__c(
            Application__c = applicationRecord.Id,
            Application_Key__c = String.valueOf(applicationRecord.Id),
            IVR_Status__c = 'B1 - To Board Awaiting Review',
            IVR_Status_Verified_At__c = System.now().addHours(-2),
            IVR_Response_Policy__c = 'offer_transfer',
            Freshness_State__c = 'stored_only',
            Source_Status__c = 'B1 - To Board Awaiting Review',
            Source_Status_SystemModstamp__c = System.now().addHours(-2),
            Last_Relevant_Job_Completed_At__c = System.now().addHours(-2),
            Reason_Codes__c = 'OLD_SNAPSHOT'
        );
        insert new IVR_Application_Status_Snapshot__c(
            Application__c = applicationRecord.Id,
            Application_Key__c = String.valueOf(applicationRecord.Id).substring(0, 15) + 'NEW',
            IVR_Status__c = 'A1 - Awaiting Review',
            IVR_Status_Verified_At__c = System.now(),
            IVR_Response_Policy__c = 'deliver_status',
            Freshness_State__c = 'fresh_enough',
            Source_Status__c = 'A1 - Awaiting Review',
            Source_Status_SystemModstamp__c = System.now(),
            Last_Relevant_Job_Completed_At__c = System.now(),
            Reason_Codes__c = 'FRESH_ENOUGH'
        );

        PVLApplicationStatusService.ResponseEnvelope response =
            PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550218', '6789'));

        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        System.assertEquals('A1_AWAITING_REVIEW', response.statusCategory);
    }

    @IsTest
    static void invalidRequestsReturnSpecificReasonCodes() {
        assertInvalid(PVLApplicationStatusService.checkStatus(null), 'REQUEST_MISSING');

        PVLApplicationStatusService.RequestEnvelope request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.correlationId = null;
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'CORRELATION_ID_MISSING');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.ccassSessionId = null;
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'CCASS_SESSION_ID_MISSING');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.callId = null;
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'CALL_ID_MISSING');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.payload = null;
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'PAYLOAD_MISSING');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.payload.phoneNumber = null;
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'PHONE_MISSING');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.payload.phoneSource = 'UNAPPROVED';
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'PHONE_SOURCE_INVALID');

        request = PVLApplicationStatusTestFactory.request('8085550220', '6789');
        request.payload.phoneNumber = '808555';
        assertInvalid(PVLApplicationStatusService.checkStatus(request), 'PHONE_INVALID');
    }

    @IsTest
    static void helperSelectorsAndPhoneClientRejectNullInputs() {
        System.assertEquals(true, PVLApplicationStatusSelector.selectOpenApplications(null).isEmpty());
        System.assertEquals(null, PVLApplicationStatusSnapshotSelector.selectLatestForApplication(null));
        System.assertEquals('', PVLApplicationStatusPhoneMatchClient.normalizePhone(null));
        System.assertEquals('555', PVLApplicationStatusPhoneMatchClient.normalizePhone('abc555'));
        System.assertEquals(true, PVLApplicationStatusPhoneMatchClient.findMatchingPersonAccounts('555', '6789').isEmpty());
        System.assertEquals(true, PVLApplicationStatusPhoneMatchClient.findMatchingPersonAccounts('8085550221', null).isEmpty());
    }

    @IsTest
    static void serviceExceptionReturnsError() {
        PVLApplicationStatusService.forceExceptionForTest = true;
        try {
            PVLApplicationStatusService.ResponseEnvelope response =
                PVLApplicationStatusService.checkStatus(PVLApplicationStatusTestFactory.request('8085550211', '6789'));

            System.assertEquals(PVLApplicationStatusService.RESULT_ERROR, response.result);
            System.assertEquals('SALESFORCE_UNAVAILABLE', response.errorCode);
        } finally {
            PVLApplicationStatusService.forceExceptionForTest = false;
        }
    }

    private static void assertInvalid(PVLApplicationStatusService.ResponseEnvelope response, String expectedReasonCode) {
        System.assertEquals(PVLApplicationStatusService.RESULT_INVALID_INPUT, response.result);
        System.assertEquals('INVALID_REQUEST', response.errorCode);
        System.assertEquals(expectedReasonCode, response.handoffReason);
        System.assertEquals(true, response.reasonCodes.contains(expectedReasonCode));
    }
}