trigger SanctionTrigger on Sanction__c (before update, after update) {
    if(SanctionService.skipTrigger) return;
    TriggerFactory.createAndExecuteHandler(Sanction__c.sObjectType);
}