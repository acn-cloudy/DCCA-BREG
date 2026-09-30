/*
* ─────────────────────────────────────────────────────────
* class for the License Condition Handller used to handle 
* License Condition trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ112019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin ZHou - PacificPointCorp 
* @created      2019-11-20
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseConditionHandler implements ITrigger{
    public LicenseConditionHandler(){}
    public void bulkBefore() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}

    public void afterInsert(SObject so) {
        LicenseConditionService.captureLicenseConditionForCreate(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        LicenseConditionService.captureLicenseConditionForCreate(oldSo, so);
        LicenseConditionService.captureLicenseConditionForDelete(oldSo, so);
    }

    public void beforeDelete(SObject so){
        LicenseConditionService.captureLicenseConditionForDelete(so);
    } 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        LicenseConditionService.runFinally(trigger.new);
    }
}