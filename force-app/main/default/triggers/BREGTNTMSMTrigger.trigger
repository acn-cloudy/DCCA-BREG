trigger BREGTNTMSMTrigger on breg_TN_TM_SM__c(before insert, before update, after update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    new BREGTNTMSMTriggerHandler().run();
}