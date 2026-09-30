/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Unique trigger for the Filing__c object
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
trigger FilingAll on Filing__c (before update, after insert, after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        StatusHistoryAux.LogStatus(Trigger.new, Trigger.oldMap, 'Status__c', 'Filing__c', 'Filing__c');
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        StatusHistoryAux.LogStatus(Trigger.new, null, 'Status__c', 'Filing__c', 'Filing__c');
    }

    TriggerFactory.createAndExecuteHandler(Filing__c.sObjectType);
    
}