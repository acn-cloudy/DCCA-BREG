@isTest
public with sharing class BREGCaseTriggerHandlerTest {
    @TestSetup
    private static void prepareData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFileNumberSequences();
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createRegistrationCases(forms);
        upsert new breg_Docusign_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Chars_per_Line__c = 88,
            Page_Lines__c = 43,
            Lines_Before_Rejection_Reason__c = 20,
            Lines_After_Rejection_Reason__c = 11,
            Non_Web_Page_Break_Lines_Offset__c = 13
        );
    }

    private static breg_Docusign_Settings__c getDocusignSettings() {
        breg_Docusign_Settings__c settings = breg_Docusign_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings, 'DocuSign settings org default must exist for page-break tests.');
        return settings;
    }

    private static Integer getCharsPerLine() {
        return getDocusignSettings().Chars_per_Line__c.intValue();
    }

    private static Integer getPageLines() {
        return getDocusignSettings().Page_Lines__c.intValue();
    }

    private static Integer getLinesBeforeRejectionReason() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings.Lines_Before_Rejection_Reason__c != null
            ? settings.Lines_Before_Rejection_Reason__c.intValue()
            : 20;
    }

    private static Integer getLinesAfterRejectionReason() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings.Lines_After_Rejection_Reason__c != null
            ? settings.Lines_After_Rejection_Reason__c.intValue()
            : 11;
    }

    private static Integer getNonWebPageBreakLinesOffset() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings.Non_Web_Page_Break_Lines_Offset__c != null
            ? settings.Non_Web_Page_Break_Lines_Offset__c.intValue()
            : 13;
    }

    private static breg_Form_Configuration__c getAnnualReportForm() {
        return [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Business_Process__c = 'Annual Report' LIMIT 1];
    }

    private static breg_Form_Configuration__c getNonAnnualForm() {
        return [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Business_Process__c = 'New Business' LIMIT 1];
    }

    private static Id getTestAccountId() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        return acc.Id;
    }

    private static Id getTestFormConfigId() {
        return getAnnualReportForm().Id;
    }

    private static String getExpectedTransactionCodeFromCsv(String formCode) {
        Map<String, String> transactionCodeByFormCode = new Map<String, String>{
            'AG-1' => 'ART',
            'DC-1' => 'ART',
            'DNP-1' => 'ART',
            'LLC-1' => 'LLC',
            'GP-1' => 'PRS',
            'LLP-1' => 'LLP'
        };

        return transactionCodeByFormCode.get(formCode);
    }

    private static String extractTransactionCodeValueForAssert(String picklistLabel) {
        if (String.isBlank(picklistLabel)) {
            return null;
        }

        List<String> parts = picklistLabel.split(' - ');
        if (parts.size() > 1) {
            return parts[1].trim();
        }

        return picklistLabel.trim();
    }

    private static RecordTypeInfo getCaseRecordType() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case');
    }

    private static Id getNonBregCaseRecordTypeId() {
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' AND IsActive = TRUE]) {
            if (rt.DeveloperName != 'BREG_Case' && rt.DeveloperName != 'BREG_Refund_Request_Case') {
                return rt.Id;
            }
        }
        System.assert(false, 'No non-BREG Case record type found for negative test coverage');
        return null;
    }

    @isTest
    static void testNoDelinquents_ReturnsZero() {
        Id accId = getTestAccountId();
        Id formId = getTestFormConfigId();

        Case c = createCase();
        c.Subject = 'Test No Delinquent';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity__c = accId;
        c.breg_Annual_Report_Filing_Year__c = '2024';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT breg_Number_of_Delinquent_Annual_Reports__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(0, inserted.breg_Number_of_Delinquent_Annual_Reports__c);
    }

    @isTest
    static void testOneDelinquent_ReturnsOne() {
        Id accId = getTestAccountId();
        Id formId = getTestFormConfigId();

        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2024');

        Case c = createCase();
        c.Subject = 'Test One Delinquent';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity__c = accId;
        c.breg_Annual_Report_Filing_Year__c = '2024';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT breg_Number_of_Delinquent_Annual_Reports__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(1, inserted.breg_Number_of_Delinquent_Annual_Reports__c);
    }

    @isTest
    static void testTwoDelinquents_ReturnsTwo() {
        Id accId = getTestAccountId();
        Id formId = getTestFormConfigId();

        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2024');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2023');

        Case c = createCase();
        c.Subject = 'Test Two Delinquents';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity__c = accId;
        c.breg_Annual_Report_Filing_Year__c = '2023';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT breg_Number_of_Delinquent_Annual_Reports__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(2, inserted.breg_Number_of_Delinquent_Annual_Reports__c);
    }

    @isTest
    static void testThreeDelinquents_ReturnsThree() {
        Id accId = getTestAccountId();
        Id formId = getTestFormConfigId();

        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2024');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2023');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2022');

        Case c = createCase();
        c.Subject = 'Test Too Many Delinquents';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity__c = accId;
        c.breg_Annual_Report_Filing_Year__c = '2022';

        Test.startTest();
        insert c; 
        Test.stopTest();

        Case newCase = [SELECT breg_Number_of_Delinquent_Annual_Reports__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(3, newCase.breg_Number_of_Delinquent_Annual_Reports__c);
    }

    @isTest
    static void testFourDelinquents_ThrowsException() {
        Id accId = getTestAccountId();
        Id formId = getTestFormConfigId();

        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2025');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2024');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2023');
        insert new breg_Annual__c(breg_Account__c = accId, breg_Status__c = 'D', breg_Filing_Year__c = '2022');

        Case c = createCase();
        c.Subject = 'Test Too Many Delinquents';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity__c = accId;
        c.breg_Annual_Report_Filing_Year__c = '2022';

        Test.startTest();
        try {
            insert c;
            System.assert(false, 'Expected exception was not thrown');
        } catch (DMLException ex) {
            System.assert(
                ex.getMessage()
                    .contains('Entity can have maximum 3 delinquent annual reports'),
                'Unexpected DML exception message: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }


    @isTest
    static void testBeforeUpdateSetsEffectiveDateFromSubmissionDatetimeForNonAnnualForm() {
        breg_Form_Configuration__c nonAnnualForm = [
            SELECT Id, breg_Days_After_Submission_hold_Approval__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'New Business'
            LIMIT 1
        ];

        if (nonAnnualForm.breg_Days_After_Submission_hold_Approval__c != null) {
            nonAnnualForm.breg_Days_After_Submission_hold_Approval__c = null;
            update nonAnnualForm;
        }

        Case c = createCase();
        c.Subject = 'Submission Datetime To Effective Date';
        c.breg_Form_Configuration__c = nonAnnualForm.Id;
        insert c;

        Datetime submissionDateTime = Datetime.newInstance(2026, 2, 10, 14, 35, 0);
        c = [SELECT Id, breg_Submission_Date__c, breg_Effective_Date__c FROM Case WHERE Id = :c.Id];
        c.breg_Submission_Date__c = submissionDateTime;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update c;
        Test.stopTest();

        Case updated = [SELECT breg_Submission_Date__c, breg_Effective_Date__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            Date.newInstance(2026, 2, 10),
            updated.breg_Effective_Date__c,
            'Effective date should be set to the date part of submission datetime for non-annual forms.'
        );
    }

    private static Case createCase() {
        return new Case(
            Origin = 'Web',
            Status = 'New',
            RecordTypeId = getCaseRecordType().getRecordTypeId(),
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__Street__s = 'Mart rd, 134',
            breg_Company_Address__PostalCode__s = '1234'
        );
    }

    @isTest
    private static void testFileNumberGenerator() {
        List<Case> cases = [
            SELECT Id, Status, breg_Bypass_Status_Change_Validation__c, breg_File__c, breg_Form_Code__c
            FROM Case
            WHERE
                RecordType.DeveloperName = 'BREG_Case'
                AND Status = 'New'
                AND breg_File__c = NULL
                AND breg_Form_Configuration__r.breg_Business_Process__c = 'New Business'
        ];

        createCompletedPayment(cases);
        createRequiredApprovedStatusAffiliations(cases);

        for (Case theCase : cases) {
            theCase.Status = 'Approved';
            theCase.breg_Bypass_Status_Change_Validation__c = true;
        }
        Integer initialCasesAmount = cases.size();
        TriggerUtils.disableTrigger = false;

        Test.startTest();
        update cases;
        Test.stopTest();

        cases = [
            SELECT breg_File__c
            FROM Case
            WHERE
                RecordType.DeveloperName = 'BREG_Case'
                AND Status = 'Approved'
                AND breg_File__c != NULL
                AND breg_Form_Configuration__r.breg_Business_Process__c = 'New Business'
        ];
        System.assertEquals(initialCasesAmount, cases.size(), 'All approved cases should have a file number assigned.');
    }

    private static void createRequiredApprovedStatusAffiliations(List<Case> cases) {
        for (Case c : cases) {
            if (c.breg_Form_Code__c == 'LLC-1' || c.breg_Form_Code__c == 'FLLC-1') {
                BREGTestDataFactory.createAccountAffiliationsForRole(c.Id, 'Member', 1);
            } else if (c.breg_Form_Code__c == 'AG-1' || c.breg_Form_Code__c == 'CONS-1') {
                BREGTestDataFactory.createAccountAffiliationsForRole(c.Id, 'Director', 3);
            } else if (c.breg_Form_Code__c == 'GP-1' || c.breg_Form_Code__c == 'LP-1' || c.breg_Form_Code__c == 'FLP-1') {
                BREGTestDataFactory.createAccountAffiliationsForRole(c.Id, 'Partner', 1);
            }
        }
    }

    private static void createCompletedPayment(List<Case> cases) {
        Transaction__c trans = new Transaction__c();
        insert trans;

        List<TransactionLine__c> linesToInsert = new List<TransactionLine__c>();

        for (Case c : cases) {
            TransactionLine__c line = new TransactionLine__c(Transaction__c = trans.Id, breg_Case__c = c.Id, PaidStatus__c = 'Paid', Amount__c = 100);
            linesToInsert.add(line);
        }

        insert linesToInsert;
    }

    @isTest
    static void afterUpdateStatusTransitionsCoverBranchesTest() {
        List<Case> seedCases = [
            SELECT
                Id,
                Status,
                Origin,
                ParentId,
                breg_Form_Action__c,
                breg_Form_Configuration__c,
                breg_Form_Code__c,
                breg_Number_of_Delinquent_Annual_Reports__c,
                breg_Duration_Period__c,
                breg_Is_Allowed_Generate_Reinstatem_Cert__c,
                breg_Bypass_Status_Change_Validation__c,
                breg_Reopened_Date__c
            FROM Case
            WHERE RecordType.DeveloperName = 'BREG_Case' AND breg_Form_Code__c != 'LLC-1'
            ORDER BY CreatedDate ASC
            LIMIT 8
        ];

        Case resubmitted = seedCases[1];
        resubmitted.Status = 'Rejected';
        resubmitted.breg_Resubmission_Due_Date__c = Date.today().addDays(10);
        resubmitted.breg_Bypass_Status_Change_Validation__c = true;
        update resubmitted;

        Case approvedCase = seedCases[2];
        approvedCase.Status = 'Approved';
        approvedCase.Origin = 'Web';
        approvedCase.breg_Number_of_Delinquent_Annual_Reports__c = 0;
        approvedCase.breg_Is_Allowed_Generate_Reinstatem_Cert__c = false;
        approvedCase.breg_Bypass_Status_Change_Validation__c = true;

        Case allowedForCertCase = seedCases[3];
        allowedForCertCase.Status = 'Approved';
        allowedForCertCase.Origin = 'In Person';
        allowedForCertCase.breg_Is_Allowed_Generate_Reinstatem_Cert__c = true;
        allowedForCertCase.breg_Bypass_Status_Change_Validation__c = true;

        Case completedCase = seedCases[4];
        completedCase.Status = 'Completed';
        completedCase.breg_Duration_Period__c = '120';
        completedCase.breg_Bypass_Status_Change_Validation__c = true;

        Case withdrawnCase = seedCases[6];
        withdrawnCase.Status = 'Withdrawn';
        withdrawnCase.breg_Bypass_Status_Change_Validation__c = true;

        Case bouncedCase = seedCases[7];
        bouncedCase.Status = 'Bounced Check';
        bouncedCase.breg_Bypass_Status_Change_Validation__c = true;
        bouncedCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';

        resubmitted.Status = 'Received';
        resubmitted.breg_Form_Action__c = 'Resubmit';

        Test.startTest();
        update new List<Case>{ resubmitted, approvedCase, allowedForCertCase, completedCase, withdrawnCase, bouncedCase };
        Test.stopTest();

        Case refreshedResubmitted = [SELECT Id, Status FROM Case WHERE Id = :resubmitted.Id LIMIT 1];
        System.assertEquals('Received', refreshedResubmitted.Status, 'Resubmitted case should remain in Received status after update');
    }
    @isTest
    static void afterUpdateNoChangesToggleTriggersAnnualRobotTest() {
        upsert new BREG_Setting__c(
            SetupOwnerId = UserInfo.getUserId(),
            Annual_Robot_Enabled__c = true,
            Global_Data_Migration_Triggers_Disabled__c = true
        );

        Account entity = BREGAnnualRobotTestHelper.prepareEntity('TR-AN-1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('Annual Trigger');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annualRecord = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Account agentAccount = new Account(
            Name = 'Annual Trigger Agent',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Annual',
            breg_Last_Name__c = 'Director',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );
        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Annual',
            breg_Last_Name__c = 'Officer',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        BREGAnnualRobotTestHelper.AnnualCaseInput annualInput = BREGAnnualRobotTestHelper.buildAnnualCaseInput(
            entity,
            contactRecord,
            annualFormId,
            annualRecord.Id,
            annualRecord.breg_Filing_Year__c,
            'WI-AN-1',
            false,
            null,
            true
        );
        Case annualCase = BREGAnnualRobotTestHelper.createAnnualCase(annualInput);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);
        annualCase.breg_No_Changes__c = true;
        annualCase.breg_Effective_Date__c = annualRecord.breg_Filing_Date__c;
        update annualCase;

        Test.startTest();
        List<Case> loadedCases = BREGAnnualRobotEngine.queryCases(new Set<Id>{ annualCase.Id });
        BREGAnnualRobotEngine.EvaluationContext context = BREGAnnualRobotEngine.buildContext(loadedCases);
        List<BREGAnnualRobotRules.CaseOutcomePlan> plans = BREGAnnualRobotRules.buildOutcomePlans(loadedCases, context);
        BREGAnnualRobotRules.finalizeSuccessPlans(plans);
        BREGAnnualRobotRules.applyPlans(plans);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Annual_Robot_Status__c FROM Case WHERE Id = :annualCase.Id];
        System.assertEquals('Completed', updatedCase.breg_Annual_Robot_Status__c, 'Toggling No Changes to true on a Received annual case should trigger the annual robot.');
    }
    
    @isTest
    static void beforeInsertJurisdictionAndFormationLabelsSetFromPicklistOrFreeTextTest() {
        Id formId = getNonAnnualForm().Id;

        Case c = createCase();
        c.Subject = 'Label Mapping Insert Test';
        c.breg_Name_of_the_Entity__c = 'Label Mapping Insert Test Corporation';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity_Jurisdiction__c = 'US';
        c.breg_Formation_State__c = 'HI';
        c.breg_New_Entity_Jurisdiction__c = 'US';
        c.breg_New_Formation_State__c = 'CO';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [
            SELECT
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State_Label__c,
                breg_New_Entity_Jurisdiction_Label__c,
                breg_New_Formation_State_Label__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            'United States',
            inserted.breg_Entity_Jurisdiction_Label__c,
            'Jurisdiction label should map to picklist label or retain free text'
        );
        System.assertEquals('Hawaii', inserted.breg_Formation_State_Label__c, 'Formation state label should map to picklist label or retain free text');
        System.assertEquals(
            'United States',
            inserted.breg_New_Entity_Jurisdiction_Label__c,
            'New entity jurisdiction label should map to picklist label or retain free text'
        );
        System.assertEquals(
            'Colorado',
            inserted.breg_New_Formation_State_Label__c,
            'New formation state label should map to picklist label or retain free text'
        );
    }

    @isTest
    static void beforeUpdateJurisdictionAndFormationLabelsRefreshWhenSourceChangesTest() {
        Id formId = getNonAnnualForm().Id;

        Case c = createCase();
        c.Subject = 'Label Mapping Update Test';
        c.breg_Name_of_the_Entity__c = 'Label Mapping Update Test Corporation';
        c.breg_Form_Configuration__c = formId;
        c.breg_Entity_Jurisdiction__c = 'Initial Jurisdiction';
        c.breg_Formation_State__c = 'Initial Formation';
        c.breg_New_Entity_Jurisdiction__c = 'Initial New Jurisdiction';
        c.breg_New_Formation_State__c = 'Initial New Formation';
        insert c;

        Case insertedCase = [
            SELECT
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State_Label__c,
                breg_New_Entity_Jurisdiction_Label__c,
                breg_New_Formation_State_Label__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            'Initial Jurisdiction',
            insertedCase.breg_Entity_Jurisdiction_Label__c,
            'Jurisdiction label should refresh from changed source value'
        );
        System.assertEquals(
            'Initial Formation',
            insertedCase.breg_Formation_State_Label__c,
            'Formation state label should refresh from changed source value'
        );
        System.assertEquals(
            'Initial New Jurisdiction',
            insertedCase.breg_New_Entity_Jurisdiction_Label__c,
            'New entity jurisdiction label should refresh from changed source value'
        );
        System.assertEquals(
            'Initial New Formation',
            insertedCase.breg_New_Formation_State_Label__c,
            'New formation state label should refresh from changed source value'
        );

        insertedCase.breg_Entity_Jurisdiction__c = 'US';
        insertedCase.breg_Formation_State__c = 'CA';
        insertedCase.breg_New_Entity_Jurisdiction__c = 'US';
        insertedCase.breg_New_Formation_State__c = 'HI';

        TriggerUtils.disableTrigger = false;
        Test.startTest();
        update insertedCase;
        Test.stopTest();

        Case updated = [
            SELECT
                breg_Entity_Jurisdiction__c,
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State__c,
                breg_Formation_State_Label__c,
                breg_New_Entity_Jurisdiction__c,
                breg_New_Entity_Jurisdiction_Label__c,
                breg_New_Formation_State__c,
                breg_New_Formation_State_Label__c
            FROM Case
            WHERE Id = :insertedCase.Id
        ];

        System.assertEquals('US', updated.breg_Entity_Jurisdiction__c, 'Jurisdiction source field should be updated');
        System.assertEquals('CA', updated.breg_Formation_State__c, 'Formation source field should be updated');
        System.assertEquals('US', updated.breg_New_Entity_Jurisdiction__c, 'New jurisdiction source field should be updated');
        System.assertEquals('HI', updated.breg_New_Formation_State__c, 'New formation source field should be updated');

        System.assertEquals('United States', updated.breg_Entity_Jurisdiction_Label__c, 'Jurisdiction label should refresh from changed source value');
        System.assertEquals('California', updated.breg_Formation_State_Label__c, 'Formation state label should refresh from changed source value');
        System.assertEquals(
            'United States',
            updated.breg_New_Entity_Jurisdiction_Label__c,
            'New entity jurisdiction label should refresh from changed source value'
        );
        System.assertEquals('Hawaii', updated.breg_New_Formation_State_Label__c, 'New formation state label should refresh from changed source value');
    }

    @isTest
    static void testBeforeInsertPopulatesNSSearchFields() {
        Case c = createCase();
        c.Subject = 'NS Test';
        c.breg_Name_of_the_Entity__c = 'Māhoe Industries LLC';
        c.breg_Xref_Name_1__c = 'The Beaut\u00E9 Spot';
        c.breg_Xref_Name_2__c = 'Save-A-Wish';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c
            FROM Case
            WHERE Id = :c.Id
        ];
        Assert.areEqual('MAHOE INDUSTRIES LLC', inserted.breg_Search_Name_NS__c, 'Search Name NS should be normalized with spaces.');
        Assert.areEqual('BEAUTE SPOT', inserted.breg_Search_Xref_Name_1_NS__c, 'Xref 1 NS should be normalized with spaces.');
        Assert.areEqual('SAVE A WISH', inserted.breg_Search_Xref_Name_2_NS__c, 'Xref 2 NS should be normalized with spaces.');
    }

    @isTest
    static void testBeforeUpdatePopulatesNSSearchFieldsOnChange() {
        Case c = createCase();
        c.Subject = 'NS Update Test';
        c.breg_Name_of_the_Entity__c = 'Original Name';
        insert c;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        c.breg_Name_of_the_Entity__c = 'Ā\'ala Services LLC';
        c.breg_Xref_Name_1__c = 'Acme & Co.';
        update c;
        Test.stopTest();

        Case updated = [
            SELECT breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c
            FROM Case
            WHERE Id = :c.Id
        ];
        Assert.areEqual('AALA SERVICES LLC', updated.breg_Search_Name_NS__c, 'NS field should update when Name of Entity changes.');
        Assert.areEqual('ACME CO', updated.breg_Search_Xref_Name_1_NS__c, 'NS Xref 1 should update when source changes.');
    }


    @isTest
    static void testBeforeInsertPopulatesNeedToAddPageBreak() {
        String reasonWithPageBreak = buildBoundaryReasonForWebAndNonWebOrigins();

        Case c = createCase();
        c.Subject = 'Rejection Reason Page Break Insert Test';
        c.Origin = 'Web';
        c.breg_Rejection_Reason_Description__c = reasonWithPageBreak;

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [
            SELECT breg_Rejection_Reason_Description__c, breg_Need_to_Add_Page_Break__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            true,
            inserted.breg_Need_to_Add_Page_Break__c,
            'Before insert should calculate page break flag from rejection reason description.'
        );
    }

    @isTest
    static void testBeforeUpdatePopulatesNeedToAddPageBreakOnlyWhenDescriptionChanged() {
        String reasonWithPageBreak = buildBoundaryReasonForWebAndNonWebOrigins();

        Case c = createCase();
        c.Subject = 'Rejection Reason Page Break Update Test';
        c.Origin = 'Web';
        c.breg_Rejection_Reason_Description__c = 'Short rejection reason';
        insert c;

        Case inserted = [
            SELECT RecordTypeId, breg_Need_to_Add_Page_Break__c, breg_Rejection_Reason_Description__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            true,
            inserted.breg_Need_to_Add_Page_Break__c,
            'Insert should set initial page break flag.'
        );

        inserted.Subject = 'Rejection Reason Page Break Update Test - Subject Change';
        TriggerUtils.disableTrigger = false;
        update inserted;

        Case afterSubjectOnlyUpdate = [
            SELECT RecordTypeId, breg_Need_to_Add_Page_Break__c, breg_Rejection_Reason_Description__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(
            true,
            afterSubjectOnlyUpdate.breg_Need_to_Add_Page_Break__c,
            'Page break flag should not change when rejection reason description is unchanged.'
        );

        afterSubjectOnlyUpdate.breg_Rejection_Reason_Description__c = reasonWithPageBreak;
        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update afterSubjectOnlyUpdate;
        Test.stopTest();

        Case afterDescriptionUpdate = [
            SELECT breg_Need_to_Add_Page_Break__c, breg_Rejection_Reason_Description__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(
            true,
            afterDescriptionUpdate.breg_Need_to_Add_Page_Break__c,
            'Page break flag should recalculate when rejection reason description changes.'
        );
    }

    @isTest
    static void testBeforeInsertPageBreakThresholdIsLowerForWebOrigin() {
        String sameReason = buildBoundaryReasonForWebAndNonWebOrigins();

        Case webCase = createCase();
        webCase.Subject = 'Page Break Threshold Web';
        webCase.Origin = 'Web';
        webCase.breg_Rejection_Reason_Description__c = sameReason;

        Case nonWebCase = createCase();
        nonWebCase.Subject = 'Page Break Threshold Non-Web';
        nonWebCase.Origin = 'In Person';
        nonWebCase.breg_Rejection_Reason_Description__c = sameReason;

        Test.startTest();
        insert new List<Case>{ webCase, nonWebCase };
        Test.stopTest();

        Map<Id, Case> insertedById = new Map<Id, Case>([
            SELECT Id, Origin, breg_Need_to_Add_Page_Break__c
            FROM Case
            WHERE Id IN :new Set<Id>{ webCase.Id, nonWebCase.Id }
        ]);

        System.assertEquals(
            true,
            insertedById.get(webCase.Id).breg_Need_to_Add_Page_Break__c,
            'Web origin should trigger page break for this boundary text length.'
        );
        System.assertEquals(
            false,
            insertedById.get(nonWebCase.Id).breg_Need_to_Add_Page_Break__c,
            'Non-Web origin should not trigger page break for the same text length because Web applies the additional offset.'
        );
    }

    @isTest
    static void testBeforeUpdateRecalculatesNeedToAddPageBreakWhenOriginChanges() {
        String sameReason = buildBoundaryReasonForWebAndNonWebOrigins();

        Case c = createCase();
        c.Subject = 'Page Break Recalc On Origin Change';
        c.Origin = 'Web';
        c.breg_Rejection_Reason_Description__c = sameReason;
        insert c;

        Case inserted = [
            SELECT Id, Origin, breg_Rejection_Reason_Description__c, breg_Need_to_Add_Page_Break__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(true, inserted.breg_Need_to_Add_Page_Break__c, 'Baseline for Web should be true for this reason length.');

        inserted.Origin = 'In Person';
        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update inserted;
        Test.stopTest();

        Case updated = [
            SELECT Origin, breg_Rejection_Reason_Description__c, breg_Need_to_Add_Page_Break__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals('In Person', updated.Origin, 'Origin should be updated.');
        System.assertEquals(
            false,
            updated.breg_Need_to_Add_Page_Break__c,
            'Page break flag should be recalculated when origin changes even if rejection reason stays unchanged.'
        );
    }

    private static String buildTextOfLength(Integer length) {
        String result = '';
        while (result.length() < length) {
            result += '1234567890';
        }

        return result.substring(0, length);
    }

    private static String buildReasonWithLineCount(Integer lineCount) {
        return buildTextOfLength(getCharsPerLine() * (lineCount - 1) + 1);
    }

    private static String buildBoundaryReasonForWebAndNonWebOrigins() {
        for (Integer reasonLines = 1; reasonLines <= getPageLines() * 2; reasonLines++) {
            String reason = buildReasonWithLineCount(reasonLines);

            Boolean webAddsPageBreak = shouldAddPageBreakForTest(reason, 'Web');
            Boolean nonWebAddsPageBreak = shouldAddPageBreakForTest(reason, 'In Person');
            if (webAddsPageBreak && !nonWebAddsPageBreak) {
                return reason;
            }
        }

        System.assert(false, 'Unable to find a rejection reason length that differs between Web and non-Web origins.');
        return null;
    }

    private static Boolean shouldAddPageBreakForTest(String rejectionReason, String caseOrigin) {
        Integer linesBeforeRejectionReason = getLinesBeforeRejectionReason();
        if (caseOrigin == null || caseOrigin.equalsIgnoreCase('Web')) {
            linesBeforeRejectionReason += getNonWebPageBreakLinesOffset();
        }

        Integer linesAfterRejectionReason = getLinesAfterRejectionReason();
        Integer totalLines = linesBeforeRejectionReason + getEstimatedLineCountForTest(rejectionReason) + linesAfterRejectionReason;
        Integer remainderLastPage = Math.mod(totalLines, getPageLines());

        return remainderLastPage < linesAfterRejectionReason;
    }

    private static Integer getEstimatedLineCountForTest(String value) {
        if (String.isBlank(value)) {
            return 0;
        }

        Integer totalLines = 0;
        for (String paragraph : value.split('\\r\\n|\\n|\\r', -1)) {
            if (paragraph == '') {
                totalLines++;
            } else {
                totalLines += (Integer)Math.ceil((Decimal)paragraph.length() / getCharsPerLine());
            }
        }

        return totalLines;
    }

    @isTest
    static void testBeforeInsertSkipsBregLogicForDefaultRecordType() {
        Case c = new Case(
            Subject = 'Non-BREG Insert Test',
            Origin = 'Web',
            Status = 'Pending Submission',
            RecordTypeId = getNonBregCaseRecordTypeId(),
            breg_No_Changes__c = false,
            breg_Is_Amended__c = true,
            breg_Name_of_the_Entity__c = 'Non BREG Name',
            breg_Xref_Name_1__c = 'Non BREG Xref',
            breg_Entity_Jurisdiction__c = 'US',
            breg_Formation_State__c = 'HI'
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [
            SELECT
                Status,
                breg_Search_Name_NS__c,
                breg_Search_Xref_Name_1_NS__c,
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State_Label__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals('Pending Submission', inserted.Status, 'Amended status logic should not run for non-BREG record type');
        System.assertEquals(null, inserted.breg_Search_Name_NS__c, 'NS name field should not be populated for non-BREG record type');
        System.assertEquals(null, inserted.breg_Search_Xref_Name_1_NS__c, 'NS xref field should not be populated for non-BREG record type');
        System.assertEquals(null, inserted.breg_Entity_Jurisdiction_Label__c, 'Jurisdiction label should not be populated for non-BREG record type');
        System.assertEquals(null, inserted.breg_Formation_State_Label__c, 'Formation label should not be populated for non-BREG record type');
    }

    @isTest
    static void testBeforeUpdateSkipsBregLogicForDefaultRecordType() {
        Case c = new Case(
            Subject = 'Non-BREG Update Test',
            Origin = 'Web',
            Status = 'Pending Submission',
            RecordTypeId = getNonBregCaseRecordTypeId(),
            breg_No_Changes__c = false,
            breg_Is_Amended__c = true,
            breg_Name_of_the_Entity__c = 'Start Name'
        );
        insert c;

        c.breg_Name_of_the_Entity__c = 'Updated Non BREG Name';
        c.breg_Xref_Name_1__c = 'Updated Xref';
        c.breg_Entity_Jurisdiction__c = 'US';
        c.breg_Formation_State__c = 'HI';

        Test.startTest();
        update c;
        Test.stopTest();

        Case updated = [
            SELECT
                Status,
                breg_Search_Name_NS__c,
                breg_Search_Xref_Name_1_NS__c,
                breg_Entity_Jurisdiction_Label__c,
                breg_Formation_State_Label__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals('Pending Submission', updated.Status, 'Amended status logic should not run for non-BREG record type on update');
        System.assertEquals(null, updated.breg_Search_Name_NS__c, 'NS name field should remain unchanged for non-BREG record type');
        System.assertEquals(null, updated.breg_Search_Xref_Name_1_NS__c, 'NS xref field should remain unchanged for non-BREG record type');
        System.assertEquals(null, updated.breg_Entity_Jurisdiction_Label__c, 'Jurisdiction label should remain unchanged for non-BREG record type');
        System.assertEquals(null, updated.breg_Formation_State_Label__c, 'Formation label should remain unchanged for non-BREG record type');
    }


    // ===== createSearchLogsForRejectedToReceived tests =====

    private static Case getSeedCaseForSearchLogTest() {
        return [
            SELECT Id, Status, breg_New_Entity_Name__c, breg_Name_of_the_Entity__c, breg_Name_of_the_Entity_Previous__c
            FROM Case
            WHERE RecordType.DeveloperName = 'BREG_Case' AND breg_Form_Code__c != 'LLC-1'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
    }

    private static void rejectCase(Case theCase) {
        theCase.Status = 'Rejected';
        theCase.breg_Resubmission_Due_Date__c = Date.today().addDays(10);
        theCase.breg_Bypass_Status_Change_Validation__c = true;
        update theCase;
    }

    @isTest
    static void afterUpdateCreatesSearchLogWhenRejectedCaseResubmittedWithNameChangeTest() {
        Case seedCase = getSeedCaseForSearchLogTest();
        rejectCase(seedCase);

        seedCase.Status = 'Received';
        seedCase.breg_Name_of_the_Entity_Previous__c = 'Old Rejected Name';
        seedCase.breg_Bypass_Status_Change_Validation__c = true;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update seedCase;
        Test.stopTest();

        List<breg_Search_Log__c> logs = [
            SELECT breg_Case__c, breg_Search_Term__c, breg_Normalized_Search_Term__c, breg_Rejected_Name__c
            FROM breg_Search_Log__c
            WHERE breg_Case__c = :seedCase.Id
        ];

        System.assertEquals(1, logs.size(), 'A search log should be created for the rejected-to-received transition with a name change.');
        System.assertEquals('Old Rejected Name', logs[0].breg_Search_Term__c, 'Search term should be the previous entity name.');
        System.assertEquals(
            BREGUtils.cleanBusinessName('Old Rejected Name'),
            logs[0].breg_Normalized_Search_Term__c,
            'Normalized search term should be the cleaned previous entity name.'
        );
        System.assertEquals(true, logs[0].breg_Rejected_Name__c, 'Search log should be flagged as a rejected name.');
        System.assertEquals(seedCase.Id, logs[0].breg_Case__c, 'Search log should be linked to the case.');
    }

    @isTest
    static void afterUpdateSkipsSearchLogWhenPreviousNameBlankTest() {
        Case seedCase = getSeedCaseForSearchLogTest();
        rejectCase(seedCase);

        seedCase.Status = 'Received';
        seedCase.breg_Bypass_Status_Change_Validation__c = true;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update seedCase;
        Test.stopTest();

        List<breg_Search_Log__c> logs = [SELECT Id FROM breg_Search_Log__c WHERE breg_Case__c = :seedCase.Id];
        System.assertEquals(0, logs.size(), 'No search log should be created when the previous entity name is blank.');
    }

    @isTest
    static void afterUpdateSkipsSearchLogWhenPreviousNameMatchesCurrentNameTest() {
        Case seedCase = getSeedCaseForSearchLogTest();
        rejectCase(seedCase);

        seedCase.Status = 'Received';
        seedCase.breg_Name_of_the_Entity_Previous__c = seedCase.breg_New_Entity_Name__c;
        seedCase.breg_Bypass_Status_Change_Validation__c = true;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update seedCase;
        Test.stopTest();

        List<breg_Search_Log__c> logs = [SELECT Id FROM breg_Search_Log__c WHERE breg_Case__c = :seedCase.Id];
        System.assertEquals(0, logs.size(), 'No search log should be created when the previous entity name matches the current entity name.');
    }

    @isTest
    static void afterUpdateCreatesSearchLogsInBulkForMultipleRejectedToReceivedCasesTest() {
        List<Case> seedCases = [
            SELECT Id, Status, breg_New_Entity_Name__c, breg_Name_of_the_Entity__c, breg_Name_of_the_Entity_Previous__c
            FROM Case
            WHERE RecordType.DeveloperName = 'BREG_Case' AND breg_Form_Code__c != 'LLC-1'
            ORDER BY CreatedDate ASC
            LIMIT 3
        ];

        for (Case c : seedCases) {
            rejectCase(c);
        }

        Case changedNameCase = seedCases[0];
        changedNameCase.Status = 'Received';
        changedNameCase.breg_Name_of_the_Entity_Previous__c = 'Bulk Old Name One';
        changedNameCase.breg_Bypass_Status_Change_Validation__c = true;

        Case unchangedNameCase = seedCases[1];
        unchangedNameCase.Status = 'Received';
        unchangedNameCase.breg_Name_of_the_Entity_Previous__c = unchangedNameCase.breg_New_Entity_Name__c;
        unchangedNameCase.breg_Bypass_Status_Change_Validation__c = true;

        Case blankPreviousNameCase = seedCases[2];
        blankPreviousNameCase.Status = 'Received';
        blankPreviousNameCase.breg_Bypass_Status_Change_Validation__c = true;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update seedCases;
        Test.stopTest();

        List<breg_Search_Log__c> logs = [
            SELECT breg_Case__c, breg_Search_Term__c
            FROM breg_Search_Log__c
            WHERE breg_Case__c IN :new Set<Id>{ changedNameCase.Id, unchangedNameCase.Id, blankPreviousNameCase.Id }
        ];

        System.assertEquals(1, logs.size(), 'Only the case with a genuine name change should produce a search log.');
        System.assertEquals(changedNameCase.Id, logs[0].breg_Case__c, 'The search log should be linked to the case with the name change.');
        System.assertEquals('Bulk Old Name One', logs[0].breg_Search_Term__c, 'Search term should be the previous entity name for the changed case.');
    }
    
    @isTest
    static void afterUpdate_DraftInitialGenerated_WithPaidTransactionLine_SetsGenerationInProcess() {
        breg_Form_Configuration__c nonAnnualForm = getNonAnnualForm();

        Case c = createCase();
        c.Subject = 'Not Started With Paid Line';
        c.Origin = 'Web';
        c.breg_Form_Configuration__c = nonAnnualForm.Id;
        c.breg_Form_Code__c = 'X-1';
        c.breg_Bypass_Status_Change_Validation__c = true;
        insert c;

        Transaction__c trns = new Transaction__c();
        insert trns;

        insert new TransactionLine__c(
            Transaction__c = trns.Id,
            breg_Case__c = c.Id,
            PaidStatus__c = 'Paid',
            Amount__c = 100
        );

        c = [
            SELECT Id, breg_Document_Generation_Status__c, Origin, breg_Form_Code__c, breg_Form_Configuration__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];
        c.breg_Document_Generation_Status__c = 'Draft Initial generated';
        c.Origin = 'Web';
        c.breg_Form_Code__c = 'X-1';
        c.breg_Form_Configuration__c = nonAnnualForm.Id;

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update c;
        Test.stopTest();

        Case updated = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            'Generation in Process',
            updated.breg_Document_Generation_Status__c,
            'Case with paid transaction line should move from Draft Initial generated to Generation in Process'
        );
    }

    @isTest
    static void afterUpdate_DraftInitialGenerated_WithoutPaidTransactionLine_RemainsDraftInitialGenerated() {
        breg_Form_Configuration__c nonAnnualForm = getNonAnnualForm();

        Case c = createCase();
        c.Subject = 'Not Started No Paid Line';
        c.Origin = 'Web';
        c.breg_Form_Configuration__c = nonAnnualForm.Id;
        c.breg_Form_Code__c = 'X-1';
        c.breg_Bypass_Status_Change_Validation__c = true;
        insert c;

        Transaction__c trns = new Transaction__c();
        insert trns;

        insert new TransactionLine__c(
            Transaction__c = trns.Id,
            breg_Case__c = c.Id,
            PaidStatus__c = 'Pending',
            Amount__c = 100
        );

        c = [SELECT Id, breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        c.breg_Document_Generation_Status__c = 'Draft Initial generated';

        Test.startTest();
        TriggerUtils.disableTrigger = false;
        update c;
        Test.stopTest();

        Case updated = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            'Draft Initial generated',
            updated.breg_Document_Generation_Status__c,
            'Case without paid transaction line should remain Draft Initial generated'
        );
    }
}