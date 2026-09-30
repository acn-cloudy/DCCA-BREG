/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Generate List Builder Payment Weekly on Friday
 *  
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhou- PacificPointCorp 
 *  @created      PacPoint-AZ081121 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class GenerateListBuilderPayment implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public String query = 'Select Id, ListBuilderWeeklySubscriber__c, GenerateListBuilderPayment__c from Account where ListBuilderWeeklySubscriber__c = true';
    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Account> records = (List<Account>) scope;
        for(Account record: records) {
            record.GenerateListBuilderPayment__c = true;
        }
        update records;
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new GenerateListBuilderPayment(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {}
}