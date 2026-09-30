/*
* ─────────────────────────────────────────────────────────
* SendTo4GovController Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ171019 - Created for PVL 4Gov Integration
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-10-17
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class SendTo4GovController {
    //Apex properties or variables
    public Id Id { get; set; }
    public Reconciliation_Batch__c batchObject { get; set; }
    public List<DataTableWrapper> cdl { get; set; }
    public Boolean isDisabled { get; set; }
    public ContentVersion fileAttachment { get; set; }
    private ApexPages.standardController sc = null;

    //constructor to get the Reconciliation_Batch__c record
    public SendTo4GovController(ApexPages.StandardController controller) {
        batchObject =  (Reconciliation_Batch__c) controller.getRecord();
        Id = batchObject.Id;
        sc = controller;
        isDisabled = false;
        cdl = new List<DataTableWrapper>();
        List<ContentDocumentLink> tempCDL = new List<ContentDocumentLink>();
        if (String.isNotEmpty(Id)) {
            batchObject = [SELECT Id, Name, Batch_Time__c, Status__c from Reconciliation_Batch__c where id =: Id];
            tempCDL = [SELECT ContentDocument.Title, ContentDocument.ContentModifiedDate, ContentDocument.LatestPublishedVersionId, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink where LinkedEntityId =: Id and LinkedEntity.Type = 'Reconciliation_Batch__c' order by ContentDocument.ContentModifiedDate DESC];
        }

        if (batchObject != null && batchObject.Status__c != 'Pending Review') {
            isDisabled = true;
        }

        if (tempCDL.size() == 0) {
            isDisabled = true;
        } else {
            integer i = 1;
            for (ContentDocumentLink cd : tempCDL) {
                if (i == 1) {
                    cdl.add(new DataTableWrapper(true,cd));
                } else {
                    cdl.add(new DataTableWrapper(false,cd));
                }
                i++;
            }
            fileAttachment = [SELECT Id, VersionData, Title FROM ContentVersion WHERE ContentDocumentId =: tempCDL[0].ContentDocumentId];
        }
    }

    public PageReference sendEmailAtt() {
        Send_to_4Gov_Email_Setting__mdt send4govSetting = [SELECT To_Email_Addresses__c, Reply_To_Email_Address__c, Sender_Display_Name__c FROM Send_to_4Gov_Email_Setting__mdt WHERE MasterLabel = 'Send to 4 Gov'];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[]{send4govSetting.To_Email_Addresses__c};
        mail.setToAddresses(toAddresses);
        mail.setReplyTo(send4govSetting.Reply_To_Email_Address__c);
        mail.setSenderDisplayName(send4govSetting.Sender_Display_Name__c);
        mail.setBccSender(false);
        mail.setUseSignature(false);
        //mail.setTargetObjectId(Id);
        mail.setSubject('Send to 4Gov File Generated!');
        mail.setPlainTextBody('Please pick up the 4Gov File from this email attached!');
        //mail.setTemplateId('00XQ0000000QULj');
        mail.saveAsActivity = false;

        //Set email file attachments
        List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();
        Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
        efa.setFileName(fileAttachment.Title);
        efa.setBody(fileAttachment.VersionData);
        fileAttachments.add(efa);
        mail.setFileAttachments(fileAttachments);

        //Send email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        
        // Update Reconciliation_Batch__c object 
        batchObject.Status__c = 'Sent To 4Gov';
        Database.update(batchObject);
        return sc.cancel();
    }

    public PageReference doCancel() {
        return sc.cancel();
    }

    // inner class
    class DataTableWrapper {
        public Boolean fileChecked { get; set; }
        public ContentDocumentLink cdl { get; set;}

        public DataTableWrapper(Boolean fileChecked, ContentDocumentLink cdl) {
            this.fileChecked = fileChecked;
            this.cdl = cdl;
        }
    }
}