trigger InsuranceBondTrigger on InsuranceBond__c(
        before insert,
        before update,
        before delete,
        after insert,
        after update,
        after delete) {
    OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
    if(orgSetting.DisableTriggers__c ) {
        return;
    }
    TriggerFactory.createAndExecuteHandler(InsuranceBond__c.SObjectType);
}