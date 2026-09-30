public without sharing class CaseTeamMemberAssignmentEmailController {
    
    public Id recordId { get; set; }

    private CaseTeamAssignment__c caseAssignment {
        get {
            try{
            if (caseAssignment == null) {
                //String className, String methodName, String message, String parameters, String stackTrace, Integer logLevel
                EmailAlertTrigger__c eat = (EmailAlertTrigger__c)EmailAlertTriggersSelector.INSTANCE.selectSObjectsById(new Set<Id>{recordId})[0];
                caseAssignment = (CaseTeamAssignment__c)CaseTeamAssignmentsSelector.INSTANCE.selectSObjectsById(new Set<Id>{eat.RelatedRecordId__c})[0];
            }} catch(Exception e) {
                CustomLogger.logException(e, 'CaseTeamMemberAssignmentEmailController', 'caseAssignment', recordId);
            }
            return caseAssignment;
        } set;
    }

    public String getCaseNumber() {
        return caseAssignment.Case__r.CaseNumber;
    }
    public String getAccount() {
        return caseAssignment.Case__r.AccountId;
    }
    public String getType() {
        return caseAssignment.Case__r.Type;
    }
    public String getUrl() {
        return Url.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Case__c/' + caseAssignment.Case__c + '/view';
    }

}