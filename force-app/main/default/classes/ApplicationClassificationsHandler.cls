/*
* ─────────────────────────────────────────────────────────
* class for the Application Classifications Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ140619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-14
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class ApplicationClassificationsHandler implements ITrigger {
    public ApplicationClassificationsHandler() {}
    public void bulkBefore() {}
    public void bulkAfter() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {
        // capture applicaiton if new created
        ApplicationClassificationsService.captureApplications(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {
        // capture applicaiton if new created
        ApplicationClassificationsService.captureApplications(so);
    } 
    public void afterUnDelete(SObject so) {
         // capture applicaiton if new created
        ApplicationClassificationsService.captureApplications(so);
    } 
    public void andFinally() {
        ApplicationClassificationsService.runFinally(Trigger.new);
    }

}