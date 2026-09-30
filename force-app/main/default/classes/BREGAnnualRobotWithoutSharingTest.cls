@IsTest
private class BREGAnnualRobotWithoutSharingTest {
    @TestSetup
    private static void setupData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFormConfigurations();
    }

    @IsTest
    static void queryCasesAndUpdateCaseStatusThroughWithoutSharingService() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30010-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('WithoutSharing');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());
        BREGAnnualRobotTestHelper.AnnualCaseInput input = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual.Id,
            annual.breg_Filing_Year__c,
            'WI-WS-1',
            true,
            null,
            true
        );
        Case annualCase = BREGAnnualRobotTestHelper.createAnnualCase(input);

        List<Case> queriedCases = BREGAnnualRobotWithoutSharing.queryCases(new Set<Id>{ annualCase.Id });
        System.assertEquals(1, queriedCases.size(), 'The without-sharing service should retrieve the annual case by Id.');

        List<Case> casesToUpdate = new List<Case>{ new Case(Id = annualCase.Id, breg_Annual_Robot_Status__c = 'Completed') };
        BREGAnnualRobotWithoutSharing.updateCasesSafely(casesToUpdate);

        Case updatedCase = [SELECT breg_Annual_Robot_Status__c FROM Case WHERE Id = :annualCase.Id];
        System.assertEquals('Completed', updatedCase.breg_Annual_Robot_Status__c, 'The without-sharing service should update the case robot status.');
    }
}