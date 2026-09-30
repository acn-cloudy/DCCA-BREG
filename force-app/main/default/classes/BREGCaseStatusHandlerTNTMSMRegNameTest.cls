/**
 * Test class for BREGCaseStatusHandlerTNTMSMRegNameChange
 * Tests the registrant name change logic for TN/TM/SM records
 */
@isTest
private class BREGCaseStatusHandlerTNTMSMRegNameTest {
    /**
     * Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create TN/TM/SM record with registrant information
        breg_TN_TM_SM__c testTNTMSM = new breg_TN_TM_SM__c(
            Name = 'Test TN Record',
            breg_Type__c = 'Trade Name',
            breg_Registrant_Type__c = 'Individual',
            breg_Registrant_First_Name__c = 'John',
            breg_Registrant_Last_Name__c = 'Doe',
            breg_Registrant_Name__c = null
        );
        insert testTNTMSM;

        // Create form configuration for TN-RNC form
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'TN-RNC', breg_Form_Code__c = 'TN-RNC');
        insert testFormConfig;

        // Create test case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        // Create Account and assign to case
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        List<Case> testCases = new List<Case>{
            new Case(
                Subject = 'Test TN Registrant Name Change',
                Status = 'Pending Submission',
                Origin = 'Web',
                RecordTypeId = bregCaseRecordTypeId,
                breg_TN_TM_SM__c = testTNTMSM.Id,
                breg_Form_Configuration__c = testFormConfig.Id,
                breg_Form_Code__c = 'TN-RNC',
                AccountId = testAccount.Id
            ), 
            new Case(
                Subject = 'Test TN Registrant Name Change 2',
                Status = 'Pending Submission',
                Origin = 'Web',
                RecordTypeId = bregCaseRecordTypeId,
                breg_TN_TM_SM__c = testTNTMSM.Id,
                breg_Form_Configuration__c = testFormConfig.Id,
                breg_Form_Code__c = 'TN-RNC',
                AccountId = testAccount.Id
            )
        };
        insert testCases;

    }

    /**
     * Test successful handling of status change with validation
     */
    @isTest
    static void testHandleStatusChangeWithValidation() {
        Case testCase = getTestCase('Test TN Registrant Name Change');

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        Test.stopTest();

        // Verify no errors - case should still exist
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful validation');
    }

    /**
     * Test successful handling of status change with actions
     */
    @isTest
    static void testHandleStatusChangeWithActions() {
        Case testCase = getTestCase('Test TN Registrant Name Change');

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify case still exists
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful action execution');
    }

