/**
 * Service class for managing Apex Managed Sharing on tkt_Ticket__c.
 * Handles sharing based on public group membership, queue assignment, and confidentiality.
 * Uses tkt_Ticket_Sharing_Group__mdt for configuring eligible sharing groups.
 */
public without sharing class tkt_TicketSharingService {

    // Cache for sharing group configuration
    private static List<tkt_Ticket_Sharing_Group__mdt> cachedSharingGroups;

    // Cache for eligible group IDs (from custom metadata)
    private static Set<Id> eligibleGroupIdsCache;

    // Test-injectable settings override (dependency injection for tests)
    @TestVisible
    private static List<tkt_Ticket_Sharing_Group__mdt> testSharingGroupsOverride;

    /**
     * Main entry point for sharing calculation.
     * Called from trigger handler after insert and after update.
     * @param tickets List of tickets to process
     * @param oldMap Map of old values (null for insert)
     */
    public static void calculateSharing(List<tkt_Ticket__c> tickets, Map<Id, tkt_Ticket__c> oldMap) {
        if (tickets == null || tickets.isEmpty()) {
            return;
        }

        // Determine which tickets need sharing recalculation
        List<tkt_Ticket__c> ticketsToProcess = filterTicketsNeedingRecalculation(tickets, oldMap);

        if (ticketsToProcess.isEmpty()) {
            return;
        }

        // Process sharing in bulk
        processSharingInBulk(ticketsToProcess);
    }

    /**
     * Filter tickets that need sharing recalculation based on field changes.
     */
    private static List<tkt_Ticket__c> filterTicketsNeedingRecalculation(
        List<tkt_Ticket__c> tickets,
        Map<Id, tkt_Ticket__c> oldMap
    ) {
        List<tkt_Ticket__c> result = new List<tkt_Ticket__c>();

        for (tkt_Ticket__c ticket : tickets) {
            if (oldMap == null) {
                // After insert - always process
                result.add(ticket);
            } else {
                tkt_Ticket__c oldTicket = oldMap.get(ticket.Id);
                // Check if relevant fields changed
                if (sharingFieldsChanged(ticket, oldTicket)) {
                    result.add(ticket);
                }
            }
        }

        return result;
    }

    /**
     * Check if any sharing-relevant fields changed.
     */
    private static Boolean sharingFieldsChanged(tkt_Ticket__c newTicket, tkt_Ticket__c oldTicket) {
        return newTicket.Is_Confidential__c != oldTicket.Is_Confidential__c ||
               newTicket.OwnerId != oldTicket.OwnerId ||
               newTicket.Assigned_To__c != oldTicket.Assigned_To__c ||
               newTicket.Submitted_By__c != oldTicket.Submitted_By__c;
    }

    /**
     * Process sharing for a list of tickets in bulk.
     */
    private static void processSharingInBulk(List<tkt_Ticket__c> tickets) {
        // Collect all data we need in single queries
        Set<Id> submitterIds = new Set<Id>();
        Set<Id> queueIds = new Set<Id>();
        Set<Id> ticketIds = new Set<Id>();

        for (tkt_Ticket__c ticket : tickets) {
            ticketIds.add(ticket.Id);
            if (ticket.Submitted_By__c != null) {
                submitterIds.add(ticket.Submitted_By__c);
            }
            if (isQueue(ticket.OwnerId)) {
                queueIds.add(ticket.OwnerId);
            }
        }

        // Get eligible sharing groups from custom metadata
        Set<Id> eligibleGroupIds = getEligibleGroupIds();

        // Pre-fetch: Which groups do submitters belong to?
        Map<Id, Set<Id>> submitterToGroups = getUserToGroupsMap(submitterIds, eligibleGroupIds);

        // Pre-fetch: Who are the members of those groups?
        Set<Id> allRelevantGroupIds = new Set<Id>();
        for (Set<Id> groups : submitterToGroups.values()) {
            allRelevantGroupIds.addAll(groups);
        }
        allRelevantGroupIds.addAll(queueIds);

        Map<Id, Set<Id>> groupToMembers = getGroupMembersMap(allRelevantGroupIds);

        // Delete existing Apex managed shares for these tickets
        deleteExistingShares(ticketIds);

        // Build new share records
        List<tkt_Ticket__Share> newShares = new List<tkt_Ticket__Share>();

        for (tkt_Ticket__c ticket : tickets) {
            newShares.addAll(buildSharesForTicket(
                ticket,
                submitterToGroups,
                groupToMembers
            ));
        }

        // Insert shares
        if (!newShares.isEmpty()) {
            insertShares(newShares);
        }
    }

    /**
     * Build share records for a single ticket.
     */
    private static List<tkt_Ticket__Share> buildSharesForTicket(
        tkt_Ticket__c ticket,
        Map<Id, Set<Id>> submitterToGroups,
        Map<Id, Set<Id>> groupToMembers
    ) {
        List<tkt_Ticket__Share> shares = new List<tkt_Ticket__Share>();
        Set<Id> usersToShareWith = new Set<Id>();

        if (ticket.Is_Confidential__c) {
            // CONFIDENTIAL: Only share with queue members and assignee

            // Queue members (if OwnerId is a queue)
            if (isQueue(ticket.OwnerId) && groupToMembers.containsKey(ticket.OwnerId)) {
                usersToShareWith.addAll(groupToMembers.get(ticket.OwnerId));
            }

            // Assigned user
            if (ticket.Assigned_To__c != null) {
                usersToShareWith.add(ticket.Assigned_To__c);
            }

        } else {
            // NON-CONFIDENTIAL: Share with submitter's groups + queue members

            // Get all users in submitter's eligible groups
            if (ticket.Submitted_By__c != null && submitterToGroups.containsKey(ticket.Submitted_By__c)) {
                Set<Id> submitterGroups = submitterToGroups.get(ticket.Submitted_By__c);
                for (Id groupId : submitterGroups) {
                    if (groupToMembers.containsKey(groupId)) {
                        usersToShareWith.addAll(groupToMembers.get(groupId));
                    }
                }
            }

            // Queue members (if OwnerId is a queue)
            if (isQueue(ticket.OwnerId) && groupToMembers.containsKey(ticket.OwnerId)) {
                usersToShareWith.addAll(groupToMembers.get(ticket.OwnerId));
            }
        }

        // Remove the record owner (they already have access)
        if (!isQueue(ticket.OwnerId)) {
            usersToShareWith.remove(ticket.OwnerId);
        }

        // Remove submitter from group-based set to avoid duplicate shares
        usersToShareWith.remove(ticket.Submitted_By__c);

        // Create share records for group/queue members
        for (Id userId : usersToShareWith) {
            shares.add(new tkt_Ticket__Share(
                ParentId = ticket.Id,
                UserOrGroupId = userId,
                AccessLevel = 'Read',
                RowCause = Schema.tkt_Ticket__Share.RowCause.Team_Sharing__c
            ));
        }

        // Submitter must always retain access to their own ticket.
        // Submitted_By__c is a lookup field that does NOT grant implicit sharing.
        // When the ticket is routed to a queue, the submitter loses ownership
        // and needs an explicit sharing record.
        Boolean submitterIsOwner = !isQueue(ticket.OwnerId) &&
            ticket.OwnerId == ticket.Submitted_By__c;
        if (ticket.Submitted_By__c != null && !submitterIsOwner) {
            shares.add(new tkt_Ticket__Share(
                ParentId = ticket.Id,
                UserOrGroupId = ticket.Submitted_By__c,
                AccessLevel = 'Edit',
                RowCause = Schema.tkt_Ticket__Share.RowCause.Team_Sharing__c
            ));
        }

        return shares;
    }

    /**
     * Check if an ID is a Queue (starts with 00G).
     */
    private static Boolean isQueue(Id recordId) {
        if (recordId == null) return false;
        return String.valueOf(recordId).startsWith('00G');
    }

    /**
     * Get eligible group IDs from custom metadata.
     */
    private static Set<Id> getEligibleGroupIds() {
        if (eligibleGroupIdsCache != null) {
            return eligibleGroupIdsCache;
        }

        List<tkt_Ticket_Sharing_Group__mdt> configs = getActiveSharingGroups();
        Set<String> groupDevNames = new Set<String>();

        for (tkt_Ticket_Sharing_Group__mdt config : configs) {
            if (String.isNotBlank(config.Group_Name__c)) {
                groupDevNames.add(config.Group_Name__c);
            }
        }

        eligibleGroupIdsCache = new Set<Id>();

        if (!groupDevNames.isEmpty()) {
            for (Group g : [
                SELECT Id FROM Group
                WHERE Type = 'Regular'
                AND DeveloperName IN :groupDevNames
            ]) {
                eligibleGroupIdsCache.add(g.Id);
            }
        }

        return eligibleGroupIdsCache;
    }

    /**
     * Get active sharing group configurations.
     */
    @TestVisible
    private static List<tkt_Ticket_Sharing_Group__mdt> getActiveSharingGroups() {
        // Check for test override (dependency injection)
        if (testSharingGroupsOverride != null) {
            return testSharingGroupsOverride;
        }

        if (cachedSharingGroups != null) {
            return cachedSharingGroups;
        }

        cachedSharingGroups = [
            SELECT DeveloperName, MasterLabel, Group_Name__c, Is_Active__c, Description__c
            FROM tkt_Ticket_Sharing_Group__mdt
            WHERE Is_Active__c = true
        ];

        return cachedSharingGroups;
    }

    /**
     * Get map of user ID to set of group IDs they belong to.
     * Only includes groups that are in the eligibleGroupIds set.
     */
    private static Map<Id, Set<Id>> getUserToGroupsMap(Set<Id> userIds, Set<Id> eligibleGroupIds) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

        for (Id userId : userIds) {
            result.put(userId, new Set<Id>());
        }

        if (eligibleGroupIds.isEmpty() || userIds.isEmpty()) {
            return result;
        }

        // Query GroupMember for users in eligible groups
        for (GroupMember gm : [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE UserOrGroupId IN :userIds
            AND GroupId IN :eligibleGroupIds
        ]) {
            if (result.containsKey(gm.UserOrGroupId)) {
                result.get(gm.UserOrGroupId).add(gm.GroupId);
            }
        }

        return result;
    }

    /**
     * Get map of group ID to set of member user IDs.
     * Handles both regular groups and queues.
     */
    private static Map<Id, Set<Id>> getGroupMembersMap(Set<Id> groupIds) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

        for (Id groupId : groupIds) {
            result.put(groupId, new Set<Id>());
        }

        if (groupIds.isEmpty()) {
            return result;
        }

        // Get direct user members
        for (GroupMember gm : [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupIds
        ]) {
            // Only include direct user members (prefix 005)
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                result.get(gm.GroupId).add(gm.UserOrGroupId);
            }
        }

        return result;
    }

    /**
     * Delete existing Apex managed shares for tickets.
     * Only deletes shares with our custom RowCause.
     */
    private static void deleteExistingShares(Set<Id> ticketIds) {
        List<tkt_Ticket__Share> existingShares = [
            SELECT Id FROM tkt_Ticket__Share
            WHERE ParentId IN :ticketIds
            AND RowCause = :Schema.tkt_Ticket__Share.RowCause.Team_Sharing__c
        ];

        if (!existingShares.isEmpty()) {
            delete existingShares;
        }
    }

    /**
     * Insert share records with error handling.
     */
    private static void insertShares(List<tkt_Ticket__Share> shares) {
        // Use Database.insert with allOrNone=false for graceful handling
        Database.SaveResult[] results = Database.insert(shares, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(LoggingLevel.WARN,
                        'Share insert failed: ' + err.getMessage() +
                        ' for record: ' + shares[i].ParentId);
                }
            }
        }
    }

    /**
     * Inject test sharing groups for testing (dependency injection).
     */
    @TestVisible
    private static void injectTestSharingGroups(List<tkt_Ticket_Sharing_Group__mdt> groups) {
        testSharingGroupsOverride = groups;
        cachedSharingGroups = null;
        eligibleGroupIdsCache = null;
    }

    /**
     * Clear all caches (for testing).
     */
    @TestVisible
    private static void clearCache() {
        cachedSharingGroups = null;
        eligibleGroupIdsCache = null;
        testSharingGroupsOverride = null;
    }
}