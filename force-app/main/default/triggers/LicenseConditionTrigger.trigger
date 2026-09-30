trigger LicenseConditionTrigger on LicenseConditions__c (after insert, after update, after delete, before delete ) {
    if(TriggerHelper.disableLicenseConditionsTrigger) {
        return;
    }
    TriggerFactory.createAndExecuteHandler(LicenseConditions__c.SObjectType);
}