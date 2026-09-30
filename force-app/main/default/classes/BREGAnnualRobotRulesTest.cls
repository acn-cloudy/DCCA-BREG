@IsTest
private class BREGAnnualRobotRulesTest {
    @TestSetup
    private static void setupData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFormConfigurations();
    }

    @IsTest
    static void buildOutcomePlansIncludesMappingErrorReason() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40001-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();

        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Case annualCase = new Case(
            Subject = 'Rules Mapping Error',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualFormId,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = 'WI-R-1',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = annualRecord.breg_Filing_Year__c,
            breg_Annual__c = annualRecord.Id,
            breg_Override_Payment__c = true
        );
        insert annualCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = annualCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Rules Mapping Error',
            breg_Mapping_Status__c = 'Error'
        );

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce a single outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Mapping error should route the case for manual filing.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Mapping_Error), 'Failure message should include mapping error reason.');
    }

    @IsTest
    static void buildOutcomePlansRoutesManualWhenEntityComparisonDiffExists() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40002-D1');
        entity.breg_Entity_Type__c = 'A2';
        entity.breg_Number_of_initial_members__c = 10;
        update entity;

        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Case annualCase = new Case(
            Subject = 'Rules Comparison Diff',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualFormId,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = 'WI-R-2',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = annualRecord.breg_Filing_Year__c,
            breg_Annual__c = annualRecord.Id,
            breg_Override_Payment__c = true,
            breg_Number_of_initial_members__c = 9
        );
        insert annualCase;
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Case should be routed for manual when case and entity values differ.');
        System.assert(plans[0].commentBody.contains('NumberOfInitialMembers'), 'Failure message should reference the differing field.');
    }

    @IsTest
    static void buildOutcomePlansAggregatesManyReasonsInSingleComment() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40003-D1');
        entity.breg_Entity_Status__c = 'Dissolved (D)';
        entity.breg_Bounced_Check__c = true;
        entity.breg_BRIM_CRA_FL__c = true;
        entity.breg_Formation_State__c = 'HI';
        entity.breg_Registrant_Address__Street__s = '123 Main St';
        entity.breg_Registrant_Address__City__s = 'Honolulu';
        entity.breg_Registrant_Address__StateCode__s = 'HI';
        entity.breg_Registrant_Address__PostalCode__s = '96813';
        entity.breg_Registrant_Address__CountryCode__s = 'US';
        update entity;

        Account agentAccount = new Account(
            Name = 'Rules Dense Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Account__c = agentAccount.Id,
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Agent',
                breg_Type__c = 'Entity',
                breg_Address__Street__s = '123 Main St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.today().addMonths(-1),
                breg_Status__c = 'A'
            ),
            new breg_Account_Affiliation__c(
                breg_Account__c = agentAccount.Id,
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Officer',
                breg_Type__c = 'Entity',
                breg_Address__Street__s = '123 Main St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.today().addMonths(-1),
                breg_Status__c = 'A'
            )
        };

        breg_Annual__c annualRecord = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'P',
            breg_Filing_Date__c = Date.today().addMonths(-4),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annualRecord;

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case annualCase = new Case(
            Subject = 'Rules Dense Failure Case',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = null,
            breg_Workitem_Number__c = 'WI-R-3',
            breg_Submission_Date__c = System.now().addDays(1),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year() + 1),
            breg_Annual__c = annualRecord.Id,
            breg_Override_Payment__c = false
        );
        insert annualCase;

        annualCase.breg_File__c = null;
        update annualCase;

        annualRecord.breg_Status__c = 'P';
        update annualRecord;

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should still produce one plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Dense failure case should route for manual.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Contact_Missing), 'Should include contact missing reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_File_Number_Missing), 'Should include file number reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Entity_Status_Invalid), 'Should include entity status reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Annual_Status_Invalid), 'Should include annual status reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Payment_Missing), 'Should include payment reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Agent_Is_Entity), 'Should include agent entity reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Entity_Affiliation), 'Should include entity affiliation reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Company_Is_Cra), 'Should include company is CRA reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Company_Bounced_Check), 'Should include bounced check reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Annual_Report_Year_Future), 'Should include annual report year reason.');
        System.assert(plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Submission_Date_Future), 'Should include submission date reason.');
    }

    @IsTest
    static void buildOutcomePlansAllowsCraAgentWhenTypeIsEntity() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40004-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account craAgentAccount = new Account(
            Name = 'Rules CRA Entity Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = true
        );
        insert craAgentAccount;

        insert createAgentAffiliation(entity.Id, craAgentAccount.Id, 'Entity');
        insert createDirectorAffiliations(entity.Id, 1);
        insert createRoleAffiliation(entity.Id, 'Officer', 'Individual');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules CRA Entity Allowed');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Completed', plans[0].robotStatus, 'Case should complete when CRA agent and public initial filing validations both pass.');
        System.assert(
            plans[0].commentBody == null || !plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Agent_Is_Entity),
            'CRA agent with Entity type should not fail agent validation.'
        );
    }

    @IsTest
    static void buildOutcomePlansBlocksEntityAgentWhenNotCra() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40005-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account nonCraAgentAccount = new Account(
            Name = 'Rules Entity Non CRA Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert nonCraAgentAccount;

        insert createAgentAffiliation(entity.Id, nonCraAgentAccount.Id, 'Entity');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules Entity Non CRA Blocked');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Entity non-CRA agent should fail validation and route for manual.');
        System.assert(
            plans[0].commentBody != null && plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Agent_Is_Entity),
            'Entity non-CRA agent should include agent entity reason.'
        );
    }

    @IsTest
    static void buildOutcomePlansRoutesManualWhenPublicInitialFilingMissing() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40006-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(
            Name = 'Rules Missing Document Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules Missing Public Initial Filing');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Missing public initial filing should route the case for manual filing.');
        /*System.assert(
            plans[0].commentBody != null && plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Public_Initial_Filing_Missing),
            'Failure message should include the public initial filing reason.'
        );*/
    }

    @IsTest
    static void buildOutcomePlansIncludesConflictingTransactionReason() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40006-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        breg_Form_Configuration__c conflictingForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE Name = 'DC-2'
            LIMIT 1
        ];
        conflictingForm.breg_Form_Code__c = 'DC-2';
        update conflictingForm;
        insert new Case(
            Subject = 'Rules Conflicting Transaction',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = conflictingForm.Id,
            breg_Form_Code__c = 'DC-2',
            breg_Submission_Date__c = System.now().addHours(-2)
        );

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules Conflicting Transaction');
        insert annualCase;

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'Conflicting transaction should route the case for manual filing.');
        System.assert(
            plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_Conflicting_Transaction),
            'Failure comment should include the conflicting transaction reason.'
        );
    }

    @IsTest
    static void buildOutcomePlansRoutesManualWhenDomesticProfitHasNoIndividualDirector() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40008-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(Name = 'Rules D1 Director Agent');
        insert agentAccount;
        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules D1 Missing Director');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'D1 entity with no individual director should route for manual.');
        System.assert(
            plans[0].commentBody != null && plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_D1_Individual_Director_Required),
            'Failure message should include the D1 individual director reason.'
        );
    }

    @IsTest
    static void buildOutcomePlansRoutesManualWhenDomesticNonProfitHasTooFewIndividualDirectors() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40009-D2');
        entity.breg_Entity_Type__c = 'D2';
        update entity;
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(Name = 'Rules D2 Director Agent');
        insert agentAccount;
        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');
        insert createDirectorAffiliations(entity.Id, 2);

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules D2 Too Few Directors');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Routed for manual', plans[0].robotStatus, 'D2 entity with fewer than 3 individual directors should route for manual.');
        System.assert(
            plans[0].commentBody != null && plans[0].commentBody.contains(System.Label.BREG_AnnualRobot_D2_Individual_Directors_Required),
            'Failure message should include the D2 individual director reason.'
        );
    }

    @IsTest
    static void buildOutcomePlansCompletesWhenDomesticNonProfitHasThreeIndividualDirectors() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40010-D2');
        entity.breg_Entity_Type__c = 'D2';
        update entity;
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(Name = 'Rules D2 Valid Director Agent');
        insert agentAccount;
        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');
        insert createDirectorAffiliations(entity.Id, 3);
        insert createRoleAffiliation(entity.Id, 'Officer', 'Individual');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules D2 Valid Directors');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Completed', plans[0].robotStatus, 'D2 entity with 3 individual directors should complete.');
    }

    @IsTest
    static void buildOutcomePlansCompletesWhenLimitedPartnershipHasEntityPartner() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40011-L6');
        entity.breg_Entity_Type__c = 'L6';
        update entity;
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(Name = 'Rules L6 Partner Agent');
        insert agentAccount;
        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');
        insert createRoleAffiliation(entity.Id, 'Partner', 'Entity');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules L6 Entity Partner');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(
            loadedCases,
            BREGAnnualRobotEngine.buildContext(loadedCases)
        );

        System.assertEquals('Completed', plans[0].robotStatus, 'L6 should accept a partner of any affiliation type.');
    }

    @IsTest
    static void buildOutcomePlansUsesLlcManagementModeForRequiredAffiliationRole() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40012-C5');
        entity.breg_Entity_Type__c = 'C5';
        update entity;
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(Name = 'Rules C5 Manager Agent');
        insert agentAccount;
        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');
        insert createRoleAffiliation(entity.Id, 'Manager', 'Entity');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules C5 Manager Managed');
        annualCase.breg_Is_Manager_Managed__c = true;
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(
            loadedCases,
            BREGAnnualRobotEngine.buildContext(loadedCases)
        );

        System.assertEquals('Completed', plans[0].robotStatus, 'Manager-managed C5 should require a manager, not a member.');
    }

    @IsTest
    static void buildOutcomePlansCompletesWhenPublicInitialFilingExists() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40007-D1');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(
            Name = 'Rules Valid Document Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert createAgentAffiliation(entity.Id, agentAccount.Id, 'Individual');
        insert createDirectorAffiliations(entity.Id, 1);
        insert createRoleAffiliation(entity.Id, 'Officer', 'Individual');

        Case annualCase = createBaselineAnnualCase(entity, annualRecord, annualFormId, 'Rules Public Initial Filing Present');
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);

        System.assertEquals(1, plans.size(), 'Single case should produce one outcome plan.');
        System.assertEquals('Completed', plans[0].robotStatus, 'Case should complete when a qualifying public initial filing exists.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Success_Message, plans[0].commentBody, 'Success path should keep the success message.');
    }

    @IsTest
    static void applyPlansUpdatesCaseAndCreatesComment() {
        Case caseRecord = new Case(
            Subject = 'Rules Apply Plan',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Code__c = 'ANN-DNP-1'
        );
        insert caseRecord;

        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = new List<BREGAnnualRobotRules.CaseOutcomePlan>{
            BREGAnnualRobotRules.createPlan(caseRecord.Id, null, BREGAnnualRobotRules.ROBOT_STATUS_ROUTED_FOR_MANUAL, 'Manual path reason')
        };

        BREGAnnualRobotRules.applyPlans(plans);

        Case updatedCase = [SELECT breg_Annual_Robot_Status__c, breg_Robot_Processed_DateTime__c FROM Case WHERE Id = :caseRecord.Id];
        CaseComment commentRecord = [SELECT CommentBody FROM CaseComment WHERE ParentId = :caseRecord.Id LIMIT 1];

        System.assertEquals('Routed for manual', updatedCase.breg_Annual_Robot_Status__c, 'applyPlans should update robot status from the outcome plan.');
        System.assertEquals(null, updatedCase.breg_Robot_Processed_DateTime__c, 'applyPlans should not stamp processed datetime for non-completed status.');
        System.assertEquals('Manual path reason', commentRecord.CommentBody, 'applyPlans should insert the exact comment body from plan.');
    }

    @IsTest
    static void finalizeSuccessPlansSkipsCalloutAndEntityExtractionWorksInTest() {
        Case caseRecord = new Case(
            Subject = 'Rules Finalize Success',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Code__c = 'ANN-DNP-1'
        );
        insert caseRecord;

        Account entity = BREGAnnualRobotTestHelper.prepareEntity('40002-D1');

        BREGAnnualRobotRules.CaseOutcomePlan successPlan = BREGAnnualRobotRules.createPlan(
            caseRecord.Id,
            entity.Id,
            BREGAnnualRobotRules.ROBOT_STATUS_COMPLETED,
            'Success comment'
        );
        BREGAnnualRobotRules.CaseOutcomePlan routedPlan = BREGAnnualRobotRules.createPlan(
            caseRecord.Id,
            null,
            BREGAnnualRobotRules.ROBOT_STATUS_ROUTED_FOR_MANUAL,
            'Manual comment'
        );

        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = new List<BREGAnnualRobotRules.CaseOutcomePlan>{ successPlan, routedPlan };

        Test.startTest();
        BREGAnnualRobotRules.finalizeSuccessPlans(plans);
        Test.stopTest();

        System.assertEquals('Completed', successPlan.robotStatus, 'Success status should remain unchanged in tests when callout path is skipped.');
        System.assertEquals('Success comment', successPlan.commentBody, 'Success comment should remain unchanged in tests.');

        Set<Id> successfulEntityIds = BREGAnnualRobotRules.getSuccessfulEntityIds(plans);
        System.assertEquals(1, successfulEntityIds.size(), 'Only completed plans with entity id should be returned.');
        System.assert(successfulEntityIds.contains(entity.Id), 'Returned successful entity set should contain the completed plan entity.');
    }

    private static Case createBaselineAnnualCase(Account entity, breg_Annual__c annualRecord, Id annualFormId, String subject) {
        Contact caseContact = new Contact(LastName = subject + ' Contact', AccountId = entity.Id);
        insert caseContact;

        Account entityRecord = [
            SELECT Name, breg_Entity_Type__c, breg_Purpose__c, breg_Number_of_initial_members__c,
                   breg_Membership_Fees_Received__c, breg_Number_of_Shareholders__c,
                   BillingStreet, BillingCity, BillingStateCode, BillingPostalCode, BillingCountryCode,
                   breg_Billing_Address_Street_2__c, breg_Mailing_Address__Street__s,
                   breg_Mailing_Address_Street_2__c, breg_Mailing_Address__City__s,
                   breg_Mailing_Address__StateCode__s, breg_Mailing_Address__CountryCode__s,
                   breg_Mailing_Address__PostalCode__s
            FROM Account
            WHERE Id = :entity.Id
        ];

        return new Case(
            Subject = subject,
            Status = 'Received',
            Origin = 'Web',
            ContactId = caseContact.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualFormId,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = 'WI-NO-BASE-01',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Effective_Date__c = Date.today(),
            breg_Annual_Report_Filing_Year__c = annualRecord.breg_Filing_Year__c,
            breg_Annual__c = annualRecord.Id,
            breg_Override_Payment__c = true,
            breg_Name_of_the_Entity__c = entityRecord.Name,
            breg_Entity_Type__c = entityRecord.breg_Entity_Type__c,
            breg_Entity_Nature_Of_Business__c = entityRecord.breg_Purpose__c,
            breg_Number_of_initial_members__c = entityRecord.breg_Number_of_initial_members__c,
            breg_Membership_Fees_Received__c = entityRecord.breg_Membership_Fees_Received__c,
            breg_Number_of_Shareholders__c = entityRecord.breg_Number_of_Shareholders__c,
            breg_Mailing_Address__Street__s = entityRecord.breg_Mailing_Address__Street__s,
            breg_Mailing_Address_Number_and_Street_2__c = entityRecord.breg_Mailing_Address_Street_2__c,
            breg_Mailing_Address__City__s = entityRecord.breg_Mailing_Address__City__s,
            breg_Mailing_Address__StateCode__s = entityRecord.breg_Mailing_Address__StateCode__s,
            breg_Mailing_Address__CountryCode__s = entityRecord.breg_Mailing_Address__CountryCode__s,
            breg_Mailing_Address__PostalCode__s = entityRecord.breg_Mailing_Address__PostalCode__s,
            breg_Company_Address__Street__s = entityRecord.BillingStreet,
            breg_Company_Address_Street2__c = entityRecord.breg_Billing_Address_Street_2__c,
            breg_Company_Address__City__s = entityRecord.BillingCity,
            breg_Company_Address__StateCode__s = entityRecord.BillingStateCode,
            breg_Company_Address__CountryCode__s = entityRecord.BillingCountryCode,
            breg_Company_Address__PostalCode__s = entityRecord.BillingPostalCode
        );
    }

    private static breg_Account_Affiliation__c createAgentAffiliation(Id entityId, Id agentAccountId, String typeValue) {
        return new breg_Account_Affiliation__c(
            breg_Account__c = agentAccountId,
            breg_Entity__c = entityId,
            breg_Role__c = 'Agent',
            breg_Type__c = typeValue,
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );
    }

    private static List<breg_Account_Affiliation__c> createDirectorAffiliations(Id entityId, Integer directorCount) {
        List<breg_Account_Affiliation__c> affiliations = new List<breg_Account_Affiliation__c>();
        for (Integer index = 0; index < directorCount; index++) {
            affiliations.add(new breg_Account_Affiliation__c(
                breg_Entity__c = entityId,
                breg_Role__c = 'Director',
                breg_Type__c = 'Individual',
                breg_First_Name__c = 'Director' + index,
                breg_Last_Name__c = 'Person' + index,
                breg_Address__Street__s = '123 Main St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.today().addMonths(-1),
                breg_Status__c = 'A'
            ));
        }
        return affiliations;
    }

    private static breg_Account_Affiliation__c createRoleAffiliation(Id entityId, String role, String type) {
        return new breg_Account_Affiliation__c(
            breg_Entity__c = entityId,
            breg_Role__c = role,
            breg_Type__c = type,
            breg_First_Name__c = role,
            breg_Last_Name__c = 'Test',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );
    }

}