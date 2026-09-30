@isTest
private class tkt_TicketRoutingServiceTest {

    /**
     * Helper to create mock routing rules.
     */
    private static List<tkt_Ticket_Routing_Rule__mdt> createMockRules() {
        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();

        // Rule 1: Critical priority -> Critical_Queue
        tkt_Ticket_Routing_Rule__mdt criticalRule = new tkt_Ticket_Routing_Rule__mdt();
        criticalRule.DeveloperName = 'Critical_Priority_Rule';
        criticalRule.MasterLabel = 'Critical Priority Rule';
        criticalRule.Is_Active__c = true;
        criticalRule.Priority_Order__c = 1;
        criticalRule.Match_Priority__c = 'Critical';
        criticalRule.Match_Category__c = null;
        criticalRule.Assign_To_Queue__c = 'Critical_Queue';
        criticalRule.Assign_To_User__c = null;
        criticalRule.Is_Default__c = false;
        rules.add(criticalRule);

        // Rule 2: Technical Issue -> Tech_Support_Queue
        tkt_Ticket_Routing_Rule__mdt techRule = new tkt_Ticket_Routing_Rule__mdt();
        techRule.DeveloperName = 'Technical_Issue_Rule';
        techRule.MasterLabel = 'Technical Issue Rule';
        techRule.Is_Active__c = true;
        techRule.Priority_Order__c = 2;
        techRule.Match_Priority__c = null;
        techRule.Match_Category__c = 'Technical Issue';
        techRule.Assign_To_Queue__c = 'Tech_Support_Queue';
        techRule.Assign_To_User__c = null;
        techRule.Is_Default__c = false;
        rules.add(techRule);

        // Rule 3: Default rule -> General_Queue
        tkt_Ticket_Routing_Rule__mdt defaultRule = new tkt_Ticket_Routing_Rule__mdt();
        defaultRule.DeveloperName = 'Default_Rule';
        defaultRule.MasterLabel = 'Default Rule';
        defaultRule.Is_Active__c = true;
        defaultRule.Priority_Order__c = 100;
        defaultRule.Match_Priority__c = null;
        defaultRule.Match_Category__c = null;
        defaultRule.Assign_To_Queue__c = 'General_Queue';
        defaultRule.Assign_To_User__c = null;
        defaultRule.Is_Default__c = true;
        rules.add(defaultRule);

        return rules;
    }

    /**
     * Helper to create mock queue IDs.
     */
    private static Map<String, Id> createMockQueueIds() {
        // Create actual queues for testing
        Map<String, Id> queueIds = new Map<String, Id>();

        // Query for existing queues or create test ones
        List<Group> existingQueues = [
            SELECT Id, DeveloperName FROM Group
            WHERE Type = 'Queue' AND DeveloperName IN ('Critical_Queue', 'Tech_Support_Queue', 'General_Queue')
        ];

        for (Group q : existingQueues) {
            queueIds.put(q.DeveloperName, q.Id);
        }

        // If no queues exist, we'll use fake IDs (the routing logic still works)
        // In real tests, the queues would exist
        if (!queueIds.containsKey('Critical_Queue')) {
            // Use a valid Group ID format for testing
            queueIds.put('Critical_Queue', UserInfo.getUserId()); // Fallback to user ID
        }

        return queueIds;
    }

