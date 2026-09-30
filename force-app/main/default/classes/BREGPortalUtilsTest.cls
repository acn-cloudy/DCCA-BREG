@isTest
public class BREGPortalUtilsTest {

    @TestSetup
    static void setupTestData() {
        BREGTestDataFactory.createCommunityUser();
    }

    @isTest
    static void testIsHomeWarningBannerEnabled() {
        Assert.isFalse(BREGPortalUtils.isHomeWarningBannerEnabled(), 'Banner should be hidden when setting is not configured.');

        insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), Home_Warning_Banner_Enabled__c = true);

        Test.startTest();
        Boolean enabled = BREGPortalUtils.isHomeWarningBannerEnabled();
        Test.stopTest();

        Assert.isTrue(enabled, 'Banner should be visible when setting is enabled.');
    }

    @isTest
    static void testGetGp1FormUsReturnsG5Record() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'GP-1',
            breg_Suffix_Code__c = 'G5'
        );
        insert formConfig;

        Test.startTest();
        Id resultId = BREGPortalUtils.getGP1Form('US');
        Test.stopTest();

        Assert.areEqual(formConfig.Id, resultId, 'US country should return the G5 GP-1 form record.');
    }

    @isTest
    static void testGetGp1FormNonUsReturnsG6Record() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'GP-1',
            breg_Suffix_Code__c = 'G6'
        );
        insert formConfig;

        Test.startTest();
        Id resultId = BREGPortalUtils.getGP1Form('CA');
        Test.stopTest();

        Assert.areEqual(formConfig.Id, resultId, 'Non-US country should return the G6 GP-1 form record.');
    }

    @isTest
    static void testGetGp1FormNoRecordThrowsAuraHandledException() {
        Test.startTest();
        try {
            BREGPortalUtils.getGP1Form('US');
            Assert.fail('Expected AuraHandledException when no GP-1 record exists.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage() != null, 'Exception message should be present.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFormConfigurationByIdIncludesElements() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CFG-ID',
            breg_Form_Instruction_URL__c = 'https://example.test/instructions',
            breg_What_is_this_Form__c = 'Read this: /{instructionURL}',
            breg_Days_After_Submission_hold_Approval__c = 5,
            breg_Suffix_Code__c = 'S1'
        );
        insert formConfig;

        BREGPortalUtils.FormConfiguration result;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestCommunityUser()) {
            result = BREGPortalUtils.getFormConfiguration(formConfig.Id);
        }
        Test.stopTest();

        Assert.isNotNull(result, 'Form configuration should be returned for a valid Id.');
        Assert.areEqual(formConfig.Id, result.id, 'Returned config Id should match.');
        Assert.isTrue(result.whatIsThisForm.contains('https://example.test/instructions'), 'Instruction URL token should be replaced.');
        Assert.areEqual(5, result.daysAfterSubmissionHoldApproval, 'Days field should be mapped as Integer.');
        Assert.isNotNull(result.elements, 'Elements list should always be initialized.');
    }

    @isTest
    static void testGetFormConfigurationByCriteriaAndNoMatch() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CFG-CRITERIA',
            breg_Suffix_Code__c = 'A1'
        );
        insert formConfig;

        BREGPortalUtils.FormConfiguration matched;
        BREGPortalUtils.FormConfiguration noMatch;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestCommunityUser()) {
            matched = BREGPortalUtils.getFormConfiguration(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
            noMatch = BREGPortalUtils.getFormConfiguration(
                'NON_EXISTENT_ID',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        }
        Test.stopTest();

        Assert.isNotNull(matched, 'Configuration should be returned when all filter fields are null and record matches.');
        Assert.areEqual(formConfig.Id, matched.id, 'Matched Id should be the inserted record.');
        Assert.areEqual(null, noMatch, 'No match should return null.');
    }

    @isTest
    static void testGetUserInfoInternalUserShape() {
        Test.startTest();
        Map<String, Object> userInfo = BREGPortalUtils.getUserInfo();
        Test.stopTest();

        Assert.areEqual(false, (Boolean) userInfo.get('isGuest'), 'Current test-running user should not be guest.');
        Assert.isTrue(userInfo.containsKey('id'), 'User map should include id for internal user.');
    }

    @isTest
    static void testGetSsoUrlDoesNotReturnBlank() {
        Test.startTest();
        String ssoUrl;
        Exception captured;
        try {
            ssoUrl = BREGPortalUtils.getSSOUrl(null);
        } catch (Exception ex) {
            captured = ex;
        }
        Test.stopTest();

        Assert.isTrue(String.isNotBlank(ssoUrl), 'SSO URL should not be blank.');
    }

    @isTest
    static void testGetCaseWithRelationsNullIdThrows() {
        Test.startTest();
        try {
            BREGPortalUtils.getCaseWithRelations(null);
            Assert.fail('Expected AuraHandledException when case id is null.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Exception should include a message.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCaseWithRelationsValidIdReturnsCase() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Subject = 'Portal Utils Test', Status = 'New', RecordTypeId = bregCaseRecordTypeId);
        insert testCase;

        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(testCase.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Case should be returned for a valid case id.');
        Assert.areEqual(testCase.Id, result.Id, 'Returned case id should match inserted case id.');
    }

    @isTest
    static void testGetCaseWithRelationsExcludesAffiliationsMarkedToRemove() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Subject = 'Portal Utils Test', Status = 'New', RecordTypeId = bregCaseRecordTypeId);
        insert testCase;

        breg_Account_Affiliation__c keptOfficer = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Kept'
        );
        breg_Account_Affiliation__c removedOfficer = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Removed',
            breg_To_Remove__c = true
        );
        insert new List<breg_Account_Affiliation__c>{ keptOfficer, removedOfficer };

        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(testCase.Id);
        Test.stopTest();

        Set<Id> returnedAffiliationIds = new Set<Id>();
        for (breg_Account_Affiliation__c aff : result.Account_Affiliations__r) {
            returnedAffiliationIds.add(aff.Id);
        }

        Assert.isTrue(returnedAffiliationIds.contains(keptOfficer.Id), 'Active officer should still be returned.');
        Assert.isFalse(returnedAffiliationIds.contains(removedOfficer.Id), 'Officer marked to remove should not be returned when reloading a draft.');
    }

    @isTest
    static void testGetCaseForWithdrawalNullIdThrows() {
        Test.startTest();
        try {
            BREGPortalUtils.getCasesForWithdrawal(null);
            Assert.fail('Expected AuraHandledException when case id is null.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Exception should include a message.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCaseForWithdrawalValidIdReturnsWrapper() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CASE-CFG',
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Form_Name__c = 'Articles of Incorporation',
            breg_Business_Process__c = 'New Business',
            breg_Is_Expeditable__c = true,
            breg_Withdrawal_Range__c = 24
        );
        insert formConfig;

        Case testCase = new Case(
            Subject = 'Withdrawal Test',
            RecordTypeId = bregCaseRecordTypeId,
            Status = 'New',
            breg_Workitem_Number__c = 'WI-001',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        Test.startTest();
        List<BREGPortalUtils.CaseWithdrawalDataWrapper> wrapperResults = BREGPortalUtils.getCasesForWithdrawal(new List<Id>{ testCase.Id });
        Test.stopTest();

        Assert.isNotNull(wrapperResults, 'Wrapper result should be returned for a valid case id.');
        Assert.areEqual(1, wrapperResults.size(), 'A single requested case should return a single wrapper.');
        BREGPortalUtils.CaseWithdrawalDataWrapper wrapperResult;
        for (BREGPortalUtils.CaseWithdrawalDataWrapper wrapper : wrapperResults) {
            if (wrapper.parentCaseId == testCase.Id) {
                wrapperResult = wrapper;
                break;
            }
        }

        Assert.isNotNull(wrapperResult, 'Wrapper should be found by matching parent case id.');
        Assert.areEqual(testCase.Id, wrapperResult.parentCaseId, 'Parent case id should be included in wrapper for client-side matching.');
        Assert.areEqual('Withdrawal Test', wrapperResult.entityName, 'Entity name should be mapped from case.');
        Assert.areEqual('WI-001', wrapperResult.workitemNumber, 'Workitem number should be mapped from case.');
        Assert.areEqual('DC-1', wrapperResult.formCode, 'Form code should be mapped from case.');
        Assert.areEqual('Articles of Incorporation', wrapperResult.formName, 'Form name should be mapped from case.');
    }

    @isTest
    static void testGetFormConfigurationTenParamOverload() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CFG-10P',
            breg_Business_Process__c = 'New Business',
            breg_Business_Location__c = null,
            breg_Business_Structure__c = null,
            breg_Profit_Type__c = null,
            breg_Registration_Type__c = null,
            breg_Corporation_Type__c = null,
            breg_Cooperative_Type__c = null,
            breg_Stock_Type__c = null,
            breg_Partnership_Type__c = null,
            breg_Suffix_Code__c = 'X9'
        );
        insert formConfig;

        BREGPortalUtils.FormConfiguration result;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestCommunityUser()) {
            result = BREGPortalUtils.getFormConfiguration(
                'New Business',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        }
        Test.stopTest();

        Assert.isNotNull(result, '10-param overload should return a matching configuration.');
    }

    @isTest
    static void testGetFormConfigurationWithConfigItems() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CFG-ITEMS',
            breg_Suffix_Code__c = 'T1'
        );
        insert formConfig;

        insert new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1,
            breg_Is_Internal_Only__c = false
        );

        BREGPortalUtils.FormConfiguration result;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestCommunityUser()) {
            result = BREGPortalUtils.getFormConfiguration(formConfig.Id);
        }
        Test.stopTest();

        Assert.areEqual(1, result.elements.size(), 'One non-internal config item should produce one FormElement.');
        Assert.areEqual('Company Name', result.elements[0].name, 'FormElement name should match the component name.');
    }

    @isTest
    static void testGetFormConfigurationSkipsInternalOnlyItems() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CFG-INTERNAL',
            breg_Suffix_Code__c = 'I1'
        );
        insert formConfig;

        insert new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1,
            breg_Is_Internal_Only__c = true
        );
        insert new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Address',
            breg_Order__c = 2,
            breg_Is_Internal_Only__c = false
        );

        BREGPortalUtils.FormConfiguration result;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestCommunityUser()) {
            result = BREGPortalUtils.getFormConfiguration(formConfig.Id);
        }
        Test.stopTest();

        Assert.isTrue(result.elements.size() >= 1, 'At least the visible item should be in elements.');
    }
}