/**
 * Test class for BREGCaseStatusHandlerBase
 * Tests validation logic, payment checks, and form configuration item handling
 */
@isTest
public class BREGCaseStatusHandlerBaseTest {
    /**
     * Setup test data for all test methods
     */
    @TestSetup
    public static void setupTestData() {
        // Create form configurations
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1'
        );
        breg_Form_Configuration__c testFormConfig2 = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'DC-3', breg_Form_Code__c = 'DC-3');
        insert new List<breg_Form_Configuration__c>{ testFormConfig, testFormConfig2 };

        // Create form configuration items with required fields
        List<breg_Form_Configuration_Item__c> formConfigItems = new List<breg_Form_Configuration_Item__c>();

        // Add a form config item with required fields for 'Approved' status
        formConfigItems.add(
            new breg_Form_Configuration_Item__c(
                breg_Form_Configuration__c = testFormConfig.Id,
                breg_Component_Name__c = 'Company Name',
                breg_Required_for_Statuses__c = 'Approved',
                breg_Target_Fields_Mapping__c = '{"companyName":"Case.breg_New_Registrant_First_Name__c"}',
                breg_Order__c = 1
            )
        );
        formConfigItems.add(
            new breg_Form_Configuration_Item__c(
                breg_Form_Configuration__c = testFormConfig2.Id,
                breg_Component_Name__c = 'Company Name',
                breg_Required_for_Statuses__c = 'Approved',
                breg_Target_Fields_Mapping__c = '{"companyName":"Case.breg_New_Registrant_First_Name__c"}',
                breg_Order__c = 1
            )
        );

        // Add a form config item with custom validation class
        formConfigItems.add(
            new breg_Form_Configuration_Item__c(
                breg_Form_Configuration__c = testFormConfig.Id,
                breg_Component_Name__c = 'Applicant',
                breg_APEX_Validation_Class_Name__c = 'BREGCaseStatusHandlerBaseTest.BREGCaseStatusHandlerBaseTestMockValidation',
                breg_Target_Fields_Mapping__c = '{"firstName":"Case.breg_New_Registrant_First_Name__c","lastName":"Case.breg_New_Registrant_Last_Name__c"}',
                breg_Order__c = 2
            )
        );

        // Add a form config item with no validation
        formConfigItems.add(
            new breg_Form_Configuration_Item__c(
                breg_Form_Configuration__c = testFormConfig.Id,
                breg_Component_Name__c = 'Address',
                breg_Target_Fields_Mapping__c = '{"address":"Case.breg_Company_Address__Street__s"}',
                breg_Order__c = 1
            )
        );

        insert formConfigItems;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        // Create test case
        Case testCase = new Case(
            Subject = 'Test Case for ' + testFormConfig.breg_Entity_Type__c,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Name_of_the_Entity__c = 'Corporation Company LLC',
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'DC-1'
        );
        Case testCase2 = new Case(
            Subject = 'Test Case for ' + testFormConfig2.breg_Form_Code__c,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Name_of_the_Entity__c = 'Corporation Company LLC',
            breg_Form_Configuration__c = testFormConfig2.Id,
            breg_Form_Code__c = 'DC-3'
        );

        insert new List<Case>{ testCase, testCase2 };
    }

    /**
     * Test successful status change without validation or actions
     */
    @isTest
    static void testHandleStatusChangeNoValidationNoActions() {
        // Get test case
        Case testCase = [SELECT breg_Form_Code__c, Status, breg_Form_Configuration__c FROM Case LIMIT 1];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler without validation or actions
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, false);
        Test.stopTest();

        // Verify no errors occurred
        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual('New', updatedCase.Status, 'Case status should remain unchanged');
    }

    /**
     * Test status change with validation that passes
     */
    @isTest
    static void testHandleStatusChangeWithValidationSuccess() {
        // Get test case and update required fields
        Case testCase = [
            SELECT
                breg_Form_Code__c,
                Status,
                breg_Form_Configuration__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Due_Date__c,
                breg_Name_of_the_Entity__c,
                breg_Resubmission_Received_Date__c,
                breg_Effective_Date__c,
                breg_Entity__c,
                breg_Reg_Agent_Type__c,
                breg_File__c,
                breg_Override_Payment__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_New_Registrant_First_Name__c = 'John';
        testCase.breg_Effective_Date__c = Date.today();
        update testCase;

        // Create completed payment for the case
        createCompletedPayment(testCase.Id);

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler with validation - should pass
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        Test.stopTest();
        // Verify no errors occurred - case should still exist
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful validation');
    }

    /**
     * Test validation class that exists but does not implement BREGIFormFieldValidation
     */
    @isTest
    static void testValidationClassWithoutRequiredInterface() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1'
        );
        insert formConfig;

        breg_Form_Configuration_Item__c formConfigItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Name',
            breg_Apex_Validation_Class_Name__c = 'BREGCaseStatusHandlerBase',
            breg_Target_Fields_Mapping__c = '{"companyName":"Case.breg_New_Registrant_First_Name__c"}',
            breg_Order__c = 1
        );
        insert formConfigItem;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Invalid Interface Validation Class',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Corporation Company LLC'
        );
        insert testCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Rejected', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Exception should be thrown when validation class does not implement interface');
        Assert.isTrue(exceptionMessage.contains('must implement BREGIFormFieldValidation interface'), 'Error should explain interface requirement');
    }

    /**
     * Test shares count validation for Pending Submission status
     */
    @isTest
    static void testPendingSubmissionSharesCountValidationFailure() {
        Case testCase = new Case(breg_Outstanding_Shares_Count__c = 200, breg_Authorized_Shares_Count__c = 100);

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Exception should be thrown for invalid shares count');
        Assert.isTrue(
            exceptionMessage.contains('issued shares can not exceed the number of authorized shares'),
            'Error should mention shares count validation'
        );
    }

    /**
     * Test validation failure for missing required fields
     */
    @isTest
    static void testValidationFailureMissingRequiredFields() {
        // Get test case without setting required fields
        Case testCase = [SELECT breg_Form_Code__c, Status, breg_Form_Configuration__c FROM Case LIMIT 1];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            // Call handler with validation - should fail due to missing required field
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown for missing required field');
        Assert.isTrue(exceptionMessage.contains('is a required field'), 'Error message should mention required field');
    }

    @isTest
    static void testApprovedStatusBlocksCaseWhenLinkedEntityIsClosed() {
        Case testCase = [
            SELECT Id, breg_Form_Code__c, breg_Entity__c, breg_Form_Configuration__c,
                breg_New_Registrant_First_Name__c, breg_New_Registrant_Last_Name__c,
                breg_Effective_Date__c, breg_File__c, breg_Override_Payment__c,
                breg_Resubmission_Received_Date__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];

        Id accountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account entity = new Account(
            Name = 'Closed Entity Test',
            RecordTypeId = accountRtId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Terminated (T)'
        );
        insert entity;

        testCase.breg_Entity__c = entity.Id;
        testCase.breg_Name_of_the_Entity__c = entity.Name;
        testCase.breg_New_Registrant_First_Name__c = 'John';
        testCase.breg_New_Registrant_Last_Name__c = 'Doe';
        testCase.breg_Effective_Date__c = Date.today();
        testCase.breg_File__c = 'FILE-1001';
        update testCase;

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Approval should fail when the linked entity is in a closed status');
        Assert.isTrue(
            exceptionMessage.contains(BREGCaseStatusHandlerBase.ERROR_ENTITY_STATUS_CLOSED),
            'Approval error should mention the closed-entity validation message'
        );
    }

    @isTest
    static void testApprovedStatusAllowsClosedEntityForReinstatementForm() {
        Id accountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account entity = new Account(
            Name = 'Reinstatement Entity',
            RecordTypeId = accountRtId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Terminated (T)'
        );
        insert entity;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c x4Config = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'X-4',
            breg_Suffix_Code__c = 'X-4'
        );
        insert x4Config;

        Case x4Case = new Case(
            Subject = 'X-4 Reinstatement case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = x4Config.Id,
            breg_Form_Code__c = 'X-4',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_File__c = 'FILE-1002',
            breg_Name_of_the_Entity__c = 'Reinstatement Entity'
        );
        insert x4Case;

        createCompletedPayment(x4Case.Id);

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ x4Case }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'Closed entity should be ignored for Reinstatement forms like X-4');
    }

    @isTest
    static void testFormationStateNotRequiredWhenJurisdictionHasNoStates() {
        String countryWithoutStates = getCountryCodeByStateRequirement(false);
        String requiredStatus = getRequiredStatusForTest();
        if (countryWithoutStates == null) {
            Assert.isTrue(true, 'No active country without states found in org metadata; skipping assertion.');
            return;
        }
        Assert.isNotNull(requiredStatus, 'An active Required-for-Statuses value is required for this test.');

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1'
        );
        insert formConfig;

        breg_Form_Configuration_Item__c requiredFormationState = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Jurisdiction',
            breg_Required_for_Statuses__c = requiredStatus,
            breg_Target_Fields_Mapping__c = '{"formationState":"Case.breg_Formation_State__c", "country": "Case.breg_Entity_Jurisdiction__c"}',
            breg_Order__c = 1
        );
        insert requiredFormationState;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Formation State Optional for Country Without States',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity Without States',
            breg_Entity_Jurisdiction__c = countryWithoutStates,
            breg_Formation_State__c = null
        );
        insert testCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, requiredStatus, true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'Formation state should not be required for countries without states.');
        Assert.isFalse(
            String.isNotBlank(exceptionMessage) && exceptionMessage.contains('Formation State'),
            'No formation state required-field error should be raised.'
        );
    }

    @isTest
    static void testFormationStateRequiredWhenJurisdictionHasStates() {
        String countryWithStates = getCountryCodeByStateRequirement(true);
        String requiredStatus = 'Approved';
        Assert.isNotNull(countryWithStates, 'An active country with states is required for this test.');

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1'
        );
        insert formConfig;

        breg_Form_Configuration_Item__c requiredFormationState = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Jurisdiction',
            breg_Required_for_Statuses__c = requiredStatus,
            breg_Target_Fields_Mapping__c = '{"formationState":"Case.breg_Formation_State__c", "country": "Case.breg_Entity_Jurisdiction__c"}',
            breg_Order__c = 1
        );
        insert requiredFormationState;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Formation State Required for Country With States',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity With States',
            breg_Entity_Jurisdiction__c = countryWithStates,
            breg_Effective_Date__c = Date.today(),
            breg_Formation_State__c = null
        );
        insert testCase;

        createCompletedPayment(testCase.Id);

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, requiredStatus, true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Formation state should be required for countries that have states.');
        Assert.isTrue(
            String.isNotBlank(exceptionMessage) && exceptionMessage.contains('is a required field'),
            'Required-field error should be raised for missing formation state.'
        );
    }

    /**
     * Test payment validation for Approved status
     */
    @isTest
    static void testValidationFailureNoPayment() {
        // Get test case and set required fields
        Case testCase = [
            SELECT breg_Form_Code__c, Status, breg_Override_Payment__c, breg_Form_Configuration__c, breg_Name_of_the_Entity__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_New_Registrant_First_Name__c = 'John';
        update testCase;

        // Do NOT create payment - validation should fail

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            // Call handler with validation - should fail due to no payment
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown for missing payment');
        Assert.isTrue(exceptionMessage.contains('payment'), 'Error message should mention payment');
    }

    /**
     * Test payment validation is skipped for DOCDLVR form code
     */
    @isTest
    static void testValidationNoPaymentRequiredForDOCDLVR() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account entity = new Account(Name = 'Doc Delivery Entity', RecordTypeId = bregAccountRecordTypeId);
        insert entity;

        breg_Form_Configuration__c docFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'DOCDLVR',
            breg_Form_Code__c = 'DOCDLVR'
        );
        insert docFormConfig;

        Case docCase = new Case(
            Subject = 'Test DOCDLVR No Payment',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = docFormConfig.Id,
            breg_Form_Code__c = 'DOCDLVR',
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert docCase;

        TestableHandler handler = new TestableHandler();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.invokeValidatePaymentCompletion(new List<Case>{ docCase });
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'DOCDLVR should be skipped by payment validation logic.');
        Assert.isFalse(
            String.isNotBlank(exceptionMessage) && exceptionMessage.contains('payment'),
            'Payment validation message should not be raised for DOCDLVR'
        );
    }

    /**
     * Test custom validation class that implements BREGIFormFieldValidation
     */
    @isTest
    static void testCustomValidationClassSuccess() {
        // Get test case and set required fields
        Case testCase = [
            SELECT
                breg_Form_Code__c,
                Status,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_New_Registrant_First_Name__c,
                breg_New_Registrant_Last_Name__c,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Effective_Date__c,
                breg_Entity__c,
                breg_Reg_Agent_Type__c,
                breg_File__c,
                breg_Is_LLP_Registration__c,
                breg_Override_Payment__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_New_Registrant_First_Name__c = 'John';
        testCase.breg_New_Registrant_Last_Name__c = 'Doe';
        testCase.breg_Effective_Date__c = Date.today();
        update testCase;

        // Create completed payment
        createCompletedPayment(testCase.Id);

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler with validation - custom validation should pass
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        Test.stopTest();

        // Verify no errors occurred
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful custom validation');
    }

    /**
     * Test custom validation class that fails validation
     */
    @isTest
    static void testCustomValidationClassFailure() {
        // Get test case and set fields that will fail custom validation
        Case testCase = [
            SELECT
                breg_Form_Code__c,
                Status,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_New_Registrant_First_Name__c,
                breg_New_Registrant_Last_Name__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Last_Rejection_Date__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_New_Registrant_First_Name__c = 'Invalid'; // Will trigger validation failure
        testCase.breg_New_Registrant_Last_Name__c = 'Doe';
        update testCase;

        // Create completed payment
        createCompletedPayment(testCase.Id);

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            // Call handler with validation - custom validation should fail
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown for failed custom validation');
        Assert.isTrue(exceptionMessage.contains('Invalid'), 'Error message should reference validation failure');
    }

    /**
     * Test validation with non-approved status (should skip payment validation)
     */
    @isTest
    static void testValidationNonApprovedStatus() {
        // Get test case without payment
        Case testCase = [
            SELECT
                breg_Form_Code__c,
                Status,
                breg_Resubmission_Received_Date__c,
                breg_Form_Configuration__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Due_Date__c
            FROM Case
            LIMIT 1
        ];
        testCase.breg_New_Registrant_First_Name__c = 'John';
        update testCase;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler with Rejected status - should not check payment
        handler.handleStatusChange(new List<Case>{ testCase }, 'Rejected', true, false);
        Test.stopTest();

        // Verify no errors occurred (payment check should be skipped)
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist - payment validation skipped for non-Approved status');
    }

    /**
     * Test bulk processing of multiple cases
     */
    // @isTest
    // static void testBulkProcessing() {
    //     // Get multiple test cases
    //     List<Case> testCases = [SELECT breg_Form_Code__c, Status, breg_Form_Configuration__c, breg_Name_of_the_Entity__c
    //                             FROM Case LIMIT 5];

    //     // Update required fields for all cases
    //     for (Case c : testCases) {
    //         c.breg_Name_of_the_Entity__c = 'Corporation Company LLC ' + c.Id;
    //     }
    //     update testCases;

    //     // Create payments for all cases
    //     for (Case c : testCases) {
    //         createCompletedPayment(c.Id);
    //     }

    //     // Create handler instance
    //     BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

    //     Test.startTest();
    //     // Call handler with multiple cases
    //     handler.handleStatusChange(testCases, 'Approved', true, false);
    //     Test.stopTest();

    //     // Verify all cases processed successfully
    //     List<Case> updatedCases = [SELECT Id FROM Case WHERE Id IN :testCases];
    //     Assert.areEqual(5, updatedCases.size(), 'All cases should be processed successfully');
    // }

    /**
     * Test handling cases with no form configuration items
     */
    @isTest
    static void testCasesWithNoFormConfigItems() {
        // Create a form config without items
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(breg_Entity_Type__c = 'D1', breg_Suffix_Code__c = 'D1');
        insert formConfig;

        // Create a case with this form config
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Name_of_the_Entity__c = 'Corporation Company LLC',
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler - should handle gracefully with no config items
        handler.handleStatusChange(new List<Case>{ testCase }, 'Rejected', true, false);
        Test.stopTest();

        // Verify no errors occurred
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after validation with no config items');
    }

    /**
     * Test handling with invalid JSON in target fields mapping
     */
    @isTest
    static void testInvalidJsonInTargetFieldsMapping() {
        // Create form config with invalid JSON
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(breg_Entity_Type__c = 'D1', breg_Suffix_Code__c = 'D1');
        insert formConfig;

        // Create form config item with invalid JSON
        breg_Form_Configuration_Item__c formConfigItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Component_Name__c = 'Company Name',
            breg_Target_Fields_Mapping__c = 'invalid json',
            breg_Order__c = 1
        );
        insert formConfigItem;

        // Create a case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Name_of_the_Entity__c = 'Corporation Company LLC',
            breg_New_Registrant_First_Name__c = 'John',
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        // Call handler - should handle invalid JSON gracefully
        handler.handleStatusChange(new List<Case>{ testCase }, 'Rejected', true, false);
        Test.stopTest();

        // Verify case still exists (invalid JSON should be handled gracefully)
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after handling invalid JSON');
    }

    /**
     * Test approved actions for NBR form - creates Account, and Received creates Transaction
     */
    @isTest
    static void testApprovedActionsForNBRForm() {
        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Structure__c = 'Corporation',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create NBR case
        Case nbrCase = new Case(
            Subject = 'Test NBR Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test NBR Entity LLC Corporation',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify Account was created
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name = 'Test NBR Entity LLC Corporation'];
        Assert.areEqual(1, accounts.size(), 'Account should be created for NBR form');

        // On Approved, transactions are no longer created by base handler
        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c WHERE breg_Case__c = :nbrCase.Id];
        Assert.areEqual(0, transactions.size(), 'No transaction should be created on Approved for NBR form in base handler');

        // Verify Case was updated with Entity
        Case updatedCase = [SELECT Id, breg_Entity__c, breg_Form_Code__c FROM Case WHERE Id = :nbrCase.Id];
        Assert.isNotNull(updatedCase.breg_Entity__c, 'Case should be linked to Entity');

        // On Received, transaction should be created
        handler.handleStatusChange(new List<Case>{ updatedCase }, 'Received', false, true);

        List<breg_Transaction__c> receivedTransactions = [
            SELECT Id, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :nbrCase.Id
        ];
        Assert.areEqual(1, receivedTransactions.size(), 'Transaction should be created on Received for NBR form');
        Assert.areEqual('R', receivedTransactions[0].breg_Status__c, 'Received transaction should have status R');
    }

    @isTest
    static void testApprovedActionsForNBRFormPopulatesConsentSimilarNameAndTerm() {
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Structure__c = 'Corporation',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case nbrCase = new Case(
            Subject = 'Test NBR Case With Consent',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test NBR Entity With Consent Corporation',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St',
            breg_Effective_Date__c = Date.today(),
            breg_Consent__c = 'Consent from Existing Corp',
            breg_Similar_Name__c = 'Existing Similar Corp',
            breg_Duration_Period__c = 'At-will'
        );
        insert nbrCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        Account entity = [
            SELECT breg_Consent__c, breg_Similar_Name__c, breg_Term__c, breg_Partner_Term__c
            FROM Account
            WHERE Name = 'Test NBR Entity With Consent Corporation'
        ];
        Assert.areEqual('Consent from Existing Corp', entity.breg_Consent__c, 'Consent should be copied from Case to Account');
        Assert.areEqual('Existing Similar Corp', entity.breg_Similar_Name__c, 'Similar Name should be copied from Case to Account');
        Assert.areEqual('AT-WILL', entity.breg_Term__c, 'Term should be derived from Duration Period');
        Assert.isNull(entity.breg_Partner_Term__c, 'Partner Term should not be set for a Corporation');
    }

    /**
     * Test approved actions for TNTMSM form - creates Account, TNTMSM, and Transaction
     */
    static void helperApprovedActionsForTNTMSMForm() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account existingAccount = new Account(Name = 'Test Trade Name Entity', RecordTypeId = bregAccountRtId, breg_Entity_Type__c = 'D1');
        insert existingAccount;
        breg_TN_TM_SM__c existingTntmsm = new breg_TN_TM_SM__c(Name = 'My Trade Name', breg_Account__c = existingAccount.Id, breg_Status__c = 'A');
        insert existingTntmsm;

        // Create TNTMSM form configuration
        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create TNTMSM case
        Case tntmsmCase = new Case(
            Subject = 'Test TNTMSM Case',
            Status = 'Completed',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Test Trade Name Entity',
            breg_Entity__c = existingAccount.Id,
            breg_TN_TM_SM__c = existingTntmsm.Id,
            breg_TNTMSM_Description__c = 'My Trade Name',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St',
            breg_Effective_Date__c = Date.today(),
            breg_Applicant_Is_Entity__c = false,
            breg_Applicant_First_Name__c = 'John',
            breg_Applicant_Last_Name__c = 'Doe',
            breg_Xref_Name_1__c = 'XREF1 Value',
            breg_Xref_Name_2__c = 'XREF2 Value'
        );
        insert tntmsmCase;

        // Create applicant affiliation
        breg_Account_Affiliation__c applicant = new breg_Account_Affiliation__c(
            breg_Case__c = tntmsmCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe'
        );
        insert applicant;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            handler.handleStatusChange(new List<Case>{ tntmsmCase }, 'Approved', false, false);
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Assert.isFalse(exceptionThrown, 'Handler invocation should succeed with no actions for Individual applicant setup');

        breg_Account_Affiliation__c insertedApplicant = [
            SELECT breg_Type__c, breg_First_Name__c, breg_Last_Name__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :tntmsmCase.Id AND breg_Role__c = 'Applicant'
            LIMIT 1
        ];
        Assert.areEqual('Individual', insertedApplicant.breg_Type__c, 'Applicant should remain Individual');
        Assert.areEqual('John', insertedApplicant.breg_First_Name__c, 'Applicant first name should remain John');
        Assert.areEqual('Doe', insertedApplicant.breg_Last_Name__c, 'Applicant last name should remain Doe');
    }

    /**
     * Test approved actions with free email notification subscription
     */
    @isTest
    static void testApprovedActionsWithEmailNotification() {
        // Create contact for notification
        Id bregContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BREG_Contact').getRecordTypeId();

        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com', RecordTypeId = bregContactRecordTypeId);
        insert testContact;

        // Create TNTMSM form configuration
        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create TNTMSM case with subscription flag
        Case tntmsmCase = new Case(
            Subject = 'Test TNTMSM Case with Subscription',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Test Entity Corporation With Subscription',
            breg_TNTMSM_Description__c = 'Subscribed Trade Name',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St',
            breg_Effective_Date__c = Date.today(),
            breg_Subscribe_Owner_Free_Email_Alerts__c = true,
            ContactId = testContact.Id
        );
        insert tntmsmCase;

        // Create applicant affiliation
        breg_Account_Affiliation__c applicant = new breg_Account_Affiliation__c(
            breg_Case__c = tntmsmCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Test Entity Corporation With Subscription'
        );
        insert applicant;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ tntmsmCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify notification was created
        List<breg_Notification__c> notifications = [
            SELECT Id, breg_Notification_Category__c, breg_Status__c, breg_Free_Of_Charge__c
            FROM breg_Notification__c
            WHERE breg_Contact__c = :testContact.Id
        ];
        Assert.areEqual(1, notifications.size(), 'Notification should be created for subscription');
        Assert.areEqual(true, notifications[0].breg_Free_Of_Charge__c, 'Notification should be Free of Charge');
        Assert.areEqual('Active', notifications[0].breg_Status__c, 'Notification status should be Active');
    }

    /**
     * Test approved actions updates Account Affiliations with lookups
     */
    @isTest
    static void testApprovedActionsUpdatesAccountAffiliations() {
        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Structure__c = 'Corporation',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create NBR case
        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Affiliations',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity Corporation for Affiliations',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        // Create account affiliation without entity link
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = nbrCase.Id,
            breg_Role__c = 'Officer',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe'
        );
        insert affiliation;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify Account Affiliation was updated with Entity lookup
        breg_Account_Affiliation__c updatedAff = [SELECT breg_Entity__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.isNotNull(updatedAff.breg_Entity__c, 'Account Affiliation should be linked to Entity');
    }

    /**
     * Test approved actions skips transaction for ADD form code
     */
    @isTest
    static void testApprovedActionsSkipsTransactionForADDForm() {
        // Create NBR form configuration with ADD form code
        breg_Form_Configuration__c addFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'ADD',
            breg_Transaction_Code__c = 'ADD'
        );
        insert addFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create ADD case (should be treated as special form for this test)
        Case addCase = new Case(
            Subject = 'Test ADD Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = addFormConfig.Id,
            breg_Form_Code__c = 'ADD',
            breg_Name_of_the_Entity__c = 'Test ADD Entity',
            breg_Effective_Date__c = Date.today()
        );
        insert addCase;

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ addCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify no Transaction was created (ADD creates its own)
        List<breg_Transaction__c> transactions = [SELECT Id FROM breg_Transaction__c WHERE breg_Case__c = :addCase.Id];
        Assert.areEqual(0, transactions.size(), 'No transaction should be created for ADD form - handled by its own handler');
    }

    /**
     * Test approved actions for non-special form (should not create anything)
     */
    @isTest
    static void testApprovedActionsForNonSpecialForm() {
        // Get standard DC-3 case from test setup (not NBR/TNTMSM/NameReservation)
        Case testCase = [SELECT Id, breg_Form_Code__c FROM Case WHERE breg_Form_Code__c = 'DC-3' LIMIT 1];

        Integer accountsBefore = [SELECT COUNT() FROM Account];
        Integer transactionsBefore = [SELECT COUNT() FROM breg_Transaction__c];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify no new records created (DC-3 is not a special form in BREGUtils)
        Integer accountsAfter = [SELECT COUNT() FROM Account];
        Integer transactionsAfter = [SELECT COUNT() FROM breg_Transaction__c];

        // Note: DC-3 is not in NBR/TNTMSM/NameReservation lists, so nothing should be created
        Assert.areEqual(accountsBefore, accountsAfter, 'No new accounts should be created for non-special form');
        Assert.areEqual(transactionsBefore, transactionsAfter, 'No new transactions should be created for non-special form');
    }

    /**
     * Test approved actions uses existing Account when entity already linked
     */
    @isTest
    static void testApprovedActionsWithExistingEntity() {
        // Create existing account
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account existingAccount = new Account(Name = 'Existing Test Entity Corporation', RecordTypeId = bregAccountRtId);
        insert existingAccount;

        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create case with entity already linked
        Case nbrCase = new Case(
            Subject = 'Test NBR Case with Existing Entity',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Existing Test Entity Corporation',
            breg_Entity__c = existingAccount.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        Integer accountsBefore = [SELECT COUNT() FROM Account];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify no new account was created
        Integer accountsAfter = [SELECT COUNT() FROM Account];
        Assert.areEqual(accountsBefore, accountsAfter, 'No new account should be created when entity already linked');

        // Verify case still linked to existing entity
        Case updatedCase = [SELECT breg_Entity__c FROM Case WHERE Id = :nbrCase.Id];
        Assert.areEqual(existingAccount.Id, updatedCase.breg_Entity__c, 'Case should remain linked to existing entity');
    }

    @isTest
    static void testApprovedActionsTNTMSMApplicantEntityReusesExistingAccountAndPopulatesAffiliationFields() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account existingAccount = new Account(
            Name = 'Existing Applicant Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Type_Description__c = 'Domestic Corporation',
            breg_File_Suffix__c = 'D1',
            breg_File__c = '7654321',
            breg_Authorized_Shares_Count__c = 500,
            breg_Formation_Country__c = 'US',
            breg_Formation_Country_Label__c = 'United States',
            breg_Formation_State__c = 'HI',
            breg_Formation_State_Label__c = 'Hawaii'
        );
        insert existingAccount;

        insert new breg_TN_TM_SM__c(
            Name = 'Existing Trade Name',
            breg_Account__c = existingAccount.Id,
            breg_Status__c = 'A'
        );

        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case tntmsmCase = new Case(
            Subject = 'Test TNTMSM Case Existing Applicant Entity',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Existing Applicant Entity',
            breg_TNTMSM_Description__c = 'Existing Trade Name',
            breg_TNTMSM_Registration_Type__c = 'Renewal',
            breg_Effective_Date__c = Date.today(),
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St'
        );
        insert tntmsmCase;

        breg_Account_Affiliation__c applicant = new breg_Account_Affiliation__c(
            breg_Case__c = tntmsmCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Existing Applicant Entity'
        );
        insert applicant;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ tntmsmCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Entity__c FROM Case WHERE Id = :tntmsmCase.Id];
        Assert.areEqual(existingAccount.Id, updatedCase.breg_Entity__c, 'Case should stay linked to the existing entity account');

        breg_Account_Affiliation__c updatedAffiliation = [
            SELECT
                breg_Account__c,
                breg_Entity_Name__c,
                breg_Entity_Type__c,
                breg_Entity_Type_Description__c,
                breg_Suffix__c,
                breg_File__c,
                breg_Number_of_shares__c,
                breg_Entity_Location__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :applicant.Id
        ];

        Assert.areEqual(existingAccount.Id, updatedAffiliation.breg_Account__c, 'Applicant affiliation should be linked to the reused entity account');
        Assert.areEqual('Existing Applicant Entity', updatedAffiliation.breg_Entity_Name__c, 'Affiliation entity name should be copied from the reused entity');
        Assert.areEqual('Corporation', updatedAffiliation.breg_Entity_Type__c, 'Affiliation entity type should be normalized from the entity');
        Assert.areEqual('Domestic Corporation', updatedAffiliation.breg_Entity_Type_Description__c, 'Affiliation entity type description should be copied from the entity');
        Assert.areEqual('D1', updatedAffiliation.breg_Suffix__c, 'Affiliation suffix should be copied from the entity');
        Assert.areEqual('7654321', updatedAffiliation.breg_File__c, 'Affiliation file should be copied from the entity');
        Assert.areEqual(500, updatedAffiliation.breg_Number_of_shares__c, 'Affiliation shares count should be copied from the entity');
        Assert.areEqual('United States, Hawaii', updatedAffiliation.breg_Entity_Location__c, 'Affiliation entity location should be composed from entity country and state');
    }

    @isTest
    static void testApprovedActionsTNTMSMNewDoesNotReuseExistingAccountByName() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account existingAccount = new Account(
            Name = 'Existing New Filing Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1'
        );
        insert existingAccount;

        insert new breg_TN_TM_SM__c(
            Name = 'Brand New Trade Name',
            breg_Account__c = existingAccount.Id,
            breg_Status__c = 'A'
        );

        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case tntmsmCase = new Case(
            Subject = 'Test TNTMSM New Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Existing New Filing Entity',
            breg_TNTMSM_Description__c = 'Brand New Trade Name',
            breg_TNTMSM_Registration_Type__c = 'New',
            breg_Effective_Date__c = Date.today(),
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St'
        );
        insert tntmsmCase;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = tntmsmCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Existing New Filing Entity'
        );

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ tntmsmCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Entity__c FROM Case WHERE Id = :tntmsmCase.Id];
        Assert.isNotNull(updatedCase.breg_Entity__c, 'New TNTMSM filing should still create or link an entity');
        Assert.areNotEqual(
            existingAccount.Id,
            updatedCase.breg_Entity__c,
            'New TNTMSM filing should not reuse an existing Account by name'
        );
    }

    @isTest
    static void testApprovedActionsTNTMSMRenewalDoesNotReuseAccountWithoutMatchingTntmsm() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account existingAccount = new Account(
            Name = 'Existing Renewal Filing Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1'
        );
        insert existingAccount;

        insert new breg_TN_TM_SM__c(
            Name = 'Unrelated Trade Name',
            breg_Account__c = existingAccount.Id,
            breg_Status__c = 'A'
        );

        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case tntmsmCase = new Case(
            Subject = 'Test TNTMSM Renewal Without Matching TNTMSM',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Existing Renewal Filing Entity',
            breg_TNTMSM_Description__c = 'Renewal Trade Name',
            breg_TNTMSM_Registration_Type__c = 'Renewal',
            breg_Effective_Date__c = Date.today(),
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St'
        );
        insert tntmsmCase;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = tntmsmCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Existing Renewal Filing Entity'
        );

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ tntmsmCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Entity__c FROM Case WHERE Id = :tntmsmCase.Id];
        Assert.isNotNull(updatedCase.breg_Entity__c, 'Renewal without a matching TNTMSM should still create an entity');
        Assert.areNotEqual(
            existingAccount.Id,
            updatedCase.breg_Entity__c,
            'Renewal should not reuse an Account that has no related TNTMSM with the Case description'
        );
    }

    @isTest
    static void testApprovedActionsTNTMSMRenewalBulkDoesNotCrossMatchAccounts() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account matchingAccount = new Account(
            Name = 'Shared Renewal Filing Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1'
        );
        Account otherAccount = new Account(
            Name = 'Other Renewal Filing Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'D1'
        );
        insert new List<Account>{ matchingAccount, otherAccount };

        insert new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(Name = 'Matching Trade Name', breg_Account__c = matchingAccount.Id, breg_Status__c = 'A'),
            new breg_TN_TM_SM__c(Name = 'Unmatched Trade Name', breg_Account__c = otherAccount.Id, breg_Status__c = 'A')
        };

        breg_Form_Configuration__c tntmsmFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'TN',
            breg_Form_Code__c = 'T-1',
            breg_Registration_Type__c = 'Trade Name',
            breg_Transaction_Code__c = 'TNNA'
        );
        insert tntmsmFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case matchingCase = new Case(
            Subject = 'Test TNTMSM Renewal Matching',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Shared Renewal Filing Entity',
            breg_TNTMSM_Description__c = 'Matching Trade Name',
            breg_TNTMSM_Registration_Type__c = 'Renewal',
            breg_Effective_Date__c = Date.today(),
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St'
        );
        Case unmatchedCase = new Case(
            Subject = 'Test TNTMSM Renewal Unmatched',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = tntmsmFormConfig.Id,
            breg_Form_Code__c = 'T-1',
            breg_Name_of_the_Entity__c = 'Shared Renewal Filing Entity',
            breg_TNTMSM_Description__c = 'Unmatched Trade Name',
            breg_TNTMSM_Registration_Type__c = 'Renewal',
            breg_Effective_Date__c = Date.today(),
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__PostalCode__s = '96801',
            breg_Company_Address__Street__s = '123 Main St'
        );
        insert new List<Case>{ matchingCase, unmatchedCase };

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Case__c = matchingCase.Id,
                breg_Role__c = 'Applicant',
                breg_Type__c = 'Entity',
                breg_Entity_Name__c = 'Shared Renewal Filing Entity'
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = unmatchedCase.Id,
                breg_Role__c = 'Applicant',
                breg_Type__c = 'Entity',
                breg_Entity_Name__c = 'Shared Renewal Filing Entity'
            )
        };

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ matchingCase, unmatchedCase }, 'Approved', false, true);
        Test.stopTest();

        Map<Id, Case> updatedCases = new Map<Id, Case>([
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE Id IN :new List<Id>{ matchingCase.Id, unmatchedCase.Id }
        ]);

        Assert.areEqual(
            matchingAccount.Id,
            updatedCases.get(matchingCase.Id).breg_Entity__c,
            'Renewal with a matching related TNTMSM should reuse that Account'
        );
        Assert.areNotEqual(
            matchingAccount.Id,
            updatedCases.get(unmatchedCase.Id).breg_Entity__c,
            'Renewal should not reuse an Account that only matches another Case TNTMSM in the same batch'
        );
        Assert.areNotEqual(
            otherAccount.Id,
            updatedCases.get(unmatchedCase.Id).breg_Entity__c,
            'Renewal should not reuse a differently named Account just because TNTMSM Names overlap in the batch'
        );
    }

    @isTest
    static void testApprovedActionsCreatesNewAccountWhenExistingMatchIsClosed() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account terminatedAccount = new Account(
            Name = 'Terminated Test Entity Corporation',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Status__c = 'Terminated (T)'
        );
        insert terminatedAccount;

        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Closed-Status Name Match',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Terminated Test Entity Corporation',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedNbrCase = [SELECT breg_Entity__c FROM Case WHERE Id = :nbrCase.Id];
        Assert.isNotNull(updatedNbrCase.breg_Entity__c, 'Case should be linked to a newly created Account');
        Assert.areNotEqual(
            terminatedAccount.Id,
            updatedNbrCase.breg_Entity__c,
            'Case should not be linked to the pre-existing Terminated Account'
        );

        Account newAccount = [SELECT Id, Name, breg_Entity_Status__c FROM Account WHERE Id = :updatedNbrCase.breg_Entity__c];
        Assert.areEqual('Terminated Test Entity Corporation', newAccount.Name, 'New Account should carry the entity name from the Case');
        Assert.areNotEqual(
            'Terminated (T)',
            newAccount.breg_Entity_Status__c,
            'New Account should not inherit the Terminated status of the unrelated pre-existing Account'
        );
    }

    @isTest
    static void testApprovedActionsNBRDoesNotReuseActiveAccount() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account activeAccount = new Account(
            Name = 'Active Test Entity Corporation',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Status__c = 'Active (A)'
        );
        insert activeAccount;

        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Active-Status Name Match',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Active Test Entity Corporation',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedNbrCase = [SELECT breg_Entity__c FROM Case WHERE Id = :nbrCase.Id];
        Assert.isNotNull(updatedNbrCase.breg_Entity__c, 'Case should be linked to a newly created Account');
        Assert.areNotEqual(
            activeAccount.Id,
            updatedNbrCase.breg_Entity__c,
            'Case should not be linked to the pre-existing Active Account'
        );

        Account newAccount = [SELECT Id, Name FROM Account WHERE Id = :updatedNbrCase.breg_Entity__c];
        Assert.areEqual('Active Test Entity Corporation', newAccount.Name, 'New Account should carry the entity name from the Case');
    }

    /**
     * Test approved actions sets Start Date on Account Affiliations from Case Effective Date
     */
    @isTest
    static void testApprovedActionsSetsAffiliationStartDate() {
        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Date effectiveDate = Date.today().addDays(5);

        // Create NBR case with specific effective date
        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Start Date',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity Corporation for Start Date',
            breg_Effective_Date__c = effectiveDate
        );
        insert nbrCase;

        // Create account affiliation without start date
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = nbrCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe'
        );
        insert affiliation;

        // Verify start date is null before
        breg_Account_Affiliation__c affBefore = [SELECT breg_Start_Date__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.isNull(affBefore.breg_Start_Date__c, 'Start date should be null before approval');

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify Start Date was populated with Case Effective Date
        breg_Account_Affiliation__c updatedAff = [SELECT breg_Start_Date__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.areEqual(effectiveDate, updatedAff.breg_Start_Date__c, 'Start date should be set to Case Effective Date');
    }

    /**
     * Test approved actions creates Contact for Individual type affiliation without Contact
     */
    @isTest
    static void testApprovedActionsCreatesContactForIndividual() {
        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create NBR case
        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Contact Creation',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity Corporation for Contact',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        // Create Individual affiliation without Contact
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = nbrCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith'
        );
        insert affiliation;

        Integer contactsBefore = [SELECT COUNT() FROM Contact WHERE LastName = 'Smith'];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify Contact was created
        List<Contact> contacts = [SELECT Id, FirstName, LastName FROM Contact WHERE LastName = 'Smith'];
        Assert.isTrue(contacts.size() > contactsBefore, 'Contact should be created for Individual affiliation');

        // Verify affiliation was linked to new Contact
        breg_Account_Affiliation__c updatedAff = [SELECT breg_Contact__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.isNotNull(updatedAff.breg_Contact__c, 'Affiliation should be linked to new Contact');
    }

    /**
     * Test approved actions creates Account for Entity type affiliation without Account
     */
    @isTest
    static void testApprovedActionsCreatesAccountForEntity() {
        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create NBR case
        Case nbrCase = new Case(
            Subject = 'Test NBR Case for Account Creation',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test EntityCorporation for Account',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        // Create Entity affiliation without Account
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = nbrCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Affiliate Company LLC'
        );
        insert affiliation;

        Integer accountsBefore = [SELECT COUNT() FROM Account WHERE Name = 'Affiliate Company LLC'];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify Account was created
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name = 'Affiliate Company LLC'];
        Assert.isTrue(accounts.size() > accountsBefore, 'Account should be created for Entity affiliation');

        // Verify affiliation was linked to new Account
        breg_Account_Affiliation__c updatedAff = [SELECT breg_Account__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.isNotNull(updatedAff.breg_Account__c, 'Affiliation should be linked to new Account');
    }

    /**
     * Test approved actions does not create Contact when already linked
     */
    @isTest
    static void testApprovedActionsSkipsContactCreationWhenExists() {
        // Create existing contact
        Contact existingContact = new Contact(FirstName = 'Existing', LastName = 'Person');
        insert existingContact;

        // Create NBR form configuration
        breg_Form_Configuration__c nbrFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert nbrFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create NBR case
        Case nbrCase = new Case(
            Subject = 'Test NBR Case with Existing Contact',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Test Entity Corporation',
            breg_Effective_Date__c = Date.today()
        );
        insert nbrCase;

        // Create Individual affiliation WITH Contact already linked
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Case__c = nbrCase.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Existing',
            breg_Last_Name__c = 'Person',
            breg_Contact__c = existingContact.Id
        );
        insert affiliation;

        Integer contactsBefore = [SELECT COUNT() FROM Contact];

        // Create handler instance
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ nbrCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify no new Contact was created
        Integer contactsAfter = [SELECT COUNT() FROM Contact];
        Assert.areEqual(contactsBefore, contactsAfter, 'No new Contact should be created when already linked');

        // Verify affiliation still linked to existing Contact
        breg_Account_Affiliation__c updatedAff = [SELECT breg_Contact__c FROM breg_Account_Affiliation__c WHERE Id = :affiliation.Id];
        Assert.areEqual(existingContact.Id, updatedAff.breg_Contact__c, 'Affiliation should remain linked to existing Contact');
    }

    @isTest
    static void testProtectedHelpersCreateTransAddressAndUpdateEndDate() {
        TestableHandler handler = new TestableHandler();

        List<breg_Transaction_Address__c> addresses = handler.invokeCreateTransactionAdresses(
            new Map<Id, Case>(),
            new List<breg_Transaction__c>(),
            new Map<Id, Id>()
        );
        Assert.isNull(addresses, 'Should return null for empty case map');

        Test.startTest();
        handler.invokeUpdateEndDateInLastTransAddressRecords(new List<Account>(), new Map<Id, Case>(), new Map<Id, Id>());
        Test.stopTest();

        Assert.isTrue(true, 'No exception should be thrown for empty updateEndDate invocation');
    }

    @isTest
    static void testValidateEntityNameEqualAccNameBranches() {
        TestableHandler handler = new TestableHandler();

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Entity Name From Account Corporation', RecordTypeId = bregAccountRecordTypeId);
        insert acc;

        Case triggerCaseMissingEntity = new Case(
            Subject = 'Missing Entity',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Name_of_the_Entity__c = 'Any Name'
        );

        Boolean missingEntityThrown = false;
        String missingEntityMessage = '';
        try {
            handler.invokeValidateEntityNameEqualAccName(new Map<Id, Case>(), new List<Case>{ triggerCaseMissingEntity });
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            missingEntityThrown = true;
            missingEntityMessage = e.errorMessage;
        }
        Assert.isTrue(missingEntityThrown, 'Missing entity branch should throw');
        Assert.isTrue(missingEntityMessage.contains('required field'), 'Error should indicate missing required entity.');

        Case triggerCaseMismatchedName = new Case(
            Subject = 'Mismatched Name',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            breg_Entity__c = acc.Id,
            breg_Name_of_the_Entity__c = acc.Name
        );
        insert triggerCaseMismatchedName;

        Case queriedCase = [
            SELECT Id, breg_Form_Code__c, breg_Entity__c, breg_Entity__r.Name, breg_Name_of_the_Entity__c
            FROM Case
            WHERE Id = :triggerCaseMismatchedName.Id
            LIMIT 1
        ];
        queriedCase.breg_Name_of_the_Entity__c = 'Different Name Than Account';
        handler.invokeValidateEntityNameEqualAccName(new Map<Id, Case>{ queriedCase.Id => queriedCase }, new List<Case>{ triggerCaseMismatchedName });

        Case triggerCaseMissingReservation = new Case(
            Subject = 'Missing Reservation',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'X-1',
            breg_Name_for_Reservation__c = 'Reserved Name'
        );
        Boolean missingReservationThrown = false;
        String missingReservationMessage = '';
        try {
            handler.invokeValidateEntityNameEqualAccName(new Map<Id, Case>(), new List<Case>{ triggerCaseMissingReservation });
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            missingReservationThrown = true;
            missingReservationMessage = e.errorMessage;
        }
        Assert.isTrue(missingReservationThrown, 'Missing name reservation branch should throw');
        Assert.isTrue(missingReservationMessage.contains('required field'), 'Error should indicate missing required reservation.');

        Account reservation = new Account(
            Id = Schema.SObjectType.Account.getKeyPrefix() + '000000000001',
            Name = 'Reserved Name Account'
        );
        Case triggerCaseReservationMismatch = new Case(
            Id = Schema.SObjectType.Case.getKeyPrefix() + '000000000001',
            Subject = 'Reservation Name Mismatch',
            breg_Form_Code__c = 'X-1',
            breg_Name_Reservation__c = reservation.Id,
            breg_Name_Reservation__r = reservation,
            breg_Name_for_Reservation__c = 'Different Reserved Name'
        );

        Boolean reservationMismatchThrown = false;
        String reservationMismatchMessage = '';
        try {
            handler.invokeValidateEntityNameEqualAccName(
                new Map<Id, Case>{ triggerCaseReservationMismatch.Id => triggerCaseReservationMismatch },
                new List<Case>{ triggerCaseReservationMismatch }
            );
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            reservationMismatchThrown = true;
            reservationMismatchMessage = e.errorMessage;
        }
        Assert.isTrue(reservationMismatchThrown, 'Mismatched reservation name branch should throw: ' + reservationMismatchMessage);
        Assert.isTrue(
            reservationMismatchMessage.contains('does not match'),
            'Error should mention reservation mismatch: ' + reservationMismatchMessage
        );
    }

    @isTest
    static void testApprovedActionsCoverStockBusinessStructureAndLLPParent() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K5',
            breg_Suffix_Code__c = 'K5',
            breg_Form_Code__c = 'LLP-1',
            breg_Business_Structure__c = 'Limited Liability Partnership',
            breg_Transaction_Code__c = 'ART'
        );
        breg_Form_Configuration__c stockFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'C5',
            breg_Suffix_Code__c = 'C5',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Structure__c = 'Limited Liability Company',
            breg_Transaction_Code__c = 'ART'
        );
        insert new List<breg_Form_Configuration__c>{ llpFormConfig, stockFormConfig };

        Account llpEntity = new Account(Name = 'LLP Entity ' + String.valueOf(System.now().getTime()), RecordTypeId = bregAccountRecordTypeId);
        Account gpEntity = new Account(Name = 'GP Entity ' + String.valueOf(System.now().getTime()), RecordTypeId = bregAccountRecordTypeId);
        insert new List<Account>{ llpEntity, gpEntity };

        String uniqueSuffix = String.valueOf(System.now().getTime());
        Case llpCase = new Case(
            Subject = 'LLP Parent Link ' + uniqueSuffix,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = 'LLP-1',
            breg_Name_of_the_Entity__c = llpEntity.Name,
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = llpEntity.Id,
            breg_GP_Already_Registered__c = true,
            breg_GP_Entity__c = gpEntity.Id
        );
        Case stockCase = new Case(
            Subject = 'NBR With Stock ' + uniqueSuffix,
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = stockFormConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Stock Limited Liability Company ' + uniqueSuffix,
            breg_Effective_Date__c = Date.today(),
            breg_Partnership_Begin_Business_Date__c = Date.today().addDays(-10),
            breg_Purposes__c = 'Purpose from case purposes field',
            breg_Number_of_common_shares__c = 10,
            breg_Par_Value_Of_Each_Share__c = 1
        );
        insert new List<Case>{ llpCase, stockCase };

        TestableHandler handler = new TestableHandler();
        Test.startTest();
        handler.invokePerformApprovedActionsForSpecialForms(new List<Case>{ llpCase, stockCase });
        Test.stopTest();

        Account gpAfter = [SELECT Id, ParentId FROM Account WHERE Id = :gpEntity.Id];
        Assert.areEqual(llpEntity.Id, gpAfter.ParentId, 'GP entity should be linked to LLP entity as parent');

        Case stockCaseAfter = [SELECT Id, breg_Entity__c, breg_Name_of_the_Entity__c FROM Case WHERE Id = :stockCase.Id LIMIT 1];
        List<breg_Stock__c> stocks = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Stock_Class__c
            FROM breg_Stock__c
            WHERE breg_Case__c = :stockCaseAfter.Id
        ];
        Assert.isTrue(!stocks.isEmpty(), 'Stock record should be created for NBR form with stock');
        Assert.areEqual('Common', stocks[0].breg_Stock_Class__c, 'Stock class should be Common');

        Account createdEntity = [
            SELECT Id, Name, breg_Business_Structure__c, breg_Purpose__c, breg_Commence_Date__c
            FROM Account
            WHERE Id = :stockCaseAfter.breg_Entity__c
            LIMIT 1
        ];
        Assert.areEqual('Limited Liability Company', createdEntity.breg_Business_Structure__c, 'Business structure should be calculated and populated');
        Assert.areEqual('Purpose from case purposes field', createdEntity.breg_Purpose__c, 'Purpose should fall back to case purposes when entity nature of business is blank');
        Assert.areEqual(Date.today().addDays(-10), createdEntity.breg_Commence_Date__c, 'Commence date should be mapped from partnership begin business date');
    }

    private static List<Case> createLLPAndGPChildCases(String llpFormCode) {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(breg_Form_Code__c = llpFormCode, breg_Suffix_Code__c = 'K5');
        breg_Form_Configuration__c gpFormConfig = new breg_Form_Configuration__c(breg_Form_Code__c = 'GP-1', breg_Suffix_Code__c = 'G5');
        insert new List<breg_Form_Configuration__c>{ llpFormConfig, gpFormConfig };

        String uniqueSuffix = String.valueOf(System.now().getTime());
        Case llpCase = new Case(
            Subject = 'LLP Parent ' + uniqueSuffix,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = llpFormCode
        );
        insert llpCase;

        Case gpCase = new Case(
            Subject = 'GP Child ' + uniqueSuffix,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ParentId = llpCase.Id,
            breg_Form_Configuration__c = gpFormConfig.Id,
            breg_Form_Code__c = 'GP-1',
            breg_Is_LLP_Registration__c = true
        );
        insert gpCase;

        return new List<Case>{ llpCase, gpCase };
    }

    @isTest
    static void testLLPToReceivedSyncsGPChild() {
        List<Case> pair = createLLPAndGPChildCases('LLP-1');
        Case llpCase = pair[0];
        Case gpCase = pair[1];
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ llpCase }, 'Received', false, true);
        Test.stopTest();

        Case gpAfter = [SELECT Id, Status FROM Case WHERE Id = :gpCase.Id];
        Assert.areEqual('Received', gpAfter.Status, 'Linked GP child case should be synced to Received when LLP moves to Received');
    }

    @isTest
    static void testLLPToRejectedSyncsGPChild() {
        List<Case> pair = createLLPAndGPChildCases('LLP-1');
        Case llpCase = pair[0];
        Case gpCase = pair[1];
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ llpCase }, 'Rejected', false, true);
        Test.stopTest();

        Case gpAfter = [SELECT Id, Status FROM Case WHERE Id = :gpCase.Id];
        Assert.areEqual('Rejected', gpAfter.Status, 'Linked GP child case should be synced to Rejected when LLP moves to Rejected');
    }

    @isTest
    static void testGPToReceivedSyncsLLPParent() {
        List<Case> pair = createLLPAndGPChildCases('LLP-1');
        Case llpCase = pair[0];
        Case gpCase = pair[1];
        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ gpCase }, 'Received', false, true);
        Test.stopTest();

        Case llpAfter = [SELECT Id, Status FROM Case WHERE Id = :llpCase.Id];
        Assert.areEqual('Received', llpAfter.Status, 'Linked LLP parent case should be synced to Received when GP moves to Received');
    }

    @isTest
    static void testReceivedNonLinkedCaseNoSideEffects() {
        Case existingCase = [SELECT Id, Status, breg_Form_Code__c FROM Case WHERE breg_Form_Code__c = 'DC-1' LIMIT 1];
        Integer caseCountBefore = [SELECT COUNT() FROM Case];
        String statusBefore = existingCase.Status;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ existingCase }, 'Received', false, true);
        Test.stopTest();

        Integer caseCountAfter = [SELECT COUNT() FROM Case];
        Assert.areEqual(caseCountBefore, caseCountAfter, 'Case count should be unchanged');
        Case afterCase = [SELECT Id, Status FROM Case WHERE Id = :existingCase.Id];
        Assert.areEqual(statusBefore, afterCase.Status, 'Non-LLP/GP case status should be unchanged by handler (sync only updates linked LLP/GP cases)');
    }

    @isTest
    static void testReceivedBothInBatchExcluded() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(breg_Form_Code__c = 'FLLP-1', breg_Suffix_Code__c = 'K6');
        breg_Form_Configuration__c gpFormConfig = new breg_Form_Configuration__c(breg_Form_Code__c = 'GP-1', breg_Suffix_Code__c = 'G5');
        insert new List<breg_Form_Configuration__c>{ llpFormConfig, gpFormConfig };

        String uniqueSuffix = String.valueOf(System.now().getTime());
        Case llpCase = new Case(
            Subject = 'FLLP Parent ' + uniqueSuffix,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = 'FLLP-1'
        );
        insert llpCase;

        Case gpCase = new Case(
            Subject = 'GP Child ' + uniqueSuffix,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ParentId = llpCase.Id,
            breg_Form_Configuration__c = gpFormConfig.Id,
            breg_Form_Code__c = 'GP-1',
            breg_Is_LLP_Registration__c = true
        );
        insert gpCase;

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ llpCase, gpCase }, 'Received', false, true);
        Test.stopTest();

        Case llpAfter = [SELECT Id, Status FROM Case WHERE Id = :llpCase.Id];
        Case gpAfter = [SELECT Id, Status FROM Case WHERE Id = :gpCase.Id];
        Assert.areEqual('Pending Submission', llpAfter.Status, 'LLP case status unchanged by handler when both in batch');
        Assert.areEqual('Pending Submission', gpAfter.Status, 'GP case status unchanged by handler when both in batch');
    }


    @isTest
    static void testHandleStatusChangeBouncedCheckUpdatesCasesWithAssignmentRules() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        List<Group> officeServicesQueues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue' AND Name = 'Office Services'
            LIMIT 1
        ];

        if (officeServicesQueues.isEmpty()) {
            Assert.isTrue(true, 'Queue "Office Services" does not exist in this org. Skipping test.');
            return;
        }

        Group officeServicesQueue = officeServicesQueues[0];

        Datetime nowUtc = System.now();
        TimeZone tz = UserInfo.getTimeZone();
        Integer offset = tz.getOffset(nowUtc) / 1000;
        Datetime orgNow = nowUtc.addSeconds(offset);
        Date expectedDueDate = orgNow.date().addDays(15);

        Date existingDueDate = Date.today().addDays(7);

        Case queueOwnedCase = new Case(
            Subject = 'Queue owned bounced check case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            OwnerId = officeServicesQueue.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'Queue Owned Entity'
        );

        Case userOwnedCaseWithoutDueDate = new Case(
            Subject = 'User owned bounced check case without due date',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            OwnerId = UserInfo.getUserId(),
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'User Owned Entity 1'
        );

        Case userOwnedCaseWithExistingDueDate = new Case(
            Subject = 'User owned bounced check case with due date',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            OwnerId = UserInfo.getUserId(),
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = 'User Owned Entity 2',
            breg_Bounced_Check_Due_Date__c = existingDueDate
        );

        insert new List<Case>{ queueOwnedCase, userOwnedCaseWithoutDueDate, userOwnedCaseWithExistingDueDate };

        List<Case> casesForHandler = [
            SELECT Id, OwnerId, breg_Bounced_Check_Due_Date__c
            FROM Case
            WHERE Id IN :new List<Id>{ queueOwnedCase.Id, userOwnedCaseWithoutDueDate.Id, userOwnedCaseWithExistingDueDate.Id }
        ];

        BREGCaseStatusHandlerBase handler = new BREGCaseStatusHandlerBase();

        Test.startTest();
        handler.handleStatusChange(casesForHandler, 'Bounced Check', false, true);
        Test.stopTest();

        Map<Id, Case> updatedCases = new Map<Id, Case>(
            [
                SELECT Id, OwnerId, breg_Bounced_Check_Due_Date__c
                FROM Case
                WHERE Id IN :new List<Id>{ queueOwnedCase.Id, userOwnedCaseWithoutDueDate.Id, userOwnedCaseWithExistingDueDate.Id }
            ]
        );

        Assert.isNull(updatedCases.get(queueOwnedCase.Id).breg_Bounced_Check_Due_Date__c, 'Case owned by Office Services queue should be skipped');

        Assert.areEqual(
            expectedDueDate,
            updatedCases.get(userOwnedCaseWithoutDueDate.Id).breg_Bounced_Check_Due_Date__c,
            'Case without due date should receive +15 days due date'
        );

        Assert.areEqual(
            existingDueDate,
            updatedCases.get(userOwnedCaseWithExistingDueDate.Id).breg_Bounced_Check_Due_Date__c,
            'Existing due date should not be overwritten'
        );
    }

    /**
     * Helper method to create a completed payment for a case
     */
    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;

        TransactionLine__c line = new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = caseId,
            PaidStatus__c = 'Paid',
            Payment__c = payment.Id,
            Amount__c = 100
        );
        insert line;
    }

    private static String getCountryCodeByStateRequirement(Boolean expectedHasStates) {
        for (Schema.PicklistEntry countryEntry : Account.BillingCountryCode.getDescribe().getPicklistValues()) {
            if (!countryEntry.isActive()) {
                continue;
            }

            String countryCode = countryEntry.getValue();
            if (BREGUtils.doesCountryHaveStates(countryCode) == expectedHasStates) {
                return countryCode;
            }
        }
        return null;
    }

    private static String getRequiredStatusForTest() {
        String approvedValue;
        for (Schema.PicklistEntry entry : breg_Form_Configuration_Item__c.breg_Required_for_Statuses__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }

            if (entry.getValue() != 'Approved') {
                return entry.getValue();
            }
            approvedValue = entry.getValue();
        }
        return approvedValue;
    }

    /**
     * Mock validation class for testing custom validation
     */
    public class BREGCaseStatusHandlerBaseTestMockValidation implements BREGIFormFieldValidation {
        public Map<String, String> validateFields(breg_Form_Configuration_Item__c formConfigItem, sObject sobj) {
            Map<String, String> errors = new Map<String, String>();
            Case c = (Case) sobj;

            // Example validation: First name cannot be "Invalid"
            if (String.isNotBlank(c.breg_New_Registrant_First_Name__c) && c.breg_New_Registrant_First_Name__c == 'Invalid') {
                errors.put('breg_New_Registrant_First_Name__c', 'Invalid first name provided');
            }

            return errors;
        }
    }

    public class TestableHandler extends BREGCaseStatusHandlerBase {
        public List<breg_Transaction_Address__c> invokeCreateTransactionAdresses(
            Map<Id, Case> casesMap,
            List<breg_Transaction__c> transactions,
            Map<Id, Id> caseToAffiliationMap
        ) {
            return createTransactionAdresses(casesMap, transactions, caseToAffiliationMap);
        }

        public void invokeUpdateEndDateInLastTransAddressRecords(
            List<Account> accounts,
            Map<Id, Case> entityToCaseMap,
            Map<Id, Id> caseIdToAffiliationId
        ) {
            updateEndDateInLastTransAddressRecords(accounts, entityToCaseMap, caseIdToAffiliationId);
        }

        public void invokeValidateEntityNameEqualAccName(Map<Id, Case> casesForCheck, List<Case> cases) {
            validateEntityNameEqualAccName(casesForCheck, cases);
        }

        public void invokePerformApprovedActionsForSpecialForms(List<Case> cases) {
            performApprovedActionsForSpecialForms(cases);
        }

        public void invokeValidatePaymentCompletion(List<Case> cases) {
            validatePaymentCompletion(cases);
        }
    }
}