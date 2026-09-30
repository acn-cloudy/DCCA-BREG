/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Unique trigger for the Exam__c object
* - adds history records
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
trigger ExamAll on Exam__c (before update, after insert, after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        StatusHistoryAux.LogStatus(Trigger.new, Trigger.oldMap, 'ExamStatus__c', 'Exam__c', 'Exam__c');
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        StatusHistoryAux.LogStatus(Trigger.new, null, 'ExamStatus__c', 'Exam__c', 'Exam__c');
    }

    TriggerFactory.createAndExecuteHandler(Exam__c.sObjectType);
}