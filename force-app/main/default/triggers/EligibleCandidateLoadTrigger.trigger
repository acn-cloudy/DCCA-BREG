/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for EligibleCandidateLoad
* ─────────────────────────────────────────────────────────
* PacPoint-SS05582 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Surbhi SHarma - PacificPointCorp 
* @created      2019-09-12
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger EligibleCandidateLoadTrigger on EligibleCandidateLoad__c (after insert,after update,before insert,before update,before delete,after delete) {
    if(TriggerHelper.disableEligibleCandidateLoadTrigger) {return;}
    TriggerFactory.createAndExecuteHandler(EligibleCandidateLoad__c.SObjectType);
}