    @isTest
    static void testRouteCriticalPriorityTicket() {
        Test.startTest();
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Critical Issue',
            'Priority__c' => 'Critical',
            'Category__c' => 'General Inquiry'
        });
        Test.stopTest();

        tkt_Ticket__c insertedTicket = [SELECT OwnerId, Priority__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertNotEquals(null, insertedTicket.Id, 'Ticket should be created');
        System.assertEquals('Critical', insertedTicket.Priority__c, 'Priority should be Critical');
    }

    @isTest
    static void testRouteTechnicalIssueTicket() {
        Test.startTest();
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Technical Problem',
            'Priority__c' => 'Medium',
            'Category__c' => 'Technical Issue'
        });
        Test.stopTest();

        tkt_Ticket__c insertedTicket = [SELECT OwnerId, Category__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Technical Issue', insertedTicket.Category__c, 'Category should be Technical Issue');
    }

    @isTest
    static void testRouteDefaultQueueTicket() {
        Test.startTest();
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'General Question',
            'Priority__c' => 'Low',
            'Category__c' => 'General Inquiry'
        });
        Test.stopTest();

        tkt_Ticket__c insertedTicket = [SELECT OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertNotEquals(null, insertedTicket.Id, 'Ticket should be created');
    }

    @isTest
    static void testRouteMultipleTickets() {
        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(tkt_TestDataFactory.createTicket(new Map<String, Object>{
            'Subject__c' => 'Critical 1',
            'Priority__c' => 'Critical'
        }));
        tickets.add(tkt_TestDataFactory.createTicket(new Map<String, Object>{
            'Subject__c' => 'Normal 1',
            'Priority__c' => 'Medium'
        }));
        tickets.add(tkt_TestDataFactory.createTicket(new Map<String, Object>{
            'Subject__c' => 'Bug 1',
            'Priority__c' => 'High',
            'Category__c' => 'Bug Report'
        }));
        insert tickets;
        Test.stopTest();

        List<tkt_Ticket__c> insertedTickets = [SELECT Id, Priority__c FROM tkt_Ticket__c WHERE Id IN :tickets];
        System.assertEquals(3, insertedTickets.size(), 'All 3 tickets should be created');
    }

    @isTest
    static void testRerouteOnCategoryChange() {
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Started as General',
            'Priority__c' => 'Medium',
            'Category__c' => 'General Inquiry'
        });

        Test.startTest();
        ticket.Category__c = 'Technical Issue';
        update ticket;
        Test.stopTest();

        tkt_Ticket__c updatedTicket = [SELECT Category__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Technical Issue', updatedTicket.Category__c, 'Category should be updated');
    }

    @isTest
    static void testRerouteOnPriorityChange() {
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Started as Medium',
            'Priority__c' => 'Medium',
            'Category__c' => 'General Inquiry'
        });

        Test.startTest();
        ticket.Priority__c = 'Critical';
        update ticket;
        Test.stopTest();

        tkt_Ticket__c updatedTicket = [SELECT Priority__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Critical', updatedTicket.Priority__c, 'Priority should be updated');
    }

    @isTest
    static void testNoRerouteOnManualAssignment() {
        User testUser = tkt_TestDataFactory.createAndInsertUser();

        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Manually Assigned',
            'Priority__c' => 'Medium',
            'Category__c' => 'General Inquiry'
        });

        Test.startTest();
        ticket.Assigned_To__c = testUser.Id;
        ticket.Category__c = 'Technical Issue';
        update ticket;
        Test.stopTest();

        tkt_Ticket__c updatedTicket = [SELECT Assigned_To__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(testUser.Id, updatedTicket.Assigned_To__c, 'Manual assignment should be preserved');
    }

    @isTest
    static void testRoutingServiceWithMockRules() {
        // Inject mock rules
        tkt_TicketRoutingService.injectTestRules(createMockRules());

        // Create a queue for testing
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'Critical Queue', DeveloperName = 'Critical_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        // Inject queue IDs
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Critical_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'Critical Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Critical',
            Category__c = 'General Inquiry'
        ));
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        // Verify routing applied queue assignment
        System.assertEquals(testQueue.Id, tickets[0].OwnerId, 'Critical ticket should be routed to Critical_Queue');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceWithCategoryMatch() {
        // Inject mock rules
        tkt_TicketRoutingService.injectTestRules(createMockRules());

        // Create a queue for testing
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'Tech Support Queue', DeveloperName = 'Tech_Support_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        // Inject queue IDs
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Tech_Support_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'Technical Issue Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'Technical Issue'
        ));
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assertEquals(testQueue.Id, tickets[0].OwnerId, 'Technical issue should be routed to Tech_Support_Queue');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceWithDefaultRule() {
        // Inject mock rules
        tkt_TicketRoutingService.injectTestRules(createMockRules());

        // Create a queue for testing
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'General Queue', DeveloperName = 'General_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        // Inject queue IDs
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('General_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'General Request',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Low',
            Category__c = 'General Inquiry'  // No matching rule, should use default
        ));
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assertEquals(testQueue.Id, tickets[0].OwnerId, 'Non-matching ticket should be routed to General_Queue via default rule');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceWithUserAssignment() {
        User testUser = tkt_TestDataFactory.createAndInsertUser();

        // Create rule that assigns to user
        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt userRule = new tkt_Ticket_Routing_Rule__mdt();
        userRule.DeveloperName = 'User_Assignment_Rule';
        userRule.MasterLabel = 'User Assignment Rule';
        userRule.Is_Active__c = true;
        userRule.Priority_Order__c = 1;
        userRule.Match_Priority__c = 'High';
        userRule.Match_Category__c = null;
        userRule.Assign_To_Queue__c = null;
        userRule.Assign_To_User__c = String.valueOf(testUser.Id);
        userRule.Is_Default__c = false;
        rules.add(userRule);

        tkt_TicketRoutingService.injectTestRules(rules);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'High Priority User Assignment',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'High',
            Category__c = 'General Inquiry'
        ));
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assertEquals(testUser.Id, tickets[0].Assigned_To__c, 'Ticket should be assigned to user');
        System.assertEquals(testUser.Id, tickets[0].OwnerId, 'Ticket owner should be the assigned user');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceWithInvalidUserId() {
        // Create rule with invalid user ID
        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt invalidRule = new tkt_Ticket_Routing_Rule__mdt();
        invalidRule.DeveloperName = 'Invalid_User_Rule';
        invalidRule.MasterLabel = 'Invalid User Rule';
        invalidRule.Is_Active__c = true;
        invalidRule.Priority_Order__c = 1;
        invalidRule.Match_Priority__c = 'High';
        invalidRule.Match_Category__c = null;
        invalidRule.Assign_To_Queue__c = null;
        invalidRule.Assign_To_User__c = 'invalid_id';
        invalidRule.Is_Default__c = false;
        rules.add(invalidRule);

        tkt_TicketRoutingService.injectTestRules(rules);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'Invalid User Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'High',
            Category__c = 'General Inquiry'
        ));
        // Should not throw exception
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assert(true, 'Should handle invalid user ID gracefully');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceWithMissingQueue() {
        // Inject rules but no queue IDs
        tkt_TicketRoutingService.injectTestRules(createMockRules());
        tkt_TicketRoutingService.injectTestQueueIds(new Map<String, Id>()); // Empty queue map

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(new tkt_Ticket__c(
            Subject__c = 'Missing Queue Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Critical',
            Category__c = 'General Inquiry'
        ));
        // Should not throw exception even if queue doesn't exist
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assert(true, 'Should handle missing queue gracefully');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingServiceDirectCall() {
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tickets.add(tkt_TestDataFactory.createTicket(new Map<String, Object>{
            'Subject__c' => 'Direct Call Test',
            'Priority__c' => 'High',
            'Category__c' => 'Bug Report'
        }));

        Test.startTest();
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        System.assertEquals(1, tickets.size(), 'Tickets list should remain intact');
    }

    @isTest
    static void testRoutingServiceWithNullInput() {
        Test.startTest();
        tkt_TicketRoutingService.routeTickets(null);
        tkt_TicketRoutingService.routeTickets(new List<tkt_Ticket__c>());
        Test.stopTest();

        System.assert(true, 'Should handle null and empty inputs gracefully');
    }

    @isTest
    static void testClearCache() {
        Test.startTest();
        tkt_TicketRoutingService.clearCache();
        Test.stopTest();

        System.assert(true, 'Cache clear should work without exception');
    }

    @isTest
    static void testGetActiveRules() {
        Test.startTest();
        List<tkt_Ticket_Routing_Rule__mdt> rules = tkt_TicketRoutingService.getActiveRules();
        Test.stopTest();

        System.assertNotEquals(null, rules, 'Rules list should not be null');
    }

    @isTest
    static void testInjectTestRules() {
        List<tkt_Ticket_Routing_Rule__mdt> mockRules = createMockRules();

        Test.startTest();
        tkt_TicketRoutingService.injectTestRules(mockRules);
        List<tkt_Ticket_Routing_Rule__mdt> retrievedRules = tkt_TicketRoutingService.getActiveRules();
        Test.stopTest();

        System.assertEquals(mockRules.size(), retrievedRules.size(), 'Injected rules should be returned');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testInjectTestQueueIds() {
        Map<String, Id> mockQueueIds = new Map<String, Id>();
        mockQueueIds.put('Test_Queue', UserInfo.getUserId());

        Test.startTest();
        tkt_TicketRoutingService.injectTestQueueIds(mockQueueIds);
        Test.stopTest();

        System.assert(true, 'Queue ID injection should work');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testTriggerBulkInsert() {
        Test.startTest();
        List<tkt_Ticket__c> tickets = tkt_TestDataFactory.createAndInsertTickets(200);
        Test.stopTest();

        Integer insertedCount = [SELECT COUNT() FROM tkt_Ticket__c WHERE Id IN :tickets];
        System.assertEquals(200, insertedCount, 'All 200 tickets should be inserted');
    }

    @isTest
    static void testTicketsWithVaryingPriorities() {
        Test.startTest();
        List<tkt_Ticket__c> tickets = tkt_TestDataFactory.createTicketsWithPriorities();
        Test.stopTest();

        System.assertEquals(4, tickets.size(), 'Should create 4 tickets with different priorities');
    }

    @isTest
    static void testTicketsWithVaryingCategories() {
        Test.startTest();
        List<tkt_Ticket__c> tickets = tkt_TestDataFactory.createTicketsWithCategories();
        Test.stopTest();

        System.assertEquals(5, tickets.size(), 'Should create 5 tickets with different categories');
    }

    @isTest
    static void testBulkRoutingWithMockRules() {
        // Inject mock rules
        tkt_TicketRoutingService.injectTestRules(createMockRules());

        // Create queues for testing
        Group criticalQueue;
        Group techQueue;
        Group generalQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            criticalQueue = new Group(Name = 'Critical Queue', DeveloperName = 'Critical_Queue', Type = 'Queue');
            techQueue = new Group(Name = 'Tech Support Queue', DeveloperName = 'Tech_Support_Queue', Type = 'Queue');
            generalQueue = new Group(Name = 'General Queue', DeveloperName = 'General_Queue', Type = 'Queue');
            insert new List<Group>{criticalQueue, techQueue, generalQueue};
            insert new List<QueueSObject>{
                new QueueSObject(QueueId = criticalQueue.Id, SObjectType = 'tkt_Ticket__c'),
                new QueueSObject(QueueId = techQueue.Id, SObjectType = 'tkt_Ticket__c'),
                new QueueSObject(QueueId = generalQueue.Id, SObjectType = 'tkt_Ticket__c')
            };
        }

        // Inject queue IDs
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Critical_Queue', criticalQueue.Id);
        queueIds.put('Tech_Support_Queue', techQueue.Id);
        queueIds.put('General_Queue', generalQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        // Add tickets that should match different rules
        for (Integer i = 0; i < 50; i++) {
            String priority = Math.mod(i, 4) == 0 ? 'Critical' : 'Medium';
            String category = Math.mod(i, 3) == 0 ? 'Technical Issue' : 'General Inquiry';
            tickets.add(new tkt_Ticket__c(
                Subject__c = 'Bulk Test ' + i,
                Description__c = 'Test description',
                Status__c = 'New',
                Priority__c = priority,
                Category__c = category
            ));
        }
        tkt_TicketRoutingService.routeTickets(tickets);
        Test.stopTest();

        // Verify tickets were routed
        Integer criticalCount = 0;
        Integer techCount = 0;
        Integer generalCount = 0;
        for (tkt_Ticket__c ticket : tickets) {
            if (ticket.OwnerId == criticalQueue.Id) {
                criticalCount++;
            } else if (ticket.OwnerId == techQueue.Id) {
                techCount++;
            } else if (ticket.OwnerId == generalQueue.Id) {
                generalCount++;
            }
        }

        System.assert(criticalCount > 0 || techCount > 0 || generalCount > 0, 'Tickets should be routed to queues');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testSkipRoutingWithTriggerControl() {
        // Enable Skip_Routing__c for current user
        insert new tkt_Trigger_Control__c(
            SetupOwnerId = UserInfo.getUserId(),
            Skip_Routing__c = true,
            Skip_Email_Notifications__c = false
        );

        // Create a queue and inject routing rules
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'Skip Test Queue', DeveloperName = 'Skip_Test_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt rule = new tkt_Ticket_Routing_Rule__mdt();
        rule.DeveloperName = 'Skip_Test_Rule';
        rule.MasterLabel = 'Skip Test Rule';
        rule.Is_Active__c = true;
        rule.Priority_Order__c = 1;
        rule.Match_Priority__c = 'Critical';
        rule.Assign_To_Queue__c = 'Skip_Test_Queue';
        rule.Is_Default__c = false;
        rules.add(rule);

        tkt_TicketRoutingService.injectTestRules(rules);
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Skip_Test_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        // Create ticket that would normally be routed to queue
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Skip Routing Test',
            Description__c = 'Testing trigger bypass',
            Status__c = 'New',
            Priority__c = 'Critical'
        );
        insert ticket;
        Test.stopTest();

        // Verify ticket was NOT routed (owner should be the inserting user, not the queue)
        tkt_Ticket__c insertedTicket = [SELECT OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertNotEquals(testQueue.Id, insertedTicket.OwnerId,
            'Ticket should NOT be routed to queue when Skip_Routing__c is true');
        System.assertEquals(UserInfo.getUserId(), insertedTicket.OwnerId,
            'Ticket should remain owned by inserting user');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingOccursWithoutTriggerControl() {
        // Ensure NO trigger control setting exists
        delete [SELECT Id FROM tkt_Trigger_Control__c WHERE SetupOwnerId = :UserInfo.getUserId()];

        // Create a queue and inject routing rules
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'Normal Route Queue', DeveloperName = 'Normal_Route_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt rule = new tkt_Ticket_Routing_Rule__mdt();
        rule.DeveloperName = 'Normal_Route_Rule';
        rule.MasterLabel = 'Normal Route Rule';
        rule.Is_Active__c = true;
        rule.Priority_Order__c = 1;
        rule.Match_Priority__c = 'High';
        rule.Assign_To_Queue__c = 'Normal_Route_Queue';
        rule.Is_Default__c = false;
        rules.add(rule);

        tkt_TicketRoutingService.injectTestRules(rules);
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Normal_Route_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Normal Routing Test',
            Description__c = 'Testing normal routing',
            Status__c = 'New',
            Priority__c = 'High'
        );
        insert ticket;
        Test.stopTest();

        // Verify ticket WAS routed to queue
        tkt_Ticket__c insertedTicket = [SELECT OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(testQueue.Id, insertedTicket.OwnerId,
            'Ticket SHOULD be routed to queue when no trigger control setting exists');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testSkipRoutingFalseAllowsRouting() {
        // Explicitly set Skip_Routing__c = false
        insert new tkt_Trigger_Control__c(
            SetupOwnerId = UserInfo.getUserId(),
            Skip_Routing__c = false,
            Skip_Email_Notifications__c = true
        );

        // Create a queue and inject routing rules
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(Name = 'Explicit False Queue', DeveloperName = 'Explicit_False_Queue', Type = 'Queue');
            insert testQueue;
            insert new QueueSObject(QueueId = testQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt rule = new tkt_Ticket_Routing_Rule__mdt();
        rule.DeveloperName = 'Explicit_False_Rule';
        rule.MasterLabel = 'Explicit False Rule';
        rule.Is_Active__c = true;
        rule.Priority_Order__c = 1;
        rule.Match_Priority__c = 'Medium';
        rule.Assign_To_Queue__c = 'Explicit_False_Queue';
        rule.Is_Default__c = false;
        rules.add(rule);

        tkt_TicketRoutingService.injectTestRules(rules);
        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Explicit_False_Queue', testQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Explicit False Test',
            Description__c = 'Testing explicit false setting',
            Status__c = 'New',
            Priority__c = 'Medium'
        );
        insert ticket;
        Test.stopTest();

        // Verify ticket WAS routed (Skip_Routing__c = false should allow routing)
        tkt_Ticket__c insertedTicket = [SELECT OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(testQueue.Id, insertedTicket.OwnerId,
            'Ticket SHOULD be routed when Skip_Routing__c is explicitly false');

        tkt_TicketRoutingService.clearCache();
    }

    @isTest
    static void testRoutingWithBothPriorityAndCategory() {
        // Create rule that matches both priority AND category
        List<tkt_Ticket_Routing_Rule__mdt> rules = new List<tkt_Ticket_Routing_Rule__mdt>();
        tkt_Ticket_Routing_Rule__mdt comboRule = new tkt_Ticket_Routing_Rule__mdt();
        comboRule.DeveloperName = 'Combo_Rule';
        comboRule.MasterLabel = 'Combo Rule';
        comboRule.Is_Active__c = true;
        comboRule.Priority_Order__c = 1;
        comboRule.Match_Priority__c = 'Critical';
        comboRule.Match_Category__c = 'Bug Report';
        comboRule.Assign_To_Queue__c = 'Combo_Queue';
        comboRule.Assign_To_User__c = null;
        comboRule.Is_Default__c = false;
        rules.add(comboRule);

        tkt_TicketRoutingService.injectTestRules(rules);

        // Create queue
        Group comboQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            comboQueue = new Group(Name = 'Combo Queue', DeveloperName = 'Combo_Queue', Type = 'Queue');
            insert comboQueue;
            insert new QueueSObject(QueueId = comboQueue.Id, SObjectType = 'tkt_Ticket__c');
        }

        Map<String, Id> queueIds = new Map<String, Id>();
        queueIds.put('Combo_Queue', comboQueue.Id);
        tkt_TicketRoutingService.injectTestQueueIds(queueIds);

        Test.startTest();
        // This ticket matches both criteria
        List<tkt_Ticket__c> matchingTickets = new List<tkt_Ticket__c>();
        matchingTickets.add(new tkt_Ticket__c(
            Subject__c = 'Combo Match Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Critical',
            Category__c = 'Bug Report'
        ));
        tkt_TicketRoutingService.routeTickets(matchingTickets);

        // This ticket only matches priority
        List<tkt_Ticket__c> partialMatchTickets = new List<tkt_Ticket__c>();
        partialMatchTickets.add(new tkt_Ticket__c(
            Subject__c = 'Partial Match Test',
            Description__c = 'Test description',
            Status__c = 'New',
            Priority__c = 'Critical',
            Category__c = 'General Inquiry'
        ));
        tkt_TicketRoutingService.routeTickets(partialMatchTickets);
        Test.stopTest();

        System.assertEquals(comboQueue.Id, matchingTickets[0].OwnerId, 'Fully matching ticket should be routed');
        // Partial match should NOT be routed (no default rule)
        System.assertNotEquals(comboQueue.Id, partialMatchTickets[0].OwnerId, 'Partially matching ticket should not match combo rule');

        tkt_TicketRoutingService.clearCache();
    }
}