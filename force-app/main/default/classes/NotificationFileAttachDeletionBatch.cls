/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: NotificationFileAttachDeletionBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-TK03092023 - Created for PVL Case 00027783
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author takashi.koyama@pacificpointcorp.com
 *
 * @created 03/09/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class NotificationFileAttachDeletionBatch implements Schedulable, Database.Batchable<SObject>{
    public String query;

    public NotificationFileAttachDeletionBatch() {
        query = 'SELECT Id ' +
                'FROM Notification__c ' +
                'WHERE Status__c = \'Completed\' AND CreatedDate < LAST_N_DAYS:7';
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Notification__c> notifications = (List<Notification__c>) scope;

        Set<Id> notifIDs = new Set<Id>();

        for(Notification__c n: notifications){
            notifIDs.add(n.Id);            
        }
        
        List<ContentDocumentLink> contDocLinks = [SELECT ContentDocumentId FROM ContentDocumentLink  
        WHERE LinkedEntityId  IN : notifIDs];

        Set<Id> contIDs = new Set<Id>();

        for(ContentDocumentLink c: contDocLinks){
            contIDs.add(c.ContentDocumentId);            
        }

        List<ContentDocument> contDocs = [SELECT Id, IsDeleted, FileType FROM ContentDocument
        WHERE Id IN :contIDs];
        
        
        delete contDocs;
    }

    public void finish(Database.BatchableContext bc) {
    }

    public Database.QueryLocator start(Database.BatchableContext param1) {
        return Database.getQueryLocator(query);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NotificationFileAttachDeletionBatch());
    }
}