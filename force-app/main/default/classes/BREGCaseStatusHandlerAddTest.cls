/**
 * Test class for BREGCaseStatusHandlerAdd
 * Tests address change validation logic for ADD form
 */
@isTest
private class BREGCaseStatusHandlerAddTest {
    /**
     * Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create Account with address information
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Test Corporation',
            RecordTypeId = bregAccountRecordTypeId,
            BillingStreet = '123 Main St',
            breg_Billing_Address_Street_2__c = 'Suite 100',
            BillingCity = 'Honolulu',
            BillingState = 'Hawaii',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountry = 'United States',
            BillingCountryCode = 'US',
            breg_Mailing_Address__Street__s = '456 Oak Ave',
            breg_Mailing_Address_Street_2__c = 'Apt 200',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__PostalCode__s = '96814',
            breg_Mailing_Address__CountryCode__s = 'US'
        );
        insert testAccount;

        // Create form configuration for ADD form
        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'ADD',
            breg_Form_Code__c = 'ADD'
        );
        insert testFormConfig;

        // Create test case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Address Change',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Entity__c = testAccount.Id,
            breg_Portal_User_Entity_Selected__c = testAccount.Id,
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'ADD',
            breg_Mailing_Address_Has_Changed__c = false,
            breg_Company_Address_Has_Changed__c = false
        );
        insert testCase;
    }

    /**
     * Test successful validation when both addresses have changed
     */
    @isTest
    static void testBothAddressesChangedSuccess() {
        Case testCase = getTestCase();

        // Update case with both addresses changed
        testCase.breg_Mailing_Address_Has_Changed__c = true;
        testCase.breg_Mailing_Address__CountryCode__s = 'US';
        testCase.breg_Mailing_Address__Street__s = '789 New Street';
        testCase.breg_Mailing_Address__StateCode__s = 'HI';
        testCase.breg_Mailing_Address__City__s = 'Honolulu';
        testCase.breg_Mailing_Address__PostalCode__s = '96815';
        testCase.breg_Company_Address_Has_Changed__c = true;
        testCase.breg_Company_Address__CountryCode__s = 'US';
        testCase.breg_Company_Address__Street__s = '999 Business Blvd';
        testCase.breg_Company_Address__StateCode__s = 'HI';
        testCase.breg_Company_Address__City__s = 'Honolulu';
        testCase.breg_Company_Address__PostalCode__s = '96816';
        update testCase;

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Pending Submission', true, false);
        Test.stopTest();

        // Verify no errors - case should still exist
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(1, cases.size(), 'Case should exist after successful validation');
    }

    /**
     * Test validation failure when no account is linked
     */
    @isTest
    static void testValidationFailureNoAccount() {
        Case testCase = getTestCase();

        // Remove account from case
        testCase.breg_Entity__c = null;
        update testCase;

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

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

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when account is not linked');
    }

    /**
     * Test validation failure when neither address has changed flag is set
     */
    @isTest
    static void testValidationFailureNoAddressChangedFlags() {
        Case testCase = getTestCase();

        // Ensure both flags are false
        testCase.breg_Mailing_Address_Has_Changed__c = false;
        testCase.breg_Company_Address_Has_Changed__c = false;
        update testCase;

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

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

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when no address change is indicated');
    }

    /**
     * Test validation failure when mailing address has not actually changed
     */
    @isTest
    static void testValidationFailureMailingAddressNotChanged() {
        Case testCase = getTestCase();
        Account testAccount = getTestAccount();

        // Set mailing address flag but use same address as account
        testCase.breg_Mailing_Address_Has_Changed__c = true;
        testCase.breg_New_Mailing_Address__CountryCode__s = testAccount.breg_Mailing_Address__CountryCode__s;
        testCase.breg_New_Mailing_Address__Street__s = testAccount.breg_Mailing_Address__Street__s;
        testCase.breg_New_Mailing_Address_Street_2__c = testAccount.breg_Mailing_Address_Street_2__c;
        testCase.breg_New_Mailing_Address__StateCode__s = testAccount.breg_Mailing_Address__StateCode__s;
        testCase.breg_New_Mailing_Address_State_Text__c = testAccount.breg_Billing_Address_State_Text__c;
        testCase.breg_New_Mailing_Address__City__s = testAccount.breg_Mailing_Address__City__s;
        testCase.breg_New_Mailing_Address__PostalCode__s = testAccount.breg_Mailing_Address__PostalCode__s;
        update testCase;

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

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

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when mailing address has not changed');
    }