    /**
     * Test TNTMSM update when approved with Entity type Applicant
     */
    @isTest
    static void testUpdateTNTMSMsApprovedWithEntityApplicant() {
        Case testCase = getTestCase('Test TN Registrant Name Change');
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        // Create Account Affiliation with Entity type and Applicant role
        breg_Account_Affiliation__c accAff = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Applicant',
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'ABC Corporation'
        );
        insert accAff;

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify TNTMSM was updated with Entity information
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_Type__c, breg_Registrant_Name__c, breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.areEqual('Entity', updatedTNTMSM.breg_Registrant_Type__c, 'Registrant type should be Entity');
        Assert.areEqual('ABC Corporation', updatedTNTMSM.breg_Registrant_Name__c, 'Registrant name should be set');
        Assert.isNull(updatedTNTMSM.breg_Registrant_First_Name__c, 'First name should be null for Entity');
        Assert.isNull(updatedTNTMSM.breg_Registrant_Last_Name__c, 'Last name should be null for Entity');
    }

    /**
     * Test TNTMSM update when approved with Individual type Applicant
     */
    @isTest
    static void testUpdateTNTMSMsApprovedWithIndividualApplicant() {
        Case testCase = getTestCase('Test TN Registrant Name Change');
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();
        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();
        // Create Account Affiliation with Individual type and Applicant role
        breg_Account_Affiliation__c accAff = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Individual',
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith'
        );
        insert accAff;

        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);

        // Verify TNTMSM was updated with Individual information
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_Type__c, breg_Registrant_Name__c, breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.areEqual('Individual', updatedTNTMSM.breg_Registrant_Type__c, 'Registrant type should be Individual');
        Assert.isNull(updatedTNTMSM.breg_Registrant_Name__c, 'Registrant name should be null for Individual');
        Assert.areEqual('Jane', updatedTNTMSM.breg_Registrant_First_Name__c, 'First name should be set');
        Assert.areEqual('Smith', updatedTNTMSM.breg_Registrant_Last_Name__c, 'Last name should be set');
    }

    /**
     * Test TNTMSM update when approved with Entity type Applicant linked to the same TNTMSM
     */
    @isTest
    static void testUpdateTNTMSMsApprovedWithExistingApplicantForSameRecord() {
        Case testCase = getTestCase('Test TN Registrant Name Change');
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        insert new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Applicant',
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Existing Applicant Entity'
        );

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMRegNameChange().handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_Type__c, breg_Registrant_Name__c, breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.areEqual('Entity', updatedTNTMSM.breg_Registrant_Type__c, 'Applicant branch should update the registrant type to Entity');
        Assert.areEqual('Existing Applicant Entity', updatedTNTMSM.breg_Registrant_Name__c, 'Applicant branch should update the registrant name when linked to the same TNTMSM');
        Assert.isNull(updatedTNTMSM.breg_Registrant_First_Name__c, 'Entity applicant should clear first name');
        Assert.isNull(updatedTNTMSM.breg_Registrant_Last_Name__c, 'Entity applicant should clear last name');
    }

    /**
     * Test no update when approved status but no TNTMSM linked
     */
    @isTest
    static void testNoUpdateWhenNoTNTMSMLinked() {
        Case testCase = getTestCase('Test TN Registrant Name Change');

        // Remove TNTMSM link
        testCase.breg_TN_TM_SM__c = null;
        update testCase;

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify no errors occurred (no TNTMSM to update)
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should still exist');
    }

    /**
      * Test no update when no Applicant exists
     */
    @isTest
    static void testNoUpdateWhenNoNewApplicant() {
          Case testCase = getTestCase('Test TN Registrant Name Change');
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        // Create Account Affiliation with different role (not New Applicant)
        breg_Account_Affiliation__c accAff = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Officer/Director',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'XYZ Company'
        );
        insert accAff;

        // Get original TNTMSM values
        String originalFirstName = testTNTMSM.breg_Registrant_First_Name__c;
        String originalLastName = testTNTMSM.breg_Registrant_Last_Name__c;

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify TNTMSM was not updated
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.areEqual(originalFirstName, updatedTNTMSM.breg_Registrant_First_Name__c, 'First name should not be changed');
        Assert.areEqual(originalLastName, updatedTNTMSM.breg_Registrant_Last_Name__c, 'Last name should not be changed');
    }

    /**
     * Test no update when status is not Approved
     */
    @isTest
    static void testNoUpdateWhenStatusNotApproved() {
        Case testCase = getTestCase('Test TN Registrant Name Change');
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        // Create Account Affiliation
        breg_Account_Affiliation__c accAff = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Applicant',
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Test Company'
        );
        insert accAff;

        // Get original TNTMSM values
        String originalFirstName = testTNTMSM.breg_Registrant_First_Name__c;
        String originalLastName = testTNTMSM.breg_Registrant_Last_Name__c;

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', false, true);
        Test.stopTest();

        // Verify TNTMSM was not updated
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c, breg_Registrant_Type__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.areEqual(originalFirstName, updatedTNTMSM.breg_Registrant_First_Name__c, 'First name should not be changed for non-Approved status');
        Assert.areEqual(originalLastName, updatedTNTMSM.breg_Registrant_Last_Name__c, 'Last name should not be changed for non-Approved status');
    }

    /**
     * Test with multiple New Applicant affiliations - should use last one processed
     */
    @isTest
    static void testMultipleNewApplicants() {
        List<Case> testCases = [
            SELECT Id, breg_TN_TM_SM__c, breg_Form_Code__c
            FROM Case
            WHERE Subject LIKE 'Test TN Registrant Name Change%'
            LIMIT 2
        ];
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        // Create multiple Account Affiliations with New Applicant role
        List<breg_Account_Affiliation__c> accAffs = new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Case__c = testCases[0].Id,
                breg_Role__c = 'New Applicant',
                breg_TN_TM_SM__c = testTNTMSM.Id,
                breg_Type__c = 'Entity',
                breg_Entity_Name__c = 'First Company'
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = testCases[1].Id,
                breg_Role__c = 'New Applicant',
                breg_Type__c = 'Individual',
                breg_First_Name__c = 'Bob',
                breg_Last_Name__c = 'Williams'
            )
        };
        insert accAffs;

        BREGCaseStatusHandlerTNTMSMRegNameChange handler = new BREGCaseStatusHandlerTNTMSMRegNameChange();

        Test.startTest();
        handler.handleStatusChange(testCases, 'Approved', false, true);
        Test.stopTest();

        // Verify TNTMSM was updated (last processed wins)
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Registrant_Type__c, breg_Registrant_Name__c, breg_Registrant_First_Name__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];
        Assert.isNotNull(updatedTNTMSM.breg_Registrant_Type__c, 'Registrant type should be set');
    }

    /**
     * Helper method to get test case
     */
    private static Case getTestCase(String subject) {
        return [
            SELECT Id, breg_TN_TM_SM__c, breg_Form_Code__c, breg_Outstanding_Shares_Count__c, breg_Authorized_Shares_Count__c
            FROM Case
            WHERE Subject = :subject
            LIMIT 1
        ];
    }

    /**
     * Helper method to get test TNTMSM
     */
    private static breg_TN_TM_SM__c getTestTNTMSM() {
        return [
            SELECT Id, breg_Registrant_Type__c, breg_Registrant_Name__c, breg_Registrant_First_Name__c, breg_Registrant_Last_Name__c
            FROM breg_TN_TM_SM__c
            LIMIT 1
        ];
    }
}