trigger BREGAccountTrigger on Account(before insert, before update, after update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    System.debug('BREGAccountTrigger triggered');
    new BREGAccountTriggerHandler().run();
}