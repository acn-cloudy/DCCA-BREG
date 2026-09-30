@IsTest
private class CaseTeamAssignmentHandlerTest {
    
    @IsTest
    static void test_onBeforeInsert() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        CaseTeamAssignmentService mockCaseTeamAssignmentService = (CaseTeamAssignmentService)mocks.mock(CaseTeamAssignmentService.class);
        fflibe_Applicationimpl.SERVICE.setMock(CaseTeamAssignmentService.class, mockCaseTeamAssignmentService);
        CaseTeamAssignmentsSelector mockCaseTeamAssignmentsSelector = (CaseTeamAssignmentsSelector)mocks.mock(CaseTeamAssignmentsSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamAssignment__c.sObjectType, mockCaseTeamAssignmentsSelector);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);

        CaseTeamAssignment__c[] ctas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(

            ),
            new CaseTeamAssignment__c(

            ),
            new CaseTeamAssignment__c(

            )
        };

        CaseTeamAssignmentHandler ctaHandler = new CaseTeamAssignmentHandler(ctas);
        Test.startTest();
        ctaHandler.onBeforeInsert();
        Test.stopTest();
        
        ((CaseTeamAssignmentService)mocks.verify(mockCaseTeamAssignmentService, 1)).validateCTAs((CaseTeamAssignment__c[])fflib_Match.eqList(ctas), (Map<Id, CaseTeamAssignment__c>)fflib_Match.isNull());
        
    }
    @IsTest
    static void test_onAfterInsert() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        CaseTeamAssignmentService mockCaseTeamAssignmentService = (CaseTeamAssignmentService)mocks.mock(CaseTeamAssignmentService.class);
        fflibe_Applicationimpl.SERVICE.setMock(CaseTeamAssignmentService.class, mockCaseTeamAssignmentService);
        CaseTeamAssignmentsSelector mockCaseTeamAssignmentsSelector = (CaseTeamAssignmentsSelector)mocks.mock(CaseTeamAssignmentsSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamAssignment__c.sObjectType, mockCaseTeamAssignmentsSelector);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);

        User testUser = new User(
            IsActive = true,
            Id = fflib_IDGenerator.generate(User.SObjectType)
        );
        Case testCase = new Case(
            OwnerId = fflib_IDGenerator.generate(User.SObjectType)
        );
        CaseTeamAssignment__c[] ctas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__c = testCase.OwnerId
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id
            )
        };

        mocks.startStubbing();
        mocks.when(mockCaseTeamAssignmentsSelector.selectSObjectsById((Set<Id>)fflib_Match.anyObject())).thenReturn(ctas);
        mocks.stopStubbing();

        CaseTeamAssignmentHandler ctaHandler = new CaseTeamAssignmentHandler(ctas);

        Test.startTest();
        ctaHandler.onAfterInsert();
        Test.stopTest();

    }
    @IsTest
    static void test_onBeforeUpdate() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        CaseTeamAssignmentService mockCaseTeamAssignmentService = (CaseTeamAssignmentService)mocks.mock(CaseTeamAssignmentService.class);
        fflibe_Applicationimpl.SERVICE.setMock(CaseTeamAssignmentService.class, mockCaseTeamAssignmentService);
        CaseTeamAssignmentsSelector mockCaseTeamAssignmentsSelector = (CaseTeamAssignmentsSelector)mocks.mock(CaseTeamAssignmentsSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamAssignment__c.sObjectType, mockCaseTeamAssignmentsSelector);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);

        User testUser = new User(
            IsActive = true,
            Id = fflib_IDGenerator.generate(User.SObjectType)
        );
        Case testCase = new Case(
            OwnerId = fflib_IDGenerator.generate(User.SObjectType)
        );
        CaseTeamAssignment__c[] ctas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__c = testCase.OwnerId
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id
            )
        };

        mocks.startStubbing();
        mocks.when(mockCaseTeamAssignmentsSelector.selectSObjectsById((Set<Id>)fflib_Match.anyObject())).thenReturn(ctas);
        mocks.stopStubbing();

        Map<Id, CaseTeamAssignment__c> oldMap = new Map<Id, CaseTeamAssignment__c>(ctas);
        CaseTeamAssignmentHandler ctaHandler = new CaseTeamAssignmentHandler(ctas);
        ctaHandler.ExistingRecords = oldMap;

        Test.startTest();
        ctaHandler.onBeforeUpdate(ctaHandler.ExistingRecords);
        Test.stopTest();

        ((CaseTeamAssignmentService)mocks.verify(mockCaseTeamAssignmentService, 1)).validateCTAs((CaseTeamAssignment__c[])fflib_Match.eqList(ctas), (Map<Id, CaseTeamAssignment__c>)fflib_Match.isNotNull());

    }
    @IsTest
    static void test_onAfterUpdate() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        CaseTeamAssignmentService mockCaseTeamAssignmentService = (CaseTeamAssignmentService)mocks.mock(CaseTeamAssignmentService.class);
        fflibe_Applicationimpl.SERVICE.setMock(CaseTeamAssignmentService.class, mockCaseTeamAssignmentService);
        CaseTeamAssignmentsSelector mockCaseTeamAssignmentsSelector = (CaseTeamAssignmentsSelector)mocks.mock(CaseTeamAssignmentsSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamAssignment__c.sObjectType, mockCaseTeamAssignmentsSelector);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);

        User testUser = new User(
            IsActive = true,
            Id = fflib_IDGenerator.generate(User.SObjectType)
        );
        Case testCase = new Case(
            OwnerId = fflib_IDGenerator.generate(User.SObjectType)
        );
        Id[] ctaIds = new Id[]{
            fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
            fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
            fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType)
        };
        CaseTeamAssignment__c[] ctas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(
                Id = ctaIds[0],
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Read'
            ),
            new CaseTeamAssignment__c(
                Id = ctaIds[1],
                Case__r = testCase,
                User__c = testCase.OwnerId,
                Access__c = 'Read'
            ),
            new CaseTeamAssignment__c(
                Id = ctaIds[2],
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Read'
            )
        };
        CaseTeamAssignment__c[] oldCtas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(
                Id = ctaIds[0],
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Edit'
            ),
            new CaseTeamAssignment__c(
                Id = ctaIds[1],
                Case__r = testCase,
                User__c = testCase.OwnerId,
                Access__c = 'Read'
            ),
            new CaseTeamAssignment__c(
                Id = ctaIds[2],
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Read'
            )
        };

        mocks.startStubbing();
        mocks.when(mockCaseTeamAssignmentsSelector.selectSObjectsById((Set<Id>)fflib_Match.anyObject())).thenReturn(ctas);
        mocks.stopStubbing();

        Map<Id, CaseTeamAssignment__c> oldMap = new Map<Id, CaseTeamAssignment__c>(oldCtas);
        CaseTeamAssignmentHandler ctaHandler = new CaseTeamAssignmentHandler(ctas);
        ctaHandler.ExistingRecords = oldMap;

        Test.startTest();
        ctaHandler.onAfterUpdate(ctaHandler.ExistingRecords);
        Test.stopTest();

    }
    @IsTest
    static void test_onAfterDelete() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        CaseTeamAssignmentService mockCaseTeamAssignmentService = (CaseTeamAssignmentService)mocks.mock(CaseTeamAssignmentService.class);
        fflibe_Applicationimpl.SERVICE.setMock(CaseTeamAssignmentService.class, mockCaseTeamAssignmentService);
        CaseTeamAssignmentsSelector mockCaseTeamAssignmentsSelector = (CaseTeamAssignmentsSelector)mocks.mock(CaseTeamAssignmentsSelector.class);
        fflibe_Applicationimpl.SELECTOR.setMock(CaseTeamAssignment__c.sObjectType, mockCaseTeamAssignmentsSelector);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fflibe_Applicationimpl.UOW.setMock(mockUow);

        User testUser = new User(
            IsActive = true,
            Id = fflib_IDGenerator.generate(User.SObjectType)
        );
        Case testCase = new Case(
            OwnerId = fflib_IDGenerator.generate(User.SObjectType)
        );
        CaseTeamAssignment__c[] ctas = new CaseTeamAssignment__c[]{
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Read'
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__c = testCase.OwnerId,
                Access__c = 'Read'
            ),
            new CaseTeamAssignment__c(
                Id = fflib_IDGenerator.generate(CaseTeamAssignment__c.SObjectType),
                Case__r = testCase,
                User__r = testUser,
                User__c = testUser.Id,
                Access__c = 'Read'
            )
        };

        mocks.startStubbing();
        mocks.when(mockCaseTeamAssignmentsSelector.selectSObjectsById((Set<Id>)fflib_Match.anyObject())).thenReturn(ctas);
        mocks.stopStubbing();

        Map<Id, CaseTeamAssignment__c> oldMap = new Map<Id, CaseTeamAssignment__c>(ctas);
        CaseTeamAssignmentHandler ctaHandler = new CaseTeamAssignmentHandler(ctas);
        ctaHandler.ExistingRecords = oldMap;

        Test.startTest();
        ctaHandler.onAfterDelete(ctaHandler.ExistingRecords);
        Test.stopTest();

        ((CaseTeamAssignmentService)mocks.verify(mockCaseTeamAssignmentService, 1)).removeShareRecords((CaseTeamAssignment__c[])fflib_Match.anyList(), (fflib_SObjectUnitOfWork)fflib_Match.anyObject());
    }
    
}