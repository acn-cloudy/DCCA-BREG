public with sharing class PVLApplicationStatusSnapshotSelector {
    public static IVR_Application_Status_Snapshot__c selectLatestForApplication(Id applicationId) {
        if (applicationId == null) {
            return null;
        }

        List<IVR_Application_Status_Snapshot__c> snapshots = [
            SELECT
                Id,
                Application__c,
                Application_Key__c,
                Freshness_State__c,
                IVR_Status__c,
                IVR_Status_Message_Key__c,
                IVR_Status_Verified_At__c,
                IVR_Response_Policy__c,
                Reason_Codes__c
            FROM IVR_Application_Status_Snapshot__c
            WHERE Application__c = :applicationId
            ORDER BY IVR_Status_Verified_At__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 1
        ];

        return snapshots.isEmpty() ? null : snapshots[0];
    }
}