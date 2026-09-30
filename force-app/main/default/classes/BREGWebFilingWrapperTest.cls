@isTest
private class BREGWebFilingWrapperTest {
    // ─── Constructor ──────────────────────────────────────────────────────────

    @isTest
    static void testConstructorInitializesAllCollections() {
        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();

        Assert.isNotNull(wrapper.WebCase, 'WebCase should be initialized');
        Assert.isNotNull(wrapper.AccountAffiliations, 'AccountAffiliations should be initialized');
        Assert.isNotNull(wrapper.Stocks, 'Stocks should be initialized');
        Assert.isNotNull(wrapper.TradeMarks, 'TradeMarks should be initialized');
        Assert.isTrue(wrapper.AccountAffiliations.isEmpty(), 'AccountAffiliations should start empty');
        Assert.isTrue(wrapper.Stocks.isEmpty(), 'Stocks should start empty');
        Assert.isTrue(wrapper.TradeMarks.isEmpty(), 'TradeMarks should start empty');
    }

    // ─── createMembers — guard paths ─────────────────────────────────────────

    @isTest
    static void testCreateMembersNullWrapperReturnsEmpty() {
        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(null);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isEmpty(), 'Null wrapper should return empty list');
    }

    @isTest
    static void testCreateMembersNullAffiliationsReturnsEmpty() {
        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.AccountAffiliations = null;

        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isEmpty(), 'Null affiliations list should return empty list');
    }

    @isTest
    static void testCreateMembersEmptyAffiliationsReturnsEmpty() {
        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        // AccountAffiliations is already empty from constructor

        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isEmpty(), 'Empty affiliations list should return empty list');
    }

    // ─── createMembers — account insertion ───────────────────────────────────

    @isTest
    static void testCreateMembersInsertsNewAccount() {
        Id bregCaseRTId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRTId);
        insert testCase;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        affWrapper.Account = new Account(Name = 'Test Entity LLC');
        // Contact left with no name — will be inserted as-is
        affWrapper.Contact = null;
        wrapper.AccountAffiliations.add(affWrapper);

        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return one affiliation wrapper');
        Assert.isNotNull(affWrapper.Account.Id, 'Account should have been inserted and have an Id');

        List<breg_Account_Affiliation__c> affiliations = [SELECT Id, breg_Case__c, breg_Account__c FROM breg_Account_Affiliation__c];
        Assert.areEqual(1, affiliations.size(), 'One affiliation should be inserted');
        Assert.areEqual(testCase.Id, affiliations[0].breg_Case__c, 'Affiliation case lookup should be set from WebCase');
        Assert.areEqual(affWrapper.Account.Id, affiliations[0].breg_Account__c, 'Affiliation account lookup should be set from inserted account');
    }

    // ─── createMembers — contact insertion ───────────────────────────────────

    @isTest
    static void testCreateMembersInsertsNewContact() {
        Id bregCaseRTId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRTId);
        insert testCase;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        affWrapper.Account = null;
        affWrapper.Contact = new Contact(LastName = 'TestContact');
        wrapper.AccountAffiliations.add(affWrapper);

        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return one affiliation wrapper');
        Assert.isNotNull(affWrapper.Contact.Id, 'Contact should have been inserted and have an Id');

        List<breg_Account_Affiliation__c> affiliations = [SELECT Id, breg_Case__c, breg_Contact__c FROM breg_Account_Affiliation__c];
        Assert.areEqual(1, affiliations.size(), 'One affiliation should be inserted');
        Assert.areEqual(affWrapper.Contact.Id, affiliations[0].breg_Contact__c, 'Affiliation contact lookup should be set from inserted contact');
    }

    // ─── createMembers — already-existing account skipped ────────────────────

    @isTest
    static void testCreateMembersSkipsExistingAccount() {
        Account existingAccount = new Account(Name = 'Existing Corp');
        insert existingAccount;

        Id bregCaseRTId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRTId);
        insert testCase;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        affWrapper.Account = existingAccount; // already has Id
        affWrapper.Contact = null;
        wrapper.AccountAffiliations.add(affWrapper);

        Integer accountCountBefore = [SELECT COUNT() FROM Account];

        Test.startTest();
        BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Integer accountCountAfter = [SELECT COUNT() FROM Account];
        Assert.areEqual(accountCountBefore, accountCountAfter, 'Existing account should not be re-inserted');
    }

    // ─── createMembers — null affiliation wrapper in list skipped ─────────────

    @isTest
    static void testCreateMembersSkipsNullAffiliationWrapper() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;
        wrapper.AccountAffiliations.add(null);

        Test.startTest();
        List<BREGWebAccountAffiliationWrapper> result = BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'The null wrapper should still be in the returned list (from filingWrapper.AccountAffiliations)');
        Assert.areEqual(0, [SELECT COUNT() FROM breg_Account_Affiliation__c], 'No affiliation should be inserted for null wrapper entry');
    }

    // ─── createMembers — affiliation with null accountAffiliation skipped ─────

    @isTest
    static void testCreateMembersSkipsWrapperWithNullAffiliation() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        affWrapper.Account = null; // prevent Account DML with no Name
        affWrapper.Contact = null;
        affWrapper.accountAffiliation = null;
        wrapper.AccountAffiliations.add(affWrapper);

        Test.startTest();
        BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM breg_Account_Affiliation__c], 'No affiliation should be inserted when accountAffiliation is null');
    }

    // ─── createMembers — affiliation with existing Id is not re-inserted ──────

    @isTest
    static void testCreateMembersSkipsExistingAffiliation() {
        Account acct = new Account(Name = 'Corp');
        insert acct;
        Id bregCaseRTId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRTId);
        insert testCase;
        breg_Account_Affiliation__c existing = new breg_Account_Affiliation__c(breg_Case__c = testCase.Id, breg_Account__c = acct.Id);
        insert existing;

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.Id = testCase.Id;

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        affWrapper.Account = acct;
        affWrapper.accountAffiliation = existing; // already has Id
        affWrapper.Contact = null;
        wrapper.AccountAffiliations.add(affWrapper);

        Integer countBefore = [SELECT COUNT() FROM breg_Account_Affiliation__c];

        Test.startTest();
        BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        Assert.areEqual(countBefore, [SELECT COUNT() FROM breg_Account_Affiliation__c], 'Existing affiliation should not be re-inserted');
    }

    // ─── setAffiliationLookups — WebCase has no Id ────────────────────────────

    @isTest
    static void testCreateMembersWithNoCaseIdDoesNotSetCaseLookup() {
        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        // WebCase has no Id (not inserted)

        BREGWebAccountAffiliationWrapper affWrapper = new BREGWebAccountAffiliationWrapper();
        Account acct = new Account(Name = 'No-Case Corp');
        insert acct;
        affWrapper.Account = acct;
        affWrapper.Contact = null;
        wrapper.AccountAffiliations.add(affWrapper);

        Test.startTest();
        BREGWebFilingWrapper.createMembers(wrapper);
        Test.stopTest();

        List<breg_Account_Affiliation__c> affiliations = [SELECT Id, breg_Case__c FROM breg_Account_Affiliation__c];
        Assert.areEqual(1, affiliations.size());
        Assert.isNull(affiliations[0].breg_Case__c, 'Case lookup should not be set when WebCase has no Id');
    }
}