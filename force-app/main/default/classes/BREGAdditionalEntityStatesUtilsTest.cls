@isTest
public with sharing class BREGAdditionalEntityStatesUtilsTest {

    private static Id bregCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

    @TestSetup
    private static void setupTestData() {
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(3);
        for (Integer index = 0; index < accounts.size(); index++) {
            accounts[index].Name = 'Test Account ' + (index + 1);
        }
        update accounts;

        List<breg_Form_Configuration__c> formConfigs = new List<breg_Form_Configuration__c>{
            new breg_Form_Configuration__c(Name = 'ODC-TEST', breg_Form_Name__c = 'ODC', breg_Suffix_Code__c = 'ODC'),
            new breg_Form_Configuration__c(Name = 'ADD', breg_Suffix_Code__c = 'ADD'),
            new breg_Form_Configuration__c(Name = 'ADD-MEMBER', breg_Suffix_Code__c = 'ADD-MEMBER'),
            new breg_Form_Configuration__c(Name = 'ADD-TNTMSM', breg_Suffix_Code__c = 'ADD-TNTMSM'),
            new breg_Form_Configuration__c(Name = 'X-2', breg_Suffix_Code__c = 'X-2'),
            new breg_Form_Configuration__c(Name = 'ANN-TEST', breg_Suffix_Code__c = 'ANN'),
            new breg_Form_Configuration__c(Name = 'DC-2', breg_Suffix_Code__c = 'DC-2')
        };
        insert formConfigs;

        insert new breg_TN_TM_SM__c(Name = 'Test TN/TM/SM 1');
    }

    @isTest
    private static void testGetAdditionalEntityStatesForAccountNullIdReturnsNull() {
        Assert.areEqual(null, BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(null),
            'Should return null for null accountId');
    }

    @isTest
    private static void testGetAdditionalEntityStatesForAccountInvalidIdReturnsNull() {
        Account deletedAcc = new Account(Name = 'ToDelete');
        insert deletedAcc;
        Id deletedId = deletedAcc.Id;
        delete deletedAcc;
        Assert.areEqual(null, BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(deletedId),
            'Should return null when account not found');
    }

    @isTest
    private static void testAccountBasedGoodStandingAndNotActive() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Good_Standing__c = false;
        account.breg_Entity_Status__c = 'Dissolved (D)';
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isNotNull(result);
        Assert.isTrue(result.values.contains('Not in good standing'));
        Assert.isTrue(result.values.contains('Not active'));
        Assert.isTrue(result.valueString != null && result.valueString.contains('Not in good standing'));
    }

    @isTest
    private static void testAccountBasedExpiredStatus() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Entity_Status__c = 'Expired (E)';
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Expired'));
        Assert.isTrue(result.values.contains('Not active'));
    }

    @isTest
    private static void testAccountBasedMergedStatus() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Entity_Status__c = 'Merged (M)';
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Not survivor or merged entity'));
        Assert.isTrue(result.values.contains('Not active'));
    }

    @isTest
    private static void testAccountBasedNotACRA() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_BRIM_CRA_FL__c = false;
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Not a CRA'));
    }

    @isTest
    private static void testAccountBasedNoActiveAgentCRA() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Certified_Register_Agent__c = null;
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('No active agent associated who is not a CRA'));
    }

    @isTest
    private static void testAccountBasedNotZZFileSuffix() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_File_Suffix__c = 'LLC';
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Not have a ZZ file suffix'));
    }

    @isTest
    private static void testAccountBasedNotEntity() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Registrant_Type__c = 'Individual';
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Not Entity'));
    }

    @isTest
    private static void testAccountBased180DaysAfterIncorporation() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Incorporation_Date__c = Date.today().addDays(-200);
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Current date is not within the last 180 days of active term'));
    }

    @isTest
    private static void testAccountBasedMoreThan14DaysPriorToExpiration() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Expiration_Date__c = Date.today().addDays(30);
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('More than 14 days prior to the expiration date'));
    }

    @isTest
    private static void testAccountBasedExpiredMoreThan180Days() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Expiration_Date__c = Date.today().addDays(-200);
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Expired more than 180 days'));
    }

    @isTest
    private static void testAccountBased120DaysAfterDissolution() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Date_of_dissol_cancel_revoc_term__c = Date.today().addDays(-150);
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('120 days after dissolution effective date'));
    }

    @isTest
    private static void testAccountBased2YearsAfterDissolution() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Entity_Status__c = 'Dissolved (D)';
        account.breg_Date_of_dissol_cancel_revoc_term__c = Date.today().addDays(-800);
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('2 years after dissolution'));
    }

    // --- Case-based: Pending ODC, ADD, Pending annual, Bounce check ---

    @isTest
    private static void testCaseBasedPendingODCRequest() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Name__c = 'ODC' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Pending ODC request'));
    }

    @isTest
    private static void testCaseBasedPendingADDRequest() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'ADD' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Entity__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Pending ADD request'));
    }

    @isTest
    private static void testCaseBasedPendingAnnual() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'ANN-TEST' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Pending annual'));
    }

    @isTest
    private static void testCaseBasedBounceCheckInProgress() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'ADD' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Entity__c = account.Id,
            breg_Bounced_Check__c = true
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Bounce check in progress'));
    }

    @isTest
    private static void testCaseBasedPendingNotAddedWhenStatusApproved() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Name__c = 'ODC' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'Approved',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isFalse(result.values.contains('Pending ODC request'),
            'Pending values should not be set when Case Status is Approved');
    }

    @isTest
    private static void testCaseBasedPendingNotAddedWhenStatusRejected() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Name__c = 'ODC' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'Rejected',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isFalse(result.values.contains('Pending ODC request'),
            'Pending values should not be set when Case Status is Rejected');
    }

    @isTest
    private static void testCaseBasedPendingNotAddedWhenStatusCancelled() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Name__c = 'ODC' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'Cancelled',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isFalse(result.values.contains('Pending ODC request'),
            'Pending values should not be set when Case Status is Cancelled');
    }

    // --- Has no amendments approved ---

    @isTest
    private static void testHasNoAmendmentsApproved() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        // No approved Case with amendment form (DC-2, etc.) for this account

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Has no amendments approved'));
    }

    @isTest
    private static void testHasAmendmentsApprovedWhenApprovedCaseExists() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'DC-2' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'Approved',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Entity__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isFalse(result.values.contains('Has no amendments approved'),
            'Should not have "Has no amendments approved" when an approved amendment Case exists');
    }

    // --- No active registered agent ---

    @isTest
    private static void testNoActiveRegisteredAgent() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        // No Account Affiliation with Role=Agent, Status=A, End_Date=null

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('No active registered agent'));
    }

    @isTest
    private static void testHasActiveRegisteredAgentWhenAffiliationExists() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        Account account2 = [SELECT Id, breg_BRIM_CRA_FL__c FROM Account WHERE Name = 'Test Account 2'];
        account2.breg_BRIM_CRA_FL__c = false;
        update account2;

        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(
            breg_Entity__c = account.Id,
            breg_Account__c = account2.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_As_of_Date__c = Date.today()
        );
        insert aff;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isFalse(result.values.contains('No active registered agent'),
            'Should not have "No active registered agent" when active Agent affiliation exists');
    }

    @isTest
    private static void testNoActiveNonCraAgentWhenAffiliationTypeIsCra() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        Account account2 = [SELECT Id, breg_BRIM_CRA_FL__c FROM Account WHERE Name = 'Test Account 2'];
        account2.breg_BRIM_CRA_FL__c = false;
        update account2;

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = account.Id,
            breg_Account__c = account2.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'CRA',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_As_of_Date__c = Date.today()
        );

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('No active agent associated who is not a CRA'),
            'CRA type should not count as an active non-CRA agent');
    }

    @isTest
    private static void testNoActiveNonCraAgentWhenAccountFlagIsCra() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 2'];

        Account account2 = new Account(
            Name = 'CRA Link Account',
            breg_BRIM_CRA_FL__c = true,
            breg_Formation_State__c = 'DE',
            breg_Registrant_Address__Street__s = '1 Main St',
            breg_Entity_Type__c = 'C5',
            BillingStreet = '1 Main St',
            BillingCity = 'Dover',
            BillingStateCode = 'DE',
            BillingPostalCode = '19901',
            BillingCountryCode = 'US'
        );
        insert account2;

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = account.Id,
            breg_Account__c = account2.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_As_of_Date__c = Date.today()
        );

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('No active agent associated who is not a CRA'),
            'CRA account flag should mark agent as CRA even when affiliation type is not CRA');
    }

    // --- Result structure ---

    @isTest
    private static void testResultStructureValueStringAndValues() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        account.breg_Good_Standing__c = false;
        update account;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isNotNull(result.valueString);
        Assert.isNotNull(result.values);
        Assert.isTrue(result.values.size() > 0);
        Assert.isTrue(result.valueString.contains(';') || result.values.size() == 1,
            'valueString should be semicolon-separated when multiple values');
    }

    @isTest
    private static void testPendingTransferOfNameReservation() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'X-2' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Portal_User_Entity_Selected__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Pending transfer of name reservation'));
    }

    @isTest
    private static void testPendingODMMPADDRequest() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'ADD-MEMBER' LIMIT 1];

        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Entity__c = account.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForAccount(account.Id);

        Assert.isTrue(result.values.contains('Pending O/D/M/M/P ADD request'));
    }


    @isTest
    private static void testGetAdditionalEntityStatesForTNTMSMNullIdReturnsNull() {
        Assert.areEqual(null, BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForTNTMSM(null),
            'Should return null for null tntmsmId');
    }

    @isTest
    private static void testGetAdditionalEntityStatesForTNTMSMInvalidIdReturnsNull() {
        breg_TN_TM_SM__c rec = new breg_TN_TM_SM__c(Name = 'ToDelete');
        insert rec;
        Id deletedId = rec.Id;
        delete rec;
        Assert.areEqual(null, BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForTNTMSM(deletedId),
            'Should return null when TNTMSM record not found');
    }

    @isTest
    private static void testTNTMSMBasedNotActiveAndExpired() {
        breg_TN_TM_SM__c rec = [SELECT Id FROM breg_TN_TM_SM__c WHERE Name = 'Test TN/TM/SM 1'];
        rec.breg_Status__c = 'E';
        update rec;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForTNTMSM(rec.Id);

        Assert.isNotNull(result);
        Assert.isTrue(result.values.contains('Not active'));
        Assert.isTrue(result.values.contains('Expired'));
    }

    @isTest
    private static void testTNTMSMBasedFileSuffixAndRegistrantType() {
        breg_TN_TM_SM__c rec = [SELECT Id FROM breg_TN_TM_SM__c WHERE Name = 'Test TN/TM/SM 1'];
        rec.breg_File_Suffix__c = 'AG';
        rec.breg_Registrant_Type__c = 'Individual';
        update rec;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForTNTMSM(rec.Id);

        Assert.isNotNull(result);
        Assert.isTrue(result.values.contains('Not have a ZZ file suffix'));
        Assert.isTrue(result.values.contains('Not Entity'));
    }

    @isTest
    private static void testTNTMSMCaseBasedPendingADD() {
        breg_TN_TM_SM__c rec = [SELECT Id FROM breg_TN_TM_SM__c WHERE Name = 'Test TN/TM/SM 1'];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE Name = 'ADD-TNTMSM' LIMIT 1];
        Case testCase = new Case(
            RecordTypeId = bregCaseRtId,
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = formConfig.Id,
            breg_TN_TM_SM__c = rec.Id
        );
        insert testCase;

        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult result =
            BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForTNTMSM(rec.Id);

        Assert.isNotNull(result);
        Assert.isTrue(result.values.contains('Pending ADD request'));
    }
}