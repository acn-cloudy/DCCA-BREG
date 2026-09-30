public with sharing class tkt_TicketController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> checkTicketAccess() {
        Map<String, Boolean> accessMap = new Map<String, Boolean>();
        
        Boolean canCreate = Schema.sObjectType.tkt_Ticket__c.isCreateable();
        Boolean hasPermission = FeatureManagement.checkPermission('tkt_Can_Create_Tickets');
        Boolean hasAccess = canCreate && hasPermission;
        
        accessMap.put('canCreate', canCreate);
        accessMap.put('hasPermission', hasPermission);
        accessMap.put('hasAccess', hasAccess);
        
        return accessMap;
    }

    @AuraEnabled
    public static Id createTicket(String subject, String description, String priority, String category, 
                                   String impact, String environment, String relatedRecordId) {
        try {
            if (String.isBlank(subject)) {
                throw new AuraHandledException('Subject is required.');
            }
            
            tkt_Ticket__c ticket = new tkt_Ticket__c(
                Subject__c = subject,
                Description__c = description,
                Priority__c = String.isNotBlank(priority) ? priority : 'Medium',
                Category__c = category,
                Impact__c = String.isNotBlank(impact) ? impact : 'Individual',
                Environment__c = String.isNotBlank(environment) ? environment : 'Production',
                Related_Record_Id__c = relatedRecordId,
                Status__c = 'New',
                Submitted_By__c = UserInfo.getUserId()
            );
            insert ticket;
            return ticket.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create ticket: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id attachFile(Id ticketId, String fileName, String base64Data, String contentType) {
        try {
            if (ticketId == null) {
                throw new AuraHandledException('Ticket ID is required.');
            }
            if (String.isBlank(fileName)) {
                throw new AuraHandledException('File name is required.');
            }
            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('File data is required.');
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            insert cv;

            ContentVersion insertedCV = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = insertedCV.ContentDocumentId;
            cdl.LinkedEntityId = ticketId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            return cv.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to attach file: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<tkt_Ticket__c> getMyTickets() {
        return [
            SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Category__c, 
                   Impact__c, Environment__c, Due_Date__c, CreatedDate
            FROM tkt_Ticket__c
            WHERE Submitted_By__c = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    @AuraEnabled
    public static Map<String, Object> getTicketWithComments(Id ticketId) {
        try {
            if (ticketId == null) {
                throw new AuraHandledException('Ticket ID is required.');
            }

            // Get the ticket
            tkt_Ticket__c ticket = [
                SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Category__c, 
                       Submitted_By__c, Assigned_To__c, CreatedDate, Close_Note__c, Closed_Date__c,
                       Impact__c, Environment__c, Resolution__c, First_Response_Date__c, 
                       Due_Date__c, Related_Record_Id__c
                FROM tkt_Ticket__c
                WHERE Id = :ticketId
                AND Submitted_By__c = :UserInfo.getUserId()
                LIMIT 1
            ];

            // Get comments (excluding internal comments for the submitter)
            List<tkt_Ticket_Comment__c> comments = [
                SELECT Id, Comment_Body__c, Posted_By__c, Posted_By__r.Name, Is_Internal__c, CreatedDate
                FROM tkt_Ticket_Comment__c
                WHERE Ticket__c = :ticketId
                AND Is_Internal__c = false
                ORDER BY CreatedDate DESC
            ];

            Map<String, Object> result = new Map<String, Object>();
            result.put('ticket', ticket);
            result.put('comments', comments);
            
            return result;
        } catch (QueryException e) {
            throw new AuraHandledException('Ticket not found or access denied.');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load ticket: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id addComment(Id ticketId, String commentBody) {
        try {
            if (ticketId == null) {
                throw new AuraHandledException('Ticket ID is required.');
            }
            if (String.isBlank(commentBody)) {
                throw new AuraHandledException('Comment cannot be empty.');
            }

            // Verify the user owns this ticket
            List<tkt_Ticket__c> tickets = [
                SELECT Id FROM tkt_Ticket__c 
                WHERE Id = :ticketId 
                AND Submitted_By__c = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            if (tickets.isEmpty()) {
                throw new AuraHandledException('Ticket not found or access denied.');
            }

            tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
                Ticket__c = ticketId,
                Comment_Body__c = commentBody,
                Posted_By__c = UserInfo.getUserId(),
                Is_Internal__c = false
            );
            insert comment;
            
            return comment.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to add comment: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void closeTicket(Id ticketId, String closeNote) {
        try {
            if (ticketId == null) {
                throw new AuraHandledException('Ticket ID is required.');
            }

            // Verify the user owns this ticket
            List<tkt_Ticket__c> tickets = [
                SELECT Id, Status__c FROM tkt_Ticket__c 
                WHERE Id = :ticketId 
                AND Submitted_By__c = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            if (tickets.isEmpty()) {
                throw new AuraHandledException('Ticket not found or access denied.');
            }

            tkt_Ticket__c ticket = tickets[0];
            
            if (ticket.Status__c == 'Closed') {
                throw new AuraHandledException('Ticket is already closed.');
            }

            ticket.Status__c = 'Closed';
            ticket.Close_Note__c = closeNote;
            ticket.Closed_Date__c = DateTime.now();
            update ticket;

            // Add a system comment noting the closure
            tkt_Ticket_Comment__c comment = new tkt_Ticket_Comment__c(
                Ticket__c = ticketId,
                Comment_Body__c = '<p><strong>Ticket closed by submitter</strong></p>' + 
                    (String.isNotBlank(closeNote) ? '<p>Close note: ' + closeNote + '</p>' : ''),
                Posted_By__c = UserInfo.getUserId(),
                Is_Internal__c = false
            );
            insert comment;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to close ticket: ' + e.getMessage());
        }
    }
}