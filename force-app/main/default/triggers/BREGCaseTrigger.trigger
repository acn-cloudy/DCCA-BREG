trigger BREGCaseTrigger on Case(before update, before insert, after update, after insert) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    } else {
        //Recursive trigger prevention
        Boolean run = !TriggerUtils.disableTrigger;
        if (run) {
            new BREGCaseTriggerHandler(true).run();
            if (Trigger.isAfter) {
                TriggerUtils.disableTrigger = true;
            }
        }
    }
}