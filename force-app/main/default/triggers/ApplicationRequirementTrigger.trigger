/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for Application Requirement
* ─────────────────────────────────────────────────────────
* PacPoint-AZ210919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-09-21
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger ApplicationRequirementTrigger on ApplicationRequirement__c (after insert, after update, before update) {
    OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
   if(orgSetting.DisableTriggers__c ) {
      return;
   }
    TriggerFactory.createAndExecuteHandler(ApplicationRequirement__c.SObjectType);
}