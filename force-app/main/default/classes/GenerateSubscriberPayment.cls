/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Generate PVL Subscriber Payment on the 1st of the Month
 *  
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhuang - PacificPointCorp 
 *  @created      PacPoint-AZ081121 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class GenerateSubscriberPayment implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    String query = 'Select Id, PVLSubscriber__c, PVLGenerateSubscriberPayment__c from Account where PVLSubscriber__c = true';
    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Account> records = (List<Account>) scope;
        for(Account record: records) {
            record.PVLSubscriber__c = false;
            record.PVLGenerateSubscriberPayment__c = true;
        }
        update records;
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new GenerateSubscriberPayment(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {}
}