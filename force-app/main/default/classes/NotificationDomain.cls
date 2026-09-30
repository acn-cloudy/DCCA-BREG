/*
* ─────────────────────────────────────────────────────────
* class for the dealing of the list of the records in 
* Notification
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
public class NotificationDomain extends SObjectDomain{
    public NotificationDomain(List<Notification__c> notifications) {
        super(notifications);
    }

    public List<Notification__c> filterNotificationsByIdSet(Set<String> recordIdSet) {
        List<Notification__c> filteredNotifications = new List<Notification__c>();
        for(SObject record: records) {
            Notification__c notification = (Notification__c) record;
            if( recordIdSet.contains(notification.Id)) {
                filteredNotifications.add(notification);
            }
        }
        return filteredNotifications;
    }

    // Call future actions
    public void generatePDF() {
        List<PVLProcess__e> processes = new List<PVLProcess__e>();
        for(Notification__c record: (List<Notification__c>)records) {
            String fileEngines = record.DocumentTemplateName__c;
            if(record.RunBatchUpdateToLicense__c && record.LicenseType__c != null) {
                Database.executeBatch(new DocumentGeneratorProcessBatch(record.LicenseType__c, 
                    record.Id, record.DocumentTemplateName__c), 10);
            } else if(record.VFPage__c != null) {
                // Generate file
                Map<String, String> payload = new Map<String, String>();
                PVLProcess__e process = new PVLProcess__e();
                payload.put('fileEngines', record.VFPage__c);
                payload.put('Id', record.RecordId__c);
                payload.put('notificationId', record.Id);
                payload.put('fileName', record.DocumentTemplateName__c);
                process.Type__c = 'Generate VF Page';
                process.Payload__c = JSON.serialize(payload);
                processes.add(process);

            } else if(record.Type__c == 'Email CLM') {
                SpringCMFileHelper.saveFileAndSendEmail(record.Id, record.RecipientEmail__c, record.DownloadDocumentHref__c, record.DocumentTemplateName__c);
            } else {
                Map<String, String> payload = new Map<String, String>();
                PVLProcess__e process = new PVLProcess__e();
                if(fileEngines != null ) {
                    List<String> fileEngineList = new List<String>();
                    payload.put('Id', record.RecordId__c);
                    payload.put('fileEngines', fileEngines);
                    payload.put('notificationId', record.Id);
                    process.Type__c = 'Generate PDF';
                    process.Payload__c = JSON.serialize(payload);
                    processes.add(process);
                }
            }
            
        }
        EventBus.publish(processes);
    }

    public List<Notification__c> getNotifications() {
        List<Notification__c> recordsForUpdate = new List<Notification__c>();
        for(Notification__c record: (List<Notification__c>)records) {
            if(record.Fire__c) {
                recordsForUpdate.add(new Notification__c(Id=record.Id, Fire__c=true));
            }
        }
        return recordsForUpdate;
    }

    public void fireNotifications() {
        PVL_PDFGenerator.checkIfCreateSpringCM = false;
        for(Notification__c record: (List<Notification__c>)records) {
        
           PVL_PDFGenerator.createFiles(record.RecordId__c, record.DocumentTemplateName__c, record.Id);
        }
    }
}