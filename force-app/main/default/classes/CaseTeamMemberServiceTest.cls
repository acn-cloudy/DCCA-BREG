@IsTest 
private class CaseTeamMemberServiceTest {
    
  @IsTest 
    static void testFutureDeleteCaseTeamMembers() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);
        CaseTeamMembersSelector mockCaseTeamMembersSelector = (CaseTeamMembersSelector)mocks.mock(CaseTeamMembersSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamMember__c.sObjectType, mockCaseTeamMembersSelector);
        CaseTeamMember__c[] newCtms = new CaseTeamMember__c[]{
            new CaseTeamMember__c(id = fflib_IDGenerator.generate(CaseTeamMember__c.sObjectType)),
            new CaseTeamMember__c(id = fflib_IDGenerator.generate(CaseTeamMember__c.sObjectType))
        };

        mocks.startStubbing();
        mocks.when(mockCaseTeamMembersSelector.selectByUserIds((set<id>)fflib_Match.anyObject())).thenReturn(newCtms);
        mocks.stopStubbing();

        Test.startTest();
        CaseTeamMemberService.INSTANCE.futureDeleteCaseTeamMembers(new Set<Id> { fflib_IDGenerator.generate(User.sObjectType), fflib_IDGenerator.generate(User.sObjectType) });
        Test.stopTest();
    }
    
}