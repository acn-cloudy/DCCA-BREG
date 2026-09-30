/**
 * Trigger for Ticket__c object.
 * Delegates to tkt_TicketTriggerHandler for logic.
 */
trigger tkt_TicketTrigger on tkt_Ticket__c (before insert, after insert, before update, after update) {
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            tkt_TicketTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            tkt_TicketTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            tkt_TicketTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            tkt_TicketTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}