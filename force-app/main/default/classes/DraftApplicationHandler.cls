/*
* ─────────────────────────────────────────────────────────
* class for the Application Cache Handller used to handle 
* Transaction trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ230205 - Created for PVL phase 2
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2023-02-05
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class DraftApplicationHandler implements ITrigger {
    public DraftApplicationHandler() {}
    public void bulkBefore() {}
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so) {
        DraftApplicationService.checkSubmittedStatus(oldSo, so);
    }
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        
    }
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {}
    public void andFinally() {
        if(Trigger.isAfter && Trigger.isUpdate) {
            DraftApplicationService.generateApp();
        }
    }

}