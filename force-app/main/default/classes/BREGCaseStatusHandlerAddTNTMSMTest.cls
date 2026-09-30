/**
 * Test class for BREGCaseStatusHandlerAddTNTMSM
 * Tests address change validation logic for ADD-TNTMSM form
 */
@isTest
private class BREGCaseStatusHandlerAddTNTMSMTest {
    /**
     * Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create TN/TM/SM record with address information
        breg_TN_TM_SM__c testTNTMSM = new breg_TN_TM_SM__c(
            Name = 'Test TN Record',
            breg_Type__c = 'Trade Name',
            breg_Mailing_Address__Street__s = '456 Oak Ave',
            // breg_Mailing_Address_Street_2__c = 'Suite 300',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__PostalCode__s = '96814',
            breg_Mailing_Address__CountryCode__s = 'US'
        );
        insert testTNTMSM;

        // Create form configuration for ADD-TNTMSM form
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'ADD-TNTMSM',
            breg_Form_Code__c = 'ADD-TNTMSM'
        );
        insert testFormConfig;

        // Create test case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('BREG_Case')
            .getRecordTypeId();

        Case testCase = new Case(
            Subject = 'Test TN Address Change',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_TN_TM_SM__c = testTNTMSM.Id,
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'ADD-TNTMSM'
        );
        insert testCase;
    }

    /**
     * Test successful validation when address has changed
     */
    @isTest
    static void testAddressChangedSuccess() {
        Case testCase = getTestCase();

        setCompanyAddressToHonoluluChange(testCase);
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        Test.stopTest();

        // Verify no errors - case should still exist
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful validation');
    }

    /**
     * Test validation failure when no TN/TM/SM is linked
     */
    @isTest
    static void testValidationFailureNoTNTMSM() {
        Case testCase = getTestCase();

        // Remove TN/TM/SM from case
        testCase.breg_TN_TM_SM__c = null;
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when TN/TM/SM/PRN is not linked');
    }

    /**
     * Test validation failure when address has not actually changed
     */
    @isTest
    static void testValidationFailureAddressNotChanged() {
        Case testCase = getTestCase();
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        setCompanyAddressFromTNTMSM(testCase, testTNTMSM);
        setNewMailingAddressFromTNTMSM(testCase, testTNTMSM);
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when address has not changed');
    }

