public with sharing class BREGStartDocusignWorkflow implements Queueable, Database.AllowsCallouts {
    public static final String ANNUAL_ROBOT_WORKFLOW = 'BREG Annual Robot Process';

    private String workflowName;
    private Id recordId;
    private String params;
    private List<Id> recordIds;
    private Id logId;
    private List<Id> logIds;
    private String startedBy;

    public BREGStartDocusignWorkflow(String workflowName, List<Id> recordIds, String startedBy, Boolean generateLog) {
        this.workflowName = workflowName;
        this.recordIds = recordIds;
        this.params = null;
        this.startedBy = startedBy;
        this.logIds = null;
        this.logId = null;
    }

    public BREGStartDocusignWorkflow(String workflowName, Id recordId, String params, String startedBy, Boolean generateLog) {
        this.workflowName = workflowName;
        this.recordId = recordId;
        this.params = params;
        this.recordIds = null;
        this.startedBy = startedBy;
        this.logId = null;
        this.logIds = null;
    }
    public BREGStartDocusignWorkflow(String workflowName, Id recordId, String startedBy, Boolean generateLog) {
        this.workflowName = workflowName;
        this.recordId = recordId;
        this.params = null;
        this.recordIds = null;
        this.startedBy = startedBy;
        this.logId = null;
        this.logIds = null;
    }

    public BREGStartDocusignWorkflow(String workflowName, List<Id> recordIds, String startedBy, List<Id> logIds) {
        this.workflowName = workflowName;
        this.recordIds = recordIds;
        this.params = null;
        this.startedBy = startedBy;
        this.logIds = logIds;
        this.logId = null;
    }

    public BREGStartDocusignWorkflow(String workflowName, Id recordId, String params, String startedBy, Id logId) {
        this.workflowName = workflowName;
        this.recordId = recordId;
        this.params = params;
        this.recordIds = null;
        this.startedBy = startedBy;
        this.logId = logId;
        this.logIds = null;
    }

    public void execute(QueueableContext context) {
        if (recordIds != null && !recordIds.isEmpty()) {
            if (logIds != null) {
                List<Id> updatedLogIds = new List<Id>();
                List<Id> updatedRecordIds = new List<Id>();
                List<String> responseBodies = new List<String>();

                for (Integer index = 0; index < recordIds.size(); index++) {
                    Id currentRecordId = recordIds[index];
                    if (currentRecordId == null) {
                        continue;
                    }

                    Id currentLogId = index < logIds.size() ? logIds[index] : null;
                    if (currentLogId == null) {
                        continue;
                    }

                    String workflowParams = '<recordId>' + currentRecordId + '</recordId><logId>' + currentLogId + '</logId>';
                    String responseBody = DocuSignAPI.startWorkflowWithParams(workflowName, workflowParams);
                    updatedLogIds.add(currentLogId);
                    updatedRecordIds.add(currentRecordId);
                    responseBodies.add(responseBody);
                }

                for (Integer index = 0; index < updatedLogIds.size(); index++) {
                    BREGUtils.updateWorkflowsLog(updatedLogIds[index], updatedRecordIds[index], responseBodies[index]);
                }
                return;
            }

            for (Id id : recordIds) {
                if (id != null) {
                    DocuSignAPI.startWorkflow(workflowName, id);
                }
            }
            return;
        }

        if (logId != null) {
            String workflowParams;
            if (params == null) {
                workflowParams = '<recordId>' + recordId + '</recordId><logId>' + logId + '</logId>';
            } else {
                workflowParams = params + '<logId>' + logId + '</logId>';
            }

            String responseBody = DocuSignAPI.startWorkflowWithParams(workflowName, workflowParams);
            BREGUtils.updateWorkflowsLog(logId, recordId, responseBody);
            return;
        }

        if (params == null) {
            DocuSignAPI.startWorkflow(workflowName, recordId);
        } else {
            DocuSignAPI.startWorkflowWithParams(workflowName, params);
        }
    }

    @InvocableMethod(label='Start DocuSign Annual Robot')
    public static void startDocuSignAnnualRobot(List<Id> ids) {
        String startedBy = 'Annual Robot Process';
        List<Id> logIds = createWorkflowLogsSafely(ids, startedBy);
        System.enqueueJob(new BREGStartDocusignWorkflow(ANNUAL_ROBOT_WORKFLOW, ids, startedBy, logIds));
    }

    public static void startDocusignWorkflow(List<Id> ids, String startedBy, String workflowName, List<Id> logIds) {
        if (ids == null || ids.isEmpty() || String.isBlank(workflowName) || logIds == null) {
            return;
        }

        System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, ids, startedBy, logIds));
    }

    public static Id createWorkflowLogSafely(Id workflowRecordId, String startedByValue) {
        Boolean previousDisableTrigger = TriggerUtils.disableTrigger;
        TriggerUtils.disableTrigger = true;
        try {
            return BREGUtils.createWorkflowLog(workflowRecordId, startedByValue);
        } finally {
            TriggerUtils.disableTrigger = previousDisableTrigger;
        }
    }

    public static List<Id> createWorkflowLogsSafely(List<Id> workflowRecordIds, String startedByValue) {
        if (workflowRecordIds == null || workflowRecordIds.isEmpty()) {
            return null;
        }

        List<Id> workflowLogIds = new List<Id>();
        for (Id workflowRecordId : workflowRecordIds) {
            if (workflowRecordId != null) {
                workflowLogIds.add(createWorkflowLogSafely(workflowRecordId, startedByValue));
            } else {
                workflowLogIds.add(null);
            }
        }

        return workflowLogIds;
    }
}