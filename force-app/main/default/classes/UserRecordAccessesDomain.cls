public inherited sharing class UserRecordAccessesDomain extends fflib_SObjectDomain {

    /*********************
    * DEFAULT DOMAIN CODE
    *********************/

    UserRecordAccess[] castedRecords;

    public static UserRecordAccessesDomain newInstance(UserRecordAccess[] records) {
        return (UserRecordAccessesDomain)fflibe_Applicationimpl.DOMAIN.newInstance(records, UserRecordAccess.getSObjectType());
    }

    public UserRecordAccessesDomain(UserRecordAccess[] records) {
        super(records);
        this.castedRecords = records;
    }

    public class Constructor implements fflib_IDomainConstructor {
        public fflib_SObjects construct(List<Object> objectList) {
            return new UserRecordAccessesDomain((List<SObject>) objectList);
        }
    }


    /*********************
    * DOMAIN METHODS
    *********************/

    public Map<Id, String> getRecordIdToMaxAccessLevelMap() {
        Map<Id, String> ret = new Map<Id, String>();
        for (UserRecordAccess ura : castedRecords) {
            ret.put(ura.RecordId, ura.MaxAccessLevel);
        }
        return ret;
    }

}