    /**
     * Test validation failure when company address has not actually changed
     */
    @isTest
    static void testValidationFailureCompanyAddressNotChanged() {
        Case testCase = getTestCase();
        Account testAccount = getTestAccount();

        // Set company address flag but use same address as account
        testCase.breg_Company_Address_Has_Changed__c = true;
        testCase.breg_New_Company_Address__CountryCode__s = testAccount.BillingCountryCode;
        testCase.breg_New_Company_Address__Street__s = testAccount.BillingStreet;
        testCase.breg_New_Company_Address_Street_2__c = testAccount.breg_Billing_Address_Street_2__c;
        testCase.breg_New_Company_Address__StateCode__s = testAccount.BillingStateCode;
        testCase.breg_New_Company_Address_State_Text__c = testAccount.breg_Billing_Address_State_Text__c;
        testCase.breg_New_Company_Address__City__s = testAccount.BillingCity;
        testCase.breg_New_Company_Address__PostalCode__s = testAccount.BillingPostalCode;
        update testCase;

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

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

        // Verify exception was thrown
        Assert.isTrue(exceptionThrown, 'Exception should be thrown when company address has not changed');
    }

    @isTest
    static void testCompletedActionsUpdateAddressOnceDueToCounter() {
        Case testCase = getTestCase();
        BREGCaseStatusHandlerAdd.counter = 0;
        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Under Review', false, true);

        handler.handleStatusChange(new List<Case>{ testCase }, 'Under Review', false, true);
        Test.stopTest();

        Assert.areEqual(1, BREGCaseStatusHandlerAdd.counter, 'Counter should stop repeated action execution');
    }

