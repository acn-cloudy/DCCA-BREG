/**
 * Service class for ticket routing based on Custom Metadata rules.
 * Evaluates tkt_Ticket_Routing_Rule__mdt records to determine assignment.
 */
public with sharing class tkt_TicketRoutingService {
    
    // Cache for routing rules
    private static List<tkt_Ticket_Routing_Rule__mdt> cachedRules;

    // Cache for queue IDs
    private static Map<String, Id> queueIdCache;

    // Test-injectable rules override (dependency injection for tests)
    @TestVisible
    private static List<tkt_Ticket_Routing_Rule__mdt> testRulesOverride;

    // Test-injectable queue IDs (dependency injection for tests)
    @TestVisible
    private static Map<String, Id> testQueueIdsOverride;
    
    /**
     * Route a list of tickets based on configured rules.
     * @param tickets List of tickets to route
     */
    public static void routeTickets(List<tkt_Ticket__c> tickets) {
        if (tickets == null || tickets.isEmpty()) {
            return;
        }
        
        // Get all active routing rules, ordered by priority
        List<tkt_Ticket_Routing_Rule__mdt> rules = getActiveRules();
        
        if (rules.isEmpty()) {
            return; // No rules configured
        }
        
        // Pre-fetch all queue IDs we might need
        Set<String> queueNames = new Set<String>();
        for (tkt_Ticket_Routing_Rule__mdt rule : rules) {
            if (String.isNotBlank(rule.Assign_To_Queue__c)) {
                queueNames.add(rule.Assign_To_Queue__c);
            }
        }
        Map<String, Id> queueIds = getQueueIds(queueNames);
        
        // Route each ticket
        for (tkt_Ticket__c ticket : tickets) {
            routeTicket(ticket, rules, queueIds);
        }
    }
    
    /**
     * Route a single ticket based on rules.
     */
    private static void routeTicket(tkt_Ticket__c ticket, List<tkt_Ticket_Routing_Rule__mdt> rules, Map<String, Id> queueIds) {
        tkt_Ticket_Routing_Rule__mdt matchedRule = null;
        tkt_Ticket_Routing_Rule__mdt defaultRule = null;
        
        for (tkt_Ticket_Routing_Rule__mdt rule : rules) {
            // Track default rule for fallback
            if (rule.Is_Default__c) {
                defaultRule = rule;
            }
            
            // Check if this rule matches
            if (ruleMatches(ticket, rule)) {
                matchedRule = rule;
                break; // First match wins (rules are ordered by priority)
            }
        }
        
        // Use default rule if no match found
        if (matchedRule == null && defaultRule != null) {
            matchedRule = defaultRule;
        }
        
        // Apply the assignment
        if (matchedRule != null) {
            applyAssignment(ticket, matchedRule, queueIds);
        }
    }
    
    /**
     * Check if a routing rule matches the ticket.
     */
    private static Boolean ruleMatches(tkt_Ticket__c ticket, tkt_Ticket_Routing_Rule__mdt rule) {
        // Skip default rules during matching phase
        if (rule.Is_Default__c) {
            return false;
        }
        
        // Check category match
        if (String.isNotBlank(rule.Match_Category__c)) {
            if (ticket.Category__c != rule.Match_Category__c) {
                return false;
            }
        }
        
        // Check priority match
        if (String.isNotBlank(rule.Match_Priority__c)) {
            if (ticket.Priority__c != rule.Match_Priority__c) {
                return false;
            }
        }
        
        // If we get here with no criteria, it's a wildcard match
        // But only if at least one criterion was specified
        Boolean hasCriteria = String.isNotBlank(rule.Match_Category__c) || 
                             String.isNotBlank(rule.Match_Priority__c);
        
        return hasCriteria;
    }
    
    /**
     * Apply the assignment from a matched rule to the ticket.
     */
    private static void applyAssignment(tkt_Ticket__c ticket, tkt_Ticket_Routing_Rule__mdt rule, Map<String, Id> queueIds) {
        // User assignment takes precedence
        if (String.isNotBlank(rule.Assign_To_User__c)) {
            try {
                ticket.Assigned_To__c = Id.valueOf(rule.Assign_To_User__c);
                // Also set OwnerId to the user
                ticket.OwnerId = Id.valueOf(rule.Assign_To_User__c);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Invalid user ID in routing rule: ' + rule.Assign_To_User__c);
            }
            return;
        }
        
        // Queue assignment
        if (String.isNotBlank(rule.Assign_To_Queue__c)) {
            Id queueId = queueIds.get(rule.Assign_To_Queue__c);
            if (queueId != null) {
                ticket.OwnerId = queueId;
            } else {
                System.debug(LoggingLevel.WARN, 'Queue not found: ' + rule.Assign_To_Queue__c);
            }
        }
    }
    
    /**
     * Get all active routing rules, ordered by priority.
     */
    @TestVisible
    private static List<tkt_Ticket_Routing_Rule__mdt> getActiveRules() {
        // Check for test override (dependency injection)
        if (testRulesOverride != null) {
            return testRulesOverride;
        }

        if (cachedRules != null) {
            return cachedRules;
        }

        cachedRules = [
            SELECT DeveloperName, MasterLabel, Is_Active__c, Priority_Order__c,
                   Match_Category__c, Match_Priority__c,
                   Assign_To_Queue__c, Assign_To_User__c, Is_Default__c
            FROM tkt_Ticket_Routing_Rule__mdt
            WHERE Is_Active__c = true
            ORDER BY Priority_Order__c ASC, DeveloperName ASC
        ];

        return cachedRules;
    }
    
    /**
     * Get Queue IDs by Developer Name.
     */
    private static Map<String, Id> getQueueIds(Set<String> queueNames) {
        // Check for test override (dependency injection)
        if (testQueueIdsOverride != null) {
            return testQueueIdsOverride;
        }

        if (queueIdCache == null) {
            queueIdCache = new Map<String, Id>();
        }

        // Find which queues we need to look up
        Set<String> namesToLookup = new Set<String>();
        for (String name : queueNames) {
            if (!queueIdCache.containsKey(name)) {
                namesToLookup.add(name);
            }
        }

        // Query for missing queues
        if (!namesToLookup.isEmpty()) {
            for (Group q : [
                SELECT Id, DeveloperName
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName IN :namesToLookup
            ]) {
                queueIdCache.put(q.DeveloperName, q.Id);
            }
        }

        return queueIdCache;
    }
    
    /**
     * Clear cached data (useful for testing).
     */
    @TestVisible
    private static void clearCache() {
        cachedRules = null;
        queueIdCache = null;
        testRulesOverride = null;
        testQueueIdsOverride = null;
    }

    /**
     * Inject mock routing rules for testing (dependency injection).
     * @param rules List of mock routing rules
     */
    @TestVisible
    private static void injectTestRules(List<tkt_Ticket_Routing_Rule__mdt> rules) {
        testRulesOverride = rules;
        cachedRules = null;
    }

    /**
     * Inject mock queue IDs for testing (dependency injection).
     * @param queueIds Map of queue developer name to queue Id
     */
    @TestVisible
    private static void injectTestQueueIds(Map<String, Id> queueIds) {
        testQueueIdsOverride = queueIds;
        queueIdCache = null;
    }
}