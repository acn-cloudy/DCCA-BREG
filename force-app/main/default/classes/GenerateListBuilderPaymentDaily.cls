/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Generate List Builder Payment Daily at 6:00 pm every day.
 *  
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhou- PacificPointCorp 
 *  @created      PacPoint-AZ101521 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class GenerateListBuilderPaymentDaily implements schedulable {
    public void execute(System.SchedulableContext context) {
        GenerateListBuilderPayment gListPayment = new GenerateListBuilderPayment();
        gListPayment.query = 'Select Id, GenerateListBuilderPayment__c from Account where ListBuilderDailySubscriber__c = true';
        Database.executeBatch(gListPayment, 100);
    }
}