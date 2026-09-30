/**
 * Test class for BREGCaseStatusHandlerTNTMSMRenewal
 */
@isTest
private class BREGCaseStatusHandlerTNTMSMRenewalTest {
    /**
     * Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create TN/TM/SM record with address information
        breg_TN_TM_SM__c testTNTMSM = new breg_TN_TM_SM__c(
            Name = 'Test Renewal TN',
            breg_Type__c = 'Trade Name',
            breg_Trade_Name__c = 'Test Renewal TN',
            breg_Cert_Number__c = 'CERT-100',
            breg_Expiration_Date__c = Date.newInstance(2026, 5, 31),
            breg_Mailing_Address__Street__s = '456 Oak Ave',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__PostalCode__s = '96814',
            breg_Mailing_Address__CountryCode__s = 'US'
        );
        insert testTNTMSM;

        // Create form configuration for T-2 form
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'T-2', breg_Form_Code__c = 'T-2');
        insert testFormConfig;

        // Create test case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test T-2 Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_Form_Code__c = 'T-2',
            breg_Effective_Date__c = Date.today(),
            breg_TNTMSM_Registration_Type__c = 'Renewal',
            breg_TNTMSM_Description__c = 'Test Renewal TN',
            breg_TNTMSM_Certificate__c = 'CERT-100'
        );
        insert testCase;
    }

    /**
     * Test the date of first use
     */
    @isTest
    static void testFirstUsedDate() {
        Case testCase = getTestCase();

        testCase.breg_TNTMSM_First_Used_Anywhere__c = Date.today() + 1;
        testCase.breg_TNTMSM_First_Used_Hawaii__c = Date.today() + 1;
        update testCase;

        BREGCaseStatusHandlerTNTMSMRenewal handler = new BREGCaseStatusHandlerTNTMSMRenewal();
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.isTrue(exceptionThrown, 'Exception should be thrown');
    }

    /**
     * Test that a Renewal case without a linked TN/TM/SM cannot be approved
     */
    @isTest
    static void testApprovalRequiresLinkedTNTMSM() {
        Case testCase = getTestCase();

        testCase.breg_TN_TM_SM__c = null;
        testCase.breg_Override_Payment__c = true; // Set to true to bypass payment validation
        update testCase;

        BREGCaseStatusHandlerTNTMSMRenewal handler = new BREGCaseStatusHandlerTNTMSMRenewal();
        Boolean exceptionThrown = false;
        String errorMessage;
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            errorMessage = e.errorMessage;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Renewal case without TN/TM/SM should not be allowed to be approved.');
        Assert.areEqual('TN/TM/SM is required to approve a TN/TM/SM Renewal filing.', errorMessage, 'The TN/TM/SM required error should be returned.');
    }

    /**
     * Test the Expiration Date update
     */
    @isTest
    static void testUpdateExpirationDateForRenewal() {
        Case testCase = getTestCase();

        testCase.breg_Effective_Date__c = Date.today();
        update testCase;

        Date previousExpirationDate = [
            SELECT breg_Expiration_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :testCase.breg_TN_TM_SM__c
            LIMIT 1
        ].breg_Expiration_Date__c;

        BREGCaseStatusHandlerTNTMSMRenewal handler = new BREGCaseStatusHandlerTNTMSMRenewal();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();
        List<Case> cases = [SELECT Id, breg_Effective_Date__c, breg_Expiration_Date__c FROM Case WHERE Id = :testCase.Id LIMIT 1];
        Assert.areEqual(previousExpirationDate.addYears(5), cases[0].breg_Expiration_Date__c, 'Renewal expiration date should be based on previous TN expiration date plus five years.');
    }

