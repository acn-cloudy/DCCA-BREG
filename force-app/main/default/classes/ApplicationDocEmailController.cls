public class ApplicationDocEmailController {
    @InvocableMethod(label='Send Notification Email' category='Application')
    public static void sendEmail(Input[] inputs) {
        Map<String, String> nId2Content = new Map<String, String>();
        List<String> notificationIds = new List<String>();
        for(Input i: inputs) {
            notificationIds.add(i.recordId);
            nId2Content.put(i.recordId, i.content);
        }
        List<Notification__c> notifications = NotificationSelector.getNotifications(notificationIds);
        List<ContentDocumentLink> links = [Select Id, ContentDocumentId, LinkedEntityId from ContentDocumentLink where LinkedEntityId in: notificationIds];
        Map<String, List<String>> contentDocumentIds = new Map<String, List<String>>();
        List<String> contentDocumentIdList = new List<String>();
        for(ContentDocumentLink link: links) {
            if(!contentDocumentIds.containsKey(link.LinkedEntityId)) {
                contentDocumentIds.put(link.LinkedEntityId, new List<String>());
            }

            contentDocumentIds.get(link.LinkedEntityId).add(link.ContentDocumentId);
            contentDocumentIdList.add(link.ContentDocumentId);
        }
        List<ContentVersion> versions = [Select Id, ContentDocumentId from ContentVersion where ContentDocumentId in: contentDocumentIdList];
        Map<String, String> versionMap = new Map<String, String>();
        for(ContentVersion version: versions) {
            versionMap.put(version.ContentDocumentId, version.Id);
        }


        for(Notification__c record: notifications) {
            List<String> cdIds = contentDocumentIds.get(record.Id);
            List<String> contentVersionIds = new List<String>();
            for(String cdId: cdIds) {
                contentVersionIds.add(versionMap.get(cdId));
            }
            String content = nId2Content.get(record.Id);
            sendEmail(record.RecipientEmail__c, record.DocGeneratorSettings__c, contentVersionIds, content);
        }
    }

    public static void sendEmail(String email, String subject, List<String> contentVersionIds, String content) {
        String htmlMsg = '<p>Please see attached file for deficiency letter.</p>';
        if(content != null) {
            htmlMsg = '<p>' + content + '</p>';
        }
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgWideEmailAddress[] owea = [Select Id from OrgWideEmailAddress where DisplayName = 'DCCA No Reply'];
        if (owea.size() > 0) {
            semail.setOrgWideEmailAddressId(owea[0].Id);
        }
        semail.setSubject(subject);
        String[] sendTo = new String[]{email};
        semail.setToAddresses(sendTo);
        semail.setHtmlBody(htmlMsg);
        // Attache the files
        semail.setEntityAttachments(contentVersionIds);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }

    public class Input {
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
        @InvocableVariable(label='Content')
        public String content;
    }
    
}