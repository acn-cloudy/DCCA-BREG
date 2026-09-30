public with sharing class BREGAnnualRobotRules {
    private static final String CASE_STATUS_COMPLETED = 'Completed';
    public static final Set<String> EXCLUDED_ENTITY_TYPES = new Set<String>{ 'F1', 'F2', 'C5', 'C6', 'K6', 'L6', 'Q6', 'G6' };
    public static final Set<String> INVALID_ANNUAL_STATUSES = new Set<String>{ 'P', 'H', 'NR' };
    private static final Set<String> RESOLVED_PRIOR_ANNUAL_STATUSES = new Set<String>{ 'P', 'NR' };
    public static final Set<String> GP_ENTITY_TYPES = new Set<String>{ 'G5', 'G6' };
    public static final Set<String> LLP_ENTITY_TYPES = new Set<String>{ 'K5', 'K6' };
    private static final String DIRECTOR_ROLE = 'Director';
    private static final String OFFICER_ROLE = 'Officer';
    private static final String PARTNER_ROLE = 'Partner';
    private static final String MEMBER_ROLE = 'Member';
    private static final String MANAGER_ROLE = 'Manager';
    private static final String INDIVIDUAL_TYPE = 'Individual';

    public static final String ROBOT_STATUS_NOT_STARTED = 'Not Started';
    public static final String ROBOT_STATUS_IN_QUEUE = 'In Queue';
    public static final String ROBOT_STATUS_COMPLETED = 'Completed';
    public static final String ROBOT_STATUS_ERROR = 'Error';
    public static final String ROBOT_STATUS_ROUTED_FOR_MANUAL = 'Routed for manual';

    private static final String SUCCESS_MESSAGE = System.Label.BREG_AnnualRobot_Success_Message;
    private static final String FAILURE_HEADER = System.Label.BREG_AnnualRobot_Failure_Header;
    private static final String QUEUED_MESSAGE = System.Label.BREG_AnnualRobot_Queued_Message;
    private static final String PREVIOUS_ANNUAL_UNRESOLVED_REASON = System.Label.BREG_AnnualRobot_Previous_Annual_Unresolved;
    private static final String UNEXPECTED_ERROR_REASON = System.Label.BREG_AnnualRobot_Unexpected_Error;
    private static final String MAPPING_ERROR_REASON = System.Label.BREG_AnnualRobot_Mapping_Error;
    private static final String MAPPING_NOT_STARTED_REASON = System.Label.BREG_AnnualRobot_Mapping_Not_Started;
    private static final String PUBLIC_INITIAL_FILING_MISSING_REASON = System.Label.BREG_AnnualRobot_Public_Initial_Filing_Missing;
    private static final String CONTACT_REASON = System.Label.BREG_AnnualRobot_Contact_Missing;
    private static final String FILE_NUMBER_REASON = System.Label.BREG_AnnualRobot_File_Number_Missing;
    private static final String FORM_CODE_REASON = System.Label.BREG_AnnualRobot_Form_Code_Invalid;
    private static final String WORKITEM_ID_REASON = System.Label.BREG_AnnualRobot_Work_Item_Id_Missing;
    private static final String WORKITEM_NUMBER_REASON = System.Label.BREG_AnnualRobot_Work_Item_Number_Missing;
    private static final String ENTITY_MISSING_REASON = System.Label.BREG_AnnualRobot_Entity_Missing;
    private static final String ENTITY_STATUS_REASON = System.Label.BREG_AnnualRobot_Entity_Status_Invalid;
    private static final String ANNUAL_MISSING_REASON = System.Label.BREG_AnnualRobot_Annual_Missing;
    private static final String ANNUAL_STATUS_REASON = System.Label.BREG_AnnualRobot_Annual_Status_Invalid;
    private static final String DUPLICATE_ANNUAL_YEAR_REASON = System.Label.BREG_AnnualRobot_Duplicate_Annual_Year;
    private static final String DUPLICATE_CASE_FOR_ANNUAL_REASON = System.Label.BREG_AnnualRobot_Duplicate_Case_For_Annual;
    private static final String PAYMENT_REASON = System.Label.BREG_AnnualRobot_Payment_Missing;
    private static final String CONFLICTING_TRANSACTION_REASON = System.Label.BREG_AnnualRobot_Conflicting_Transaction;
    private static final String NO_ACTIVE_AGENT_REASON = System.Label.BREG_AnnualRobot_No_Active_Agent;
    private static final String AGENT_ENTITY_REASON = System.Label.BREG_AnnualRobot_Agent_Is_Entity;
    private static final String COMPANY_HAS_CRA_REASON = System.Label.BREG_AnnualRobot_Company_Has_Cra;
    private static final String COMPANY_IS_CRA_REASON = System.Label.BREG_AnnualRobot_Company_Is_Cra;
    private static final String ENTITY_AFFILIATION_REASON = System.Label.BREG_AnnualRobot_Entity_Affiliation;
    private static final String COMPANY_BOUNCED_CHECK_REASON = System.Label.BREG_AnnualRobot_Company_Bounced_Check;
    private static final String RELATED_GP_BOUNCED_CHECK_REASON = System.Label.BREG_AnnualRobot_Related_Gp_Bounced_Check;
    private static final String GP_LLP_PARENT_REASON = System.Label.BREG_AnnualRobot_Gp_Llp_Parent;
    private static final String ANNUAL_FILING_DATE_MISSING_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Date_Missing;
    private static final String ANNUAL_FILING_DATE_FUTURE_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Date_Future;
    private static final String ANNUAL_FILING_DUE_DATE_MISSING_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Due_Date_Missing;
    private static final String ANNUAL_FILING_DUE_DATE_PAST_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Due_Date_Past;
    private static final String ANNUAL_FILING_YEAR_MISSING_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Year_Missing;
    private static final String ANNUAL_FILING_YEAR_GT_CURRENT_REASON = System.Label.BREG_AnnualRobot_Annual_Filing_Year_Future;
    private static final String SUBMISSION_DATE_MISSING_REASON = System.Label.BREG_AnnualRobot_Submission_Date_Missing;
    private static final String SUBMISSION_DATE_GT_NOW_REASON = System.Label.BREG_AnnualRobot_Submission_Date_Future;
    private static final String INCORPORATION_DATE_MISSING_REASON = System.Label.BREG_AnnualRobot_Incorporation_Date_Missing;
    private static final String INCORPORATION_DATE_GT_TODAY_REASON = System.Label.BREG_AnnualRobot_Incorporation_Date_Future;
    private static final String COMPARISON_DIFFERENCE_REASON = System.Label.BREG_AnnualRobot_Comparison_Difference;
    private static final String COMPARISON_DIFF_FIELDS_LABEL = System.Label.BREG_AnnualRobot_Comparison_Diff_Fields;
    private static final String ANNUAL_REPORT_YEAR_MISSING_REASON = System.Label.BREG_AnnualRobot_Annual_Report_Year_Missing;
    private static final String ANNUAL_REPORT_YEAR_GT_CURRENT_REASON = System.Label.BREG_AnnualRobot_Annual_Report_Year_Future;
    private static final String RECEIVED_DATE_MISSING_REASON = System.Label.BREG_AnnualRobot_Received_Date_Missing;
    private static final String RECEIVED_DATE_GT_NOW_REASON = System.Label.BREG_AnnualRobot_Received_Date_Future;
    private static final String L6_PARTNER_REASON = System.Label.BREG_AnnualRobot_L6_Partner_Required;
    private static final String Q6_PARTNER_REASON = System.Label.BREG_AnnualRobot_Q6_Partner_Required;
    private static final String G5_PARTNER_REASON = System.Label.BREG_AnnualRobot_G5_Partners_Required;
    private static final String G6_PARTNER_REASON = System.Label.BREG_AnnualRobot_G6_Partners_Required;
    private static final String K5_PARTNER_REASON = System.Label.BREG_AnnualRobot_K5_Partners_Required;
    private static final String K6_PARTNER_REASON = System.Label.BREG_AnnualRobot_K6_Partners_Required;
    private static final String A2_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_A2_Directors_Required;
    private static final String A2_OFFICER_REASON = System.Label.BREG_AnnualRobot_A2_Officer_Required;
    private static final String C2_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_C2_Directors_Required;
    private static final String C2_OFFICER_REASON = System.Label.BREG_AnnualRobot_C2_Officer_Required;
    private static final String A1_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_A1_Director_Required;
    private static final String A1_OFFICER_REASON = System.Label.BREG_AnnualRobot_A1_Officer_Required;
    private static final String C1_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_C1_Director_Required;
    private static final String C1_OFFICER_REASON = System.Label.BREG_AnnualRobot_C1_Officer_Required;
    private static final String F1_DIRECTOR_OR_OFFICER_REASON = System.Label.BREG_AnnualRobot_F1_Director_Or_Officer_Required;
    private static final String F2_DIRECTOR_OR_OFFICER_REASON = System.Label.BREG_AnnualRobot_F2_Director_Or_Officer_Required;
    private static final String P1_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_P1_Director_Required;
    private static final String P1_OFFICER_REASON = System.Label.BREG_AnnualRobot_P1_Officer_Required;
    private static final String S1_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_S1_Director_Required;
    private static final String S1_OFFICER_REASON = System.Label.BREG_AnnualRobot_S1_Officer_Required;
    private static final String D9_OFFICER_REASON = System.Label.BREG_AnnualRobot_D9_Officer_Required;
    private static final String D1_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_D1_Individual_Director_Required;
    private static final String D1_OFFICER_REASON = System.Label.BREG_AnnualRobot_D1_Officer_Required;
    private static final String D2_DIRECTOR_REASON = System.Label.BREG_AnnualRobot_D2_Individual_Directors_Required;
    private static final String D2_OFFICER_REASON = System.Label.BREG_AnnualRobot_D2_Officer_Required;
    private static final String LLC_MANAGER_REASON = System.Label.BREG_AnnualRobot_Llc_Manager_Required;
    private static final String LLC_MEMBER_REASON = System.Label.BREG_AnnualRobot_Llc_Member_Required;
    private static final Map<String, List<AffiliationRequirement>> AFFILIATION_REQUIREMENTS_BY_ENTITY_TYPE = buildAffiliationRequirementsByEntityType();

    public class CaseOutcomePlan {
        public Id caseId;
        public Id entityId;
        public String robotStatus;
        public String commentBody;
    }

    public static CaseOutcomePlan createPlan(Id caseId, Id entityId, String robotStatus, String commentBody) {
        CaseOutcomePlan plan = new CaseOutcomePlan();
        plan.caseId = caseId;
        plan.entityId = entityId;
        plan.robotStatus = robotStatus;
        plan.commentBody = commentBody;
        return plan;
    }

    public static List<CaseOutcomePlan> buildOutcomePlans(List<Case> loadedCases, BREGAnnualRobotEngine.EvaluationContext context) {
        List<CaseOutcomePlan> plans = new List<CaseOutcomePlan>();
        Map<Id, List<CaseYearWrapper>> caseYearWrappersByEntityId = new Map<Id, List<CaseYearWrapper>>();

        for (Case currentCase : loadedCases) {
            if (!meetsStartCriteria(currentCase)) {
                continue;
            }

            if (currentCase.breg_Entity__c == null) {
                plans.add(buildPlan(currentCase, context, plans));
            } else {
                if (!caseYearWrappersByEntityId.containsKey(currentCase.breg_Entity__c)) {
                    caseYearWrappersByEntityId.put(currentCase.breg_Entity__c, new List<CaseYearWrapper>());
                }
                caseYearWrappersByEntityId.get(currentCase.breg_Entity__c).add(new CaseYearWrapper(currentCase));
            }
        }

        for (Id entityId : caseYearWrappersByEntityId.keySet()) {
            List<CaseYearWrapper> wrappers = caseYearWrappersByEntityId.get(entityId);
            wrappers.sort();
            for (CaseYearWrapper wrapper : wrappers) {
                plans.add(buildPlan(wrapper.caseRecord, context, plans));
            }
        }

        return plans;
    }

    public static void finalizeSuccessPlans(List<CaseOutcomePlan> plans) {
        List<Id> successfulCaseIds = new List<Id>();
        for (CaseOutcomePlan plan : plans) {
            if (plan.robotStatus == ROBOT_STATUS_COMPLETED) {
                successfulCaseIds.add(plan.caseId);
            }
        }

        if (successfulCaseIds.isEmpty() || Test.isRunningTest()) {
            return;
        }

        try {
            BREGStartDocusignWorkflow.startDocuSignAnnualRobot(successfulCaseIds);
        } catch (Exception ex) {
            for (CaseOutcomePlan plan : plans) {
                if (plan.robotStatus == ROBOT_STATUS_COMPLETED) {
                    plan.robotStatus = ROBOT_STATUS_ERROR;
                    plan.commentBody = buildFailureMessage(new List<String>{ UNEXPECTED_ERROR_REASON });
                }
            }
        }
    }

    public static void applyPlans(List<CaseOutcomePlan> plans) {
        if (plans.isEmpty()) {
            return;
        }

        List<Case> casesToUpdate = new List<Case>();
        List<CaseComment> commentsToInsert = new List<CaseComment>();
        Datetime processedTimestamp = System.now();

        for (CaseOutcomePlan plan : plans) {
            casesToUpdate.add(new Case(
                Id = plan.caseId,
                breg_Annual_Robot_Status__c = plan.robotStatus,
                breg_Robot_Processed_DateTime__c = plan.robotStatus == ROBOT_STATUS_COMPLETED ? processedTimestamp : null
            ));
            if (String.isNotBlank(plan.commentBody)) {
                commentsToInsert.add(buildComment(plan.caseId, plan.commentBody));
            }
        }

        BREGAnnualRobotWithoutSharing.updateCasesSafely(casesToUpdate);

        if (!commentsToInsert.isEmpty()) {
            BREGAnnualRobotWithoutSharing.insertCommentsSafely(commentsToInsert);
        }
    }

    public static Set<Id> getSuccessfulEntityIds(List<CaseOutcomePlan> plans) {
        Set<Id> successfulEntityIds = new Set<Id>();
        for (CaseOutcomePlan plan : plans) {
            if (plan.robotStatus == ROBOT_STATUS_COMPLETED && plan.entityId != null) {
                successfulEntityIds.add(plan.entityId);
            }
        }
        return successfulEntityIds;
    }

    private static CaseOutcomePlan buildPlan(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, List<CaseOutcomePlan> existingPlans) {
        if (hasEarlierAnnualQueueBlock(currentCase, context, existingPlans)) {
            return createPlan(currentCase.Id, currentCase.breg_Entity__c, ROBOT_STATUS_IN_QUEUE, QUEUED_MESSAGE);
        }

        if (hasEarlierAnnualUnresolvedBlock(currentCase, context, existingPlans)) {
            return createPlan(
                currentCase.Id,
                currentCase.breg_Entity__c,
                ROBOT_STATUS_ROUTED_FOR_MANUAL,
                buildFailureMessage(new List<String>{ PREVIOUS_ANNUAL_UNRESOLVED_REASON })
            );
        }

        ReasonCollector reasonCollector = new ReasonCollector();
        addWebFilingReasons(currentCase, context, reasonCollector);
        addEntityReasons(currentCase, reasonCollector);
        addComparisonReasons(currentCase, context, reasonCollector);
        //addPublicInitialFilingReasons(currentCase, context, reasonCollector); // Document will be marked as Public from Docusign BREG Annual Robot workflow
        addContactReasons(currentCase, reasonCollector);
        addBasicAnnualParamReasons(currentCase, reasonCollector);
        addAnnualRecordReasons(currentCase, reasonCollector);
        addOlderAnnualReasons(currentCase, context, reasonCollector);
        addPaymentReasons(currentCase, context, reasonCollector);
        addConflictingTransactionReasons(currentCase, context, reasonCollector);
        addAgentReasons(currentCase, context, reasonCollector);
        addCraReasons(currentCase, context, reasonCollector);
        addEntityAffiliationReasons(currentCase, context, reasonCollector);
        addAffiliationRoleReasons(currentCase, context, reasonCollector);
        addBouncedCheckReasons(currentCase, context, reasonCollector);
        addGpParentReasons(currentCase, reasonCollector);
        addDateValidationReasons(currentCase, reasonCollector);
        if (reasonCollector.isEmpty()) {
            return createPlan(currentCase.Id, currentCase.breg_Entity__c, ROBOT_STATUS_COMPLETED, SUCCESS_MESSAGE);
        }

        return createPlan(
            currentCase.Id,
            currentCase.breg_Entity__c,
            ROBOT_STATUS_ROUTED_FOR_MANUAL,
            buildFailureMessage(reasonCollector.reasons)
        );
    }

    private static void addWebFilingReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        breg_WEB_WEB_FILING_INFO__c filingInfo = context.webFilingInfoByCaseId.get(currentCase.Id);
        if (filingInfo == null) {
            return;
        }

        if (filingInfo.breg_Mapping_Status__c == 'Error') {
            reasonCollector.add(MAPPING_ERROR_REASON);
        } else if (filingInfo.breg_Mapping_Status__c == 'Not Started' || filingInfo.breg_Mapping_Status__c == null) {
            reasonCollector.add(MAPPING_NOT_STARTED_REASON);
        }
    }

    private static void addPublicInitialFilingReasons(
        Case currentCase,
        BREGAnnualRobotEngine.EvaluationContext context,
        ReasonCollector reasonCollector
    ) {
        if (currentCase == null || context.caseIdsWithPublicInitialFilingDocuments.contains(currentCase.Id)) {
            return;
        }

        reasonCollector.add(PUBLIC_INITIAL_FILING_MISSING_REASON);
    }

    private static void addContactReasons(Case currentCase, ReasonCollector reasonCollector) {
        if (currentCase.ContactId == null) {
            reasonCollector.add(CONTACT_REASON);
        }
    }

    private static void addBasicAnnualParamReasons(Case currentCase, ReasonCollector reasonCollector) {
        if (currentCase.breg_File__c == null) {
            reasonCollector.add(FILE_NUMBER_REASON);
        }
        if (String.isBlank(currentCase.breg_Form_Code__c) || !currentCase.breg_Form_Code__c.contains('ANN-')) {
            reasonCollector.add(FORM_CODE_REASON);
        }
        if (currentCase.breg_Workitem_ID__c == null) {
            reasonCollector.add(WORKITEM_ID_REASON);
        }
        if (currentCase.breg_Workitem_Number__c == null) {
            reasonCollector.add(WORKITEM_NUMBER_REASON);
        }
    }

    private static void addEntityReasons(Case currentCase, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            reasonCollector.add(ENTITY_MISSING_REASON);
            return;
        }

        if (!hasEligibleEntityStatus(currentCase)) {
            reasonCollector.add(ENTITY_STATUS_REASON);
        }
    }

    private static void addAnnualRecordReasons(Case currentCase, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasAnnual(currentCase)) {
            reasonCollector.add(ANNUAL_MISSING_REASON);
            return;
        }

        if (INVALID_ANNUAL_STATUSES.contains(currentCase.breg_Annual__r.breg_Status__c)) {
            reasonCollector.add(ANNUAL_STATUS_REASON);
        }
    }

    private static void addPaymentReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!context.caseIdsWithPaidTransactions.contains(currentCase.Id) && currentCase.breg_Override_Payment__c != true) {
            reasonCollector.add(PAYMENT_REASON);
        }
    }

    private static void addConflictingTransactionReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (context.caseIdsWithConflictingTransactions.contains(currentCase.Id)) {
            reasonCollector.add(CONFLICTING_TRANSACTION_REASON);
        }
    }

    private static void addAgentReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        breg_Account_Affiliation__c activeAgent = context.activeAgentByEntityId.get(currentCase.breg_Entity__c);
        if (activeAgent == null) {
            reasonCollector.add(NO_ACTIVE_AGENT_REASON);
            return;
        }

        if (activeAgent.breg_Type__c == 'Entity' && activeAgent.breg_Account__r.breg_BRIM_CRA_FL__c != true) {
            reasonCollector.add(AGENT_ENTITY_REASON);
        }
    }

    private static void addCraReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        if (currentCase.breg_Entity__r.breg_BRIM_CRA_FL__c == true) {
            reasonCollector.add(COMPANY_IS_CRA_REASON);
        }

        // BREGMO-415
        // breg_Account_Affiliation__c activeAgent = context.activeAgentByEntityId.get(currentCase.breg_Entity__c);
        // if (activeAgent != null && activeAgent.breg_Account__r.breg_BRIM_CRA_FL__c == true) {
        //     reasonCollector.add(COMPANY_HAS_CRA_REASON);
        // }
    }

    private static void addEntityAffiliationReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        if (EXCLUDED_ENTITY_TYPES.contains(currentCase.breg_Entity__r.breg_Entity_Type__c)) {
            return;
        }

        List<breg_Account_Affiliation__c> affiliations = context.entityAffiliationsByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.entityAffiliationsByEntityId.get(currentCase.breg_Entity__c)
            : new List<breg_Account_Affiliation__c>();

        if (hasNonAgentEntityAffiliation(affiliations)) {
            reasonCollector.add(ENTITY_AFFILIATION_REASON);
        }
    }

    private static void addAffiliationRoleReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        List<AffiliationRequirement> requirements = getAffiliationRequirements(currentCase);
        if (requirements == null) {
            return;
        }

        List<breg_Account_Affiliation__c> affiliations = context.entityAffiliationsByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.entityAffiliationsByEntityId.get(currentCase.breg_Entity__c)
            : new List<breg_Account_Affiliation__c>();

        for (AffiliationRequirement requirement : requirements) {
            if (countAffiliations(affiliations, requirement) < requirement.minimumCount) {
                reasonCollector.add(requirement.reason);
            }
        }
    }

    private static void addOlderAnnualReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        addDuplicateAnnualYearReasons(currentCase, context, reasonCollector);
        addDuplicateCaseForAnnualReasons(currentCase, context, reasonCollector);
    }

    private static void addDuplicateAnnualYearReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        Integer filingYear = BREGAnnualRobotUtil.getAnnualProcessingYear(currentCase);
        if (filingYear == null) {
            return;
        }

        List<breg_Annual__c> annualRecords = context.annualsByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.annualsByEntityId.get(currentCase.breg_Entity__c)
            : new List<breg_Annual__c>();

        Integer sameYearAnnualCount = 0;
        for (breg_Annual__c annualRecord : annualRecords) {
            Integer annualRecordYear = BREGAnnualRobotUtil.parseInteger(annualRecord.breg_Filing_Year__c);
            if (annualRecordYear != null && annualRecordYear == filingYear) {
                sameYearAnnualCount++;
            }
        }

        if (sameYearAnnualCount > 1) {
            reasonCollector.add(DUPLICATE_ANNUAL_YEAR_REASON);
        }
    }

    private static void addDuplicateCaseForAnnualReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (currentCase.breg_Annual__c == null) {
            return;
        }

        Integer annualCaseCount = context.annualCaseCountByAnnualId.get(currentCase.breg_Annual__c);
        if (annualCaseCount != null && annualCaseCount > 1) {
            reasonCollector.add(DUPLICATE_CASE_FOR_ANNUAL_REASON);
        }
    }

    private static void addBouncedCheckReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        if (currentCase.breg_Entity__r.breg_Bounced_Check__c == true) {
            reasonCollector.add(COMPANY_BOUNCED_CHECK_REASON);
        }
        if (context.entityIdsWithBouncedGp.contains(currentCase.breg_Entity__c)) {
            reasonCollector.add(RELATED_GP_BOUNCED_CHECK_REASON);
        }
    }

    private static void addGpParentReasons(Case currentCase, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        if (GP_ENTITY_TYPES.contains(currentCase.breg_Entity__r.breg_Entity_Type__c) &&
            currentCase.breg_Entity__r.ParentId != null &&
            LLP_ENTITY_TYPES.contains(currentCase.breg_Entity__r.Parent.breg_Entity_Type__c)
        ) {
            reasonCollector.add(GP_LLP_PARENT_REASON);
        }
    }

    private static void addDateValidationReasons(Case currentCase, ReasonCollector reasonCollector) {
        Datetime nowValue = System.now();
        Date today = nowValue.dateGMT();
        Integer currentYear = today.year();

        addAnnualDateReasons(currentCase, reasonCollector, today, nowValue, currentYear);
        addCaseDateReasons(currentCase, reasonCollector, nowValue, currentYear);
        addEntityDateReasons(currentCase, reasonCollector, today);
    }

    private static void addComparisonReasons(Case currentCase, BREGAnnualRobotEngine.EvaluationContext context, ReasonCollector reasonCollector) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase) || currentCase.breg_Entity__r == null) {
            return;
        }

        BREGAnnualRobotComparison.ComparisonResult comparison = BREGAnnualRobotComparison.compareAnnualData(
            currentCase,
            currentCase.breg_Entity__r,
            context.caseAffiliationsByCaseId.get(currentCase.Id),
            context.entityAffiliationsByEntityId.get(currentCase.breg_Entity__c),
            context.caseStocksByCaseId.get(currentCase.Id),
            context.entityStocksByEntityId.get(currentCase.breg_Entity__c)
        );

        if (!comparison.hasDifferences) {
            return;
        }

        Map<String, Integer> differenceCountsByLabel = new Map<String, Integer>();
        List<String> labelOrder = new List<String>();
        for (BREGAnnualRobotComparison.ComparisonDiff diff : comparison.diffs) {
            if (String.isBlank(diff.label)) {
                continue;
            }
            if (!differenceCountsByLabel.containsKey(diff.label)) {
                differenceCountsByLabel.put(diff.label, 0);
                labelOrder.add(diff.label);
            }
            differenceCountsByLabel.put(diff.label, differenceCountsByLabel.get(diff.label) + 1);
        }

        if (labelOrder.isEmpty()) {
            reasonCollector.add(COMPARISON_DIFFERENCE_REASON);
            return;
        }

        List<String> summarizedDifferences = new List<String>();
        for (String label : labelOrder) {
            Integer count = differenceCountsByLabel.get(label);
            summarizedDifferences.add(count == 1 ? label : String.valueOf(count) + ' x ' + label);
        }
        reasonCollector.add(COMPARISON_DIFFERENCE_REASON + ' ' + COMPARISON_DIFF_FIELDS_LABEL + ' ' + String.join(summarizedDifferences, ', '));
    }

    private static void addAnnualDateReasons(
        Case currentCase,
        ReasonCollector reasonCollector,
        Date today,
        Datetime nowValue,
        Integer currentYear
    ) {
        if (!BREGAnnualRobotUtil.hasAnnual(currentCase)) {
            return;
        }

        if (currentCase.breg_Annual__r.breg_Filing_Date__c == null) {
            reasonCollector.add(ANNUAL_FILING_DATE_MISSING_REASON);
        } else if (currentCase.breg_Annual__r.breg_Filing_Date__c > today) {
            reasonCollector.add(ANNUAL_FILING_DATE_FUTURE_REASON);
        }

        // if (currentCase.breg_Annual__r.breg_Filing_Due_Date__c == null) {
        //     reasonCollector.add(ANNUAL_FILING_DUE_DATE_MISSING_REASON);
        // } else if (currentCase.breg_Annual__r.breg_Filing_Due_Date__c < today) {
        //     reasonCollector.add(ANNUAL_FILING_DUE_DATE_PAST_REASON);
        // }

        addYearReasons(currentCase.breg_Annual__r.breg_Filing_Year__c, ANNUAL_FILING_YEAR_MISSING_REASON, ANNUAL_FILING_YEAR_GT_CURRENT_REASON, currentYear, reasonCollector);

        if (currentCase.breg_Annual__r.breg_Received_Date__c == null) {
            reasonCollector.add(RECEIVED_DATE_MISSING_REASON);
        } else if (currentCase.breg_Annual__r.breg_Received_Date__c > nowValue) {
            reasonCollector.add(RECEIVED_DATE_GT_NOW_REASON);
        }
    }

    private static void addCaseDateReasons(Case currentCase, ReasonCollector reasonCollector, Datetime nowValue, Integer currentYear) {
        if (currentCase.breg_Submission_Date__c == null) {
            reasonCollector.add(SUBMISSION_DATE_MISSING_REASON);
        } else if (currentCase.breg_Submission_Date__c > nowValue) {
            reasonCollector.add(SUBMISSION_DATE_GT_NOW_REASON);
        }

        addYearReasons(currentCase.breg_Annual_Report_Filing_Year__c, ANNUAL_REPORT_YEAR_MISSING_REASON, ANNUAL_REPORT_YEAR_GT_CURRENT_REASON, currentYear, reasonCollector);
    }

    private static void addEntityDateReasons(Case currentCase, ReasonCollector reasonCollector, Date today) {
        if (!BREGAnnualRobotUtil.hasEntity(currentCase)) {
            return;
        }

        if (currentCase.breg_Entity__r.breg_Incorporation_Date__c == null) {
            reasonCollector.add(INCORPORATION_DATE_MISSING_REASON);
        } else if (currentCase.breg_Entity__r.breg_Incorporation_Date__c > today) {
            reasonCollector.add(INCORPORATION_DATE_GT_TODAY_REASON);
        }
    }

    private static void addYearReasons(
        String yearValue,
        String missingReason,
        String greaterThanCurrentReason,
        Integer currentYear,
        ReasonCollector reasonCollector
    ) {
        if (String.isBlank(yearValue)) {
            reasonCollector.add(missingReason);
            return;
        }

        Integer parsedYear = BREGAnnualRobotUtil.parseInteger(yearValue);
        if (parsedYear != null && parsedYear > currentYear) {
            reasonCollector.add(greaterThanCurrentReason);
        }
    }

    private static Boolean hasEligibleEntityStatus(Case currentCase) {
        return currentCase.breg_Entity__r.breg_Entity_Status__c == 'Active (A)' ||
            currentCase.breg_Entity__r.breg_Entity_Status__c == 'Annual report 1 yr delinquent (1)'; // ||
            // currentCase.breg_Entity__r.breg_Entity_Status__c == 'Annual report 2 yr delinquent (2)';
    }

    private static Boolean hasNonAgentEntityAffiliation(List<breg_Account_Affiliation__c> affiliations) {
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            if (affiliation.breg_Role__c != 'Agent' && affiliation.breg_Type__c == 'Entity') {
                return true;
            }
        }
        return false;
    }

    private static List<AffiliationRequirement> getAffiliationRequirements(Case currentCase) {
        String entityType = currentCase.breg_Entity__r.breg_Entity_Type__c;
        if (entityType == 'C5' || entityType == 'C6') {
            return currentCase.breg_Is_Manager_Managed__c == true
                ? new List<AffiliationRequirement>{ new AffiliationRequirement(MANAGER_ROLE, null, 1, LLC_MANAGER_REASON) }
                : new List<AffiliationRequirement>{ new AffiliationRequirement(MEMBER_ROLE, null, 1, LLC_MEMBER_REASON) };
        }
        return AFFILIATION_REQUIREMENTS_BY_ENTITY_TYPE.get(entityType);
    }

    private static Integer countAffiliations(List<breg_Account_Affiliation__c> affiliations, AffiliationRequirement requirement) {
        Integer affiliationCount = 0;
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            if (requirement.roles.contains(affiliation.breg_Role__c) &&
                (requirement.type == null || affiliation.breg_Type__c == requirement.type)) {
                affiliationCount++;
            }
        }
        return affiliationCount;
    }

    private static Map<String, List<AffiliationRequirement>> buildAffiliationRequirementsByEntityType() {
        return new Map<String, List<AffiliationRequirement>>{
            'L6' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 1, L6_PARTNER_REASON)
            },
            'Q6' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 1, Q6_PARTNER_REASON)
            },
            'G5' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 2, G5_PARTNER_REASON)
            },
            'G6' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 2, G6_PARTNER_REASON)
            },
            'K5' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 2, K5_PARTNER_REASON)
            },
            'K6' => new List<AffiliationRequirement>{
                new AffiliationRequirement(PARTNER_ROLE, null, 2, K6_PARTNER_REASON)
            },
            'A2' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 3, A2_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, A2_OFFICER_REASON)
            },
            'C2' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 3, C2_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, C2_OFFICER_REASON)
            },
            'A1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 1, A1_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, A1_OFFICER_REASON)
            },
            'C1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 1, C1_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, C1_OFFICER_REASON)
            },
            'F1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(new Set<String>{ DIRECTOR_ROLE, OFFICER_ROLE }, null, 1, F1_DIRECTOR_OR_OFFICER_REASON)
            },
            'F2' => new List<AffiliationRequirement>{
                new AffiliationRequirement(new Set<String>{ DIRECTOR_ROLE, OFFICER_ROLE }, null, 1, F2_DIRECTOR_OR_OFFICER_REASON)
            },
            'P1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 1, P1_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, P1_OFFICER_REASON)
            },
            'S1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, null, 1, S1_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, S1_OFFICER_REASON)
            },
            'D9' => new List<AffiliationRequirement>{
                new AffiliationRequirement(OFFICER_ROLE, null, 1, D9_OFFICER_REASON)
            },
            'D1' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, INDIVIDUAL_TYPE, 1, D1_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, D1_OFFICER_REASON)
            },
            'D2' => new List<AffiliationRequirement>{
                new AffiliationRequirement(DIRECTOR_ROLE, INDIVIDUAL_TYPE, 3, D2_DIRECTOR_REASON),
                new AffiliationRequirement(OFFICER_ROLE, null, 1, D2_OFFICER_REASON)
            }
        };
    }

    @TestVisible
    private static Boolean hasEarlierAnnualQueueBlock(
        Case currentCase,
        BREGAnnualRobotEngine.EvaluationContext context,
        List<CaseOutcomePlan> existingPlans
    ) {
        Integer currentYear = BREGAnnualRobotUtil.getAnnualProcessingYear(currentCase);
        if (currentYear == null || currentCase.breg_Entity__c == null) {
            return false;
        }

        List<Case> relatedAnnualCases = context.relatedAnnualCasesByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.relatedAnnualCasesByEntityId.get(currentCase.breg_Entity__c)
            : new List<Case>();

        for (Case relatedAnnualCase : relatedAnnualCases) {
            if (relatedAnnualCase.Id == currentCase.Id) {
                continue;
            }

            Integer relatedYear = BREGAnnualRobotUtil.parseInteger(relatedAnnualCase.breg_Annual__r.breg_Filing_Year__c);
            if (relatedYear == null || relatedYear >= currentYear) {
                continue;
            }

            if (!isAnnualRobotEligibleCase(relatedAnnualCase)) {
                continue;
            }

            if (context.currentBatchCaseIds.contains(relatedAnnualCase.Id)) {
                CaseOutcomePlan priorPlan = findPlan(existingPlans, relatedAnnualCase.Id);
                if (priorPlan == null || priorPlan.robotStatus == ROBOT_STATUS_IN_QUEUE) {
                    return true;
                }
            } else if (!BREGAnnualRobotUtil.isResolvedRelatedAnnualCase(relatedAnnualCase) && !BREGAnnualRobotUtil.isFinalBlockedRobotStatus(relatedAnnualCase.breg_Annual_Robot_Status__c)) {
                return true;
            }
        }

        return false;
    }

    @TestVisible
    private static Boolean hasEarlierAnnualUnresolvedBlock(
        Case currentCase,
        BREGAnnualRobotEngine.EvaluationContext context,
        List<CaseOutcomePlan> existingPlans
    ) {
        Integer currentYear = BREGAnnualRobotUtil.getAnnualProcessingYear(currentCase);
        if (currentYear == null || currentCase.breg_Entity__c == null) {
            return false;
        }

        List<breg_Annual__c> annualRecords = context.annualsByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.annualsByEntityId.get(currentCase.breg_Entity__c)
            : new List<breg_Annual__c>();
        for (breg_Annual__c annualRecord : annualRecords) {
            Integer annualYear = BREGAnnualRobotUtil.parseInteger(annualRecord.breg_Filing_Year__c);
            if (annualYear != null && annualYear < currentYear && !RESOLVED_PRIOR_ANNUAL_STATUSES.contains(annualRecord.breg_Status__c)) {
                return true;
            }
        }

        List<Case> relatedAnnualCases = context.relatedAnnualCasesByEntityId.containsKey(currentCase.breg_Entity__c)
            ? context.relatedAnnualCasesByEntityId.get(currentCase.breg_Entity__c)
            : new List<Case>();

        for (Case relatedAnnualCase : relatedAnnualCases) {
            if (relatedAnnualCase.Id == currentCase.Id) {
                continue;
            }

            Integer relatedYear = BREGAnnualRobotUtil.parseInteger(relatedAnnualCase.breg_Annual__r.breg_Filing_Year__c);
            if (relatedYear == null || relatedYear >= currentYear) {
                continue;
            }

            if (!isAnnualRobotEligibleCase(relatedAnnualCase) && !BREGAnnualRobotUtil.isResolvedRelatedAnnualCase(relatedAnnualCase)) {
                return true;
            }

            if (context.currentBatchCaseIds.contains(relatedAnnualCase.Id)) {
                CaseOutcomePlan priorPlan = findPlan(existingPlans, relatedAnnualCase.Id);
                if (priorPlan != null && BREGAnnualRobotUtil.isFinalBlockedRobotStatus(priorPlan.robotStatus)) {
                    return true;
                }
            } else if (BREGAnnualRobotUtil.isFinalBlockedRobotStatus(relatedAnnualCase.breg_Annual_Robot_Status__c)) {
                return true;
            }
        }

        return false;
    }

    private static Boolean isAnnualRobotEligibleCase(Case currentCase) {
        return currentCase != null &&
            currentCase.Status == 'Received' &&
            currentCase.breg_No_Changes__c == true &&
            currentCase.RecordType != null &&
            currentCase.RecordType.DeveloperName == 'BREG_Case';
    }

    private static CaseOutcomePlan findPlan(List<CaseOutcomePlan> existingPlans, Id caseId) {
        for (CaseOutcomePlan existingPlan : existingPlans) {
            if (existingPlan.caseId == caseId) {
                return existingPlan;
            }
        }
        return null;
    }

    private static String buildFailureMessage(List<String> reasons) {
        return FAILURE_HEADER + '\n' + String.join(reasons, '\n');
    }

    private static CaseComment buildComment(Id caseId, String commentBody) {
        return new CaseComment(ParentId = caseId, CommentBody = commentBody, IsPublished = false);
    }

    private static void updateCasesSafely(List<Case> casesToUpdate) {
        BREGAnnualRobotWithoutSharing.updateCasesSafely(casesToUpdate);
    }

    private static Boolean meetsStartCriteria(Case currentCase) {
        return currentCase != null &&
            currentCase.Status == 'Received' &&
            currentCase.breg_No_Changes__c == true &&
            currentCase.RecordType != null &&
            currentCase.RecordType.DeveloperName == 'BREG_Case';
    }

    private class CaseYearWrapper implements Comparable {
        private Case caseRecord;
        private Integer filingYear;

        private CaseYearWrapper(Case caseRecord) {
            this.caseRecord = caseRecord;
            this.filingYear = BREGAnnualRobotUtil.getAnnualProcessingYear(caseRecord);
        }

        /**
         * Compares annual wrappers by filing year so earlier years are processed first.
         * @param otherObject Another wrapper instance to compare against.
         * @return Negative when this wrapper should sort first, positive when after, or zero when equal.
         */
        public Integer compareTo(Object otherObject) {
            CaseYearWrapper otherWrapper = (CaseYearWrapper) otherObject;
            if (filingYear == null && otherWrapper.filingYear == null) {
                return 0;
            }
            if (filingYear == null) {
                return 1;
            }
            if (otherWrapper.filingYear == null) {
                return -1;
            }
            if (filingYear == otherWrapper.filingYear) {
                return 0;
            }
            return filingYear < otherWrapper.filingYear ? -1 : 1;
        }
    }

    private class ReasonCollector {
        private Set<String> seenReasons = new Set<String>();
        private List<String> reasons = new List<String>();

        private void add(String reason) {
            if (String.isBlank(reason) || seenReasons.contains(reason)) {
                return;
            }
            seenReasons.add(reason);
            reasons.add(reason);
        }

        private Boolean isEmpty() {
            return reasons.isEmpty();
        }
    }

    private class AffiliationRequirement {
        private Set<String> roles;
        private String type;
        private Integer minimumCount;
        private String reason;

        private AffiliationRequirement(String role, String type, Integer minimumCount, String reason) {
            this(new Set<String>{ role }, type, minimumCount, reason);
        }

        private AffiliationRequirement(Set<String> roles, String type, Integer minimumCount, String reason) {
            this.roles = roles;
            this.type = type;
            this.minimumCount = minimumCount;
            this.reason = reason;
        }
    }
}