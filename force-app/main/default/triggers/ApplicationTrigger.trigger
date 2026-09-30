/*
 * ─────────────────────────────────────────────────────────
 * Used for the Trigger for Application
 * ─────────────────────────────────────────────────────────
 * PacPoint-AZ140619 - Created for PVL phase 1
 * ───────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author Alvin Zhou - PacificPointCorp
 *
 * @created 2019-06-14
 * ───────────────────────────────────────────────────────────
 * Changes
 * ───────────────────────────────────────────────────────────
 */
trigger ApplicationTrigger on Application__c (before insert,
        after insert,
        before update,
        after update,
        after delete,
        after undelete) {
    OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
    Boolean disableForUser = (orgSetting.DisableApplicationTriggersForUser__c != null && UserInfo.getUserName() == orgSetting.DisableApplicationTriggersForUser__c);
    if (orgSetting.DisableTriggers__c || TriggerHelper.disableApplicationTrigger || disableForUser) {
        return;
    }

    TriggerFactory.createAndExecuteHandler(Application__c.SObjectType);
}