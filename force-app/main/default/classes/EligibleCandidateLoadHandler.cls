/*
* ─────────────────────────────────────────────────────────
* class for the EligibleCandidateLoad Handller used to handle 
* EligibleCandidateLoad object events
* ─────────────────────────────────────────────────────────
* PacPoint-SS005582 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Surbhi Sharma - PacificPointCorp 
* @created      2019-09-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class EligibleCandidateLoadHandler implements ITrigger{
    public EligibleCandidateLoadHandler() {}
    public void bulkBefore() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {
        EligibleCandidateLoadService.updateEligibleApplicationsForExam(newlstObj); //Added for case 00005582 
    }
    public void beforeInsert(List<SObject> newlstObj) {
        EligibleCandidateLoadService.updateEligibleApplicationsForExam(newlstObj); //Added for case 00005582 
    }
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {}
}