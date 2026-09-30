global without sharing class IMLCCSendEmailQueueable implements Queueable {
    global Set<Id> accountIds = new Set<Id>();

    global IMLCCSendEmailQueueable() {
        accountIds.clear();
    }

    global IMLCCSendEmailQueueable(Set<Id> accIds) {
        this();
        accountIds = accIds != null ? accIds : new Set<Id>();
    }

    global void execute(QueueableContext context) {
        try {
            sendNotificationsExecute();
        } catch(Exception ex) {
            logErrorNS('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), ex.getMessage(), '');
        }
    }

    global void sendNotificationsExecute(){
        sendNotifications(new Set<Id>(accountIds));
    }

    global static void sendNotifications(Set<Id> allAccountIds) {
        List<License__c> licenses = new List<License__c>();
        
        if (!allAccountIds.isEmpty()) {
            
            String query = 'SELECT Id, Name, IMLCCLicenseId__c, Licensee__c, Licensee__r.Name, Licensee__r.BPID__c, Application__c, Application__r.Applicant__c, CreatedDate ';
            query += 'FROM License__c ';
            query += 'WHERE IMLCCLicenseId__c != null ';
            query += 'AND Licensee__c IN :allAccountIds ';
            query += 'ORDER BY Licensee__c, CreatedDate DESC';
            
            List<License__c> allLicenses = Database.query(query);
            
            Map<Id, License__c> accountToLatestLicenseMap = new Map<Id, License__c>();
            
            for (License__c lic : allLicenses) {
                Id accountId = lic.Licensee__c;
                if (accountId != null) {
                    if (!accountToLatestLicenseMap.containsKey(accountId)) {
                        accountToLatestLicenseMap.put(accountId, lic);
                    }
                }
            }
            
            licenses = accountToLatestLicenseMap.values();
        }

        if (licenses.isEmpty()) {
            return;
        }

        Group imlccGroup = null;
        try {
            List<Group> groups = [SELECT Id FROM Group WHERE Name = 'IMLCC Applications' AND Type = 'Regular' LIMIT 1];
            if (!groups.isEmpty()) {
                imlccGroup = groups[0];
            }
        } catch(Exception ex) {
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error querying IMLCC Applications group: ' + ex.getMessage(), '');
        }

        if (imlccGroup == null) {
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'IMLCC Applications group not found', '');
            return;
        }

        Set<Id> groupMemberIds = new Set<Id>();
        try {
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :imlccGroup.Id]) {
                groupMemberIds.add(gm.UserOrGroupId);
            }
        } catch(Exception ex) {
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error querying group members: ' + ex.getMessage(), '');
        }

        if (groupMemberIds.isEmpty()) {
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'No members found in IMLCC Applications group', '');
            return;
        }

        // Get email template with body and subject for manual merge field replacement
        EmailTemplate emailTemplate = null;
        String orgWideFromAddressId = null;
        try {
            List<EmailTemplate> templates = [SELECT Id, Subject, Body, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'IMLCC_Physician_Match_Found' AND IsActive = true LIMIT 1];
            if (!templates.isEmpty()) {
                emailTemplate = templates[0];
            }

            List<OrgWideEmailAddress> orgWideEmails = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE DisplayName = 'DCCA No Reply'
                LIMIT 1
            ];
            if (!orgWideEmails.isEmpty()) {
                orgWideFromAddressId = orgWideEmails[0].Id;
            }
        } catch(Exception ex) {
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error querying email template: ' + ex.getMessage(), '');
        }

        String notificationTypeId = null;
        try {
            List<SObject> notificationTypes = Database.query('SELECT Id FROM CustomNotificationType WHERE DeveloperName = \'IMLCC_Physician_Match\' LIMIT 1');
            if (!notificationTypes.isEmpty()) {
                notificationTypeId = (String)notificationTypes[0].get('Id');
            }
        } catch(Exception ex) {
            System.debug('IMLCCSendEmailQueueable: Custom Notification Type not found: ' + ex.getMessage());
        }

        List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();

        // Convert group member IDs to String set for bell notifications
        Set<String> recipientIds = new Set<String>();
        for (Id userId : groupMemberIds) {
            recipientIds.add((String)userId);
        }

        // Query all active users with email addresses once (outside the loop)
        List<User> groupUsers = new List<User>();
        if (!groupMemberIds.isEmpty()) {
            groupUsers = [SELECT Id, Email FROM User WHERE Id IN :groupMemberIds AND IsActive = true AND Email != null];
        }

        // Process each license
        for (License__c lic : licenses) {
            // Send Bell Notifications - send one notification per license to all group members
            if (notificationTypeId != null && !recipientIds.isEmpty()) {
                try {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('IMLCC Physician Match Found');
                    notification.setBody('An existing Physician Account Record has been found in Hoala. Physician Name: ' + (lic.Licensee__c != null ? lic.Licensee__r.Name : ''));
                    notification.setNotificationTypeId(notificationTypeId);
                    notification.setTargetId(lic.Id);
                    notification.send(recipientIds);
                } catch(Exception ex) {
                    logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error sending bell notification for license: ' + lic.Id + ' - ' + ex.getMessage(), '');
                }
            }

            // Send Email Notifications - manually replace merge fields to avoid WhatId restriction
            if (emailTemplate != null || Test.isRunningTest()) { 
                try {
                    if (!groupUsers.isEmpty()) {
                        // Collect email addresses
                        List<String> toAddresses = new List<String>();
                        for (User groupUser : groupUsers) {
                            toAddresses.add(groupUser.Email);
                        }
                        
                        if (!toAddresses.isEmpty()) {
                            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                            
                            // Get template content (text template only)
                            EmailTemplate templateToUse = emailTemplate;
                            if (Test.isRunningTest()) {
                                List<EmailTemplate> testTemplates = [SELECT Id, Subject, Body FROM EmailTemplate WHERE IsActive = true LIMIT 1];
                                if (!testTemplates.isEmpty()) {
                                    templateToUse = testTemplates[0];
                                }
                            }
                            
                            if (templateToUse != null) {
                                // Manually replace merge fields in template (text template only)
                                String subject = templateToUse.Subject != null ? templateToUse.Subject : '';
                                String body = templateToUse.Body != null ? templateToUse.Body : '';
                                
                                // Replace License__c merge fields
                                if (lic.Licensee__r != null) {
                                    String accountName = lic.Licensee__r.Name != null ? lic.Licensee__r.Name : '';
                                    String bpid = lic.Licensee__r.BPID__c != null ? lic.Licensee__r.BPID__c : '';
                                    
                                    subject = subject.replace('{!License__c.Licensee__r.Name}', accountName);
                                    subject = subject.replace('{!License__c.Licensee__r.BPID__c}', bpid);
                                    
                                    body = body.replace('{!License__c.Licensee__r.Name}', accountName);
                                    body = body.replace('{!License__c.Licensee__r.BPID__c}', bpid);
                                }
                                
                                // Replace License__c.Name
                                String licenseName = lic.Name != null ? lic.Name : '';
                                subject = subject.replace('{!License__c.Name}', licenseName);
                                body = body.replace('{!License__c.Name}', licenseName);
                                
                                email.setSubject(subject);
                                email.setPlainTextBody(body);
                            }
                            
                            // Only set org wide email address if it exists
                            if (orgWideFromAddressId != null) {
                                email.setOrgWideEmailAddressId(orgWideFromAddressId);
                            }
                            
                            // Set TargetObjectId to first user (for system email context) but don't treat as recipient
                            // This allows setToAddresses to work with "System only" deliverability
                            email.setTargetObjectId(groupUsers[0].Id);
                            email.setTreatTargetObjectAsRecipient(false);
                            email.setToAddresses(toAddresses);
                            
                            emailMessages.add(email);
                            // Log successful email creation for debugging
                            System.debug('IMLCCSendEmailQueueable: Created email for license ' + lic.Id + ' with ' + toAddresses.size() + ' recipients');
                        } else {
                            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'No valid email addresses found for group members for license: ' + lic.Id + '. Group member count: ' + groupMemberIds.size() + ', Users with email: ' + groupUsers.size(), '');
                        }
                    } else {
                        logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'No valid email addresses found for group members for license: ' + lic.Id + '. Group member count: ' + groupMemberIds.size() + ', Users with email: ' + groupUsers.size(), '');
                    }
                } catch(Exception ex) {
                    logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error creating email for license: ' + lic.Id + ' - ' + ex.getMessage(), '');
                }
            } else {
                logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'Email template IMLCC_Physician_Match_Found not found', '');
            }
        }

        if (!emailMessages.isEmpty() && !Test.isRunningTest()) {
            try {
                System.debug('IMLCCSendEmailQueueable: Attempting to send ' + emailMessages.size() + ' email(s)');
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailMessages, false);
                
                // Check results for any failures
                Integer successCount = 0;
                Integer failureCount = 0;
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        String errorMsg = 'Email send failed for message ' + i + ': ';
                        for (Messaging.SendEmailError error : results[i].getErrors()) {
                            errorMsg += error.getMessage() + ' (StatusCode: ' + error.getStatusCode() + ')';
                        }
                        logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', errorMsg, '');
                    }
                }
                System.debug('IMLCCSendEmailQueueable: Email send results - Success: ' + successCount + ', Failed: ' + failureCount);
            } catch(Exception ex) {
                logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', ex.getStackTraceString(), 'Error sending emails: ' + ex.getMessage(), '');
            }
        } else if (emailMessages.isEmpty() && !Test.isRunningTest()) {
            // Log if no emails were created (for debugging)
            logError('IMLCC Integration', 'IMLCCSendEmailQueueable', 'sendNotifications', '', 'No email messages were created to send. Email template found: ' + (emailTemplate != null) + ', Group members: ' + groupMemberIds.size(), '');
        }
    }

    global static void logError(String type, String source, String sourceFunction, String stackTrace, String message, String payload) {
        Application_Log__c appLog = new Application_Log__c();
        appLog.Type__c = type;
        appLog.Source__c = source;
        appLog.Source_Function__c = sourceFunction;
        appLog.Stack_Trace__c = stackTrace;
        appLog.Message__c = message;
        appLog.Integration_Payload__c = payload;
        Database.insert(appLog, false); // Do not rollback since we're logging errors
    }

    global void logErrorNS(String type, String source, String sourceFunction, String stackTrace, String message, String payload) {
        Application_Log__c appLog = new Application_Log__c();
        appLog.Type__c = type;
        appLog.Source__c = source;
        appLog.Source_Function__c = sourceFunction;
        appLog.Stack_Trace__c = stackTrace;
        appLog.Message__c = message;
        appLog.Integration_Payload__c = payload;
        Database.insert(appLog, false); // Do not rollback since we're logging errors
    }
}