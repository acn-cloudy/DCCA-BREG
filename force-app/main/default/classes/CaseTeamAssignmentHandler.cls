public without sharing class CaseTeamAssignmentHandler extends SObjectDomainTriggerHandler {

    CaseTeamAssignment__c[] castedRecords;

    public CaseTeamAssignmentHandler(CaseTeamAssignment__c[] records) {
        super(records, new SObjectType[] {
            CaseTeamAssignment__c.SObjectType,
            CaseShare.SObjectType
        });
        this.castedRecords = records;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new CaseTeamAssignmentHandler(sObjectList);
        }
    }


    /***********************************
     * TRIGGER CONTEXT METHOD OVERRIDES
     ************************************/

    // public override void onApplyDefaults() {}

    public override void onBeforeInsert() {
        CaseTeamAssignmentService.INSTANCE.validateCTAs(castedRecords, null);
    }

    public override void onAfterInsert() {
        CaseTeamAssignmentService.INSTANCE.addCaseShareRecords(getRecordsWhereUserIsNotCaseOwner(Records), unitOfWork);
    }

    public override void onBeforeUpdate(Map<Id,SObject> existingRecords) {
        CaseTeamAssignmentService.INSTANCE.validateCTAs(castedRecords, (Map<Id, CaseTeamAssignment__c>) existingRecords);
    }

    public override void onAfterUpdate(Map<Id,SObject> existingRecords) {
        CaseTeamAssignmentService.INSTANCE.addCaseShareRecords(getRecordsWhereUserIsNotCaseOwner(getChangedRecords(new Set<SObjectField>{CaseTeamAssignment__c.Access__c})), unitOfWork);
    }

    // public override void onBeforeDelete() {}

    public override void onAfterDelete(Map<Id, sObject> existing) {
        CaseTeamAssignmentService.INSTANCE.removeShareRecords(castedRecords, unitOfWork);
    }

    // public override void onAfterUndelete() {}


    /***********************************
     * CUSTOM DOMAIN METHODS
     ************************************/

    private CaseTeamAssignment__c[] getRecordsWhereUserIsNotCaseOwner(CaseTeamAssignment__c[] ctas) {
        Map<Id, CaseTeamAssignment__c> extendedRecords = new Map<Id, CaseTeamAssignment__c>( (CaseTeamAssignment__c[])CaseTeamAssignmentsSelector.INSTANCE.selectSObjectsById(SObjectUtil.getSetIds(ctas, 'Id')));
        CaseTeamAssignment__c[] filteredRecords = new List<CaseTeamAssignment__c>();
        for (CaseTeamAssignment__c cta : ctas) {
            if(cta.User__c != extendedRecords.get(cta.Id).Case__r.OwnerId && extendedRecords.get(cta.Id).User__r.IsActive) filteredRecords.add(cta);
        }
        return filteredRecords;
    } 

}
// TEST CLASS: CaseTeamAssignmentHandlerTest