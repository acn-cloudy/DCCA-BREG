/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Trigger for License object
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-IC071819 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Irene Cahilo - PacificPointCorp
* @created      2019-07-18
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*PacPoint-AZ310819 - Updated for PVL Phase 1
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
trigger LicenseAll on License__c(after insert, before insert, before update, after update) {
    OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
    if(orgSetting.DisableTriggers__c || orgSetting.DisableLicenseTriggers__c ) {
      return;
    }
    
    TriggerFactory.createAndExecuteHandler(License__c.sobjectType);

    
}