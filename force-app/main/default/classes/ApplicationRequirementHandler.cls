/*
* ─────────────────────────────────────────────────────────
* class for the Application Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ210919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-09-21
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class ApplicationRequirementHandler implements ITrigger{
    public ApplicationRequirementHandler() {}
    public void bulkBefore() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}

    public void bulkAfter() {
        if (Trigger.isAfter && Trigger.isUpdate) {
            ApplicationRequirementService.cleanIsDeficientFlag(Trigger.newMap, Trigger.oldMap);
        }
    }

    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so) {
        ApplicationRequirementService.updateRemarkTagsForDocGen(oldSo, so);
    }
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        ApplicationRequirementService.runFinally(trigger.new);
    }
}