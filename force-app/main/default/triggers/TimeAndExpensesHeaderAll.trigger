/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Trigger
* Populates the total amount and hours on the Investigation record
* Handler class: TimeandExpenseHeaderAllHandler.cls
* Covered by TimeandExpenseHeaderAllHandlerTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC121318 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2018-12-13
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/


trigger TimeAndExpensesHeaderAll on TimeandExpenseHeader__c (before insert, before update, after insert, after update, before delete, after delete) {
    TimeandExpensesAllHandler handler = new TimeandExpensesAllHandler();
    
    if (Trigger.isInsert) {
        if (Trigger.isBefore)
            handler.onBeforeInsert(Trigger.New, Trigger.NewMap ) ;
            
        if (Trigger.isAfter) 
            handler.onAfterInsert(Trigger.New, Trigger.NewMap);
    }
    
    if (Trigger.isUpdate) {
        if (Trigger.isBefore)
            handler.onBeforeUpdate(Trigger.New, Trigger.NewMap, Trigger.oldMap);
        
        if (Trigger.isAfter)
            handler.onAfterUpdate(Trigger.New, Trigger.NewMap , Trigger.oldMap);
    }

    /*if (Trigger.isDelete) {
        if (Trigger.isBefore)
            handler.onBeforeDelete(Trigger.Old, Trigger.oldMap);
        
        if (Trigger.isAfter)
            handler.onAfterDelete(Trigger.Old, Trigger.oldMap );
    }*/

}