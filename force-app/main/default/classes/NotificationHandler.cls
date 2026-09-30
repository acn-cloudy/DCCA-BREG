/*
* ─────────────────────────────────────────────────────────
* class for the Notification Handler for the trigger
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
public class NotificationHandler implements ITrigger {
    public NotificationHandler() {

    }
    public void bulkBefore() {}
    public void bulkAfter() {}
    public void beforeInsert(SObject so) { 
    }
        

    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so) {
        // Capture the DOC Generator record
        NotificationService.captureForDocGens(oldSo, so);
    }
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}

    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        List<Notification__c> records = (List<Notification__c>)Trigger.new;
        if(Trigger.isAfter && (Trigger.isUpdate || Trigger.isInsert )) {
            NotificationService.generateFiles(records);
        }
        if(Trigger.isInsert  && Trigger.isAfter) {
            NotificationService.checkIfNeedUpdate(records);
        }
        
    }
}