/*
* ─────────────────────────────────────────────────────────
* PVL_ListBuilderFileDeletionBatchJob Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ200820 - Apex Batch 2 to check if the payment date(API: pymt__Date__c) if it passed 7 days, then delete the file in SpringCM (Payment record in SpringCM with Desciption "PVL - List Builder Generation")
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2020-08-20
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
global class PVL_ListBuilderFileDeletionBatchJob implements schedulable, Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts{
    /* variables */
    public Integer batchSize;
    public List<pymt__PaymentX__c> updatePayment_L;

    /* construction */
    global PVL_ListBuilderFileDeletionBatchJob() {
        /* default settings */
        this.batchSize = 10;
        this.updatePayment_L = new List<pymt__PaymentX__c>();
    }

    /* collect the batches of records or objects to be passed to execute */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        String today7 = String.valueOf(System.Today() - 7); 
        String query = 'SELECT Id, NAME ';
        if (Test.isRunningTest()) {
            query += ' FROM pymt__PaymentX__c';
        } else {
            query += ' FROM pymt__PaymentX__c WHERE NAME = \'PVL - List Builder Payment\' AND pymt__Status__c = \'Completed\' AND pymt__Contact__r.Name = \'PVL Portal Contact\' AND PVL_Pickup_Token__c != null AND pymt__Date__c < ' + today7; 
        }
        return Database.getQueryLocator(query); 
    }

    /* method for scheduling */
    global void execute(SchedulableContext context){
        Database.executeBatch(new ReconciliationBatchJob(), batchSize);
    }

    /* process each batch of records */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        for(sObject s : scope) {
            pymt__PaymentX__c payment = (pymt__PaymentX__c)s;
            SpringCMConnector.deletListBuilderFiles(payment.Id);
            updatePayment_L.add(payment);
        }
    }

    global void finish(Database.BatchableContext bc) {
        updatePaymentRecords();
    }

    global void updatePaymentRecords(){
        Savepoint sp = Database.setSavepoint();
        try {
            for (pymt__PaymentX__c p : this.updatePayment_L) {
                p.PVL_Pickup_Token__c = null;
            }
            Database.update(this.updatePayment_L);
        } catch(DMLException e) {
            Database.rollback(sp);
            System.debug('Something happened:' + e.getMessage());
        }
    }

    global void deleteListBuilderFiles (pymt__PaymentX__c p) {
        SpringCMConnector.getFolderUploadLink(p.Id);
    }
}