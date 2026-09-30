/*
* ─────────────────────────────────────────────────────────
* class for the business logic for Notification 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ060520 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2020-05-06
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class NotificationService {
    private static Set<String> recordIdForDocGen = new Set<String>();

    public static void captureForDocGens(SObject oldSo, SObject so) {
        Notification__c record = (Notification__c) so;
        Notification__c oldRecord = (Notification__c) oldSo;
        if(record.Fire__c) {
            recordIdForDocGen.add(record.Id);
            record.Fire__c = false;
        }
    }
    public static void checkIfNeedUpdate(List<Notification__c> records) {
        List<Notification__c> recordsForUpdate = (new NotificationDomain(records)).getNotifications();
        if(!recordsForUpdate.isEmpty()) {
            update recordsForUpdate;
        }
    }
    public static void generateFiles(List<Notification__c> notifications) {
        List<Notification__c> records = (new NotificationDomain(notifications)).filterNotificationsByIdSet(recordIdForDocGen);
        recordIdForDocGen.clear();
        // Call file generator
        (new NotificationDomain(records)).generatePDF();
    }
    public static void updateErrorStatus(String notificationId, String errorMessage) {
        List<Notification__c> records = NotificationSelector.getNotifications(notificationId);
        if(!records.isEmpty()) {
            records.get(0).FailedReason__c = errorMessage;
            records.get(0).Status__c = 'Failed';
            update records.get(0);
            ApplicationLogService.logApplicationError('File generate error', notificationId, '', errorMessage);
        }
    }

    public static void updateSuccessStatus(String notificationId, List<SpringCMDocument> results) {
        List<Notification__c> records = NotificationSelector.getNotifications(notificationId);
        if(!records.isEmpty()) {
            if(!results.isEmpty()) {
                String originalUrl = results.get(0).DownloadDocumentHref;
                String documentId = null;

                Integer documentsIndex = originalUrl.indexOf('/documents/');
                if (documentsIndex != -1) {
                    String potentialIdString = originalUrl.substring(documentsIndex + 11);
                    
                    Integer nextSeparatorIndex = potentialIdString.indexOf('/');
                    if (nextSeparatorIndex == -1) {
                        nextSeparatorIndex = potentialIdString.indexOf('?');
                    }
                    
                    if (nextSeparatorIndex != -1) {
                        documentId = potentialIdString.substring(0, nextSeparatorIndex);
                    } else {
                        documentId = potentialIdString;
                    }
                }

                if (documentId != null) {
                    String newUrlTemplate = System.Label.Document_Href_Label; 
                    
                    String newUrl = newUrlTemplate.replace('{documentId}', documentId);

                    records.get(0).DownloadDocumentHref__c = newUrl;
                }
            }
            
            records.get(0).Status__c = 'Completed';
            records.get(0).TimeDelivered__c = System.now();
            records.get(0).FailedReason__c = null;
            if(!PVL_PDFGenerator.checkIfCreateSpringCM) {
                records.get(0).PrintStatus__c = 'Ready for Print';
            }
            
            update records.get(0);
        }
    }
    public static Notification__c generateNotificationForIdContain(String queryIds, String recordId) {
        Notification__c notification = new Notification__c();
        notification.Content__c = queryIds;
        notification.Status__c = 'Completed';
        notification.RecordId__c = recordId;
        
        insert notification;
        return notification;
    }
}