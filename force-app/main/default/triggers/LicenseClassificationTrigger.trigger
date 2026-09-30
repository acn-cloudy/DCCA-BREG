/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for Application
* ─────────────────────────────────────────────────────────
* PacPoint-CZ19092019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-09-19
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger LicenseClassificationTrigger on LicenseClassification__c (before insert, after insert, 
                                              before update, after update, 
                                              after delete, after undelete) {                                        
   if(TriggerHelper.disableLicenseClassificationTrigger) {return;}
   TriggerFactory.createAndExecuteHandler(LicenseClassification__c.SObjectType);
}