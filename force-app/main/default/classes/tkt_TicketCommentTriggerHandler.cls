/**
 * Trigger handler for tkt_Ticket_Comment__c object.
 * Handles email notifications for new comments.
 * Respects tkt_Trigger_Control__c custom setting for migration scenarios.
 */
public with sharing class tkt_TicketCommentTriggerHandler {

    /**
     * Check if email notifications should be skipped based on custom setting.
     * @return true if emails should be skipped
     */
    private static Boolean shouldSkipEmails() {
        tkt_Trigger_Control__c settings = tkt_Trigger_Control__c.getInstance();
        return settings != null && settings.Skip_Email_Notifications__c == true;
    }

    /**
     * Handle after insert - send email notifications.
     * @param newComments List of newly created comments
     */
    public static void handleAfterInsert(List<tkt_Ticket_Comment__c> newComments) {
        // Skip all email notifications during migration
        if (shouldSkipEmails()) {
            return;
        }

        // Filter out internal comments from notifications
        List<tkt_Ticket_Comment__c> notifiableComments = new List<tkt_Ticket_Comment__c>();

        for (tkt_Ticket_Comment__c comment : newComments) {
            if (comment.Is_Internal__c != true) {
                notifiableComments.add(comment);
            }
        }

        if (notifiableComments.isEmpty()) {
            return;
        }

        // Send notifications
        tkt_EmailNotificationService.sendCommentNotificationToOwner(notifiableComments);
        tkt_EmailNotificationService.sendCommentNotificationToAssignee(notifiableComments);
    }
}