public without sharing class BREGCaseLifecycleHandler {
    public class FlowInput {
        @InvocableVariable(label='Case')
        public Case caseRecord;

        @InvocableVariable(
            label='Action'
            description='Action to be executed. Possible values: "updateCaseWithAssignmentRules; checkFormCode"'
            required=true
        )
        public String action;
    }
    public class FlowOutput {
        @InvocableVariable(label='Case')
        public Case caseRecord;

        @InvocableVariable(label='Is NBR Form' description='Indicates if the case is a NBR form')
        public Boolean isNBRForm;

        @InvocableVariable(label='Is TNTMSM Form' description='Indicates if the case is a TNTMSM form')
        public Boolean isTNTMSMForm;

        @InvocableVariable(label='Is Name Reservation Form' description='Indicates if the case is a Name Reservation form')
        public Boolean isNameReservationForm;
    }

    @InvocableMethod(
        label='CaseLifecycleHandler Execute Action from Flow'
        description='Executes methods based on the input provided from Flow'
        category='Case'
    )
    public static List<FlowOutput> executeActionFromFlow(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            System.debug(input);
            try {
                FlowOutput output = new FlowOutput();
                if (input.action == 'updateCaseWithAssignmentRules') {
                    output.caseRecord = updateCaseWithAssignmentRules(input.caseRecord);
                } else if (input.action == 'checkFormCode') {
                    output.isNBRForm = BREGUtils.isNBRForm(input.caseRecord.breg_Form_Code__c);
                    output.isTNTMSMForm = BREGUtils.isTNTMSMForm(input.caseRecord.breg_Form_Code__c);
                    output.isNameReservationForm = BREGUtils.isNameReservationForm(input.caseRecord.breg_Form_Code__c);
                } else {
                    throw new IllegalArgumentException('Invalid action: ' + input.action);
                }
                System.debug(output);
                outputs.add(output);
            } catch (Exception e) {
                System.debug(e.getMessage());
                throw new CustomException(e.getMessage());
            }
        }
        return outputs;
    }

    public static Case updateCaseWithAssignmentRules(Case caseRecord) {
        return updateCaseWithAssignmentRules(new List<Case>{ caseRecord })[0];
    }
    public static List<Case> updateCaseWithAssignmentRules(List<Case> cases) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;
        for (Case c : cases) {
            c.setOptions(dmlOpts);
        }
        update cases;
        return cases;
    }

    public class CustomException extends Exception {
    }
}