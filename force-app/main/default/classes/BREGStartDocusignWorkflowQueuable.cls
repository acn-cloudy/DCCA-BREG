public with sharing class BREGStartDocusignWorkflowQueuable implements Queueable, Database.AllowsCallouts {
    String workflowName;
    List<Id> recordIds;
    List<Id> logIds;
    Id recordId;
    String params;
    Id logId;

    public BREGStartDocusignWorkflowQueuable(String workflowName, List<Id> recordIds) {
        this.workflowName = workflowName;
        this.recordIds = recordIds;
        this.logIds = null;
        this.recordId = null;
        this.params = null;
        this.logId = null;
    }

    public BREGStartDocusignWorkflowQueuable(String workflowName, List<Id> recordIds, List<Id> logIds) {
        this.workflowName = workflowName;
        this.recordIds = recordIds;
        this.logIds = logIds;
        this.recordId = null;
        this.params = null;
        this.logId = null;
    }

    public BREGStartDocusignWorkflowQueuable(String workflowName, Id recordId, String params, Id logId) {
        this.workflowName = workflowName;
        this.recordIds = null;
        this.logIds = null;
        this.recordId = recordId;
        this.params = params;
        this.logId = logId;
    }

    public void execute(QueueableContext context) {
        if (logId != null || logIds != null) {
            executeCalloutWorkflow();
            return;
        }

        Database.executeBatch(new BREGStartDocusignWorkflowBatch(workflowName, recordIds), 10);
    }

    private void executeCalloutWorkflow() {
        if (recordIds != null && !recordIds.isEmpty()) {
            List<String> responseBodies = new List<String>();
            List<Id> completedRecordIds = new List<Id>();
            List<Id> completedLogIds = new List<Id>();

            for (Integer index = 0; index < recordIds.size(); index++) {
                Id currentRecordId = recordIds[index];
                if (currentRecordId == null) {
                    continue;
                }

                Id currentLogId = index < logIds.size() ? logIds[index] : null;
                String responseBody;
                if (currentLogId != null) {
                    String workflowParams = '<recordId>' + currentRecordId + '</recordId><logId>' + currentLogId + '</logId>';
                    responseBody = DocuSignAPI.startWorkflowWithParams(workflowName, workflowParams);
                    completedRecordIds.add(currentRecordId);
                    completedLogIds.add(currentLogId);
                    responseBodies.add(responseBody);
                } else {
                    responseBody = DocuSignAPI.startWorkflow(workflowName, currentRecordId);
                }
            }

            for (Integer index = 0; index < completedLogIds.size(); index++) {
                BREGUtils.updateWorkflowsLog(completedLogIds[index], completedRecordIds[index], responseBodies[index]);
            }

            return;
        }

        String responseBody;
        String workflowParams = params;
        if (logId != null) {
            if (workflowParams == null) {
                workflowParams = '<recordId>' + recordId + '</recordId>';
            }
            workflowParams += '<logId>' + logId + '</logId>';
        }

        if (params == null && logId == null) {
            responseBody = DocuSignAPI.startWorkflow(workflowName, recordId);
        } else {
            responseBody = DocuSignAPI.startWorkflowWithParams(workflowName, workflowParams);
        }

        if (logId != null) {
            BREGUtils.updateWorkflowsLog(logId, recordId, responseBody);
        }
    }
}