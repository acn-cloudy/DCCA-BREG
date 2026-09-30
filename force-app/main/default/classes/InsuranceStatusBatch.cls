/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Find the insurance Bond Records
*  Please write a apex batch job that does two things:
*  1) Set Pending Insurance Records to Active 
*   a) Query for all InsuranceBond__c records 
*     where: Status__c = Pending AND EffectiveDate__c =< today() AND (CancelDate__c IS NULL OR CancelDate__c > Today())
*     AND (TermDate__c IS NULL OR TermDate__c > Today())
*   b) For all records found, set Status__c = Active
*  2) Set Expired Insurance records to Inactive
*   a) Query for all InsuranceBond__c records where: Status__c <> Inactive AND TermDate__c =< today()
*   b) For all records found, set Status__c = Inactive
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      PacPoint-AZ032621
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* **/
global class InsuranceStatusBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public String query ='Select Id, CancelDate__c, TermDate__c, Status__c  from InsuranceBond__c '
    + ' where (Status__c = \'Pending\' and EffectiveDate__c <= today and '
    + ' (CancelDate__c = null Or CancelDate__c > today) and (TermDate__c = Null or TermDate__c > Today))'
    + ' or (Status__c != \'Inactive\' and TermDate__c < Today)';

    global InsuranceStatusBatch() {

    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<InsuranceBond__c> bonds = (List<InsuranceBond__c>) scope;
        for(InsuranceBond__c bond : bonds) {
            if(bond.Status__c == 'Pending' && (bond.TermDate__c == null || bond.TermDate__c > Date.today())) {
                bond.Status__c = 'Active';
            } else {
                bond.Status__c = 'Inactive';
            }
        }
        update bonds;
    }
    global void execute(System.SchedulableContext context) {
        Database.executeBatch(new InsuranceStatusBatch(), 100);
    }
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
    }

}