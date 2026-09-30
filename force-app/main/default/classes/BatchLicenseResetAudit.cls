/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the BatchLicenseResetAudit
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint - AZ2021010400012336
* @author       Alvin ZHou - PacificPointCorp 
* @created      2021-01-04
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global with sharing class BatchLicenseResetAudit implements  Database.Batchable<SObject>, Database.Stateful  {
    global List<Id> resetAuditLTIds;
    public String query ;
    global BatchLicenseResetAudit(List<Id> resetAuditLTIds) {
        this.resetAuditLTIds = resetAuditLTIds;
        query = 'Select Id, Status__c, AuditDate__c, AuditCERequirement__c, AuditNumber__c, FlaggedforAudit__c, PreviousStatus__c, LicenseType__r.AuditType__c '
            + ' FROM License__c WHERE LicenseType__c IN ' + GlobalUtilities.convertIdsToIdStr(resetAuditLTIds) 
            + ' AND FlaggedforAudit__c = true';
    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>) scope;
        List<String> licenseIdsForHistoryCheck = new List<String>();
        for(License__c license: licenses) {
            license.AuditDate__c = NULL;
            license.AuditCERequirement__c = NULL;
            license.AuditNumber__c = NULL;
            // Changes for 00030968 to separate the Post-Audit and Pre-Audit.
            if(license.LicenseType__r.Audittype__c == 'Pre-Audit') {
                license.Status__c = license.PreviousStatus__c;
            } else if(license.LicenseType__r.AuditType__c == 'Post-Audit') {
                licenseIdsForHistoryCheck.add(license.Id);
            }
            
            license.FlaggedforAudit__c = false;
        }
        update licenses;
        /****Find all Notifications on those Licenses with a DocumentTemplateName__c = CONTAINS
        (Notice of Audit)AND Status__c = "Scheduled"
        ANDSendToPrinter__c = True Set the Notification records found in Step 3
         and set the Notification.Status__c = "Cancelled"and SendToPrinter__c = false
         *** */

        List<String> licenseIds = (new LicenseDomain(licenses)).getIds();
        List<Notification__c> notifications =  NotificationSelector.getAuditNotificationsByLicenseIds(licenseIds);
        for(Notification__c notification: notifications) {
            notification.Status__c = 'Cancelled';
            notification.SendToPrinter__c = false;
            notification.Scheduled__c = false;
        }
        update notifications;

        // Find all LicenseHistory__c where
        // LicenseHistory.License = License ID found from step 1
        // AND
        // LicenseHistory.TransactionType__c = "RNEW - RENEWED" 
        // AND
        // LicenseHistory.LicensePeriod__c = License.LicenseType.PreviousLicensePeriod__c
        if(!licenseIdsForHistoryCheck.isEmpty()) {
            List<LicenseHistory__c> histories 
                = LicenseHistorySelector.getPostAuditLicenseHistories(new List<String>{'RNEW - RENEWED'}, licenseIdsForHistoryCheck);
            List<LicenseHistory__c> historiesForUpdate = (new LicenseHistoryDomain(histories)).clearMarks();
            if(!historiesForUpdate.isEmpty()) update historiesForUpdate;
        }
    }
	
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        List<LicenseType__c> licenseTypes = [
                SELECT
                        Id,
                        Name,
                        ResetAudit__c
                FROM LicenseType__c
                WHERE Id IN: resetAuditLTIds
        ];

        /* To send confirmation emails or execute post-processing operations. */
        updateLicenseTypeResetAuditFlag(licenseTypes);

        String licenseTypeNames = '';

        Integer cnt = 1;
        for (LicenseType__c lt : licenseTypes) {
            licenseTypeNames += lt.Name;
            if (cnt<licenseTypes.size()) {
                licenseTypeNames += ',';
            }
        }

        BatchJobFinishNotification notification = new BatchJobFinishNotification('Reset Audit', licenseTypeNames);
        notification.sendEmail();
    }

    // Update license type reset audit flag to false
    public void updateLicenseTypeResetAuditFlag(List<LicenseType__c> licenseTypes) {
        for (LicenseType__c sglLicenseType : licenseTypes) {
            sglLicenseType.ResetAudit__c = false;
        }
        update licenseTypes;
    }
}