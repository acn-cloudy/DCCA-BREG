global with sharing class ScheduledGenerateFiles implements schedulable, Database.Batchable<SObject>, Database.Stateful,Database.AllowsCallouts {
    public String query ='Select Id, Name, RecordId__c, Status__c,FailedReason__c,DocumentTemplateName__c, Fire__c, TimeDelivered__c, ScheduledTime__c, '
            +' TimeSent__c from Notification__c where ( Status__c = \'Failed\'  or Status__c =\'Scheduled\') and Scheduled__c = true';
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Notification__c> records = (List<Notification__c>) scope;
        (new NotificationDomain(records)).fireNotifications();
        // update records;
    }
    public void execute(System.SchedulableContext context) {
		Database.executeBatch(new ScheduledGenerateFiles(), 10);
	}
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        Database.executeBatch(new SendLetterToPrinterBatchJob(), 10);
    }
}