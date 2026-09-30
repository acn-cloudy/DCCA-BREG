/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Delete all applications found,
 *  check to make sure there are NO related transactions that have either been fully or partially Completed 
 *  or have been "Saved for Group Transaction". 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @created      PacPoint-AZ031822 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 * 
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class DeleteUnPaidAppsBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private final static Set<String> APPLICATION_TYPE_FILTER = new Set<String>{'LICN - New License', 'LICF - New License After Forfeiture'};
    private final static String APPLICATION_STATUS_AP = 'AP - Application Pending Submittal by Applicant/Licensee';
    private final static Set<String> APPLICATION_ONLINE_TYPE_FILTER = new Set<String>{'Online New Application (LICN)', 'Online New Application (LICF)'};
    private Date TWO_WEEKS_AGO;
    public String query;

    global DeleteUnPaidAppsBatch() {
        this(-2);
    }
    global DeleteUnPaidAppsBatch(Integer weeks) {
        Date d = System.Today();
        TWO_WEEKS_AGO = d.addDays(weeks * 7);
        query = 'SELECT Id, LastModifiedDate FROM Application__c ' +
        ' WHERE Type__c IN :APPLICATION_TYPE_FILTER AND ' +
        ' STATUS__C = :APPLICATION_STATUS_AP AND  ' +
        ' OnlineApplicationType__c IN :APPLICATION_ONLINE_TYPE_FILTER AND ' +
        ' LastModifiedDate < :TWO_WEEKS_AGO ';
    }
    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Application__c> records = (List<Application__c>) scope;
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        Set<String> recordIdSet = new Set<String>();
        recordIdSet.addAll(recordIds);
        List<Transaction__c> trans = [Select Id, Application__c from Transaction__c 
            where Application__c in: recordIds and (Status__c = 'Completed' Or Status__c = 'Pending' or SavedForGroupTransaction__c = true) ];
        Set<String> applicationExcludeForDeletion = new Set<String>();

        for(Transaction__c tran: trans) {
            recordIdSet.remove(tran.Application__c);
        }

        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Transaction__r.Application__c in: recordIdSet ];
        List<Transaction__c> transactions = [Select Id, Application__c from Transaction__c where Application__c in: recordIdSet ];
        List<Application__c> apps = [Select Id from Application__c where Id in: recordIdSet];
        
        delete payments;
        delete transactions;
        delete apps;
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new DeleteUnPaidAppsBatch(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {}

}