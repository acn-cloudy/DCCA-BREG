trigger NotificationTrigger on Notification__c (before insert, after insert, 
                                                before update, after update, 
                                                before delete, after delete) {
    TriggerFactory.createAndExecuteHandler(Notification__c.SObjectType);

}