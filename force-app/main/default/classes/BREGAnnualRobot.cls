public with sharing class BREGAnnualRobot {

    /**
     * Evaluates annual cases and starts the annual robot for records that pass all checks.
     * @param cases Cases from the trigger handler.
     */
    public static void processCases(List<Case> cases) {
        enqueueCaseIds(extractEligibleCaseIds(cases));
    }

    @TestVisible
    private static void enqueueCaseIds(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        System.enqueueJob(new RobotQueueable(new List<Id>(caseIds)));
    }

    private class RobotQueueable implements Queueable {
        private Set<Id> caseIds;

        private RobotQueueable(List<Id> caseIds) {
            this.caseIds = new Set<Id>(caseIds);
        }

        public void execute(QueueableContext context) {
            BREGAnnualRobot.processCaseIds(caseIds);
        }
    }

    public static void processCaseIds(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty() || triggersDisabled() || !annualRobotEnabled()) {
            return;
        }

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(caseIds);
        if (loadedCases.isEmpty()) {
            return;
        }

        loadedCases = BREGAnnualRobotEngine.expandWithEligibleEntityAnnualCases(loadedCases);
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);
        BREGAnnualRobotRules.finalizeSuccessPlans(plans);
        BREGAnnualRobotRules.applyPlans(plans);
        enqueueQueuedFollowUps(BREGAnnualRobotRules.getSuccessfulEntityIds(plans));
    }

    private static BREG_Setting__c getSettings() {
        BREG_Setting__c setting = BREG_Setting__c.getInstance(UserInfo.getUserId());
        return setting == null ? BREG_Setting__c.getOrgDefaults() : setting;
    }

    private static Boolean triggersDisabled() {
        BREG_Setting__c setting = getSettings();
        return setting != null && setting.Global_Data_Migration_Triggers_Disabled__c == true;
    }

    private static Boolean annualRobotEnabled() {
        BREG_Setting__c setting = getSettings();
        return setting != null && setting.Annual_Robot_Enabled__c == true;
    }

    private static Set<Id> extractEligibleCaseIds(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        if (cases == null) {
            return caseIds;
        }

        for (Case currentCase : cases) {
            if (meetsInputStartCriteria(currentCase)) {
                caseIds.add(currentCase.Id);
            }
        }

        return caseIds;
    }

    private static Boolean meetsInputStartCriteria(Case currentCase) {
        return currentCase != null &&
            currentCase.Id != null &&
            currentCase.Status == 'Received' &&
            currentCase.breg_No_Changes__c == true;
    }

    private static void enqueueQueuedFollowUps(Set<Id> successfulEntityIds) {
        if (successfulEntityIds == null || successfulEntityIds.isEmpty()) {
            return;
        }

        Set<Id> queuedCaseIds = new Set<Id>();
        for (Case queuedCase : BREGAnnualRobotWithoutSharing.getQueuedFollowUpCases(successfulEntityIds)) {
            queuedCaseIds.add(queuedCase.Id);
        }

        enqueueCaseIds(queuedCaseIds);
    }
}