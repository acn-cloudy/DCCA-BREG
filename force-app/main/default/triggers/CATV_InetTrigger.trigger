trigger CATV_InetTrigger on INET_Request__c (after insert, before update) {
	if(trigger.isAfter){
        if(trigger.IsInsert){
            CATV_InetTriggerHandler.afterInsert(Trigger.New);
        }
    }

    if(trigger.isBefore){
        if(trigger.IsUpdate){
            CATV_InetTriggerHandler.beforeUpdate(Trigger.New, Trigger.oldMap);
        }
    }
}