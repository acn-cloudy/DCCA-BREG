/**
 * ScheduledClearEarnedCEBatch
 * Author: Alvin Zhou
 * Date: December 5, 2023
 * 
 * Description:
 * This global class implements Salesforce's Schedulable, Batchable, and Stateful interfaces.
 * It's designed for batch processing of License__c records to update associated Earned_Continuing_Education__c records.
 * The class handles batch execution and can maintain state across transactions. It's also scheduled to run
 * as per Salesforce's scheduling framework.
 * It is supposed to run annually 1/1
 */

// Declares a global class that implements Schedulable, Batchable, and Stateful interfaces. 
// This class is designed to process records in batches and can maintain state across transactions.
global class ScheduledClearEarnedCEBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {

    // Query to select License records with non-zero Core or Elective Credits.
    // Also fetches the first related Earned Continuing Education record for each License.
    global String query = 'Select Id, (Select Id, Name from Earned_Continuing_Education__r limit 1) from License__c where CoreCreditsThisLicensePeriod__c > 0 or ElectiveCreditsThisLicensePeriod__c > 0 ';
    
    // Start method of the batch class. It prepares the query locator for the batch process.
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    // Execute method called for each batch of records processed. 
    // It updates Earned Continuing Education records associated with each License record.
    global void execute(Database.BatchableContext context, List<SObject> scope) {   
        List<License__c> records = (List<License__c>) scope;
        List<Earned_Continuing_Education__c> earnedRecords = new List<Earned_Continuing_Education__c>();
        
        // Iterates through each License record and accumulates associated Earned Continuing Education records.
        for(License__c record: records) {
            if(record.Earned_Continuing_Education__r != null)
                earnedRecords.addAll(record.Earned_Continuing_Education__r);
        }
        
        // Updates Earned Continuing Education records. This triggers automation to update License credit fields.
        if(!earnedRecords.isEmpty())
            update earnedRecords;
    }

    // Execute method for Schedulable context. It schedules the batch job with a batch size of 100.
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new ScheduledClearEarnedCEBatch(), 100);
    }
    
    // Finish method of the batch class. Currently, it does not perform any operations.
    global void finish(Database.BatchableContext context) {}
}