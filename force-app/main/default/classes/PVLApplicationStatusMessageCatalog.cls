public with sharing class PVLApplicationStatusMessageCatalog {
    private static final String PORTAL_PROMPT = 'For more information, go to my-P-V-L-dot-D-C-C-A-dot-hawaii-dot-g-o-v.';

    public static String statusMessage(
        Application__c application,
        IVR_Application_Status_Snapshot__c snapshot,
        String verifiedAgePhrase
    ) {
        String key = messageKey(application, snapshot);
        String verifiedClause = 'This status was ' + verifiedAgePhrase + '. ';

        if (key == 'PVL_APP_STATUS_A1_WITH_RECEIVED_DATE') {
            return 'Your application was received on ' + formatDate(application.ApplicationReceivedDate__c) +
                ' and is in queue for review. ' + verifiedClause + PORTAL_PROMPT;
        }
        if (key == 'PVL_APP_STATUS_A3_WITH_DUE_DATE') {
            return 'A deficiency notice was sent for your application. Please respond by ' +
                formatDate(application.DeficiencyDueDate__c) + '. ' + verifiedClause + PORTAL_PROMPT;
        }
        if (key == 'PVL_APP_STATUS_A3_NO_DUE_DATE') {
            return 'A deficiency notice was sent for your application. ' + verifiedClause + PORTAL_PROMPT;
        }
        return 'Your application is in queue for review. ' + verifiedClause + PORTAL_PROMPT;
    }

    public static String messageKey(Application__c application, IVR_Application_Status_Snapshot__c snapshot) {
        if (!String.isBlank(snapshot.IVR_Status_Message_Key__c)) {
            return snapshot.IVR_Status_Message_Key__c;
        }
        if (snapshot.IVR_Status__c == 'A3 - Deficiency Notice Sent') {
            return application.DeficiencyDueDate__c == null
                ? 'PVL_APP_STATUS_A3_NO_DUE_DATE'
                : 'PVL_APP_STATUS_A3_WITH_DUE_DATE';
        }
        return application.ApplicationReceivedDate__c == null
            ? 'PVL_APP_STATUS_A1_NO_RECEIVED_DATE'
            : 'PVL_APP_STATUS_A1_WITH_RECEIVED_DATE';
    }

    public static String statusCategory(IVR_Application_Status_Snapshot__c snapshot) {
        if (snapshot.IVR_Status__c == 'A3 - Deficiency Notice Sent') {
            return 'A3_DEFICIENCY_NOTICE_SENT';
        }
        if (snapshot.IVR_Status__c == 'A1 - Awaiting Review') {
            return 'A1_AWAITING_REVIEW';
        }
        return null;
    }

    public static String verifiedAgePhrase(Datetime verifiedAt) {
        if (verifiedAt == null) {
            return null;
        }
        if (verifiedAt >= System.now().addHours(-12)) {
            return 'verified earlier today';
        }
        return 'verified within the last day';
    }

    public static String limitedStatusMessage() {
        return 'We found your application, but this automated system cannot provide the exact status right now. Please hold while we connect you with a representative.';
    }

    private static String formatDate(Date value) {
        if (value == null) {
            return null;
        }
        return DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('MMMM d, yyyy');
    }
}