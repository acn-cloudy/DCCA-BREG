/**
 * Trigger handler for tkt_Ticket__c object.
 * Implements routing logic on insert and email notifications.
 * Respects tkt_Trigger_Control__c custom setting for migration scenarios.
 */
public with sharing class tkt_TicketTriggerHandler {

    /**
     * Get the current user's trigger control settings.
     * @return The trigger control settings instance, or null if not configured
     */
    private static tkt_Trigger_Control__c getTriggerSettings() {
        return tkt_Trigger_Control__c.getInstance();
    }

    /**
     * Check if routing should be skipped based on custom setting.
     * @return true if routing should be skipped
     */
    private static Boolean shouldSkipRouting() {
        tkt_Trigger_Control__c settings = getTriggerSettings();
        return settings != null && settings.Skip_Routing__c == true;
    }

    /**
     * Check if email notifications should be skipped based on custom setting.
     * @return true if emails should be skipped
     */
    private static Boolean shouldSkipEmails() {
        tkt_Trigger_Control__c settings = getTriggerSettings();
        return settings != null && settings.Skip_Email_Notifications__c == true;
    }

    /**
     * Handle before insert - route new tickets.
     */
    public static void handleBeforeInsert(List<tkt_Ticket__c> newTickets) {
        if (shouldSkipRouting()) {
            return;
        }
        tkt_TicketRoutingService.routeTickets(newTickets);
    }

    /**
     * Handle after insert - send email notifications and calculate sharing.
     * @param newTickets List of newly created tickets
     */
    public static void handleAfterInsert(List<tkt_Ticket__c> newTickets) {
        // Email notifications - skippable during migration
        if (!shouldSkipEmails()) {
            // Send confirmation email to ticket owner
            tkt_EmailNotificationService.sendNewTicketOwnerNotifications(newTickets);

            // Send notification to queue members for new tickets
            tkt_EmailNotificationService.sendNewTicketQueueNotifications(newTickets);
        }

        // Calculate sharing for new tickets - always runs (required for proper access)
        tkt_TicketSharingService.calculateSharing(newTickets, null);
    }

    /**
     * Handle before update - re-route if category/priority changed.
     */
    public static void handleBeforeUpdate(List<tkt_Ticket__c> newTickets, Map<Id, tkt_Ticket__c> oldMap) {
        if (shouldSkipRouting()) {
            return;
        }

        List<tkt_Ticket__c> ticketsToReroute = new List<tkt_Ticket__c>();

        for (tkt_Ticket__c ticket : newTickets) {
            tkt_Ticket__c oldTicket = oldMap.get(ticket.Id);

            // Re-route if category or priority changed and no manual assignment
            Boolean categoryChanged = ticket.Category__c != oldTicket.Category__c;
            Boolean priorityChanged = ticket.Priority__c != oldTicket.Priority__c;
            Boolean manuallyAssigned = ticket.Assigned_To__c != null &&
                                       ticket.Assigned_To__c != oldTicket.Assigned_To__c;

            if ((categoryChanged || priorityChanged) && !manuallyAssigned) {
                ticketsToReroute.add(ticket);
            }
        }

        if (!ticketsToReroute.isEmpty()) {
            tkt_TicketRoutingService.routeTickets(ticketsToReroute);
        }
    }

    /**
     * Handle after update - send email notifications and recalculate sharing.
     * @param newTickets List of updated tickets
     * @param oldMap Map of old ticket values
     */
    public static void handleAfterUpdate(List<tkt_Ticket__c> newTickets, Map<Id, tkt_Ticket__c> oldMap) {
        // Email notifications - skippable during migration
        if (!shouldSkipEmails()) {
            // Send notifications for status changes
            tkt_EmailNotificationService.sendStatusChangeNotifications(newTickets, oldMap);

            // Send notifications for ownership changes
            tkt_EmailNotificationService.sendOwnershipChangeNotifications(newTickets, oldMap);

            // Send notifications when ticket is closed by owner
            tkt_EmailNotificationService.sendClosedByOwnerNotifications(newTickets, oldMap);
        }

        // Recalculate sharing when relevant fields change - always runs
        tkt_TicketSharingService.calculateSharing(newTickets, oldMap);
    }
}