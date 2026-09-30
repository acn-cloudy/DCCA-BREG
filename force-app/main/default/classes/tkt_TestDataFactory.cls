/**
 * Factory class for creating test data.
 * Centralizes test data creation for consistent and maintainable tests.
 */
@isTest
public class tkt_TestDataFactory {

    /**
     * Create a single ticket with default values.
     */
    public static tkt_Ticket__c createTicket() {
        return createTicket(null);
    }

    /**
     * Create a single ticket with custom field overrides.
     */
    public static tkt_Ticket__c createTicket(Map<String, Object> fieldOverrides) {
        tkt_Ticket__c ticket = new tkt_Ticket__c(
            Subject__c = 'Test Ticket ' + generateRandomString(5),
            Description__c = 'Test Description',
            Status__c = 'New',
            Priority__c = 'Medium',
            Category__c = 'General Inquiry',
            Submitted_By__c = UserInfo.getUserId()
        );

        if (fieldOverrides != null) {
            for (String field : fieldOverrides.keySet()) {
                ticket.put(field, fieldOverrides.get(field));
            }
        }

        return ticket;
    }

    /**
     * Create and insert a single ticket.
     */
    public static tkt_Ticket__c createAndInsertTicket() {
        return createAndInsertTicket(null);
    }

    /**
     * Create and insert a single ticket with custom field overrides.
     */
    public static tkt_Ticket__c createAndInsertTicket(Map<String, Object> fieldOverrides) {
        tkt_Ticket__c ticket = createTicket(fieldOverrides);
        insert ticket;
        return ticket;
    }

    /**
     * Create multiple tickets with default values.
     */
    public static List<tkt_Ticket__c> createTickets(Integer count) {
        return createTickets(count, null);
    }

