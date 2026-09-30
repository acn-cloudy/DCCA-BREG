/**
 * Service class for sending ticket-related email notifications.
 * Uses tkt_Email_Notification_Setting__mdt for notification configuration.
 * Uses tkt_Email_Settings__mdt for company branding and contact information.
 * Supports both Email Templates and inline templates.
 * Emails are linked to tickets via setWhatId for activity tracking.
 */
public without sharing class tkt_EmailNotificationService {
    
    // Notification type constants matching custom metadata picklist values
    public static final String NOTIF_TICKET_CREATED_OWNER = 'Ticket Created - Owner Confirmation';
    public static final String NOTIF_TICKET_CREATED_QUEUE = 'Ticket Created - Queue Assignment';
    public static final String NOTIF_STATUS_CHANGED = 'Ticket Status Changed';
    public static final String NOTIF_OWNERSHIP_CHANGED = 'Ticket Ownership Changed';
    public static final String NOTIF_COMMENT_OWNER = 'Comment Added - Notify Owner';
    public static final String NOTIF_COMMENT_ASSIGNEE = 'Comment Added - Notify Assignee';
    public static final String NOTIF_CLOSED_ASSIGNEE = 'Ticket Closed - Notify Assignee';
    
    // Cache for notification settings
    private static Map<String, tkt_Email_Notification_Setting__mdt> settingsCache;

    // Cache for email templates
    private static Map<String, Id> templateIdCache;

    // Cache for org-wide email addresses
    private static Map<String, Id> orgWideEmailCache;

    // Cache for company email settings
    private static tkt_Email_Settings__mdt companySettings;

    // Test-injectable settings override (for dependency injection in tests)
    @TestVisible
    private static Map<String, tkt_Email_Notification_Setting__mdt> testSettingsOverride;

    // Test-injectable company settings override
    @TestVisible
    private static tkt_Email_Settings__mdt testCompanySettingsOverride;

    /**
     * Inject mock notification settings for testing.
     * Call this in tests to override the custom metadata settings.
     * @param settings Map of notification type to setting record
     */
    @TestVisible
    private static void injectTestSettings(Map<String, tkt_Email_Notification_Setting__mdt> settings) {
        testSettingsOverride = settings;
        settingsCache = null; // Clear cache to force re-read
    }

    /**
     * Inject mock company settings for testing.
     * @param settings The company settings to use
     */
    @TestVisible
    private static void injectTestCompanySettings(tkt_Email_Settings__mdt settings) {
        testCompanySettingsOverride = settings;
        companySettings = null; // Clear cache
    }
    
    /**
     * Send notification for new ticket creation (to owner).
     * @param tickets List of newly created tickets
     */
    public static void sendNewTicketOwnerNotifications(List<tkt_Ticket__c> tickets) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_TICKET_CREATED_OWNER);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        Set<Id> ownerIds = new Set<Id>();
        for (tkt_Ticket__c ticket : tickets) {
            if (ticket.Submitted_By__c != null) {
                ownerIds.add(ticket.Submitted_By__c);
            }
        }
        
        if (ownerIds.isEmpty()) {
            return;
        }
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :ownerIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket__c ticket : tickets) {
            if (ticket.Submitted_By__c != null && users.containsKey(ticket.Submitted_By__c)) {
                User owner = users.get(ticket.Submitted_By__c);
                if (String.isNotBlank(owner.Email)) {
                    emails.add(buildEmail(setting, ticket, owner, null, null, null));
                }
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification for new ticket to queue members.
     * @param tickets List of newly created tickets
     */
    public static void sendNewTicketQueueNotifications(List<tkt_Ticket__c> tickets) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_TICKET_CREATED_QUEUE);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        // Collect queue owner IDs
        Set<Id> queueIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();
        for (tkt_Ticket__c ticket : tickets) {
            if (ticket.OwnerId != null) {
                String ownerIdPrefix = String.valueOf(ticket.OwnerId).substring(0, 3);
                if (ownerIdPrefix == '00G') { // Queue prefix
                    queueIds.add(ticket.OwnerId);
                }
            }
            if (ticket.Submitted_By__c != null) {
                ownerIds.add(ticket.Submitted_By__c);
            }
        }
        
        if (queueIds.isEmpty()) {
            return;
        }
        
        // Get queue members
        Map<Id, Set<Id>> queueMemberMap = getQueueMembers(queueIds);
        
        // Get all users we need
        Set<Id> allUserIds = new Set<Id>(ownerIds);
        for (Set<Id> memberIds : queueMemberMap.values()) {
            allUserIds.addAll(memberIds);
        }
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :allUserIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket__c ticket : tickets) {
            if (ticket.OwnerId != null && queueMemberMap.containsKey(ticket.OwnerId)) {
                User owner = ticket.Submitted_By__c != null ? users.get(ticket.Submitted_By__c) : null;
                Set<Id> memberIds = queueMemberMap.get(ticket.OwnerId);
                
                for (Id memberId : memberIds) {
                    User member = users.get(memberId);
                    if (member != null && String.isNotBlank(member.Email)) {
                        emails.add(buildEmail(setting, ticket, owner, member, null, null));
                    }
                }
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification for status change.
     * @param newTickets Updated tickets
     * @param oldMap Map of old ticket values
     */
    public static void sendStatusChangeNotifications(List<tkt_Ticket__c> newTickets, Map<Id, tkt_Ticket__c> oldMap) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_STATUS_CHANGED);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        List<tkt_Ticket__c> changedTickets = new List<tkt_Ticket__c>();
        Map<Id, String> oldStatusMap = new Map<Id, String>();
        Set<Id> ownerIds = new Set<Id>();
        
        for (tkt_Ticket__c ticket : newTickets) {
            tkt_Ticket__c oldTicket = oldMap.get(ticket.Id);
            if (oldTicket != null && ticket.Status__c != oldTicket.Status__c) {
                changedTickets.add(ticket);
                oldStatusMap.put(ticket.Id, oldTicket.Status__c);
                if (ticket.Submitted_By__c != null) {
                    ownerIds.add(ticket.Submitted_By__c);
                }
            }
        }
        
        if (changedTickets.isEmpty()) {
            return;
        }
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :ownerIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket__c ticket : changedTickets) {
            if (ticket.Submitted_By__c != null && users.containsKey(ticket.Submitted_By__c)) {
                User owner = users.get(ticket.Submitted_By__c);
                if (String.isNotBlank(owner.Email)) {
                    String oldStatus = oldStatusMap.get(ticket.Id);
                    emails.add(buildEmail(setting, ticket, owner, null, null, oldStatus));
                }
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification for ownership change.
     * @param newTickets Updated tickets
     * @param oldMap Map of old ticket values
     */
    public static void sendOwnershipChangeNotifications(List<tkt_Ticket__c> newTickets, Map<Id, tkt_Ticket__c> oldMap) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_OWNERSHIP_CHANGED);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        List<tkt_Ticket__c> changedTickets = new List<tkt_Ticket__c>();
        Set<Id> ownerIds = new Set<Id>();
        Set<Id> assigneeIds = new Set<Id>();
        
        for (tkt_Ticket__c ticket : newTickets) {
            tkt_Ticket__c oldTicket = oldMap.get(ticket.Id);
            if (oldTicket != null && ticket.Assigned_To__c != oldTicket.Assigned_To__c && ticket.Assigned_To__c != null) {
                changedTickets.add(ticket);
                if (ticket.Submitted_By__c != null) {
                    ownerIds.add(ticket.Submitted_By__c);
                }
                assigneeIds.add(ticket.Assigned_To__c);
            }
        }
        
        if (changedTickets.isEmpty()) {
            return;
        }
        
        Set<Id> allUserIds = new Set<Id>(ownerIds);
        allUserIds.addAll(assigneeIds);
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :allUserIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket__c ticket : changedTickets) {
            if (ticket.Submitted_By__c != null && users.containsKey(ticket.Submitted_By__c)) {
                User owner = users.get(ticket.Submitted_By__c);
                User assignee = users.get(ticket.Assigned_To__c);
                if (String.isNotBlank(owner.Email)) {
                    emails.add(buildEmail(setting, ticket, owner, assignee, null, null));
                }
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification when ticket is closed by owner.
     * @param newTickets Updated tickets
     * @param oldMap Map of old ticket values
     */
    public static void sendClosedByOwnerNotifications(List<tkt_Ticket__c> newTickets, Map<Id, tkt_Ticket__c> oldMap) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_CLOSED_ASSIGNEE);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        List<tkt_Ticket__c> closedTickets = new List<tkt_Ticket__c>();
        Set<Id> ownerIds = new Set<Id>();
        Set<Id> assigneeIds = new Set<Id>();
        
        for (tkt_Ticket__c ticket : newTickets) {
            tkt_Ticket__c oldTicket = oldMap.get(ticket.Id);
            // Check if status changed to Closed and the current user is the ticket owner
            if (oldTicket != null && 
                ticket.Status__c == 'Closed' && 
                oldTicket.Status__c != 'Closed' &&
                ticket.Assigned_To__c != null &&
                UserInfo.getUserId() == ticket.Submitted_By__c) {
                
                closedTickets.add(ticket);
                if (ticket.Submitted_By__c != null) {
                    ownerIds.add(ticket.Submitted_By__c);
                }
                assigneeIds.add(ticket.Assigned_To__c);
            }
        }
        
        if (closedTickets.isEmpty()) {
            return;
        }
        
        Set<Id> allUserIds = new Set<Id>(ownerIds);
        allUserIds.addAll(assigneeIds);
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :allUserIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket__c ticket : closedTickets) {
            User owner = ticket.Submitted_By__c != null ? users.get(ticket.Submitted_By__c) : null;
            User assignee = users.get(ticket.Assigned_To__c);
            
            if (assignee != null && String.isNotBlank(assignee.Email)) {
                emails.add(buildEmailForRecipient(setting, ticket, owner, assignee, null, null));
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification for new comment to ticket owner.
     * Only sends if the comment was NOT posted by the owner.
     * @param comments List of new comments with Ticket__r populated
     */
    public static void sendCommentNotificationToOwner(List<tkt_Ticket_Comment__c> comments) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_COMMENT_OWNER);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        // Filter comments not posted by the ticket owner
        Set<Id> ticketIds = new Set<Id>();
        for (tkt_Ticket_Comment__c comment : comments) {
            ticketIds.add(comment.Ticket__c);
        }
        
        Map<Id, tkt_Ticket__c> tickets = new Map<Id, tkt_Ticket__c>([
            SELECT Id, Name, Subject__c, Status__c, Description__c, Submitted_By__c, Assigned_To__c
            FROM tkt_Ticket__c
            WHERE Id IN :ticketIds
        ]);
        
        Set<Id> userIds = new Set<Id>();
        for (tkt_Ticket__c ticket : tickets.values()) {
            if (ticket.Submitted_By__c != null) {
                userIds.add(ticket.Submitted_By__c);
            }
        }
        for (tkt_Ticket_Comment__c comment : comments) {
            if (comment.Posted_By__c != null) {
                userIds.add(comment.Posted_By__c);
            }
        }
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :userIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket_Comment__c comment : comments) {
            tkt_Ticket__c ticket = tickets.get(comment.Ticket__c);
            if (ticket == null || ticket.Submitted_By__c == null) {
                continue;
            }
            
            // Don't send if owner posted the comment
            if (comment.Posted_By__c == ticket.Submitted_By__c) {
                continue;
            }
            
            User owner = users.get(ticket.Submitted_By__c);
            User commenter = comment.Posted_By__c != null ? users.get(comment.Posted_By__c) : null;
            
            if (owner != null && String.isNotBlank(owner.Email)) {
                emails.add(buildEmailForRecipient(setting, ticket, owner, owner, comment, null));
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Send notification for new comment from owner to assignee.
     * Only sends if the comment was posted by the owner.
     * @param comments List of new comments
     */
    public static void sendCommentNotificationToAssignee(List<tkt_Ticket_Comment__c> comments) {
        tkt_Email_Notification_Setting__mdt setting = getSetting(NOTIF_COMMENT_ASSIGNEE);
        if (setting == null || !setting.Is_Active__c) {
            return;
        }
        
        Set<Id> ticketIds = new Set<Id>();
        for (tkt_Ticket_Comment__c comment : comments) {
            ticketIds.add(comment.Ticket__c);
        }
        
        Map<Id, tkt_Ticket__c> tickets = new Map<Id, tkt_Ticket__c>([
            SELECT Id, Name, Subject__c, Status__c, Description__c, Submitted_By__c, Assigned_To__c
            FROM tkt_Ticket__c
            WHERE Id IN :ticketIds
        ]);
        
        Set<Id> userIds = new Set<Id>();
        for (tkt_Ticket__c ticket : tickets.values()) {
            if (ticket.Submitted_By__c != null) {
                userIds.add(ticket.Submitted_By__c);
            }
            if (ticket.Assigned_To__c != null) {
                userIds.add(ticket.Assigned_To__c);
            }
        }
        
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email FROM User WHERE Id IN :userIds
        ]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (tkt_Ticket_Comment__c comment : comments) {
            tkt_Ticket__c ticket = tickets.get(comment.Ticket__c);
            if (ticket == null || ticket.Assigned_To__c == null) {
                continue;
            }
            
            // Only send if owner posted the comment
            if (comment.Posted_By__c != ticket.Submitted_By__c) {
                continue;
            }
            
            User owner = ticket.Submitted_By__c != null ? users.get(ticket.Submitted_By__c) : null;
            User assignee = users.get(ticket.Assigned_To__c);
            
            if (assignee != null && String.isNotBlank(assignee.Email)) {
                emails.add(buildEmailForRecipient(setting, ticket, owner, assignee, comment, null));
            }
        }
        
        sendEmails(emails);
    }
    
    /**
     * Get queue member user IDs.
     * @param queueIds Set of queue IDs
     * @return Map of queue ID to set of member user IDs
     */
    private static Map<Id, Set<Id>> getQueueMembers(Set<Id> queueIds) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        
        for (Id queueId : queueIds) {
            result.put(queueId, new Set<Id>());
        }
        
        // Get direct user members
        for (GroupMember gm : [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queueIds
        ]) {
            // Filter to user IDs only (prefix 005)
            String userOrGroupIdStr = String.valueOf(gm.UserOrGroupId);
            if (userOrGroupIdStr.startsWith('005')) {
                result.get(gm.GroupId).add(gm.UserOrGroupId);
            }
        }
        
        return result;
    }
    
    /**
     * Build email message - determines whether to use Email Template or inline template.
     * This is the primary owner-recipient version.
     */
    private static Messaging.SingleEmailMessage buildEmail(
        tkt_Email_Notification_Setting__mdt setting,
        tkt_Ticket__c ticket,
        User owner,
        User assignee,
        tkt_Ticket_Comment__c comment,
        String oldStatus
    ) {
        // Use owner as recipient for backward compatibility
        return buildEmailForRecipient(setting, ticket, owner, owner, comment, oldStatus);
    }
    
    /**
     * Build email message for a specific recipient.
     * Supports both Email Templates and inline templates.
     * Appends company footer to all emails.
     */
    private static Messaging.SingleEmailMessage buildEmailForRecipient(
        tkt_Email_Notification_Setting__mdt setting,
        tkt_Ticket__c ticket,
        User owner,
        User recipient,
        tkt_Ticket_Comment__c comment,
        String oldStatus
    ) {
        // Check if we should use Email Template
        if (String.isNotBlank(setting.Email_Template_Name__c)) {
            return buildEmailFromTemplate(setting, ticket, recipient);
        }
        
        // Use inline template from custom metadata
        return buildEmailFromInlineTemplate(setting, ticket, owner, recipient, comment, oldStatus);
    }
    
    /**
     * Build email using a Salesforce Email Template.
     * Templates use standard merge field syntax and are editable via Setup.
     * Company footer is appended after template rendering.
     */
    private static Messaging.SingleEmailMessage buildEmailFromTemplate(
        tkt_Email_Notification_Setting__mdt setting,
        tkt_Ticket__c ticket,
        User recipient
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Get template ID
        Id templateId = getTemplateId(setting.Email_Template_Name__c);
        if (templateId == null) {
            System.debug(LoggingLevel.WARN, 'Email template not found: ' + setting.Email_Template_Name__c);
            return null;
        }
        
        // Set template - this will populate subject and body from template
        email.setTemplateId(templateId);
        
        // setTargetObjectId is required for template merge fields on User
        email.setTargetObjectId(recipient.Id);
        
        // setWhatId is required for template merge fields on the related record (Ticket)
        email.setWhatId(ticket.Id);
        
        // Save as activity on the ticket record
        email.setSaveAsActivity(true);
        
        // Treat target object as recipient
        email.setTreatTargetObjectAsRecipient(true);
        
        // Set Org-Wide Email Address if configured
        if (String.isNotBlank(setting.Use_Org_Wide_Email__c)) {
            Id oweaId = getOrgWideEmailId(setting.Use_Org_Wide_Email__c);
            if (oweaId != null) {
                email.setOrgWideEmailAddressId(oweaId);
            }
        }
        
        return email;
    }
    
    /**
     * Build email using inline template from custom metadata.
     * Supports custom merge fields and appends company footer.
     */
    private static Messaging.SingleEmailMessage buildEmailFromInlineTemplate(
        tkt_Email_Notification_Setting__mdt setting,
        tkt_Ticket__c ticket,
        User owner,
        User recipient,
        tkt_Ticket_Comment__c comment,
        String oldStatus
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set recipient
        if (recipient != null && String.isNotBlank(recipient.Email)) {
            email.setToAddresses(new List<String>{ recipient.Email });
        }
        
        // Build subject and body with merge fields
        String subject = replaceMergeFields(setting.Email_Subject__c, ticket, owner, recipient, comment, oldStatus);
        String body = replaceMergeFields(setting.Email_Body__c, ticket, owner, recipient, comment, oldStatus);
        
        // Append company footer
        if (setting.Send_HTML_Email__c) {
            body = appendHtmlFooter(body);
        } else {
            body = appendPlainTextFooter(body);
        }
        
        email.setSubject(subject);
        
        if (setting.Send_HTML_Email__c) {
            email.setHtmlBody(body);
            email.setPlainTextBody(stripHtml(body));
        } else {
            email.setPlainTextBody(body);
        }
        
        // Link to ticket record for email tracking
        email.setWhatId(ticket.Id);
        email.setSaveAsActivity(true);
        
        // Set Org-Wide Email Address if configured
        if (String.isNotBlank(setting.Use_Org_Wide_Email__c)) {
            Id oweaId = getOrgWideEmailId(setting.Use_Org_Wide_Email__c);
            if (oweaId != null) {
                email.setOrgWideEmailAddressId(oweaId);
            }
        }
        
        return email;
    }
    
    /**
     * Append HTML footer with company information.
     */
    private static String appendHtmlFooter(String htmlBody) {
        tkt_Email_Settings__mdt settings = getCompanySettings();
        if (settings == null) {
            return htmlBody;
        }
        
        // Build footer HTML
        String footer = '<div style="background: #2d3748; padding: 25px; text-align: center;">';
        footer += '<p style="margin: 0 0 10px 0; color: white; font-weight: bold; font-size: 14px;">' + 
                  String.escapeSingleQuotes(settings.Support_Team_Name__c) + '</p>';
        
        // Contact info row
        List<String> contactItems = new List<String>();
        if (String.isNotBlank(settings.Contact_Email__c)) {
            contactItems.add('<a href="mailto:' + settings.Contact_Email__c + '" style="color: #90cdf4; text-decoration: none;">📧 ' + settings.Contact_Email__c + '</a>');
        }
        if (String.isNotBlank(settings.Contact_Phone__c)) {
            contactItems.add('<span style="color: #e2e8f0;">📞 ' + settings.Contact_Phone__c + '</span>');
        }
        if (String.isNotBlank(settings.Company_Website__c)) {
            contactItems.add('<a href="' + settings.Company_Website__c + '" style="color: #90cdf4; text-decoration: none;">🌐 Visit our website</a>');
        }
        
        if (!contactItems.isEmpty()) {
            footer += '<p style="margin: 0 0 10px 0; color: #a0aec0; font-size: 12px;">' + String.join(contactItems, ' &nbsp;|&nbsp; ') + '</p>';
        }
        
        // Custom footer message
        if (String.isNotBlank(settings.Footer_Message__c)) {
            footer += '<p style="margin: 10px 0 0 0; color: #718096; font-size: 11px; font-style: italic;">' + 
                      String.escapeSingleQuotes(settings.Footer_Message__c) + '</p>';
        }
        
        footer += '</div></div></body></html>';
        
        // Replace the existing footer placeholder or append before closing tags
        if (htmlBody.contains('<!-- Footer placeholder -->')) {
            return htmlBody.replace('<!-- Footer placeholder -->', footer);
        } else if (htmlBody.contains('</body>')) {
            return htmlBody.replace('</body></html>', footer);
        } else {
            return htmlBody + footer;
        }
    }
    
    /**
     * Append plain text footer with company information.
     */
    private static String appendPlainTextFooter(String textBody) {
        tkt_Email_Settings__mdt settings = getCompanySettings();
        if (settings == null) {
            return textBody;
        }
        
        String footer = '\n\n-----------------------------------\n';
        footer += settings.Support_Team_Name__c + '\n';
        
        if (String.isNotBlank(settings.Contact_Email__c)) {
            footer += 'Email: ' + settings.Contact_Email__c + '\n';
        }
        if (String.isNotBlank(settings.Contact_Phone__c)) {
            footer += 'Phone: ' + settings.Contact_Phone__c + '\n';
        }
        if (String.isNotBlank(settings.Company_Website__c)) {
            footer += 'Website: ' + settings.Company_Website__c + '\n';
        }
        if (String.isNotBlank(settings.Footer_Message__c)) {
            footer += '\n' + settings.Footer_Message__c + '\n';
        }
        footer += '-----------------------------------';
        
        return textBody + footer;
    }
    
    /**
     * Get company email settings.
     */
    private static tkt_Email_Settings__mdt getCompanySettings() {
        // Check for test-injected settings first (dependency injection for tests)
        if (testCompanySettingsOverride != null) {
            return testCompanySettingsOverride;
        }

        if (companySettings != null) {
            return companySettings;
        }

        List<tkt_Email_Settings__mdt> settings = [
            SELECT Support_Team_Name__c, Contact_Email__c, Contact_Phone__c,
                   Company_Website__c, Footer_Message__c, Is_Active__c
            FROM tkt_Email_Settings__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (!settings.isEmpty()) {
            companySettings = settings[0];
        }

        return companySettings;
    }
    
    /**
     * Get Email Template ID by Developer Name.
     * Caches both found and not-found results to prevent repeated queries.
     */
    private static Id getTemplateId(String templateDeveloperName) {
        if (templateIdCache == null) {
            templateIdCache = new Map<String, Id>();
        }

        // Check cache - containsKey handles both found (Id) and not-found (null) cases
        if (templateIdCache.containsKey(templateDeveloperName)) {
            return templateIdCache.get(templateDeveloperName);
        }

        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName = :templateDeveloperName
            AND IsActive = true
            LIMIT 1
        ];

        // Cache the result whether found or not to prevent repeated queries
        Id templateId = !templates.isEmpty() ? templates[0].Id : null;
        templateIdCache.put(templateDeveloperName, templateId);

        return templateId;
    }
    
    /**
     * Get Org-Wide Email Address ID by email address.
     * Caches both found and not-found results to prevent repeated queries.
     */
    private static Id getOrgWideEmailId(String emailAddress) {
        if (orgWideEmailCache == null) {
            orgWideEmailCache = new Map<String, Id>();
        }

        // Check cache - containsKey handles both found (Id) and not-found (null) cases
        if (orgWideEmailCache.containsKey(emailAddress)) {
            return orgWideEmailCache.get(emailAddress);
        }

        List<OrgWideEmailAddress> oweas = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = :emailAddress
            AND IsAllowAllProfiles = true
            LIMIT 1
        ];

        // Cache the result whether found or not to prevent repeated queries
        Id oweaId = !oweas.isEmpty() ? oweas[0].Id : null;
        orgWideEmailCache.put(emailAddress, oweaId);

        return oweaId;
    }
    
    /**
     * Replace merge fields in inline template.
     */
    private static String replaceMergeFields(
        String template,
        tkt_Ticket__c ticket,
        User owner,
        User recipient,
        tkt_Ticket_Comment__c comment,
        String oldStatus
    ) {
        if (String.isBlank(template)) {
            return '';
        }
        
        String result = template;
        
        // Ticket fields
        result = result.replace('{!TicketNumber}', ticket.Name != null ? ticket.Name : '');
        result = result.replace('{!TicketSubject}', ticket.Subject__c != null ? ticket.Subject__c : '');
        result = result.replace('{!Status}', ticket.Status__c != null ? ticket.Status__c : '');
        result = result.replace('{!Description}', ticket.Description__c != null ? ticket.Description__c : '');
        result = result.replace('{!OldStatus}', oldStatus != null ? oldStatus : '');
        
        // User fields
        result = result.replace('{!OwnerName}', owner != null && owner.Name != null ? owner.Name : '');
        result = result.replace('{!AssigneeName}', recipient != null && recipient.Name != null ? recipient.Name : '');
        result = result.replace('{!RecipientName}', recipient != null && recipient.Name != null ? recipient.Name : '');
        
        // Comment fields
        result = result.replace('{!CommentBody}', comment != null && comment.Comment_Body__c != null ? comment.Comment_Body__c : '');
        result = result.replace('{!CommentAuthor}', owner != null && owner.Name != null ? owner.Name : '');
        
        // Ticket link
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        result = result.replace('{!TicketLink}', baseUrl + '/' + ticket.Id);
        
        // Company settings
        tkt_Email_Settings__mdt settings = getCompanySettings();
        if (settings != null) {
            result = result.replace('{!CompanyName}', settings.Support_Team_Name__c != null ? settings.Support_Team_Name__c : '');
            result = result.replace('{!SupportEmail}', settings.Contact_Email__c != null ? settings.Contact_Email__c : '');
            result = result.replace('{!SupportPhone}', settings.Contact_Phone__c != null ? settings.Contact_Phone__c : '');
            result = result.replace('{!CompanyWebsite}', settings.Company_Website__c != null ? settings.Company_Website__c : '');
        }
        
        return result;
    }
    
    /**
     * Strip HTML tags for plain text version.
     */
    private static String stripHtml(String html) {
        if (String.isBlank(html)) {
            return '';
        }
        return html.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
    }
    
    /**
     * Get notification setting by type.
     */
    private static tkt_Email_Notification_Setting__mdt getSetting(String notificationType) {
        // Check for test-injected settings first (dependency injection for tests)
        if (testSettingsOverride != null) {
            return testSettingsOverride.get(notificationType);
        }

        if (settingsCache == null) {
            settingsCache = new Map<String, tkt_Email_Notification_Setting__mdt>();

            for (tkt_Email_Notification_Setting__mdt setting : [
                SELECT DeveloperName, MasterLabel, Is_Active__c, Notification_Type__c,
                       Recipient_Type__c, Email_Subject__c, Email_Body__c,
                       Send_HTML_Email__c, Priority_Order__c,
                       Email_Template_Name__c, Use_Org_Wide_Email__c
                FROM tkt_Email_Notification_Setting__mdt
                WHERE Is_Active__c = true
                ORDER BY Priority_Order__c ASC
            ]) {
                settingsCache.put(setting.Notification_Type__c, setting);
            }
        }

        return settingsCache.get(notificationType);
    }
    
    /**
     * Send emails and handle errors gracefully.
     * Filters out null emails from template build failures.
     */
    private static void sendEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) {
            return;
        }
        
        // Filter out null emails
        List<Messaging.SingleEmailMessage> validEmails = new List<Messaging.SingleEmailMessage>();
        for (Messaging.SingleEmailMessage email : emails) {
            if (email != null) {
                validEmails.add(email);
            }
        }
        
        if (validEmails.isEmpty()) {
            return;
        }
        
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(validEmails, false);
            
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Messaging.SendEmailError error : results[i].getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Email send error: ' + error.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Email sending failed: ' + e.getMessage());
        }
    }
    
    /**
     * Clear all caches (for testing).
     */
    @TestVisible
    private static void clearCache() {
        settingsCache = null;
        templateIdCache = null;
        orgWideEmailCache = null;
        companySettings = null;
        testSettingsOverride = null;
        testCompanySettingsOverride = null;
    }
}