public with sharing class BREGStartDocusignWorkflowInvocable {
    public class StartDocusignWorkflowInput {
        @InvocableVariable(required=true)
        public List<Id> ids;

        @InvocableVariable(required=true)
        public String startedBy;

        @InvocableVariable(required=true)
        public String workflowName;

        @InvocableVariable(required=true)
        public List<Id> logIds;
    }

    @InvocableMethod(label='Start DocuSign Workflow')
    public static void startDocusignWorkflow(List<StartDocusignWorkflowInput> flowInputs) {
        if (flowInputs == null || flowInputs.isEmpty()) {
            return;
        }

        for (StartDocusignWorkflowInput flowInput : flowInputs) {
            if (flowInput == null) {
                continue;
            }

            BREGStartDocusignWorkflow.startDocusignWorkflow(
                flowInput.ids,
                flowInput.startedBy,
                flowInput.workflowName,
                flowInput.logIds
            );
        }
    }
}