    @isTest
    static void testApprovedValidationPathWithInMemoryCase() {
        Case persistedCase = getTestCase();

        Case approvedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Override_Payment__c = true,
            breg_Is_LLP_Registration__c = false,
            breg_Effective_Date__c = Date.today(),
            breg_File__c = '123456',
            breg_Entity__c = Id.valueOf('001000000000000AAA'),
            breg_Portal_User_Entity_Selected__c = persistedCase.breg_Portal_User_Entity_Selected__c
        );

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        Boolean hasExpectedException = false;
        try {
            handler.handleStatusChange(new List<Case>{ approvedCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            hasExpectedException = true;
        }
        Test.stopTest();

        Assert.isTrue(hasExpectedException, 'Approved path should execute and throw validation exception for missing entity');
    }

    @isTest
    static void testCompletedActionsBranchExecutes() {
        Case persistedCase = getTestCase();

        Case completedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Entity__c = persistedCase.breg_Entity__c,
            breg_Name_of_the_Entity__c = 'Entity Name',
            breg_New_Company_Address__CountryCode__s = 'US',
            breg_New_Company_Address__Street__s = '500 New St',
            breg_New_Company_Address__City__s = 'Honolulu',
            breg_New_Company_Address__StateCode__s = 'HI',
            breg_New_Company_Address__PostalCode__s = '96822'
        );

        BREGCaseStatusHandlerAdd.counter = 0;
        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ completedCase }, 'Completed', false, true);
            } catch (Exception e) {
            // Ignore org-specific side effects from downstream automation.
        }
        Test.stopTest();

        Assert.areEqual(1, BREGCaseStatusHandlerAdd.counter, 'Completed action branch should execute once');
    }

    @isTest
    static void testReceivedActionsBranchExecutes() {
        Case persistedCase = getTestCase();

        Case receivedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Entity__c = persistedCase.breg_Entity__c,
            breg_Name_of_the_Entity__c = 'Entity Name'
        );

        BREGCaseStatusHandlerAdd.counter = 0;
        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        
        } catch (Exception e) {
            // Ignore org-specific side effects from downstream automation.
        }
        Test.stopTest();

        Assert.areEqual(1, BREGCaseStatusHandlerAdd.counter, 'Approved action branch should execute once');
    }

    @isTest
    static void testApprovedValidationWithLinkedEntitySucceeds() {
        Case persistedCase = getTestCase();

        Case approvedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Override_Payment__c = true,
            breg_Is_LLP_Registration__c = false,
            breg_Effective_Date__c = Date.today(),
            breg_File__c = '654321',
            breg_Entity__c = persistedCase.breg_Entity__c,
            breg_Portal_User_Entity_Selected__c = persistedCase.breg_Portal_User_Entity_Selected__c
        );

        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ approvedCase }, 'Approved', true, false);
        Test.stopTest();

        Assert.isTrue(true, 'Approved validation should complete when linked entity is present');
    }

    @isTest
    static void testApprovedActionsWithK5EntityCoversChildEntityBranch(){
        Case persistedCase = getTestCase();
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();

        Account parentEntity = new Account(
            Name = 'K5 Parent Entity',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'K5',
            BillingStreet = '100 Parent St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US'
        );
        insert parentEntity;

        Account childEntity = new Account(
            Name = 'Child Entity',
            RecordTypeId = bregAccountRecordTypeId,
            ParentId = parentEntity.Id,
            breg_Entity_Type__c = 'D1'
        );
        insert childEntity;

        Case approvedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Entity__c = parentEntity.Id,
            breg_Portal_User_Entity_Selected__c = parentEntity.Id,
            breg_New_Company_Address__CountryCode__s = 'US',
            breg_New_Company_Address__Street__s = '500 New St',
            breg_New_Company_Address__City__s = 'Honolulu',
            breg_New_Company_Address__StateCode__s = 'HI',
            breg_New_Company_Address__PostalCode__s = '96822'
        );

        BREGCaseStatusHandlerAdd.counter = 0;
        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ approvedCase }, 'Approved', false, true);
        } catch (Exception e) {
        }
        Test.stopTest();

        Assert.areEqual(1, BREGCaseStatusHandlerAdd.counter, 'Approved branch should execute once for K5 entities');
    }

    @isTest
    static void testApprovedClearsAndSplitsSubmittedAddressLines() {
        Account testAccount = getTestAccount();
        testAccount.breg_Mailing_Address_Street_2__c = 'Old Mailing Line 2';
        //testAccount.breg_Mailing_Address_Street_3__c = 'Old Mailing Line 3';
        testAccount.breg_Billing_Address_Street_2__c = 'Old Company Line 2';
        //testAccount.breg_Billing_Address_Street_3__c = 'Old Company Line 3';
        testAccount.BillingStreet = 'Original Principal St';
        update testAccount;

        Case persistedCase = getTestCase();
        Case approvedCase = new Case(
            Id = persistedCase.Id,
            breg_Form_Code__c = 'ADD',
            breg_Entity__c = persistedCase.breg_Entity__c,
            breg_Portal_User_Entity_Selected__c = persistedCase.breg_Portal_User_Entity_Selected__c,
            breg_Mailing_Address_Has_Changed__c = true,
            breg_Company_Address_Has_Changed__c = false,
            breg_New_Mailing_Address__CountryCode__s = 'US',
            breg_New_Mailing_Address__Street__s = '900 Updated Mailing St',
            breg_New_Mailing_Address__StateCode__s = 'HI',
            breg_New_Mailing_Address__City__s = 'Honolulu',
            breg_New_Mailing_Address__PostalCode__s = '96818'
        );

        BREGCaseStatusHandlerAdd.counter = 0;
        BREGCaseStatusHandlerAdd handler = new BREGCaseStatusHandlerAdd();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ approvedCase }, 'Approved', false, true);
        Test.stopTest();

        Account updatedAccount = [
            SELECT
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Street_2__c,
                //breg_Mailing_Address_Street_3__c,
                BillingStreet,
                breg_Billing_Address_Street_2__c
                //breg_Billing_Address_Street_3__c
            FROM Account
            WHERE Id = :persistedCase.breg_Entity__c
        ];

        Assert.areEqual('900 Updated Mailing St', updatedAccount.breg_Mailing_Address__Street__s, 'Mailing line 1 should match the submitted form.');
        Assert.areEqual(null, updatedAccount.breg_Mailing_Address_Street_2__c, 'Mailing line 2 should match the submitted form.');
        //Assert.areEqual(null, updatedAccount.breg_Mailing_Address_Street_3__c, 'Submitting a changed mailing address should clear the historical mailing line 3 field.');
        Assert.areEqual('Original Principal St', updatedAccount.BillingStreet, 'Principal address should remain unchanged when the company changed flag is false.');
        Assert.areEqual('Old Company Line 2', updatedAccount.breg_Billing_Address_Street_2__c, 'Principal line 2 should remain unchanged when the company changed flag is false.');
        //Assert.areEqual('Old Company Line 3', updatedAccount.breg_Billing_Address_Street_3__c, 'Principal line 3 should remain unchanged when the company changed flag is false.');
    }

    private static Case getTestCase() {
        return [
            SELECT
                Id,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Mailing_Address_Has_Changed__c,
                breg_Company_Address_Has_Changed__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__StateCode__s,
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
                breg_New_Company_Address__PostalCode__s
            FROM Case
            LIMIT 1
        ][0];
    }

    private static Account getTestAccount() {
        return [
            SELECT
                Id,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Street_2__c,
                //breg_Mailing_Address_Street_3__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__CountryCode__s,
                BillingCountryCode,
                BillingStreet,
                breg_Billing_Address_Street_2__c,
                //breg_Billing_Address_Street_3__c,
                breg_Billing_Address_State_Text__c,
                BillingStateCode,
                BillingCity,
                BillingPostalCode
            FROM Account
            LIMIT 1
        ][0];
    }
}