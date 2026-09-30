/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the LicenseType Trigger
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
*  PacPoint-AZ011920 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
trigger LicenseTypeTrigger on LicenseType__c (before insert, after insert, before update, after update, before delete , after delete, after undelete) {
    TriggerFactory.createAndExecuteHandler(LicenseType__c.SObjectType);
}