/*
* ─────────────────────────────────────────────────────────
* SendLetterToPrinterBatchJob Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ010420 - Send Letter to Printer
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2020-04-01
* ───────────────────────────────────────────────────────────
* Changes
* Alvin Zhou
* Date: 2020-07-14    
* ───────────────────────────────────────────────────────────
*/
global class SendLetterToPrinterBatchJob implements schedulable, Database.Batchable<SObject>,  Database.Stateful {
    public String query ='Select Id, Name, Status__c,FailedReason__c,Fire__c, TimeDelivered__c, ScheduledTime__c, SendtoPrinter__c, PrintStatus__c, '
            +' TimeSent__c from Notification__c where Scheduled__c = true and SendtoPrinter__c = true and (Status__c = \'Completed\' or PrintStatus__c	 = \'Ready for Print\')';
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<String> contentDocumentIds = new List<String>();
        List<Notification__c> records = (List<Notification__c>) scope;
        List<String> notificationIds = (new NotificationDomain(records)).getIds();
        List<ContentDocumentLink> links = [Select Id, ContentDocumentId, LinkedEntityId from ContentDocumentLink where LinkedEntityId in: notificationIds];
        Map<String, String> linkedContentDocumentIds = new Map<String, String>();
        for(ContentDocumentLink link: links) {
            linkedContentDocumentIds.put(link.LinkedEntityId, link.ContentDocumentId);
        }
        contentDocumentIds = linkedContentDocumentIds.values();
        // for(ContentDocumentLink dl : links) {
        //     contentDocumentIds.add(dl.ContentDocumentId);
        // }
        sendEmails(contentDocumentIds);
        // update notification to be 
        for(Notification__c record: records) {
            record.SendtoPrinter__c = false;
            record.Fire__c = true;
            record.PrintStatus__c = 'Completed';
        }
        update records;

    }
    public void execute(System.SchedulableContext context) {
    Database.executeBatch(new SendLetterToPrinterBatchJob(), 10);
    }
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        
    }
    global static List<Messaging.EmailFileAttachment> ContentDocumentAsAttachement(List<Id> contentDocumentIds) {
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>{};
        List<ContentVersion> documents                  = new List<ContentVersion>{};
    
        documents.addAll([
          SELECT Id, Title, FileType, VersionData, isLatest, ContentDocumentId
          FROM ContentVersion
          WHERE isLatest = true AND ContentDocumentId in: contentDocumentIds
        ]);
    
        for (ContentVersion document: documents) {
          Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
          attachment.setBody(document.VersionData);
          attachment.setFileName(document.Title);
          attachments.add(attachment);
        }
        return attachments;
    }

    global void sendEmails (List<Id> contentDocumentIds) {
        //get Printer Default Email 
        Send_Letter_to_Printer__mdt emailSetting = [SELECT Email_Address__c, CC_Address__c FROM Send_Letter_to_Printer__mdt WHERE MasterLabel = 'Default Printer EmailAddress'];
        // Step 3: Set who the email is sent from
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        if(orgSetting.Use_Organization_Wide_Email__c) {
          OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = 'noreply@dcca.hawaii.gov'];
          if (owea.size() > 0) {
            semail.setOrgWideEmailAddressId(owea[0].Id);
          }
        } else {
            semail.setReplyTo('noreply@dcca.hawaii.gov');
            semail.setSenderDisplayName('noreply@dcca.hawaii.gov');
        }
        semail.setSubject('Send Letter to Printer Batch');
        String[] sendTo = new String[]{emailSetting.Email_Address__c};
        semail.setToAddresses(sendTo);
        if(!String.isBlank(emailSetting.CC_Address__c) )
            semail.setBCcAddresses(emailSetting.CC_Address__c.split(','));
        semail.setPlainTextBody('Please find the attached letter to printer');
        semail.setFileAttachments(ContentDocumentAsAttachement(contentDocumentIds));
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
}