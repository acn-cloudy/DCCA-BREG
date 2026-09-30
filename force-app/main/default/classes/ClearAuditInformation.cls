/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the ClearAuditInformation
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint - EA20240507
* @author       Emel Ly Agarao - PacificPointCorp 
* @created      2024-05-07
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global with sharing class ClearAuditInformation implements  Database.Batchable<SObject>, Database.Stateful  {
    public String query = 'Select Id, Status__c, AuditDate__c, AuditCERequirement__c, AuditNumber__c, FlaggedforAudit__c, CEisConfirmed__c FROM License__c';
    global List<Id> resetAuditLTIds;

    public ClearAuditInformation(Id resetAuditLTId) {
        this.resetAuditLTIds = new List<Id>{resetAuditLTId};
        query += ' WHERE LicenseType__c IN ' + GlobalUtilities.convertIdsToIdStr(resetAuditLTIds) 
            + ' AND FlaggedforAudit__c = true';
    }
    
    global ClearAuditInformation(List<Id> resetAuditLTIds) {
        this.resetAuditLTIds = resetAuditLTIds;
        query += ' WHERE LicenseType__c IN ' + GlobalUtilities.convertIdsToIdStr(resetAuditLTIds) 
            + ' AND FlaggedforAudit__c = true';
    }
    
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>) scope;
        for(License__c license: licenses) {
            license.AuditDate__c = NULL;
            license.AuditCERequirement__c = NULL;
            license.AuditNumber__c = NULL;
            license.FlaggedforAudit__c = false;
            license.CEisConfirmed__c = false;
        }

        update licenses;
    }
	
    global void finish(Database.BatchableContext context) {
        List<LicenseType__c> lts = [SELECT Id, ClearAuditInformation__c FROM LicenseType__c WHERE Id IN: resetAuditLTIds];
        for(LicenseType__c lt:lts){
            lt.ClearAuditInformation__c = false;
        }

        if(!lts.isEmpty()){
            update lts;
        }
    }
}