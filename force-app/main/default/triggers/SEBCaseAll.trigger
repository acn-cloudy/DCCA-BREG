/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Unique trigger for the SEBCase__c object
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
trigger SEBCaseAll on SEBCase__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        StatusHistoryAux.LogStatus(Trigger.new, Trigger.oldMap, 'Status__c', 'SEBCase__c', 'SEBCase__c');
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        StatusHistoryAux.LogStatus(Trigger.new, null, 'Status__c', 'SEBCase__c', 'SEBCase__c');
    }
    
}