trigger BREGAccountAffiliationTrigger on breg_Account_Affiliation__c(before insert, before update, after insert, after update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    new BREGAccountAffiliationTriggerHandler().run();
}