public inherited sharing class UserRecordAccessSelector extends fflib_SObjectSelector {

    public static final UserRecordAccessSelector INSTANCE = (UserRecordAccessSelector)fflibe_Applicationimpl.SELECTOR.newInstance(UserRecordAccess.getSObjectType());

    public UserRecordAccessSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            UserRecordAccess.HasEditAccess,
            UserRecordAccess.MaxAccessLevel,
            UserRecordAccess.RecordId
        };
    }

    public Schema.SObjectType getSObjectType() {
        return UserRecordAccess.getSObjectType();
    }

    public UserRecordAccess[] getAccessToRecords(Id userId, Set<Id> recordIds) {
        return Database.query(
            newQueryFactory()
                .setCondition('UserId = :userId AND RecordId IN :recordIds')
                .toSOQL()
        );
    }

    public override String getOrderBy() {
        return 'RecordId';
    }

}