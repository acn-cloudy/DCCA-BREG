/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for Application Classifications
* ─────────────────────────────────────────────────────────
* PacPoint-AZ140619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-14
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger ApplicationClassificationsTrigger on ApplicationClassifications__c (after insert, after delete, after undelete) {
    OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
   if(orgSetting.DisableTriggers__c ) {
      return;
   }
    TriggerFactory.createAndExecuteHandler(ApplicationClassifications__c.SObjectType);
    if(Trigger.isAfter) {
        if (Trigger.isInsert) {
            ApplicationClassificationCreateRecords.appClassCreateExamResultsRecords(Trigger.new);
        }
    }
}