trigger BREGPaymentTrigger on pymt__PaymentX__c(before insert, after insert) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    new BREGPaymentTriggerHandler().run();
}