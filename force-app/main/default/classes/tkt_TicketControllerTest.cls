@isTest
private class tkt_TicketControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create tickets with comments using factory
        tkt_Ticket__c ticketWithComments = tkt_TestDataFactory.createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Test Ticket 0'
        });
        
        // Add public comment
        tkt_TestDataFactory.createAndInsertComment(ticketWithComments.Id, new Map<String, Object>{
            'Comment_Body__c' => 'Test comment 1'
        });
        
        // Add internal comment
        tkt_TestDataFactory.createAndInsertComment(ticketWithComments.Id, new Map<String, Object>{
            'Comment_Body__c' => 'Internal note',
            'Is_Internal__c' => true
        });
        
        // Create additional tickets
        tkt_TestDataFactory.createAndInsertTickets(2, new Map<String, Object>{
            'Priority__c' => 'Medium'
        });
    }

    @isTest
    static void testCheckTicketAccess() {
        Test.startTest();
        Map<String, Boolean> accessMap = tkt_TicketController.checkTicketAccess();
        Test.stopTest();

        System.assertNotEquals(null, accessMap, 'Access map should not be null');
        System.assert(accessMap.containsKey('canCreate'), 'Should contain canCreate key');
        System.assert(accessMap.containsKey('hasPermission'), 'Should contain hasPermission key');
        System.assert(accessMap.containsKey('hasAccess'), 'Should contain hasAccess key');
    }

    @isTest
    static void testCreateTicket() {
        Test.startTest();
        Id ticketId = tkt_TicketController.createTicket(
            'Test Subject',
            'Test Description',
            'Medium',
            'General Inquiry',
            'Branch',
            'Production',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, ticketId, 'Ticket should be created');

        tkt_Ticket__c ticket = [
            SELECT Subject__c, Status__c, Priority__c, Impact__c, Environment__c, Submitted_By__c
            FROM tkt_Ticket__c
            WHERE Id = :ticketId
        ];
        System.assertEquals('Test Subject', ticket.Subject__c, 'Subject should match');
        System.assertEquals('New', ticket.Status__c, 'Status should be New');
        System.assertEquals('Branch', ticket.Impact__c, 'Impact should be Branch');
        System.assertEquals('Production', ticket.Environment__c, 'Environment should be Production');
        System.assertEquals(UserInfo.getUserId(), ticket.Submitted_By__c, 'Submitted By should be current user');
    }

    @isTest
    static void testCreateTicketWithDefaultPriority() {
        Test.startTest();
        Id ticketId = tkt_TicketController.createTicket(
            'Test Subject',
            'Test Description',
            null,
            'Bug Report',
            null,
            null,
            null
        );
        Test.stopTest();

        tkt_Ticket__c ticket = [SELECT Priority__c, Impact__c, Environment__c FROM tkt_Ticket__c WHERE Id = :ticketId];
        System.assertEquals('Medium', ticket.Priority__c, 'Default priority should be Medium');
        System.assertEquals('Individual', ticket.Impact__c, 'Default impact should be Individual');
        System.assertEquals('Production', ticket.Environment__c, 'Default environment should be Production');
    }

    @isTest
    static void testCreateTicketValidation() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.createTicket(null, 'Description', 'Medium', 'General Inquiry', null, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null subject');
    }

    @isTest
    static void testCreateTicketWithBlankSubject() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.createTicket('   ', 'Description', 'High', 'Technical Issue', null, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for blank subject');
    }

    @isTest
    static void testCreateTicketWithRelatedRecord() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Test.startTest();
        Id ticketId = tkt_TicketController.createTicket(
            'Issue with Account',
            'Test Description',
            'High',
            'Technical Issue',
            'Division',
            'Sandbox',
            testAccount.Id
        );
        Test.stopTest();

        tkt_Ticket__c ticket = [SELECT Related_Record_Id__c FROM tkt_Ticket__c WHERE Id = :ticketId];
        System.assertEquals(testAccount.Id, ticket.Related_Record_Id__c, 'Related record ID should be saved');
    }

    @isTest
    static void testAttachFile() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];
        String base64Data = tkt_TestDataFactory.createMockBase64Data();

        Test.startTest();
        Id cvId = tkt_TicketController.attachFile(
            ticket.Id,
            'screenshot.png',
            base64Data,
            'image/png'
        );
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'ContentVersion should be created');

        List<ContentDocumentLink> cdls = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :ticket.Id
        ];
        System.assertEquals(1, cdls.size(), 'File should be linked to ticket');
    }

    @isTest
    static void testAttachMultipleFiles() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];
        String base64Data = tkt_TestDataFactory.createMockBase64Data();

        Test.startTest();
        tkt_TicketController.attachFile(ticket.Id, 'screenshot1.png', base64Data, 'image/png');
        tkt_TicketController.attachFile(ticket.Id, 'screenshot2.jpg', base64Data, 'image/jpeg');
        Test.stopTest();

        List<ContentDocumentLink> cdls = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :ticket.Id
        ];
        System.assertEquals(2, cdls.size(), 'Both files should be linked to ticket');
    }

    @isTest
    static void testAttachFileValidation() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.attachFile(null, 'test.png', 'base64data', 'image/png');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null ticket ID');
    }

    @isTest
    static void testAttachFileNoFileName() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.attachFile(ticket.Id, '', 'base64data', 'image/png');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for blank file name');
    }

    @isTest
    static void testGetMyTickets() {
        Test.startTest();
        List<tkt_Ticket__c> tickets = tkt_TicketController.getMyTickets();
        Test.stopTest();

        System.assertEquals(3, tickets.size(), 'Should return 3 tickets from test setup');
    }

    @isTest
    static void testGetTicketWithComments() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c WHERE Subject__c = 'Test Ticket 0' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = tkt_TicketController.getTicketWithComments(ticket.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.get('ticket'), 'Ticket should be returned');
        List<tkt_Ticket_Comment__c> comments = (List<tkt_Ticket_Comment__c>) result.get('comments');
        // Should only return non-internal comments
        System.assertEquals(1, comments.size(), 'Should return 1 non-internal comment');
    }

    @isTest
    static void testGetTicketWithCommentsValidation() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.getTicketWithComments(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null ticket ID');
    }

    @isTest
    static void testAddComment() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];

        Test.startTest();
        Id commentId = tkt_TicketController.addComment(ticket.Id, 'New test comment');
        Test.stopTest();

        System.assertNotEquals(null, commentId, 'Comment should be created');

        tkt_Ticket_Comment__c comment = [
            SELECT Comment_Body__c, Posted_By__c, Is_Internal__c 
            FROM tkt_Ticket_Comment__c 
            WHERE Id = :commentId
        ];
        System.assertEquals('New test comment', comment.Comment_Body__c, 'Comment body should match');
        System.assertEquals(UserInfo.getUserId(), comment.Posted_By__c, 'Posted By should be current user');
        System.assertEquals(false, comment.Is_Internal__c, 'Should not be internal');
    }

    @isTest
    static void testAddCommentValidation() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.addComment(ticket.Id, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for empty comment');
    }

    @isTest
    static void testAddCommentNullTicket() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.addComment(null, 'Test comment');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null ticket ID');
    }

    @isTest
    static void testCheckTicketAccessWithPermissionSet() {
        User testUser = tkt_TestDataFactory.createAndInsertUser();
        tkt_TestDataFactory.assignTicketPermissionSet(testUser.Id);

        Test.startTest();
        System.runAs(testUser) {
            Map<String, Boolean> accessMap = tkt_TicketController.checkTicketAccess();
            System.assert(accessMap.get('hasAccess'), 'User with permission set should have access');
        }
        Test.stopTest();
    }

    @isTest
    static void testCloseTicket() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];

        Test.startTest();
        tkt_TicketController.closeTicket(ticket.Id, 'Issue resolved by user');
        Test.stopTest();

        tkt_Ticket__c closedTicket = [SELECT Status__c, Close_Note__c, Closed_Date__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Closed', closedTicket.Status__c, 'Status should be Closed');
        System.assertEquals('Issue resolved by user', closedTicket.Close_Note__c, 'Close note should be saved');
        System.assertNotEquals(null, closedTicket.Closed_Date__c, 'Closed date should be set');

        // Verify comment was added
        List<tkt_Ticket_Comment__c> comments = [SELECT Comment_Body__c FROM tkt_Ticket_Comment__c WHERE Ticket__c = :ticket.Id ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals(1, comments.size(), 'Closure comment should be added');
        System.assert(comments[0].Comment_Body__c.contains('closed by submitter'), 'Comment should mention ticket closed');
    }

    @isTest
    static void testCloseTicketWithoutNote() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];

        Test.startTest();
        tkt_TicketController.closeTicket(ticket.Id, null);
        Test.stopTest();

        tkt_Ticket__c closedTicket = [SELECT Status__c, Close_Note__c FROM tkt_Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Closed', closedTicket.Status__c, 'Status should be Closed');
        System.assertEquals(null, closedTicket.Close_Note__c, 'Close note should be null');
    }

    @isTest
    static void testCloseTicketAlreadyClosed() {
        tkt_Ticket__c ticket = [SELECT Id FROM tkt_Ticket__c LIMIT 1];
        ticket.Status__c = 'Closed';
        update ticket;

        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.closeTicket(ticket.Id, 'Trying to close again');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException wraps messages, so just verify exception was thrown
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for already closed ticket');
    }

    @isTest
    static void testCloseTicketNullId() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            tkt_TicketController.closeTicket(null, 'Close note');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null ticket ID');
    }
}