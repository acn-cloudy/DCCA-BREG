trigger CaseTeamAssignmentTrigger on CaseTeamAssignment__c (before insert, after insert, before update, after delete) {
    fflib_SObjectDomain.triggerHandler(CaseTeamAssignmentHandler.class);
}