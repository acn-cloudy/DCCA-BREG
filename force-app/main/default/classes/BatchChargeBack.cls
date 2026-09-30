/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  checkLicenseStatus : Find and set the status of Payment that needs to be Chargeback 
 *                       and set it to be charge back
 *  Covered by BatchChargeBackTest
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhou - PacificPointCorp 
 *  @created      PacPoint-AZ083021 - Created for PVL Support
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class BatchChargeBack implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public String query = 'Select Id, pymt__Status__c from pymt__PaymentX__c where ChargebackDate__c < today '
    +' and DisputedCharge__c = true and pymt__Status__c = \'Completed\'';
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<pymt__PaymentX__c> records = (List<pymt__PaymentX__c>) scope;
        for(pymt__PaymentX__c record : records) {
            record.pymt__Status__c = 'Chargeback';
        }
        update records;
    }

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new BatchChargeBack(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {

    }
}