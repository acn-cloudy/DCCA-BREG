@isTest
public with sharing class SendLetterToPrinterBatchJobTest {
    public static testMethod void testBatch() {
        Notification__c record = new Notification__c();
        record.Status__c = 'Scheduled';
        record.SendtoPrinter__c = true;
        record.Scheduled__c = true;
        record.DocGeneratorSettings__c = 'Test Doc';
        record.DocumentTemplateName__c = 'test Doc';

        insert record;
        //Create File Attached
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = Blob.valueOf('test');
        cv.Title = record.DocumentTemplateName__c + '.txt';
        cv.PathOnClient = record.DocumentTemplateName__c + '.txt';
        insert cv;
                    
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = record.Id;
        cdl.ShareType = 'I';
        insert cdl;
        SendLetterToPrinterBatchJob job = new SendLetterToPrinterBatchJob();
        Database.executeBatch(job);
        List<Notification__c> records = NotificationSelector.getNotifications(record.Id);
        List<Id> contentDocumentIds = new List<Id>();
        contentDocumentIds.add(cdl.ContentDocumentId);
        job.execute(null, records);
        job.sendEmails(contentDocumentIds);
        SendLetterToPrinterBatchJob.ContentDocumentAsAttachement(contentDocumentIds);
    }
}