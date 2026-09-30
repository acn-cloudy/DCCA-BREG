public inherited sharing class CaseSharesSelector extends fflib_SObjectSelector {

    public static final CaseSharesSelector INSTANCE = (CaseSharesSelector)fflibe_Applicationimpl.SELECTOR.newInstance(CaseShare.getSObjectType());

    public CaseSharesSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            CaseShare.Id,
            CaseShare.CaseId,
            CaseShare.UserOrGroupId
        };
    }

    public Schema.SObjectType getSObjectType() {
        return CaseShare.getSObjectType();
    }

    public CaseShare[] getSharesByParentAndOwnerIds(Set<Id> parentIds, Set<Id> userIds) {
        return Database.query(
            newQueryFactory()
                .selectField('Case.OwnerId')
                .setCondition('CaseId IN :parentIds AND UserOrGroupId IN :userIds')
                .toSOQL()
        );
    }

}