/**
 * Trigger for Ticket_Comment__c object.
 * Delegates to tkt_TicketCommentTriggerHandler for logic.
 */
trigger tkt_TicketCommentTrigger on tkt_Ticket_Comment__c (after insert) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            tkt_TicketCommentTriggerHandler.handleAfterInsert(Trigger.new);
        }
    }
}