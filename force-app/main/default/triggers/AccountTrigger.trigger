/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for Application
* ─────────────────────────────────────────────────────────
* PacPoint-CZ100419 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp
* @created      2019-10-04
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger AccountTrigger on Account (before insert, after insert,
                                   before update, after update,
                                   after delete, after undelete) {
   OrgConfiguration__c  orgSetting = OrgConfiguration__c.getInstance();
   if(orgSetting.DisableTriggers__c || orgSetting.DisableAccountTriggers__c ) {
      return;
   }
   if(TriggerHelper.disableAccountTrigger) {return;}
   TriggerFactory.createAndExecuteHandler(Account.SObjectType);
}