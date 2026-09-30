trigger FileDetailTrigger on FileDetails__c(before update,
        before insert,
        before delete,
        after update,
        after insert,
        after delete) {
    TriggerFactory.createAndExecuteHandler(FileDetails__c.sObjectType);
}