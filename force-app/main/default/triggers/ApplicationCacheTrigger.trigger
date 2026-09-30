trigger ApplicationCacheTrigger on Application_Cache__c (before insert, before update, before delete, after insert, after update, after delete) {
    TriggerFactory.createAndExecuteHandler(Application_Cache__c.sobjectType);

}