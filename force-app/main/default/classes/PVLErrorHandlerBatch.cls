global class PVLErrorHandlerBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private String query = 'Select Id, EmailAsyncId__c from pymt__PaymentX__c where EmailAsyncId__c != null';
    /*
	 * batch start class
	 */
	global DataBase.QueryLocator Start(Database.BatchableContext context) {
		return Database.getQueryLocator(query);
	}

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<pymt__PaymentX__c> payments = (List<pymt__PaymentX__c>) scope;
        List<String> emailAsyncIds = new List<String>();
        for(pymt__PaymentX__c payment: payments) {
            emailAsyncIds.add(payment.EmailAsyncId__c);
        }
        List<AsyncApexJob> jobs = [Select Id from AsyncApexJob where Status = 'Failed' and Id in: emailAsyncIds];
        Set<String> asyncJobIds = new Set<String>();
        for(AsyncApexJob record: jobs) {
            asyncJobIds.add(record.Id);
        }

        for(pymt__PaymentX__c payment: payments) {
            if(asyncJobIds.contains(payment.EmailAsyncId__c)){
                PVL_SendPVLEmails.sendLicenseApplicationEmails(payment.Id);
            }
            payment.EmailAsyncId__c = null;
        }
        update payments;
    }

    public void execute(System.SchedulableContext context) {
		Database.executeBatch(new PVLErrorHandlerBatch(), 10);
	}
	/*
	 * batch finish class
	 */
	global void finish(Database.BatchableContext context) {}
}