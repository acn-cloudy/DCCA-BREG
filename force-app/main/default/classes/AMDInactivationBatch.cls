/*
 * ___________________________________________________________________________________
 * AMD Inactivation Letter Notice Controller
 * For AMDInactivationLetterNotice Email Templates
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA02052024 - Created for Case 00033728
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 02/05/2024
 * __________________________________________________________________________________
 */
global with sharing class AMDInactivationBatch  implements Database.Batchable<sObject>, Database.Stateful{
    public List<String> recordIds = new List<String>();  
    public String query = 'SELECT Id, RecipientEmail__c, RecordId__c, Status__c FROM Notification__c ';

    global AMDInactivationBatch() {
        query += ' WHERE Type__c = \'Email\' AND Status__c = \'Scheduled\' and RecipientEmail__c != null';
    }

    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Notification__c> scope){
        EmailTemplate emailTemplate = [Select Id,Subject,Markup from EmailTemplate where name = 'AMDInactivationLetterNotice' LIMIT 1];

        List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
        List<OrgWideEmailAddress> fromAddress = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'DCCA No Reply'];
        String eId;
        if(Test.isRunningTest()) {
            EmailTemplate temp= [Select Id from EmailTemplate where IsActive = true limit 1];
            eId = temp.Id;
        }
        
        for (Notification__c record : scope) {
            String emailTemplateId;
            if(Test.isRunningTest() ) {
                emailTemplateId = eId;
            } else {
                emailTemplateId = emailTemplate.Id;
            }

            if (emailTemplateId != null) {
                Messaging.SingleEmailMessage msg = Messaging.renderStoredEmailTemplate(emailTemplateId, UserInfo.getUserId(), record.RecordId__c);
                msg.setTreatTargetObjectAsRecipient(false);
                msg.setToAddresses(new List<String>{record.RecipientEmail__c});
                record.Status__c = 'Completed';
                msgs.add(msg);
            }
        }

        if(!Test.isRunningTest()) Messaging.sendEmail(msgs);
        update scope;
        
    }

    global void finish(Database.BatchableContext BC) {}
}