    /**
     * Test received processing creates one transaction for the linked TN/TM/SM
     */
    @isTest
    static void testReceivedCreatesSingleTransaction() {
        Case testCase = getTestCase();
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        testCase.breg_Company_Address_Has_Changed__c = true;
        setCompanyAddressToTorontoChange(testCase);
        testCase.breg_Effective_Date__c = System.today();
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        // Verify transactions were created
        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_TN_TM_SM__c, breg_Start_Date__c, breg_Effective_Date__c, breg_Status__c, breg_End_Date__c
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c = :testTNTMSM.Id
        ];
        Assert.areEqual(1, transactions.size(), 'One received transaction should be created for the linked TN/TM/SM');
        Assert.areEqual(testTNTMSM.Id, transactions[0].breg_TN_TM_SM__c, 'Transaction should stay linked to the TN/TM/SM record');
        Assert.areEqual(testCase.breg_Effective_Date__c, transactions[0].breg_Start_Date__c, 'Start date should match the case effective date');
        Assert.areEqual(testCase.breg_Effective_Date__c, transactions[0].breg_Effective_Date__c, 'Effective date should be copied to the transaction');
        Assert.areEqual('R', transactions[0].breg_Status__c, 'Received transactions should be created with status R');
        Assert.areEqual(null, transactions[0].breg_End_Date__c, 'Received processing should not create a separate old-address transaction');
    }

    /**
     * Test address update when case is approved
     */
    @isTest
    static void testUpdateAddressOnApproved() {
        Case testCase = getTestCase();
        breg_TN_TM_SM__c testTNTMSM = getTestTNTMSM();

        setNewMailingAddressToLosAngelesChange(testCase);
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        Test.stopTest();

        // Verify TNTMSM address was updated
        breg_TN_TM_SM__c updatedTNTMSM = [
            SELECT breg_Mailing_Address__Street__s, breg_Mailing_Address__City__s
            FROM breg_TN_TM_SM__c
            WHERE Id = :testTNTMSM.Id
        ];

        Assert.areEqual('999 Final Street', updatedTNTMSM.breg_Mailing_Address__Street__s, 'Street address should be updated');
        Assert.areEqual('Los Angeles', updatedTNTMSM.breg_Mailing_Address__City__s, 'City should be updated');
    }

    /**
     * Test no transactions created when company address has not changed
     */
    @isTest
    static void testNoTransactionsWhenAddressNotChanged() {
        Case testCase = getTestCase();

        // Address has not changed flag is false
        testCase.breg_Company_Address_Has_Changed__c = false;
        testCase.breg_Effective_Date__c = System.today();
        update testCase;

        BREGCaseStatusHandlerAddTNTMSM handler = new BREGCaseStatusHandlerAddTNTMSM();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        // Verify no transactions were created
        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_File_Number__c = :testCase.Id
        ];

        Assert.areEqual(0, transactions.size(), 'No transactions should be created when address has not changed');
    }

    public static Case getTestCase() {
        return TestHelper.getTestCase();
    }

    private static void setCompanyAddressFromTNTMSM(Case testCase, breg_TN_TM_SM__c testTNTMSM) {
        testCase.breg_Company_Address__CountryCode__s = testTNTMSM.breg_Mailing_Address__CountryCode__s;
        testCase.breg_Company_Address__Street__s = testTNTMSM.breg_Mailing_Address__Street__s;
        testCase.breg_Company_Address__StateCode__s = testTNTMSM.breg_Mailing_Address__StateCode__s;
        testCase.breg_Company_Address__City__s = testTNTMSM.breg_Mailing_Address__City__s;
        testCase.breg_Company_Address__PostalCode__s = testTNTMSM.breg_Mailing_Address__PostalCode__s;
    }

    private static void setNewMailingAddressFromTNTMSM(Case testCase, breg_TN_TM_SM__c testTNTMSM) {
        testCase.breg_New_Mailing_Address__CountryCode__s = testTNTMSM.breg_Mailing_Address__CountryCode__s;
        testCase.breg_New_Mailing_Address__Street__s = testTNTMSM.breg_Mailing_Address__Street__s;
        testCase.breg_New_Mailing_Address__StateCode__s = testTNTMSM.breg_Mailing_Address__StateCode__s;
        testCase.breg_New_Mailing_Address__City__s = testTNTMSM.breg_Mailing_Address__City__s;
        testCase.breg_New_Mailing_Address__PostalCode__s = testTNTMSM.breg_Mailing_Address__PostalCode__s;
    }

    private static void setCompanyAddressToHonoluluChange(Case testCase) {
        testCase.breg_Company_Address__CountryCode__s = 'US';
        testCase.breg_Company_Address__Street__s = '789 New Street';
        testCase.breg_Company_Address__StateCode__s = 'HI';
        testCase.breg_Company_Address__City__s = 'Honolulu';
        testCase.breg_Company_Address__PostalCode__s = '96815';
    }

    private static void setCompanyAddressToTorontoChange(Case testCase) {
        testCase.breg_Company_Address__CountryCode__s = 'CA';
        testCase.breg_Company_Address__Street__s = '100 New Ave';
        testCase.breg_Company_Address__StateCode__s = 'ON';
        testCase.breg_Company_Address__City__s = 'Toronto';
        testCase.breg_Company_Address__PostalCode__s = 'M5V 3A8';
    }

    private static void setNewMailingAddressToLosAngelesChange(Case testCase) {
        testCase.breg_New_Mailing_Address__CountryCode__s = 'US';
        testCase.breg_New_Mailing_Address__Street__s = '999 Final Street';
        testCase.breg_New_Mailing_Address__StateCode__s = 'CA';
        testCase.breg_New_Mailing_Address__City__s = 'Los Angeles';
        testCase.breg_New_Mailing_Address__PostalCode__s = '90001';
    }

    private static breg_TN_TM_SM__c getTestTNTMSM() {
        return [
            SELECT
                Id,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__CountryCode__s
            FROM breg_TN_TM_SM__c
            LIMIT 1
        ][0];
    }
}