public inherited sharing class CaseTeamAssignmentsSelector extends fflib_SObjectSelector {

    public static final CaseTeamAssignmentsSelector INSTANCE = (CaseTeamAssignmentsSelector)fflibe_Applicationimpl.SELECTOR.newInstance(CaseTeamAssignment__c.getSObjectType());

    public CaseTeamAssignmentsSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            CaseTeamAssignment__c.Id,
            CaseTeamAssignment__c.Role__c,
            CaseTeamAssignment__c.Case__c,
            CaseTeamAssignment__c.User__c
        };
    }

    public Schema.SObjectType getSObjectType() {
        return CaseTeamAssignment__c.getSObjectType();
    }

    public override SObject[] selectSObjectsById(Set<Id> recordIds) {
        return Database.query(
            newQueryFactory()
                .selectField('Case__r.OwnerId')
                .selectField('Case__r.Account.Name')
                .selectField('User__r.IsActive')
                .setCondition('Id IN :recordIds')
                .toSOQL()
        );
    }

    public CaseTeamAssignment__c[] selectByUserAndCase(Set<Id> userIds, Set<Id> caseIds) {
        return Database.query(
            newQueryFactory()
                .setCondition('User__c IN :userIds AND Case__c IN :caseIds')
                .toSOQL()
        );
    }

}