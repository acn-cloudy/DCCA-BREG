public inherited sharing class CaseTeamMembersSelector extends fflib_SObjectSelector {

    public static final CaseTeamMembersSelector INSTANCE = (CaseTeamMembersSelector)fflibe_Applicationimpl.SELECTOR.newInstance(CaseTeamMember__c.getSObjectType());

    public CaseTeamMembersSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            CaseTeamMember__c.Id
        };
    }

    public Schema.SObjectType getSObjectType() {
        return CaseTeamMember__c.getSObjectType();
    }

    // tested by CaseTeamMemberServiceTest.testFutureDeleteCaseTeamMembers()
    public CaseTeamMember__c[] selectByUserIds(Set<Id> userIds) {
        return Database.query(
            newQueryFactory()
                .setCondition('User__c IN :userIds')
                .toSOQL()   
        );
    }

}