    @isTest
    static void testUpdateExpirationDateForNewRegistration() {
        Case renewalCase = getTestCase();
        Case newRegistrationCase = new Case(
            Subject = 'Test T-2 New Registration Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = renewalCase.RecordTypeId,
            breg_Form_Configuration__c = renewalCase.breg_Form_Configuration__c,
            breg_TN_TM_SM__c = renewalCase.breg_TN_TM_SM__c,
            breg_Form_Code__c = 'T-2',
            breg_TNTMSM_Registration_Type__c = 'New',
            breg_Effective_Date__c = Date.today()
        );
        insert newRegistrationCase;

        BREGCaseStatusHandlerTNTMSMRenewal handler = new BREGCaseStatusHandlerTNTMSMRenewal();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ newRegistrationCase }, 'Approved', false, true);
        Test.stopTest();

        Case updatedCase = [SELECT Id, breg_Effective_Date__c, breg_Expiration_Date__c FROM Case WHERE Id = :newRegistrationCase.Id LIMIT 1];
        Assert.areEqual(
            newRegistrationCase.breg_Effective_Date__c.addYears(5).addDays(-1),
            updatedCase.breg_Expiration_Date__c,
            'New TNTMSM expiration date should be based on effective date plus five years minus one day.'
        );
    }

    /**
     * Test the TNTMSMs update
     */
    @isTest
    static void testUpdateTNTMSMs() {
        Case testCase = getTestCase();

        testCase.breg_Effective_Date__c = Date.today();
        testCase.breg_Expiration_Date__c = Date.today().addYears(5).addDays(-1);
        update testCase;

        BREGCaseStatusHandlerTNTMSMRenewal handler = new BREGCaseStatusHandlerTNTMSMRenewal();
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();
        List<breg_TN_TM_SM__c> updatedTNTMSMs = [SELECT Id, breg_Expiration_Date__c FROM breg_TN_TM_SM__c LIMIT 1];
        Assert.areEqual(testCase.breg_Expiration_Date__c, updatedTNTMSMs[0].breg_Expiration_Date__c, 'The expiration date must be updated.');
    }

    @isTest
    static void testCreateTransactionsForTNTMSMRenewalUsesTNRNCode() {
        Case testCase = getTestCase();
        testCase.breg_Effective_Date__c = Date.today();
        testCase.breg_Name_of_the_Entity__c = 'Renewal Transaction Entity';
        testCase.breg_Is_Renewal__c = true;
        testCase.breg_TNTMSM_Registration_Type__c = 'Renewal';
        update testCase;

        Case caseForTransaction = [
            SELECT
                Id,
                breg_TN_TM_SM__c,
                breg_Form_Code__c,
                breg_Effective_Date__c,
                breg_Name_of_the_Entity__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Is_Renewal__c,
                breg_TNTMSM_Registration_Type__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Id = :testCase.Id
            LIMIT 1
        ];

        Test.startTest();
        BREGTransactionUtils.createTransactionsForTNTMSM(new Map<Id, Case>{ caseForTransaction.Id => caseForTransaction }, 'R');
        Test.stopTest();

        breg_Transaction__c createdTransaction = [
            SELECT Id, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :testCase.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Assert.areEqual('TNRN', createdTransaction.breg_Transaction_Code__c, 'Renewal TNTMSM forms should create TNRN transaction code.');
    }

    private static Case getTestCase() {
        return [
            SELECT
                Id,
                RecordTypeId,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Mailing_Address_Has_Changed__c,
                breg_Company_Address_Has_Changed__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address_State__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Override_Payment__c,
                breg_Resubmission_Received_Date__c,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address_State__c,
                breg_Company_Address__City__s,
                breg_Company_Address__PostalCode__s,
                breg_Outstanding_Shares_Count__c,
                breg_Authorized_Shares_Count__c,
                breg_Portal_User_Entity_Selected__c,
                breg_New_Mailing_Address__CountryCode__s,
                breg_New_Mailing_Address__Street__s,
                breg_New_Mailing_Address_Street_2__c,
                breg_New_Mailing_Address__StateCode__s,
                breg_New_Mailing_Address_State_Text__c,
                breg_New_Mailing_Address__City__s,
                breg_New_Mailing_Address__PostalCode__s,
                breg_New_Company_Address__CountryCode__s,
                breg_New_Company_Address__Street__s,
                breg_New_Company_Address_Street_2__c,
                breg_New_Company_Address__StateCode__s,
                breg_New_Company_Address_State_Text__c,
                breg_New_Company_Address__City__s,
                breg_New_Company_Address__PostalCode__s,
                breg_TNTMSM_Classification__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Registration_Type__c,
                breg_TNTMSM_Description__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Is_Renewal__c,
                breg_Transaction_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Workitem_Number__c,
                breg_TN_TM_SM__c
            FROM Case
            LIMIT 1
        ][0];
    }
}