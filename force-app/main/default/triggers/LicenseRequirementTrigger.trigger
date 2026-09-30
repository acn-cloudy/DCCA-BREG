trigger LicenseRequirementTrigger on LicenseRequirements__c(after update) {
    TriggerFactory.createAndExecuteHandler(LicenseRequirements__c.sobjectType);
}