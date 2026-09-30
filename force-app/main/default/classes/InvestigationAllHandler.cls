/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Handler class for the InvestigationAll trigger
* - Populates the total amount and hours on the SEBCase__c record
* - Adds history records
* Covered by InvestigationAllHandlerTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC121318 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2018-12-13
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/


public without sharing class InvestigationAllHandler {
    
    //Handler for before insert methods
    public void onBeforeInsert(list<Investigation__c> newList , map<id, Investigation__c> newMap) {
        
    }
    //Handler for after insert methods
    public void onAfterInsert(list<Investigation__c> newList , map<id, Investigation__c> newMap) {
        CalculateRollups(newList, newMap, 'insert');
        StatusHistoryAux.LogStatus(Trigger.new, null, 'Status__c', 'Investigation__c', 'Investigation__c');
    }
    //Handler for before Update methods
    public void onBeforeUpdate(list<Investigation__c> newList, map<id, Investigation__c> newMap , map<id, Investigation__c> oldMap) {

    }
    //Handler for after Update methods
    public void onAfterUpdate(list<Investigation__c> newList, map<id, Investigation__c> newMap,  map<id, Investigation__c> oldMap) {
        CalculateRollups(newList, oldMap, 'update');
        StatusHistoryAux.LogStatus(Trigger.new, Trigger.oldMap, 'Status__c', 'Investigation__c', 'Investigation__c');
    }

    //Handler for before Deletes methods
    /*public void onBeforeDelete(list<Investigation__c> oldList , map<id, Investigation__c> oldMap) {

    }
    //Handler for after Deletes methods
    public void onAfterDelete(list<Investigation__c> oldList , map<id, Investigation__c> oldMap) {

    }*/
    
    
    private void CalculateRollups(list<Investigation__c> newList , map<id, Investigation__c> oldMap, String triggerAction){
        
        Set<Id> SEBCaseIdSet = new Set<Id>();
        for(Investigation__c investigation: newList)
        {
            if(triggerAction == 'insert')
                SEBCaseIdSet.add(investigation.SEBCase__c);
            if(triggerAction == 'update')
            {
                Investigation__c oldInvestigation = oldMap.get(investigation.Id);
                if(oldInvestigation.TotalExpenses__c != investigation.TotalExpenses__c || oldInvestigation.TotalHours__c != investigation.TotalHours__c)
                    SEBCaseIdSet.add(investigation.SEBCase__c);
            }
        }
        if (SEBCaseIdSet.size() > 0) {
            List<SEBCase__c> SEBCaseToUpdate = new List<SEBCase__c>();
            AggregateResult[] groupedResults = [
                SELECT SUM(TotalExpenses__c), SUM(TotalHours__c),
                    SEBCase__c
                FROM Investigation__c
                WHERE SEBCase__c in :SEBCaseIdSet
                GROUP BY SEBCase__c
            ];
            for (AggregateResult ar : groupedResults) {

                SEBCaseToUpdate.add(new SEBCase__c(
                    Id = (Id)ar.get('SEBCase__c'),
                    TotalSEBCaseExpenses__c = (Decimal)ar.get('expr0'),
                    TotalSEBCaseHours__c   = (Decimal)ar.get('expr1')
                ));
            }

            if (SEBCaseToUpdate.size() > 0) {
                update SEBCaseToUpdate;
            }
        }
    }
}