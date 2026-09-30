public with sharing class BREGStartDocusignWorkflowBatch implements Database.Batchable<Id>, Database.AllowsCallouts, Database.Stateful {
    private breg_Docusign_Settings__c settings = breg_Docusign_Settings__c.getOrgDefaults();

    private String workflowName;
    private List<Id> recordIds;
    private Integer processed = 0;
    private Integer errors = 0;

    public BREGStartDocusignWorkflowBatch(String workflowName, List<Id> recordIds) {
        this.workflowName = workflowName;
        this.recordIds = recordIds != null ? recordIds : new List<Id>();
    }

    public Iterable<Id> start(Database.BatchableContext bc) {
        return recordIds;
    }

    public void execute(Database.BatchableContext bc, List<Id> scope) {
        try {
            String requiredIds = String.join(scope, ',');
            String params = '<recordIds>' + requiredIds + '</recordIds>';
            String integrationEmail = settings.Integration_User_Email__c;
            if(String.isNotBlank(integrationEmail)) {
                params += '<email>' + integrationEmail + '</email>';
            }
            String rootLink = settings.Documents_Root_Link__c;
            params += '<rootLink>' + DocuSignAPI.escapeXml(rootLink) + '</rootLink>';
            DocuSignAPI.startWorkflowWithParams(workflowName, params);
            processed += scope.size();
        } catch (Exception e) {
            errors++;
            System.debug(LoggingLevel.ERROR, 'Error starting DocuSign workflow "' + workflowName + '" for records ' + String.join(scope, ',') + ': ' + e.getMessage());
        }

    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'BREGStartDocusignWorkflowBatch completed for workflow: ' + workflowName + ' - Processed: ' + processed + ', Errors: ' + errors);
    }

}