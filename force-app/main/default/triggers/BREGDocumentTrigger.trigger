trigger BREGDocumentTrigger on breg_Document__c(before insert, after insert, after update) {
    BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
    if (setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true) {
        return;
    }
    new BREGDocumentTriggerHandler().run();

}