/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Handler class for the TimeandExpenseHeaderAllHandler trigger
* Populates the total amount and hours on the Investigation record
* Covered by TimeandExpenseHeaderAllHandlerTest
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



public without sharing class TimeandExpensesAllHandler {
    
    //Handler for before insert methods
    public void onBeforeInsert(list<TimeandExpenseHeader__c> newList , map<id, TimeandExpenseHeader__c> newMap) {
        
    }
    //Handler for after insert methods
    public void onAfterInsert(list<TimeandExpenseHeader__c> newList , map<id, TimeandExpenseHeader__c> newMap) {
        CalculateRollups(newList, newMap, 'insert');
       
    }
    //Handler for before Update methods
    public void onBeforeUpdate(list<TimeandExpenseHeader__c> newList, map<id, TimeandExpenseHeader__c> newMap , map<id, TimeandExpenseHeader__c> oldMap) {

    }
    //Handler for after Update methods
    public void onAfterUpdate(list<TimeandExpenseHeader__c> newList, map<id, TimeandExpenseHeader__c> newMap,  map<id, TimeandExpenseHeader__c> oldMap) {
        CalculateRollups(newList, oldMap, 'update');
    }

    //Handler for before Deletes methods
    /*public void onBeforeDelete(list<TimeandExpenseHeader__c> oldList , map<id, TimeandExpenseHeader__c> oldMap) {

    }
    //Handler for after Deletes methods
    public void onAfterDelete(list<TimeandExpenseHeader__c> oldList , map<id, TimeandExpenseHeader__c> oldMap) {

    }*/
    
    
    private void CalculateRollups(list<TimeandExpenseHeader__c> newList , map<id, TimeandExpenseHeader__c> oldMap, String triggerAction){
        
        Set<Id> InvestigationsIdSet = new Set<Id>();
        
        for(TimeandExpenseHeader__c assign: newList)
        {
            if(triggerAction == 'insert')
                InvestigationsIdSet.add(assign.Investigation__c);
            if(triggerAction == 'update')
            {
                TimeandExpenseHeader__c oldAssign = oldMap.get(assign.Id);
                if(oldAssign.TotalAssignmentExpenses__c != assign.TotalAssignmentExpenses__c || oldAssign.TotalAssignmentHours__c != assign.TotalAssignmentHours__c)
                    InvestigationsIdSet.add(assign.Investigation__c);
            }
        }
        if (InvestigationsIdSet.size() > 0) {
            List<Investigation__c> InvestigationsToUpdate = new List<Investigation__c>();
            AggregateResult[] groupedResults = [
                SELECT SUM(TotalAssignmentExpenses__c ), SUM(TotalAssignmentHours__c),
                    Investigation__c
                FROM TimeandExpenseHeader__c
                WHERE Investigation__c in :InvestigationsIdSet
                GROUP BY Investigation__c
            ];
            for (AggregateResult ar : groupedResults) {
                
                InvestigationsToUpdate.add(new Investigation__c(
                    Id = (Id)ar.get('Investigation__c'),
                    TotalExpenses__c = (Decimal)ar.get('expr0'),
                    TotalHours__c = (Decimal)ar.get('expr1')
                ));
            }
    
            if (InvestigationsToUpdate.size() > 0) {
                update InvestigationsToUpdate;
            }
        }
    } 
}