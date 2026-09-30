/***
 * Description: used to clean Renewal Applications that are not used 
 * Created By: Alvin Zhou
 * Date: 09/23/2021
 * 
 * ******** */
global class CleanRenewApplicationJob implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public String query = 'Select Id, (Select Id from Transactions__r where Status__c in: tranStatuses or SavedforGroupTransaction__c = true ) ' 
    + ' from Application__c where LastModifiedDate <=: weekAgo '
    + ' and Type__c in: types and Status__c in: appStatus and OnlineApplicationType__c =: onlineAppType';

    public DateTime weekAgo = System.now().addDays(-7);
    public Set<String> tranStatuses = new Set<String> {'Completed', 'Pending'};
    public Set<String> types = new Set<String> {'RNEW - Renewal', 'RSTR - Restore - No A/I Status'};
    public Set<String> appStatus = new Set<String> {'AP - Application Pending Submittal by Applicant/Licensee'};
    public String onlineAppType = 'Online Renewal/Restore';
    Global CleanRenewApplicationJob() {}
    Global CleanRenewApplicationJob(DateTime dT) {
        this.weekAgo = dt;
    }
    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Application__c> records = (List<Application__c>) scope;
        List<String> recordIds = new List<String>();
        for(Application__c record: records) {
            //  For all applications found above, check to make sure there are NO related transactions 
            //  that have either been fully or partially Completed or have been "Saved for Group Transaction"
            if(record.Transactions__r == null || record.Transactions__r.isEmpty()) {
                recordIds.add(record.Id);
            }
        }

        if(recordIds.isEmpty()) return;
        List<Application__c> appRecords = [Select Id from Application__c where Id in: recordIds];
        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Transaction__r.Application__c in: recordIds];
        List<Transaction__c> transactions = [Select Id from Transaction__c where Application__c in: recordIds];

        Triggerhelper.disableApplicationTrigger = true;
        // Delete Payments
        delete payments;
        // Delete transactions
        delete transactions;
        // Delete applications;
        delete appRecords;


    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new CleanRenewApplicationJob(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {

    }
    
}