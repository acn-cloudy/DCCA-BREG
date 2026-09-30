public inherited sharing class CaseTeamMemberService {

    public static final CaseTeamMemberService INSTANCE = (CaseTeamMemberService)fflibe_Applicationimpl.SERVICE.newInstance(CaseTeamMemberService.class);

    public void futureDeleteCaseTeamMembers(Set<Id> userIds) {
        if (!userIds.isEmpty()) {
            CaseTeamMemberService.deleteCaseTeamMembers(userIds);
        }
    }

    @future 
    static void deleteCaseTeamMembers(Set<Id> userIds) {
        fflib_SObjectUnitOfWork uow = (fflib_SObjectUnitOfWork)fflibe_ApplicationImpl.UOW.newInstance(new SObjectType[] { CaseTeamMember__c.getSObjectType() });
        uow.registerDeleted(CaseTeamMembersSelector.INSTANCE.selectByUserIds(userIds));
        uow.commitWork();
    }

}