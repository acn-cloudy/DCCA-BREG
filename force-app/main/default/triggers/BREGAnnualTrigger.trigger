trigger BREGAnnualTrigger on breg_Annual__c(before insert, before update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    //ensure that there is only one Annual record per Account per Year
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        BREGAnnualTriggerHandler.populateUniqueKey(Trigger.new);
    }

}