    /**
     * Create multiple tickets with custom field overrides.
     */
    public static List<tkt_Ticket__c> createTickets(Integer count, Map<String, Object> fieldOverrides) {
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> overrides = new Map<String, Object>();
            if (fieldOverrides != null) {
                overrides.putAll(fieldOverrides);
            }
            // Add index to subject for uniqueness
            overrides.put('Subject__c', 'Test Ticket ' + i + ' ' + generateRandomString(3));
            tickets.add(createTicket(overrides));
        }
        return tickets;
    }

    /**
     * Create and insert multiple tickets.
     */
    public static List<tkt_Ticket__c> createAndInsertTickets(Integer count) {
        return createAndInsertTickets(count, null);
    }

    /**
     * Create and insert multiple tickets with custom field overrides.
     */
    public static List<tkt_Ticket__c> createAndInsertTickets(Integer count, Map<String, Object> fieldOverrides) {
        List<tkt_Ticket__c> tickets = createTickets(count, fieldOverrides);
        insert tickets;
        return tickets;
    }

    /**
     * Create a ticket comment.
     */
    public static tkt_Ticket_Comment__c createComment(Id ticketId) {
        return createComment(ticketId, null);
    }

    /**
     * Create a ticket comment with custom field overrides.
     */
    public static tkt_Ticket_Comment__c createComment(Id ticketId, Map<String, Object> fieldOverrides) {
        tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
            Ticket__c = ticketId,
            Comment_Body__c = 'Test comment ' + generateRandomString(5),
            Posted_By__c = UserInfo.getUserId(),
            Is_Internal__c = false
        );

        if (fieldOverrides != null) {
            for (String field : fieldOverrides.keySet()) {
                comment.put(field, fieldOverrides.get(field));
            }
        }

        return comment;
    }

    /**
     * Create and insert a ticket comment.
     */
    public static tkt_Ticket_Comment__c createAndInsertComment(Id ticketId) {
        return createAndInsertComment(ticketId, null);
    }

    /**
     * Create and insert a ticket comment with custom field overrides.
     */
    public static tkt_Ticket_Comment__c createAndInsertComment(Id ticketId, Map<String, Object> fieldOverrides) {
        tkt_Ticket_Comment__c comment = createComment(ticketId, fieldOverrides);
        insert comment;
        return comment;
    }

    /**
     * Create multiple comments for a ticket.
     */
    public static List<tkt_Ticket_Comment__c> createAndInsertComments(Id ticketId, Integer count) {
        List<tkt_Ticket_Comment__c> comments = new List<tkt_Ticket_Comment__c>();
        for (Integer i = 0; i < count; i++) {
            comments.add(createComment(ticketId, new Map<String, Object>{
                'Comment_Body__c' => 'Test comment ' + i
            }));
        }
        insert comments;
        return comments;
    }

    /**
     * Create a standard test user.
     */
    public static User createUser() {
        return createUser('Standard User');
    }

    /**
     * Create a test user with a specific profile.
     */
    public static User createUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        
        String uniqueId = generateRandomString(8);
        User u = new User(
            Alias = uniqueId.substring(0, 5),
            Email = uniqueId + '@testorg.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User ' + uniqueId,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueId + '@testorg.com'
        );
        
        return u;
    }

    /**
     * Create and insert a test user.
     */
    public static User createAndInsertUser() {
        return createAndInsertUser('Standard User');
    }

    /**
     * Create and insert a test user with a specific profile.
     */
    public static User createAndInsertUser(String profileName) {
        User u = createUser(profileName);
        insert u;
        return u;
    }

    /**
     * Create and insert a user with the Ticket System Access permission set.
     */
    public static User createAndInsertUserWithTicketAccess() {
        User u = createAndInsertUser();
        assignTicketPermissionSet(u.Id);
        return u;
    }

    /**
     * Assign the Ticket_System_Access permission set to a user.
     */
    public static void assignTicketPermissionSet(Id userId) {
        PermissionSet ps = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'tkt_Ticket_User_Standard'
            LIMIT 1
        ];
        
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
        insert psa;
    }

    /**
     * Create a ticket with comments.
     */
    public static tkt_Ticket__c createTicketWithComments(Integer commentCount) {
        tkt_Ticket__c ticket = createAndInsertTicket();
        createAndInsertComments(ticket.Id, commentCount);
        return ticket;
    }

    /**
     * Create tickets with varying priorities for routing tests.
     */
    public static List<tkt_Ticket__c> createTicketsWithPriorities() {
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        
        tickets.add(createTicket(new Map<String, Object>{
            'Subject__c' => 'Low Priority Ticket',
            'Priority__c' => 'Low'
        }));
        
        tickets.add(createTicket(new Map<String, Object>{
            'Subject__c' => 'Medium Priority Ticket',
            'Priority__c' => 'Medium'
        }));
        
        tickets.add(createTicket(new Map<String, Object>{
            'Subject__c' => 'High Priority Ticket',
            'Priority__c' => 'High'
        }));
        
        tickets.add(createTicket(new Map<String, Object>{
            'Subject__c' => 'Critical Priority Ticket',
            'Priority__c' => 'Critical'
        }));
        
        insert tickets;
        return tickets;
    }

    /**
     * Create tickets with varying categories for routing tests.
     */
    public static List<tkt_Ticket__c> createTicketsWithCategories() {
        List<String> categories = new List<String>{
            'General Inquiry',
            'Technical Issue',
            'Access Request',
            'Bug Report',
            'Feature Request'
        };
        
        List<tkt_Ticket__c> tickets = new List<tkt_Ticket__c>();
        for (String category : categories) {
            tickets.add(createTicket(new Map<String, Object>{
                'Subject__c' => category + ' Ticket',
                'Category__c' => category
            }));
        }
        
        insert tickets;
        return tickets;
    }

    /**
     * Create mock base64 data for file attachment tests.
     */
    public static String createMockBase64Data() {
        return EncodingUtil.base64Encode(Blob.valueOf('Test file content ' + generateRandomString(10)));
    }

    /**
     * Create mock image base64 data.
     */
    public static String createMockImageBase64() {
        // Simple PNG header bytes followed by random content
        Blob imageBlob = Blob.valueOf('PNG' + generateRandomString(100));
        return EncodingUtil.base64Encode(imageBlob);
    }

    /**
     * Generate a random alphanumeric string.
     */
    public static String generateRandomString(Integer length) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String result = '';
        while (result.length() < length) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            result += chars.substring(idx, idx + 1);
        }
        return result;
    }

    /**
     * Create a complete test scenario with ticket, comments, and attachments.
     */
    public static tkt_Ticket__c createCompleteTicketScenario() {
        // Create ticket
        tkt_Ticket__c ticket = createAndInsertTicket(new Map<String, Object>{
            'Subject__c' => 'Complete Test Scenario',
            'Priority__c' => 'High',
            'Category__c' => 'Technical Issue'
        });
        
        // Add comments
        createAndInsertComments(ticket.Id, 3);
        
        // Add internal comment
        createAndInsertComment(ticket.Id, new Map<String, Object>{
            'Comment_Body__c' => 'Internal note',
            'Is_Internal__c' => true
        });
        
        return ticket;
    }
}