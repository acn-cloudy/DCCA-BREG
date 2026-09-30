/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Unique trigger for the ExamResultLoad object
* Covered by 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-RP091619 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Ronald Pascual - PacificPointCorp 
* @created      2019-09-16
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/

trigger ExamResultLoadTrigger on ExamResultsLoad__c (before insert, before update, before delete,
                                                     after insert, after update, after delete, after undelete) {
    if(TriggerHelper.disableExamResultLoadTrigger) {return;}                                       
    TriggerFactory.createAndExecuteHandler(ExamResultsLoad__c.sobjectType);                                           
}