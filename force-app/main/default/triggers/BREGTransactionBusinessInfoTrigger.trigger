trigger BREGTransactionBusinessInfoTrigger on breg_Transaction_Business_Info__c(before insert, before update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    new BREGTxnBusInfoTriggerHandler().run();
}