public with sharing class BREGBatchScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new BREGBatch('Account'));
        Database.executeBatch(new BREGBatch('breg_TN_TM_SM__c'));
        Database.executeBatch(new BREGBatch('breg_Annual__c'));
        Database.executeBatch(new BREGBatch('breg_Entity_List_Result__c'));
    }
}