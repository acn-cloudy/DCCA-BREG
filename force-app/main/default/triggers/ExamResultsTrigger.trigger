/*
 * ─────────────────────────────────────────────────────────
 * Used for the Trigger for Exam Results
 * ─────────────────────────────────────────────────────────
 * PacPoint-EA05102024: Created for Case 00035511
 * ───────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author Emel Ly Agarao - PacificPointCorp
 *
 * @created 2024-05-10
 * ───────────────────────────────────────────────────────────
 * Changes
 * ───────────────────────────────────────────────────────────
 */
trigger ExamResultsTrigger on ExamResults__c (before insert,
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

    TriggerFactory.createAndExecuteHandler(ExamResults__c.SObjectType);
}