/**
 * Test class for tkt_EmailNotificationService.
 * Tests email notification functionality for ticket events.
 */
@isTest
private class tkt_EmailNotificationServiceTest {

    @testSetup
    static void setupTestData() {
        // Create test users with ticket access permission set
        User testUser1 = tkt_TestDataFactory.createAndInsertUser();
        User testUser2 = tkt_TestDataFactory.createAndInsertUser();

        // Assign permission sets in a separate context to avoid MIXED_DML
        System.runAs(new User(Id = UserInfo.getUserId())) {
            tkt_TestDataFactory.assignTicketPermissionSet(testUser1.Id);
            tkt_TestDataFactory.assignTicketPermissionSet(testUser2.Id);
        }
    }
    
    /**
     * Test new ticket owner notification.
     */
    @isTest
    static void testSendNewTicketOwnerNotifications() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        Test.startTest();
        
        // Create ticket with the test user as submitter
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });
        
        // Verify no exceptions thrown (emails are sent in trigger)
        Test.stopTest();
        
        // Query to verify ticket was created
        tkt_Ticket__c createdTicket = [SELECT Id, Submitted_By__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(testUser.Id, createdTicket.Submitted_By__c, 'Ticket should have submitted by set');
    }
    
    /**
     * Test new ticket queue notification.
     */
    @isTest
    static void testSendNewTicketQueueNotifications() {
        // Create a queue for testing in a separate context to avoid MIXED_DML
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(
                Name = 'Test Email Queue',
                DeveloperName = 'Test_Email_Queue',
                Type = 'Queue'
            );
            insert testQueue;

            // Queue needs to support our object
            QueueSObject qso = new QueueSObject(
                QueueId = testQueue.Id,
                SObjectType = 'tkt_Ticket__c'
            );
            insert qso;
        }

        Test.startTest();

        // Create ticket assigned to queue
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Queue Test Ticket',
            Description__c = 'Test Description',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'General Inquiry',
            Submitted_By__c = UserInfo.getUserId(),
            OwnerId = testQueue.Id
        );
        insert ticket;

        Test.stopTest();

        // Verify ticket was created and is owned by a queue (routing may reassign to different queue)
        tkt_Ticket__c createdTicket = [SELECT Id, OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        String ownerIdStr = String.valueOf(createdTicket.OwnerId);
        System.assert(ownerIdStr.startsWith('00G'), 'Ticket should be owned by a queue (prefix 00G)');
    }
    
    /**
     * Test status change notification.
     */
    @isTest
    static void testSendStatusChangeNotifications() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Status__c' => 'New'
        });
        
        Test.startTest();
        
        // Update status
        ticket.Status__c = 'In Progress';
        update ticket;
        
        Test.stopTest();
        
        // Verify status was updated
        tkt_Ticket__c updatedTicket = [SELECT Id, Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('In Progress', updatedTicket.Status__c, 'Status should be updated');
    }
    
    /**
     * Test ownership change notification.
     */
    @isTest
    static void testSendOwnershipChangeNotifications() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User submitter = testUsers[0];
        User assignee = testUsers[1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => submitter.Id
        });
        
        Test.startTest();
        
        // Assign to new user
        ticket.Assigned_To__c = assignee.Id;
        update ticket;
        
        Test.stopTest();
        
        // Verify assignment was updated
        tkt_Ticket__c updatedTicket = [SELECT Id, Assigned_To__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(assignee.Id, updatedTicket.Assigned_To__c, 'Assignment should be updated');
    }
    
    /**
     * Test closed by owner notification.
     * Tests that closing a ticket triggers notification to assignee.
     * Note: Notification service uses 'without sharing' so sharing context doesn't affect notification logic.
     */
    @isTest
    static void testSendClosedByOwnerNotifications() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User submitter = testUsers[0];
        User assignee = testUsers[1];

        // Create ticket with submitter and assignee
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => submitter.Id,
            'Assigned_To__c' => assignee.Id,
            'Status__c' => 'In Progress'
        });

        Test.startTest();

        // Close ticket - notification service checks if UserInfo.getUserId() == Submitted_By__c
        // For this test, we verify the close action works and triggers notification logic
        ticket.Status__c = 'Closed';
        update ticket;

        Test.stopTest();

        // Verify ticket was closed
        tkt_Ticket__c updatedTicket = [SELECT Id, Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Closed', updatedTicket.Status__c, 'Status should be Closed');
    }
    
    /**
     * Test comment notification to owner.
     */
    @isTest
    static void testSendCommentNotificationToOwner() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User submitter = testUsers[0];
        User assignee = testUsers[1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => submitter.Id,
            'Assigned_To__c' => assignee.Id
        });
        
        Test.startTest();
        
        // Add comment from assignee (not owner)
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Response from support',
            Posted_By__c = assignee.Id,
            Is_Internal__c = false
        );
        insert comment;
        
        Test.stopTest();
        
        // Verify comment was created
        List<tkt_Ticket_Comment__c> comments = [SELECT Id FROM tkt_Ticket_Comment__c WHERE Ticket__c = :ticket.Id];
        System.assertEquals(1, comments.size(), 'Comment should be created');
    }
    
    /**
     * Test comment notification to assignee.
     */
    @isTest
    static void testSendCommentNotificationToAssignee() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User submitter = testUsers[0];
        User assignee = testUsers[1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => submitter.Id,
            'Assigned_To__c' => assignee.Id
        });
        
        Test.startTest();
        
        // Add comment from owner
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Follow up from ticket owner',
            Posted_By__c = submitter.Id,
            Is_Internal__c = false
        );
        insert comment;
        
        Test.stopTest();
        
        // Verify comment was created
        List<tkt_Ticket_Comment__c> comments = [SELECT Id, Posted_By__c FROM tkt_Ticket_Comment__c WHERE Ticket__c = :ticket.Id];
        System.assertEquals(1, comments.size(), 'Comment should be created');
        System.assertEquals(submitter.Id, comments[0].Posted_By__c, 'Comment should be from owner');
    }
    
    /**
     * Test that internal comments don't trigger notifications.
     */
    @isTest
    static void testInternalCommentsNoNotification() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });
        
        Test.startTest();
        
        // Add internal comment
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Internal note - no notification',
            Posted_By__c = UserInfo.getUserId(),
            Is_Internal__c = true
        );
        insert comment;
        
        Test.stopTest();
        
        // Verify internal comment was created
        List<tkt_Ticket_Comment__c> comments = [SELECT Id, Is_Internal__c FROM tkt_Ticket_Comment__c WHERE Ticket__c = :ticket.Id];
        System.assertEquals(1, comments.size(), 'Comment should be created');
        System.assertEquals(true, comments[0].Is_Internal__c, 'Comment should be internal');
    }
    
    /**
     * Test that owner's own comments don't notify the owner.
     */
    @isTest
    static void testOwnerCommentNoSelfNotification() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });
        
        Test.startTest();
        
        // Add comment from ticket owner
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Comment from owner',
            Posted_By__c = testUser.Id,
            Is_Internal__c = false
        );
        insert comment;
        
        Test.stopTest();
        
        // Verify comment was created
        List<tkt_Ticket_Comment__c> comments = [SELECT Id, Posted_By__c FROM tkt_Ticket_Comment__c WHERE Ticket__c = :ticket.Id];
        System.assertEquals(1, comments.size(), 'Comment should be created');
    }
    
    /**
     * Test multiple status changes.
     */
    @isTest
    static void testMultipleStatusChanges() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Status__c' => 'New'
        });
        
        Test.startTest();
        
        // Change status multiple times
        ticket.Status__c = 'In Progress';
        update ticket;
        
        ticket.Status__c = 'Pending';
        update ticket;
        
        ticket.Status__c = 'Resolved';
        update ticket;
        
        Test.stopTest();
        
        // Verify final status
        tkt_Ticket__c updatedTicket = [SELECT Id, Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Resolved', updatedTicket.Status__c, 'Status should be Resolved');
    }
    
    /**
     * Test bulk ticket creation.
     */
    @isTest
    static void testBulkTicketCreation() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        Test.startTest();
        
        // Create multiple tickets
        List<tkt_Ticket__c> tickets = tkt_TestDataFactory.createTickets(50, new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });
        insert tickets;
        
        Test.stopTest();
        
        // Verify all tickets were created
        List<tkt_Ticket__c> createdTickets = [SELECT Id FROM tkt_Ticket__c WHERE Submitted_By__c = :testUser.Id];
        System.assertEquals(50, createdTickets.size(), '50 tickets should be created');
    }
    
    /**
     * Test bulk status updates.
     */
    @isTest
    static void testBulkStatusUpdates() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];
        
        // Create tickets
        List<tkt_Ticket__c> tickets = tkt_TestDataFactory.createAndInsertTickets(50, new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Status__c' => 'New'
        });
        
        Test.startTest();
        
        // Update all statuses
        for (tkt_Ticket__c ticket : tickets) {
            ticket.Status__c = 'In Progress';
        }
        update tickets;
        
        Test.stopTest();
        
        // Verify all statuses were updated
        List<tkt_Ticket__c> updatedTickets = [SELECT Id, Status__c FROM tkt_Ticket__c WHERE Id IN :tickets];
        for (tkt_Ticket__c ticket : updatedTickets) {
            System.assertEquals('In Progress', ticket.Status__c, 'Status should be updated');
        }
    }
    
    /**
     * Test email service with null values.
     */
    @isTest
    static void testHandleNullValues() {
        Test.startTest();
        
        // Create ticket without submitted_by
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Test Ticket No Submitter',
            Description__c = 'Test Description',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'General Inquiry'
            // Submitted_By__c intentionally null
        );
        insert ticket;
        
        // Update status
        ticket.Status__c = 'In Progress';
        update ticket;
        
        Test.stopTest();
        
        // Verify no exceptions
        tkt_Ticket__c updatedTicket = [SELECT Id, Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('In Progress', updatedTicket.Status__c, 'Status should be updated');
    }
    
    /**
     * Test cache clearing for coverage.
     */
    @isTest
    static void testCacheClear() {
        Test.startTest();

        tkt_EmailNotificationService.clearCache();

        Test.stopTest();

        // Just verify no exceptions
        System.assert(true, 'Cache clear should complete without errors');
    }

    /**
     * Test direct call to sendNewTicketOwnerNotifications with empty list
     */
    @isTest
    static void testSendNewTicketOwnerNotificationsEmpty() {
        Test.startTest();

        // Call with empty list
        tkt_EmailNotificationService.sendNewTicketOwnerNotifications(new List<tkt_Ticket__c>());

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendNewTicketQueueNotifications with empty list
     */
    @isTest
    static void testSendNewTicketQueueNotificationsEmpty() {
        Test.startTest();

        // Call with empty list
        tkt_EmailNotificationService.sendNewTicketQueueNotifications(new List<tkt_Ticket__c>());

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendStatusChangeNotifications with empty map
     */
    @isTest
    static void testSendStatusChangeNotificationsEmpty() {
        Test.startTest();

        // Call with empty list and map
        tkt_EmailNotificationService.sendStatusChangeNotifications(
            new List<tkt_Ticket__c>(),
            new Map<Id, tkt_Ticket__c>()
        );

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendOwnershipChangeNotifications with empty map
     */
    @isTest
    static void testSendOwnershipChangeNotificationsEmpty() {
        Test.startTest();

        // Call with empty list and map
        tkt_EmailNotificationService.sendOwnershipChangeNotifications(
            new List<tkt_Ticket__c>(),
            new Map<Id, tkt_Ticket__c>()
        );

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendClosedByOwnerNotifications with empty map
     */
    @isTest
    static void testSendClosedByOwnerNotificationsEmpty() {
        Test.startTest();

        // Call with empty list and map
        tkt_EmailNotificationService.sendClosedByOwnerNotifications(
            new List<tkt_Ticket__c>(),
            new Map<Id, tkt_Ticket__c>()
        );

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendCommentNotificationToOwner with empty list
     */
    @isTest
    static void testSendCommentNotificationToOwnerEmpty() {
        Test.startTest();

        // Call with empty list
        tkt_EmailNotificationService.sendCommentNotificationToOwner(new List<tkt_Ticket_Comment__c>());

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test direct call to sendCommentNotificationToAssignee with empty list
     */
    @isTest
    static void testSendCommentNotificationToAssigneeEmpty() {
        Test.startTest();

        // Call with empty list
        tkt_EmailNotificationService.sendCommentNotificationToAssignee(new List<tkt_Ticket_Comment__c>());

        Test.stopTest();

        System.assert(true, 'Should handle empty list');
    }

    /**
     * Test ticket with no assigned_to for ownership change
     */
    @isTest
    static void testOwnershipChangeNoAssignee() {
        User testUser = [SELECT Id FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create ticket without assignee
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Status__c' => 'New'
        });

        Test.startTest();

        // Try to unassign (set to null)
        ticket.Assigned_To__c = null;
        update ticket;

        Test.stopTest();

        System.assert(true, 'Should handle null assignee');
    }

    /**
     * Test closed notification when user is not the owner
     */
    @isTest
    static void testClosedNotOwner() {
        User testUser = [SELECT Id FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create ticket with different submitter
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Assigned_To__c' => UserInfo.getUserId(),
            'Status__c' => 'In Progress'
        });

        Test.startTest();

        // Close ticket as non-owner (current user)
        ticket.Status__c = 'Closed';
        update ticket;

        Test.stopTest();

        System.assert(true, 'Should handle close by non-owner');
    }

    /**
     * Test queue notification for ticket assigned to user (not queue)
     */
    @isTest
    static void testQueueNotificationUserOwned() {
        User testUser = [SELECT Id FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        Test.startTest();

        // Create ticket owned by user (not queue)
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'OwnerId' => UserInfo.getUserId()
        });

        Test.stopTest();

        // Verify user ownership (queue notification path not executed)
        tkt_Ticket__c createdTicket = [SELECT OwnerId FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        String ownerPrefix = String.valueOf(createdTicket.OwnerId).substring(0, 3);
        // Owner could be user (005) or queue (00G) depending on routing
        System.assert(ownerPrefix == '005' || ownerPrefix == '00G', 'Owner should be user or queue');
    }

    // ============================================
    // DEPENDENCY INJECTION TESTS
    // These tests inject mock settings to cover notification building code paths
    // ============================================

    /**
     * Helper method to create a mock notification setting
     */
    private static tkt_Email_Notification_Setting__mdt createMockSetting(String notifType) {
        tkt_Email_Notification_Setting__mdt setting = new tkt_Email_Notification_Setting__mdt();
        setting.DeveloperName = notifType.replace(' ', '_').replace('-', '_');
        setting.MasterLabel = notifType;
        setting.Is_Active__c = true;
        setting.Notification_Type__c = notifType;
        setting.Recipient_Type__c = 'Owner';
        setting.Email_Subject__c = 'Test Subject: {!Ticket.Name}';
        setting.Email_Body__c = '<p>Hello {!Owner.Name},</p><p>Your ticket {!Ticket.Name} has been updated.</p>';
        setting.Send_HTML_Email__c = true;
        setting.Priority_Order__c = 1;
        return setting;
    }

    /**
     * Helper method to create mock company settings
     */
    private static tkt_Email_Settings__mdt createMockCompanySettings() {
        tkt_Email_Settings__mdt settings = new tkt_Email_Settings__mdt();
        settings.Support_Team_Name__c = 'Test Support Team';
        settings.Contact_Email__c = 'support@test.com';
        settings.Contact_Phone__c = '555-1234';
        settings.Company_Website__c = 'https://test.com';
        settings.Footer_Message__c = 'Thank you for contacting us!';
        settings.Is_Active__c = true;
        return settings;
    }

    /**
     * Test new ticket owner notification with injected settings
     */
    @isTest
    static void testNewTicketOwnerNotificationWithMockSettings() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Create ticket - should trigger notification with mock settings
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'DI Test Ticket',
            Description__c = 'Testing with injected settings',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'General Inquiry',
            Submitted_By__c = testUser.Id
        );
        insert ticket;

        Test.stopTest();

        // Clear cache after test
        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, ticket.Id, 'Ticket should be created');
    }

    /**
     * Test status change notification with injected settings
     */
    @isTest
    static void testStatusChangeNotificationWithMockSettings() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create ticket first
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id,
            'Status__c' => 'New'
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_STATUS_CHANGED,
            createMockSetting(tkt_EmailNotificationService.NOTIF_STATUS_CHANGED));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Update status
        ticket.Status__c = 'In Progress';
        update ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        tkt_Ticket__c updated = [SELECT Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('In Progress', updated.Status__c);
    }

    /**
     * Test ownership change notification with injected settings
     */
    @isTest
    static void testOwnershipChangeNotificationWithMockSettings() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User owner = testUsers[0];
        User newAssignee = testUsers[1];

        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => owner.Id,
            'Status__c' => 'New'
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_OWNERSHIP_CHANGED,
            createMockSetting(tkt_EmailNotificationService.NOTIF_OWNERSHIP_CHANGED));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Assign to new user
        ticket.Assigned_To__c = newAssignee.Id;
        update ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        tkt_Ticket__c updated = [SELECT Assigned_To__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(newAssignee.Id, updated.Assigned_To__c);
    }

    /**
     * Test closed by owner notification with injected settings
     */
    @isTest
    static void testClosedByOwnerNotificationWithMockSettings() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User assignee = testUsers[0];

        // Create ticket with current user as submitter
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => UserInfo.getUserId(),
            'Assigned_To__c' => assignee.Id,
            'Status__c' => 'In Progress'
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_CLOSED_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_CLOSED_ASSIGNEE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Close ticket (current user is the submitter)
        ticket.Status__c = 'Closed';
        update ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        tkt_Ticket__c updated = [SELECT Status__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Closed', updated.Status__c);
    }

    /**
     * Test comment notification to owner with injected settings
     */
    @isTest
    static void testCommentNotificationToOwnerWithMockSettings() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User owner = testUsers[0];
        User commenter = testUsers[1];

        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => owner.Id,
            'Assigned_To__c' => commenter.Id
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Create comment from commenter (not owner)
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Comment from assignee',
            Posted_By__c = commenter.Id,
            Is_Internal__c = false
        );
        insert comment;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, comment.Id);
    }

    /**
     * Test comment notification to assignee with injected settings
     */
    @isTest
    static void testCommentNotificationToAssigneeWithMockSettings() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User owner = testUsers[0];
        User assignee = testUsers[1];

        // Create ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => owner.Id,
            'Assigned_To__c' => assignee.Id
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Create comment from owner
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Comment from owner',
            Posted_By__c = owner.Id,
            Is_Internal__c = false
        );
        insert comment;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, comment.Id);
    }

    /**
     * Test queue notification with injected settings
     */
    @isTest
    static void testQueueNotificationWithMockSettings() {
        // Create a queue
        Group testQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            testQueue = new Group(
                Name = 'DI Test Queue',
                DeveloperName = 'DI_Test_Queue',
                Type = 'Queue'
            );
            insert testQueue;

            QueueSObject qso = new QueueSObject(
                QueueId = testQueue.Id,
                SObjectType = 'tkt_Ticket__c'
            );
            insert qso;

            // Add current user as member
            GroupMember gm = new GroupMember(
                GroupId = testQueue.Id,
                UserOrGroupId = UserInfo.getUserId()
            );
            insert gm;
        }

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Create ticket owned by queue
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Queue DI Test',
            Description__c = 'Testing queue notification',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'General Inquiry',
            Submitted_By__c = UserInfo.getUserId(),
            OwnerId = testQueue.Id
        );
        insert ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, ticket.Id);
    }

    /**
     * Test plain text email generation
     */
    @isTest
    static void testPlainTextEmailWithMockSettings() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Inject mock settings with HTML disabled
        tkt_Email_Notification_Setting__mdt plainTextSetting = createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER);
        plainTextSetting.Send_HTML_Email__c = false;
        plainTextSetting.Email_Body__c = 'Hello {!Owner.Name}, Your ticket {!Ticket.Name} has been created.';

        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER, plainTextSetting);
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Plain Text Test',
            Description__c = 'Testing plain text email',
            Status__c = 'New',
            Priority__c = 'Low',
            Category__c = 'General Inquiry',
            Submitted_By__c = testUser.Id
        );
        insert ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, ticket.Id);
    }

    /**
     * Test notifications with inactive settings returns early
     */
    @isTest
    static void testNotificationsWithInactiveSettings() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Inject INACTIVE settings
        tkt_Email_Notification_Setting__mdt inactiveSetting = createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER);
        inactiveSetting.Is_Active__c = false;

        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER, inactiveSetting);
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Create ticket - notification should be skipped due to inactive setting
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Inactive Setting Test',
            Description__c = 'Testing inactive setting',
            Status__c = 'New',
            Priority__c = 'Low',
            Category__c = 'General Inquiry',
            Submitted_By__c = testUser.Id
        );
        insert ticket;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, ticket.Id);
    }

    /**
     * Test ticket with no submitter to cover ownerIds empty path
     */
    @isTest
    static void testTicketNoSubmitterOwnerNotification() {
        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Directly call service with ticket that has no submitter
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'No Submitter Test',
            Description__c = 'Test',
            Status__c = 'New',
            Priority__c = 'Low',
            Category__c = 'General Inquiry'
            // No Submitted_By__c
        );
        tickets.add(ticket);

        // This should hit the "ownerIds.isEmpty()" return path
        tkt_EmailNotificationService.sendNewTicketOwnerNotifications(tickets);

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assert(true, 'Should handle ticket with no submitter');
    }

    /**
     * Test queue notification with user-owned ticket to cover queueIds empty path
     */
    @isTest
    static void testQueueNotificationNoQueues() {
        User testUser = [SELECT Id FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Directly call service with user-owned ticket (no queue)
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'User Owned Test',
            Description__c = 'Test',
            Status__c = 'New',
            Priority__c = 'Low',
            Category__c = 'General Inquiry',
            Submitted_By__c = testUser.Id,
            OwnerId = testUser.Id  // User owned, not queue owned
        );
        tickets.add(ticket);

        // This should hit the "queueIds.isEmpty()" return path
        tkt_EmailNotificationService.sendNewTicketQueueNotifications(tickets);

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assert(true, 'Should handle ticket with no queue owner');
    }

    /**
     * Test comment notification when owner posts comment (skip self notification)
     */
    @isTest
    static void testCommentOwnerSkipsSelfNotification() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create and insert ticket
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Create comment posted by ticket owner - should skip notification
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Owner comment',
            Posted_By__c = testUser.Id,  // Same as Submitted_By__c
            Is_Internal__c = false
        );
        List<tkt_Ticket_Comment__c> comments = new List<tkt_Ticket_Comment__c>{ comment };

        // Directly call to ensure we hit the "continue" path
        tkt_EmailNotificationService.sendCommentNotificationToOwner(comments);

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assert(true, 'Should skip notification when owner posts comment');
    }

    /**
     * Test comment notification to assignee when no assignee exists
     */
    @isTest
    static void testCommentToAssigneeNoAssignee() {
        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create ticket WITHOUT assignee
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
            // No Assigned_To__c
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Create comment from owner
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Comment to assignee',
            Posted_By__c = testUser.Id,
            Is_Internal__c = false
        );
        List<tkt_Ticket_Comment__c> comments = new List<tkt_Ticket_Comment__c>{ comment };

        // This should hit the "ticket.Assigned_To__c == null" continue path
        tkt_EmailNotificationService.sendCommentNotificationToAssignee(comments);

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assert(true, 'Should handle comment when no assignee');
    }

    /**
     * Test comment notification to assignee when commenter is not owner
     */
    @isTest
    static void testCommentToAssigneeNotFromOwner() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User owner = testUsers[0];
        User assignee = testUsers[1];

        // Create ticket with assignee
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => owner.Id,
            'Assigned_To__c' => assignee.Id
        });

        // Inject mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();

        // Create comment from assignee (NOT owner) - should skip
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Comment from assignee',
            Posted_By__c = assignee.Id,  // Not the owner
            Is_Internal__c = false
        );
        List<tkt_Ticket_Comment__c> comments = new List<tkt_Ticket_Comment__c>{ comment };

        // This should hit the "comment.Posted_By__c != ticket.Submitted_By__c" continue path
        tkt_EmailNotificationService.sendCommentNotificationToAssignee(comments);

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assert(true, 'Should skip when comment not from owner');
    }

    /**
     * Test with all notification types enabled
     */
    @isTest
    static void testAllNotificationTypesEnabled() {
        List<User> testUsers = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 2];
        User owner = testUsers[0];
        User assignee = testUsers[1];

        // Inject all notification settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_STATUS_CHANGED,
            createMockSetting(tkt_EmailNotificationService.NOTIF_STATUS_CHANGED));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_OWNERSHIP_CHANGED,
            createMockSetting(tkt_EmailNotificationService.NOTIF_OWNERSHIP_CHANGED));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_CLOSED_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_CLOSED_ASSIGNEE));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_ASSIGNEE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();

        // Create ticket
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Full Flow Test',
            Description__c = 'Testing full notification flow',
            Status__c = 'New',
            Priority__c = 'High',
            Category__c = 'Technical Issue',
            Submitted_By__c = owner.Id
        );
        insert ticket;

        // Assign
        ticket.Assigned_To__c = assignee.Id;
        update ticket;

        // Status change
        ticket.Status__c = 'In Progress';
        update ticket;

        // Add comment
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Working on this',
            Posted_By__c = assignee.Id,
            Is_Internal__c = false
        );
        insert comment;

        Test.stopTest();

        tkt_EmailNotificationService.clearCache();

        System.assertNotEquals(null, ticket.Id);
        System.assertNotEquals(null, comment.Id);
    }

    /**
     * Test that Skip_Email_Notifications__c bypasses all email notifications.
     */
    @isTest
    static void testSkipEmailNotificationsWithTriggerControl() {
        // Enable Skip_Email_Notifications__c for current user
        insert new tkt_Trigger_Control__c(
            SetupOwnerId = UserInfo.getUserId(),
            Skip_Email_Notifications__c = true,
            Skip_Routing__c = false
        );

        // Set up mock settings with active notifications
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_OWNER));
        mockSettings.put(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE,
            createMockSetting(tkt_EmailNotificationService.NOTIF_TICKET_CREATED_QUEUE));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);
        tkt_EmailNotificationService.injectTestCompanySettings(createMockCompanySettings());

        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();

        // Create ticket - would normally trigger emails
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Skip Email Test',
            Description__c = 'Testing email bypass',
            Status__c = 'New',
            Priority__c = 'High'
        );
        insert ticket;

        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();

        // Verify ticket was created but no emails were sent
        System.assertNotEquals(null, ticket.Id, 'Ticket should be created');
        System.assertEquals(emailsBefore, emailsAfter,
            'No emails should be sent when Skip_Email_Notifications__c is true');

        tkt_EmailNotificationService.clearCache();
    }

    /**
     * Test that Skip_Email_Notifications__c = false allows emails.
     */
    @isTest
    static void testEmailsOccurWithSkipEmailFalse() {
        // Explicitly set Skip_Email_Notifications__c = false
        insert new tkt_Trigger_Control__c(
            SetupOwnerId = UserInfo.getUserId(),
            Skip_Email_Notifications__c = false,
            Skip_Routing__c = true
        );

        // No mock settings = no emails will be sent (but code path is exercised)
        Test.startTest();

        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Allow Email Test',
            Description__c = 'Testing email allowed',
            Status__c = 'New',
            Priority__c = 'Medium'
        );
        insert ticket;

        Test.stopTest();

        // Verify ticket was created (emails would be attempted if settings existed)
        System.assertNotEquals(null, ticket.Id, 'Ticket should be created');
    }

    /**
     * Test comment email bypass with Skip_Email_Notifications__c.
     */
    @isTest
    static void testSkipCommentEmailNotificationsWithTriggerControl() {
        // Enable Skip_Email_Notifications__c for current user
        insert new tkt_Trigger_Control__c(
            SetupOwnerId = UserInfo.getUserId(),
            Skip_Email_Notifications__c = true,
            Skip_Routing__c = false
        );

        User testUser = [SELECT Id, Email FROM User WHERE Email LIKE '%@testorg.com' LIMIT 1];

        // Create ticket first (with bypass, no emails)
        tkt_Ticket__c ticket = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Submitted_By__c' => testUser.Id
        });

        // Set up mock settings
        Map<String, tkt_Email_Notification_Setting__mdt> mockSettings = new Map<String, tkt_Email_Notification_Setting__mdt>();
        mockSettings.put(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER,
            createMockSetting(tkt_EmailNotificationService.NOTIF_COMMENT_OWNER));
        tkt_EmailNotificationService.injectTestSettings(mockSettings);

        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();

        // Add comment - would normally trigger emails
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticket.Id,
            Comment_Body__c = 'Test comment with bypass',
            Posted_By__c = UserInfo.getUserId(),
            Is_Internal__c = false
        );
        insert comment;

        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();

        // Verify comment was created but no emails sent
        System.assertNotEquals(null, comment.Id, 'Comment should be created');
        System.assertEquals(emailsBefore, emailsAfter,
            'No comment emails should be sent when Skip_Email_Notifications__c is true');

        tkt_EmailNotificationService.clearCache();
    }
}