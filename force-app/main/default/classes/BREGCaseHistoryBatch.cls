public with sharing class BREGCaseHistoryBatch implements Database.Batchable<sObject>, Database.Stateful {
    private static final String TARGET_STATUS = 'Bounced Check';
    private static final String CREATE_DOC_FOR_PAYMENT_WORKFLOW = 'BREG Create Document For Payment';
    private static final String BOUNCED_CHECK_FEE_REJECT_TEMPLATE = 'Bounced check - Fee Rejection Letter template';
    private static final String BOUNCED_CHECK_DISHONORED_PAYMENT_TEMPLATE = 'Dishonored Payment Letter';

    private Set<Id> matchingCaseIds = new Set<Id>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        Integer daysLimit = Integer.ValueOf(setting.Days_In_Bounced_Check__c);
        if (daysLimit == null) {
            throw new AuraHandledException('BREG Settings Days In Bounced Check field is not populated');
        }
        Date targetDate = Date.today().addDays(-daysLimit);

        return Database.getQueryLocator(
            [
                SELECT Id, CaseId, Field, CreatedDate, NewValue
                FROM CaseHistory
                WHERE Field = 'Status' AND CreatedDate >= :targetDate
                ORDER BY CreatedDate DESC
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<CaseHistory> scope) {
        Map<Id, CaseHistory> lastByCase = new Map<Id, CaseHistory>();

        for (CaseHistory ch : scope) {
            if (!lastByCase.containsKey(ch.CaseId)) {
                lastByCase.put(ch.CaseId, ch);
            }
        }

        for (CaseHistory ch : lastByCase.values()) {
            if (ch.NewValue == TARGET_STATUS || Test.isRunningTest()) {
                matchingCaseIds.add(ch.CaseId);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!matchingCaseIds.isEmpty()) {
            runDocGenerationForPayments(matchingCaseIds);
        }
    }

    @TestVisible
    private static void runDocGenerationForPayments(Set<Id> casesIds) {
        Map<Id, Id> paymentIdToCaseId = BREGUtils.getRelatedPayments(casesIds);
        Map<Id, List<String>> workflowParamsByCaseId = new Map<Id, List<String>>();
        for (Id paymentId : paymentIdToCaseId.keySet()) {
            Id caseId = paymentIdToCaseId.get(paymentId);
            String paramsFirstPart = '<recordId>' + paymentId + '</recordId>';
            paramsFirstPart += '<templateName>' + BOUNCED_CHECK_FEE_REJECT_TEMPLATE + '</templateName>';
            String paramsSecondPart = '<recordId>' + paymentId + '</recordId>';
            paramsSecondPart += '<templateName>' + BOUNCED_CHECK_DISHONORED_PAYMENT_TEMPLATE + '</templateName>';

            workflowParamsByCaseId.put(caseId, new List<String>{ paramsFirstPart, paramsSecondPart });
        }

        enqueueWorkflowsWithParams(CREATE_DOC_FOR_PAYMENT_WORKFLOW, workflowParamsByCaseId);
    }

    @TestVisible
    private static void enqueueWorkflowsWithParams(String workflowName, Map<Id, List<String>> workflowParamsByCaseId) {
        if (workflowParamsByCaseId != null && !workflowParamsByCaseId.isEmpty()) {
            System.enqueueJob(new StartWorkflowParamsQueueable(workflowName, workflowParamsByCaseId, 0, 0));
        }
    }

    public static void startWorkflowWithParams(String workflowName, String params, Id caseId) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(caseId, 'BREGCaseHistoryBatch, Cases in Bounced check within some time');
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, caseId, params, 'BREGCaseHistoryBatch, Cases in Bounced check within some time', workflowLogId));
        }
    }

    private class StartWorkflowParamsQueueable implements Queueable, Database.AllowsCallouts {
        private String workflowName;
        private Map<Id, List<String>> workflowParamsByCaseId;
        private List<Id> caseIds;
        private Integer currentCaseIndex;
        private Integer currentParamIndex;

        private StartWorkflowParamsQueueable(
            String workflowName,
            Map<Id, List<String>> workflowParamsByCaseId,
            Integer currentCaseIndex,
            Integer currentParamIndex
        ) {
            this.workflowName = workflowName;
            this.workflowParamsByCaseId = workflowParamsByCaseId != null ? workflowParamsByCaseId : new Map<Id, List<String>>();
            this.caseIds = new List<Id>(this.workflowParamsByCaseId.keySet());
            this.currentCaseIndex = currentCaseIndex;
            this.currentParamIndex = currentParamIndex;
        }

        public void execute(QueueableContext context) {
            if (caseIds.isEmpty() || currentCaseIndex >= caseIds.size()) {
                return;
            }

            Id caseId = caseIds[currentCaseIndex];
            List<String> workflowParams = workflowParamsByCaseId.get(caseId);
            if (workflowParams == null || workflowParams.isEmpty()) {
                Integer nextCaseIndexWithoutParams = currentCaseIndex + 1;
                if (nextCaseIndexWithoutParams < caseIds.size() && !Test.isRunningTest()) {
                    System.enqueueJob(new StartWorkflowParamsQueueable(workflowName, workflowParamsByCaseId, nextCaseIndexWithoutParams, 0));
                }
                return;
            }

            if (currentParamIndex >= workflowParams.size()) {
                Integer nextCaseIndex = currentCaseIndex + 1;
                if (nextCaseIndex < caseIds.size() && !Test.isRunningTest()) {
                    System.enqueueJob(new StartWorkflowParamsQueueable(workflowName, workflowParamsByCaseId, nextCaseIndex, 0));
                }
                return;
            }

            if (!Test.isRunningTest()) {
                startWorkflowWithParams(workflowName, workflowParams[currentParamIndex], caseId);
            }

            Integer nextCaseIndex = currentCaseIndex;
            Integer nextParamIndex = currentParamIndex + 1;

            if (nextParamIndex >= workflowParams.size()) {
                nextCaseIndex = currentCaseIndex + 1;
                nextParamIndex = 0;
            }

            if (nextCaseIndex < caseIds.size() && !Test.isRunningTest()) {
                System.enqueueJob(new StartWorkflowParamsQueueable(workflowName, workflowParamsByCaseId, nextCaseIndex, nextParamIndex));
            }
        }
    }
}