global with sharing class PVLApplicationStatusService {
    public static final String RESULT_DELIVER_STATUS = 'DELIVER_STATUS';
    public static final String RESULT_DELIVER_LIMITED_STATUS = 'DELIVER_LIMITED_STATUS';
    public static final String RESULT_OFFER_TRANSFER = 'OFFER_TRANSFER';
    public static final String RESULT_TEMPORARILY_UNAVAILABLE = 'TEMPORARILY_UNAVAILABLE';
    public static final String RESULT_INVALID_INPUT = 'INVALID_INPUT';
    public static final String RESULT_ERROR = 'ERROR';

    private static final Integer SNAPSHOT_MAX_AGE_HOURS = 36;
    private static final Set<String> ALLOWED_PHONE_SOURCES = new Set<String>{ 'ANI_CONFIRMED', 'CALLER_ENTERED' };

    @TestVisible
    private static Boolean forceExceptionForTest = false;
    @TestVisible
    private static Boolean forceRespondByOverdueForTest = false;

    global class RequestEnvelope {
        public String correlationId;
        public String ccassSessionId;
        public String callId;
        public String ani;
        public String timestamp;
        public String locale;
        public String path;
        public Payload payload;
    }

    global class Payload {
        public String phoneNumber;
        public String phoneSource;
        public String ssnLast4;
    }

    global class ResponseEnvelope {
        public String correlationId;
        public String result;
        public String responsePolicy;
        public String spokenMessage;
        public String messageKey;
        public String statusCategory;
        public String verifiedAt;
        public String verifiedAgePhrase;
        public List<String> reasonCodes;
        public String handoffReason;
        public String errorCode;
    }

    public static ResponseEnvelope checkStatus(RequestEnvelope request) {
        String correlationId = request == null ? null : request.correlationId;

        try {
            if (forceExceptionForTest) {
                throw new PVLApplicationStatusException('Forced service exception');
            }

            ResponseEnvelope validationError = validateRequest(request);
            if (validationError != null) {
                return validationError;
            }

            String normalizedPhone = PVLApplicationStatusPhoneMatchClient.normalizePhone(request.payload.phoneNumber);
            List<Account> accounts = PVLApplicationStatusPhoneMatchClient.findMatchingPersonAccounts(
                request.payload.phoneNumber,
                request.payload.ssnLast4
            );

            if (accounts.isEmpty()) {
                return offerTransfer(correlationId, 'NO_ACCOUNT_MATCH');
            }
            if (accounts.size() > 1) {
                return offerTransfer(correlationId, 'MULTIPLE_ACCOUNTS');
            }

            List<Application__c> openApplications = PVLApplicationStatusSelector.selectOpenApplications(accounts[0].Id);
            if (openApplications.isEmpty()) {
                return offerTransfer(correlationId, 'NO_OPEN_APPLICATION');
            }
            if (openApplications.size() > 1) {
                return offerTransfer(correlationId, 'MULTIPLE_OPEN_APPLICATIONS');
            }

            Application__c application = openApplications[0];
            if (isRespondByOverdue(application)) {
                return offerTransfer(correlationId, 'STATUS_NOT_IVR_ELIGIBLE');
            }

            IVR_Application_Status_Snapshot__c snapshot =
                PVLApplicationStatusSnapshotSelector.selectLatestForApplication(application.Id);

            if (snapshot == null) {
                return temporarilyUnavailable(correlationId, 'SNAPSHOT_NOT_FOUND');
            }
            if (snapshot.IVR_Status_Verified_At__c == null || isSnapshotStale(snapshot.IVR_Status_Verified_At__c)) {
                return temporarilyUnavailable(correlationId, 'SNAPSHOT_STALE');
            }

            String policy = normalizePolicy(snapshot.IVR_Response_Policy__c);
            if (policy == 'temporarily_unavailable') {
                return temporarilyUnavailable(correlationId, 'SNAPSHOT_TEMPORARILY_UNAVAILABLE');
            }
            if (policy == 'offer_transfer') {
                return offerTransfer(correlationId, 'SNAPSHOT_POLICY_TRANSFER', snapshot.Reason_Codes__c);
            }
            if (policy == 'deliver_limited_status') {
                return deliverLimitedStatus(correlationId, snapshot);
            }
            if (policy != 'deliver_status') {
                return offerTransfer(correlationId, 'SNAPSHOT_POLICY_TRANSFER', snapshot.Reason_Codes__c);
            }
            if (!isMvpStatus(snapshot.IVR_Status__c)) {
                return offerTransfer(correlationId, 'STATUS_NOT_IVR_ELIGIBLE', snapshot.Reason_Codes__c);
            }

            String verifiedAgePhrase = PVLApplicationStatusMessageCatalog.verifiedAgePhrase(snapshot.IVR_Status_Verified_At__c);
            ResponseEnvelope response = base(correlationId, RESULT_DELIVER_STATUS, policy);
            response.spokenMessage = PVLApplicationStatusMessageCatalog.statusMessage(application, snapshot, verifiedAgePhrase);
            response.messageKey = PVLApplicationStatusMessageCatalog.messageKey(application, snapshot);
            response.statusCategory = PVLApplicationStatusMessageCatalog.statusCategory(snapshot);
            response.verifiedAt = formatIsoGmt(snapshot.IVR_Status_Verified_At__c);
            response.verifiedAgePhrase = verifiedAgePhrase;
            return response;
        } catch (Exception ex) {
            return error(correlationId, 'SALESFORCE_UNAVAILABLE');
        }
    }

    public static ResponseEnvelope invalidInput(String correlationId, String reasonCode) {
        ResponseEnvelope response = base(correlationId, RESULT_INVALID_INPUT, null);
        response.reasonCodes.add(reasonCode);
        response.handoffReason = reasonCode;
        response.errorCode = 'INVALID_REQUEST';
        return response;
    }

    public static ResponseEnvelope error(String correlationId, String reasonCode) {
        ResponseEnvelope response = base(correlationId, RESULT_ERROR, null);
        response.reasonCodes.add(reasonCode);
        response.handoffReason = reasonCode;
        response.errorCode = reasonCode;
        return response;
    }

    public static String formatIsoGmt(Datetime value) {
        return value == null ? null : value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static ResponseEnvelope validateRequest(RequestEnvelope request) {
        if (request == null) {
            return invalidInput(null, 'REQUEST_MISSING');
        }
        if (String.isBlank(request.correlationId)) {
            return invalidInput(null, 'CORRELATION_ID_MISSING');
        }
        if (String.isBlank(request.ccassSessionId)) {
            return invalidInput(request.correlationId, 'CCASS_SESSION_ID_MISSING');
        }
        if (String.isBlank(request.callId)) {
            return invalidInput(request.correlationId, 'CALL_ID_MISSING');
        }
        if (request.payload == null) {
            return invalidInput(request.correlationId, 'PAYLOAD_MISSING');
        }
        if (String.isBlank(request.payload.phoneNumber)) {
            return invalidInput(request.correlationId, 'PHONE_MISSING');
        }
        if (!ALLOWED_PHONE_SOURCES.contains(request.payload.phoneSource)) {
            return invalidInput(request.correlationId, 'PHONE_SOURCE_INVALID');
        }
        if (PVLApplicationStatusPhoneMatchClient.normalizePhone(request.payload.phoneNumber).length() != 10) {
            return invalidInput(request.correlationId, 'PHONE_INVALID');
        }
        if (!isFourDigits(request.payload.ssnLast4)) {
            return invalidInput(request.correlationId, 'SSN_LAST4_INVALID');
        }
        return null;
    }

    private static Boolean isFourDigits(String value) {
        return value != null && value.length() == 4 && value.replaceAll('\\D', '') == value;
    }

    private static Boolean isMvpStatus(String status) {
        return status == 'A1 - Awaiting Review' || status == 'A3 - Deficiency Notice Sent';
    }

    private static Boolean isSnapshotStale(Datetime verifiedAt) {
        return verifiedAt < System.now().addHours(-SNAPSHOT_MAX_AGE_HOURS);
    }

    private static Boolean isRespondByOverdue(Application__c application) {
        return forceRespondByOverdueForTest ||
            (application.ApplicationRespondbyDate__c != null && application.ApplicationRespondbyDate__c < Date.today());
    }

    private static String normalizePolicy(String policy) {
        return String.isBlank(policy) ? null : policy.trim().toLowerCase();
    }

    private static ResponseEnvelope offerTransfer(String correlationId, String reasonCode) {
        return offerTransfer(correlationId, reasonCode, null);
    }

    private static ResponseEnvelope offerTransfer(String correlationId, String reasonCode, String snapshotReasonCodes) {
        ResponseEnvelope response = base(correlationId, RESULT_OFFER_TRANSFER, 'offer_transfer');
        response.reasonCodes.add(reasonCode);
        response.reasonCodes.addAll(parseReasonCodes(snapshotReasonCodes));
        response.handoffReason = reasonCode;
        return response;
    }

    private static ResponseEnvelope temporarilyUnavailable(String correlationId, String reasonCode) {
        ResponseEnvelope response = base(correlationId, RESULT_TEMPORARILY_UNAVAILABLE, 'temporarily_unavailable');
        response.reasonCodes.add(reasonCode);
        response.handoffReason = reasonCode;
        return response;
    }

    private static ResponseEnvelope deliverLimitedStatus(
        String correlationId,
        IVR_Application_Status_Snapshot__c snapshot
    ) {
        ResponseEnvelope response = base(correlationId, RESULT_DELIVER_LIMITED_STATUS, 'deliver_limited_status');
        response.spokenMessage = PVLApplicationStatusMessageCatalog.limitedStatusMessage();
        response.messageKey = 'PVL_APP_STATUS_LIMITED';
        response.verifiedAt = formatIsoGmt(snapshot.IVR_Status_Verified_At__c);
        response.verifiedAgePhrase = PVLApplicationStatusMessageCatalog.verifiedAgePhrase(snapshot.IVR_Status_Verified_At__c);
        response.reasonCodes.add('SNAPSHOT_POLICY_LIMITED');
        response.reasonCodes.addAll(parseReasonCodes(snapshot.Reason_Codes__c));
        response.handoffReason = 'STATUS_NOT_IVR_ELIGIBLE';
        return response;
    }

    private static ResponseEnvelope base(String correlationId, String result, String responsePolicy) {
        ResponseEnvelope response = new ResponseEnvelope();
        response.correlationId = correlationId;
        response.result = result;
        response.responsePolicy = responsePolicy;
        response.reasonCodes = new List<String>();
        return response;
    }

    private static List<String> parseReasonCodes(String rawCodes) {
        List<String> codes = new List<String>();
        if (String.isBlank(rawCodes)) {
            return codes;
        }
        for (String token : rawCodes.split('[,;\\n]')) {
            if (!String.isBlank(token)) {
                codes.add(token.trim());
            }
        }
        return codes;
    }

    private class PVLApplicationStatusException extends Exception {}
}