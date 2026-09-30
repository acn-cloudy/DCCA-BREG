@IsTest
private class BREGAnnualRobotEngineTest {
    @TestSetup
    private static void setupData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFormConfigurations();
    }

    @IsTest
    static void expandWithEligibleEntityAnnualCasesAddsRelatedCases() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30001-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('Expand');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput olderInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2025.Id,
            annual2025.breg_Filing_Year__c,
            'WI-E-1',
            true,
            null,
            true
        );
        Case olderCase = BREGAnnualRobotTestHelper.createAnnualCase(olderInput);

        BREGAnnualRobotTestHelper.AnnualCaseInput newerInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2026.Id,
            annual2026.breg_Filing_Year__c,
            'WI-E-2',
            true,
            null,
            true
        );
        Case newerCase = BREGAnnualRobotTestHelper.createAnnualCase(newerInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ newerCase.Id });
        List<Case> expandedCases = BREGAnnualRobotEngine.expandWithEligibleEntityAnnualCases(loadedCases);

        Set<Id> expandedIds = new Set<Id>();
        for (Case caseRecord : expandedCases) {
            expandedIds.add(caseRecord.Id);
        }

        System.assertEquals(2, expandedCases.size(), 'Expansion should include the related eligible annual case for the same entity.');
        System.assert(expandedIds.contains(olderCase.Id), 'Expanded set should contain the related older case.');
        System.assert(expandedIds.contains(newerCase.Id), 'Expanded set should keep the original case.');
    }

    @IsTest
    static void hasEarlierAnnualUnresolvedBlockReturnsTrueForRoutedManualOlderCase() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30002-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('Unresolved');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput olderInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2025.Id,
            annual2025.breg_Filing_Year__c,
            'WI-U-1',
            false,
            'Routed for manual',
            true
        );
        BREGAnnualRobotTestHelper.createAnnualCase(olderInput);

        BREGAnnualRobotTestHelper.AnnualCaseInput currentInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2026.Id,
            annual2026.breg_Filing_Year__c,
            'WI-U-2',
            true,
            null,
            true
        );
        Case currentCase = BREGAnnualRobotTestHelper.createAnnualCase(currentInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ currentCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        Boolean isBlocked = BREGAnnualRobotRules.hasEarlierAnnualUnresolvedBlock(
            loadedCases[0],
            context,
            new List<BREGAnnualRobotRules.CaseOutcomePlan>()
        );

        System.assertEquals(true, isBlocked, 'Later annual must be blocked when earlier annual is already routed for manual.');
    }

    @IsTest
    static void hasEarlierAnnualQueueBlockReturnsTrueForPendingOlderCase() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30003-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('QueueBlock');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput olderInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2025.Id,
            annual2025.breg_Filing_Year__c,
            'WI-Q-1',
            true,
            null,
            true
        );
        BREGAnnualRobotTestHelper.createAnnualCase(olderInput);

        BREGAnnualRobotTestHelper.AnnualCaseInput currentInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2026.Id,
            annual2026.breg_Filing_Year__c,
            'WI-Q-2',
            true,
            null,
            true
        );
        Case currentCase = BREGAnnualRobotTestHelper.createAnnualCase(currentInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ currentCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        Boolean isQueueBlocked = BREGAnnualRobotRules.hasEarlierAnnualQueueBlock(
            loadedCases[0],
            context,
            new List<BREGAnnualRobotRules.CaseOutcomePlan>()
        );

        System.assertEquals(true, isQueueBlocked, 'Later annual must be queued while earlier annual is still unresolved and not final-blocked.');
    }

    @IsTest
    static void hasEarlierAnnualQueueBlockReturnsTrueWhenOlderCaseIsStillUnresolved() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30004-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('StillUnresolved');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput olderInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2025.Id,
            annual2025.breg_Filing_Year__c,
            'WI-N-1',
            true,
            null,
            true
        );
        BREGAnnualRobotTestHelper.createAnnualCase(olderInput);

        BREGAnnualRobotTestHelper.AnnualCaseInput currentInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2026.Id,
            annual2026.breg_Filing_Year__c,
            'WI-N-2',
            true,
            null,
            true
        );
        Case currentCase = BREGAnnualRobotTestHelper.createAnnualCase(currentInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ currentCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        Boolean isQueueBlocked = BREGAnnualRobotRules.hasEarlierAnnualQueueBlock(
            loadedCases[0],
            context,
            new List<BREGAnnualRobotRules.CaseOutcomePlan>()
        );

        System.assertEquals(true, isQueueBlocked, 'A newer annual case should be queued when an earlier annual case is still unresolved and eligible for annual robot.');
    }

    @IsTest
    static void hasEarlierAnnualUnresolvedBlockReturnsTrueWhenOlderCaseIsNotEligible() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30005-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('ManualBlock');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput olderInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2025.Id,
            annual2025.breg_Filing_Year__c,
            'WI-M-1',
            false,
            null,
            true
        );
        BREGAnnualRobotTestHelper.createAnnualCase(olderInput);

        BREGAnnualRobotTestHelper.AnnualCaseInput currentInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annual2026.Id,
            annual2026.breg_Filing_Year__c,
            'WI-M-2',
            true,
            null,
            true
        );
        Case currentCase = BREGAnnualRobotTestHelper.createAnnualCase(currentInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ currentCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        Boolean isManualBlocked = BREGAnnualRobotRules.hasEarlierAnnualUnresolvedBlock(
            loadedCases[0],
            context,
            new List<BREGAnnualRobotRules.CaseOutcomePlan>()
        );

        System.assertEquals(true, isManualBlocked, 'A newer annual case should be routed for manual when the previous-year annual case is unresolved but not eligible for annual robot.');
    }

    @IsTest
    static void hasEarlierAnnualUnresolvedBlockReturnsTrueForPriorUnresolvedAnnualWithoutCase() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('30006-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('PriorAnnualOnly');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annual2025 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year() - 1);
        annual2025.breg_Status__c = 'D';
        update annual2025;
        breg_Annual__c annual2026 = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        BREGAnnualRobotTestHelper.AnnualCaseInput currentInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity, contactRecord, annualFormId, annual2026.Id, annual2026.breg_Filing_Year__c, 'WI-M-3', true, null, true
        );
        Case currentCase = BREGAnnualRobotTestHelper.createAnnualCase(currentInput);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ currentCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);

        System.assertEquals(
            true,
            BREGAnnualRobotRules.hasEarlierAnnualUnresolvedBlock(loadedCases[0], context, new List<BREGAnnualRobotRules.CaseOutcomePlan>()),
            'A newer annual case must be blocked when an earlier unresolved annual exists without a related case.'
        );
    }
}