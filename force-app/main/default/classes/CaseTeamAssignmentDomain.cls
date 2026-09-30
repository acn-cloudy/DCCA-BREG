public inherited sharing class CaseTeamAssignmentDomain extends fflib_SObjectDomain {

    /*********************
    * DEFAULT DOMAIN CODE
    *********************/

    CaseTeamAssignment__c[] castedRecords { get { return (CaseTeamAssignment__c[])Records; } }

    public static CaseTeamAssignmentDomain newInstance(CaseTeamAssignment__c[] records) {
        return (CaseTeamAssignmentDomain)fflibe_Applicationimpl.DOMAIN.newInstance(records);
    }

    public CaseTeamAssignmentDomain(CaseTeamAssignment__c[] records) {
        super(records);
    }

    public class Constructor implements fflib_IDomainConstructor {
        public fflib_SObjects construct(List<Object> objectList) {
            return new CaseTeamAssignmentDomain((List<SObject>) objectList);
        }
    }


    /*********************
    * DOMAIN METHODS
    *********************/

    public Map<String, Id[]> getRoleToUserIdsMap() {
        Map<String, Id[]> roleToUserIdMap = new Map<String, Id[]>();
        for (CaseTeamAssignment__c cta : castedRecords) {
            if (!roleToUserIdMap.containsKey(cta.Role__c)) {
                roleToUserIdMap.put(cta.Role__c, new List<Id>());
            }
            roleToUserIdMap.get(cta.Role__c).add(cta.User__c);
        }
        return roleToUserIdMap;
    }

}