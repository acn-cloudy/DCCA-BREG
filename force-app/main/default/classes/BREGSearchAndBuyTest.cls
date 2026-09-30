@isTest
private class BREGSearchAndBuyTest {
    // Setup common test data for all tests (queries use breg_Search_Name__c, not Name)
    @testSetup
    static void makeTestData() {
        // Query for the BREG_Account Record Type ID
        Id bregAccountRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'BREG_Account'
            LIMIT 1
        ]
        .Id;
        System.assertNotEquals(null, bregAccountRecordTypeId, 'BREG_Account Record Type ID must be found.');

        List<Account> accountsToInsert = new List<Account>();

        // Accounts for various search scenarios
        accountsToInsert.add(
            new Account(
                Name = 'Bright Corp Solutions',
                BillingCity = 'New York',
                Industry = 'Technology',
                breg_File__c = '209942',
                breg_File_Suffix__c = 'D1',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = 'A1',
                breg_Business_Structure__c = 'Cooperative',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        accountsToInsert.add(
            new Account(
                Name = 'Global Innovations LLC',
                BillingCity = 'Dallas',
                Industry = 'Manufacturing',
                breg_File__c = '100100_XYZ',
                breg_Entity_Status__c = 'New (Y)',
                breg_Entity_Type__c = 'A2',
                breg_Business_Structure__c = 'Cooperative',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        accountsToInsert.add(
            new Account(
                Name = 'Core Systems Corp',
                BillingCity = 'London',
                Industry = 'Finance',
                breg_File__c = '300300_ABC',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = 'C5',
                breg_Business_Structure__c = 'Cooperative',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        accountsToInsert.add(
            new Account(
                Name = 'Future Tech Hub',
                BillingCity = 'Paris',
                Industry = 'Technology',
                breg_File__c = '400400_PQR',
                breg_Entity_Status__c = 'Withdrawn (W)',
                breg_Entity_Type__c = 'A1',
                breg_Business_Structure__c = 'Cooperative',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        accountsToInsert.add(
            new Account(
                Name = 'Streamline Services',
                BillingCity = 'Los Angeles',
                Industry = 'Consulting',
                breg_File__c = '500500_UVW',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = 'A2',
                breg_Business_Structure__c = 'Cooperative',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        // Add Reservation record
        accountsToInsert.add(
            new Account(
                Name = 'Reserved Name Corp',
                BillingCity = 'Chicago',
                Industry = 'Technology',
                breg_File__c = '600600_RSV',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
                breg_Business_Structure__c = 'Corporation',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        // Account with xref names for cross reference search tests
        accountsToInsert.add(
            new Account(
                Name = 'Omega Partners Ltd',
                BillingCity = 'Houston',
                Industry = 'Consulting',
                breg_File__c = '700700 OMG',
                breg_Entity_Status__c = 'Active (A)',
                breg_Entity_Type__c = 'A1',
                breg_Business_Structure__c = 'Corporation',
                breg_Xref_Name_1__c = 'Omega XRef One Trading',
                breg_Xref_Name_2__c = 'Omega XRef Two Holdings',
                RecordTypeId = bregAccountRecordTypeId
            )
        );

        insert accountsToInsert;

        insert new breg_Transaction_Business_Info__c(
            breg_Entity__c = accountsToInsert[0].Id,
            breg_Master_Name__c = 'Legacy Bright Corporation',
            breg_Xref_Name_1__c = 'Legacy Bright XRef One',
            breg_Xref_Name_2__c = 'Legacy Bright XRef Two',
            breg_File__c = '209942',
            breg_File_Suffix__c = 'D1',
            breg_Search_Name_NS__c = BREGUtils.cleanBusinessName('Legacy Bright Corporation'),
            breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName('Legacy Bright XRef One'),
            breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName('Legacy Bright XRef Two')
        );

        List<breg_TN_TM_SM__c> tnTmSmRecords = new List<breg_TN_TM_SM__c>();
        tnTmSmRecords.add(new breg_TN_TM_SM__c(Name = 'Bright Trademark', breg_Type__c = 'Trademark', breg_Status__c = 'A'));
        tnTmSmRecords.add(new breg_TN_TM_SM__c(Name = 'Systems Service Mark', breg_Type__c = 'Service Mark', breg_Status__c = 'C'));
        tnTmSmRecords.add(new breg_TN_TM_SM__c(Name = 'Global Trade Name', breg_Type__c = 'Trade Name', breg_Status__c = 'E'));
        tnTmSmRecords.add(
            new breg_TN_TM_SM__c(
                Name = 'Alpha Trademark',
                breg_Type__c = 'Trademark',
                breg_Status__c = 'A',
                breg_Xref_Name1__c = 'Alpha TM XRef One',
                breg_Xref_Name2__c = 'Alpha TM XRef Two'
            )
        );
        insert tnTmSmRecords;

        Id bregCaseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
                AND Name = 'BREG Case'
            LIMIT 1
        ].Id;

        List<Case> completedCases = new List<Case>();
        for (Integer i = 0; i < tnTmSmRecords.size(); i++) {
            completedCases.add(new Case(
                Subject = 'Completed TN/TM/SM Case ' + i,
                Status = 'Completed',
                Origin = 'Web',
                RecordTypeId = bregCaseRecordTypeId
            ));
        }
        insert completedCases;

        List<breg_Transaction__c> completedTransactions = new List<breg_Transaction__c>();
        for (Integer i = 0; i < tnTmSmRecords.size(); i++) {
            completedTransactions.add(new breg_Transaction__c(
                breg_TN_TM_SM__c = tnTmSmRecords[i].Id,
                breg_Case__c = completedCases[i].Id,
                breg_Status__c = 'C',
                breg_Business_Name__c = tnTmSmRecords[i].Name
            ));
        }
        insert completedTransactions;

        // Pending filing cases for case search tests.
        // breg_Search_Name_NS__c and breg_Search_Xref_Name_*_NS__c are trigger-populated only on
        // beforeUpdate, so they must be set directly here to be queryable on insert.
        List<Case> pendingCases = new List<Case>();
        pendingCases.add(new Case(
            Subject = 'Alpha Filing',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_New_Entity_Name__c = 'Alpha Pending Entity',
            breg_Search_Name_NS__c = BREGUtils.cleanBusinessName('Alpha Pending Entity'),
            breg_Workitem_Number__c = 'WI-001'
        ));
        pendingCases.add(new Case(
            Subject = 'Beta Filing',
            Status = 'Approved',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_New_Entity_Name__c = 'Beta Corp Filing',
            breg_Search_Name_NS__c = BREGUtils.cleanBusinessName('Beta Corp Filing'),
            breg_Xref_Name_1__c = 'Beta Case XRef One',
            breg_Xref_Name_2__c = 'Beta Case XRef Two',
            breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName('Beta Case XRef One'),
            breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName('Beta Case XRef Two'),
            breg_Workitem_Number__c = 'WI-002'
        ));
        insert pendingCases;
    }

    @isTest
    static void testGetSearchResults_BeginsSearchType() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'begins';
        searchInputs.searchInputValue = 'Bright Corp';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        // Scenario: Begins search for existing account name
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(1, results.size(), 'Should return 1 result');

        // Scenario: Begins search for non-existing account name
        searchInputs.searchInputValue = 'DOES NOT EXIST';
        results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(0, results.size(), 'Should return 0 results');
        Test.stopTest();
    }

    @isTest
    static void testGetSearchResults_ContainsSearchType() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Systems';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        // Scenario: Contains search for existing account name
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(1, results.size(), 'Should return 1 result');

        // Scenario: Contains search for non-existing account name
        searchInputs.searchInputValue = 'DOEST NOT EXIST';
        results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(0, results.size(), 'Should return 0 results');
        Test.stopTest();
    }

    @isTest
    static void testGetSearchResults_HistoricalEntityNameSearch() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Legacy Bright';
        searchInputs.recordType = 'Entity';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Boolean foundHistoricalMasterName = false;
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            if (wrapper.sourceObject == 'breg_Transaction_Business_Info__c' && wrapper.businessName == 'Legacy Bright Corporation') {
                foundHistoricalMasterName = true;
                Assert.isTrue(wrapper.recordId.startsWith('001'), 'Historical result should point to the related Account record.');
                break;
            }
        }

        Assert.isTrue(foundHistoricalMasterName, 'Historical entity master name should be present in Search and Buy results.');
    }

    @isTest
    static void testGetSearchResults_AllFiltersPopulated() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'begins';
        searchInputs.searchInputValue = 'Bright Corp';
        searchInputs.recordType = 'Entity';
        searchInputs.status = 'Active (A)';
        searchInputs.entityType = 'Cooperative';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        // Scenario: All filters are populated
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Test.stopTest();
    }

    @isTest
    static void testGetSearchResults_ReservationType() {
        List<BREG_Setting__c> existingSettings = [SELECT Id FROM BREG_Setting__c];
        if (!existingSettings.isEmpty()) {
            delete existingSettings;
        }

        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Reserved';
        searchInputs.recordType = 'Reservation';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();

        List<BREGSearchAndBuyController.SearchResultWrapper> results =
            BREGSearchAndBuyController.getSearchResults(searchInputs);

        Assert.areEqual(0, results.size(), 'Reservation recordType excludes both Account and TN/TM/SM queries');

        searchInputs.recordType = 'all';

        results = BREGSearchAndBuyController.getSearchResults(searchInputs);

        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 reservation when recordType is all');
    }

    @isTest
    static void testGetSearchResults_ExceptionHandling() {
        Boolean isException = false;
        Test.startTest();
        try {
            BREGSearchAndBuyController.getSearchResults(null);
        } catch (Exception e) {
            isException = true;
        }
        Test.stopTest();
        Assert.isTrue(isException, 'An exception should have been caught.');
    }

    @isTest
    static void testGetSearchResults_SearchByNumberEnabled() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = '209942'; // Part of breg_File__c
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = true;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result based on file number');
    }

    @isTest
    static void testGetSearchResultsSearchByNumberWithSuffix() {
        Id bregAccountRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'BREG_Account'
            LIMIT 1
        ]
        .Id;

        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = '209942 D1';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = true;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Two-part file number searches should match file number and suffix');
        Assert.areEqual('209942', results[0].fileNumber, 'Wrapper should expose the file number when both file and suffix exist');
    }

    @isTest
    static void testGetSearchResults_SearchByNumberDisabled() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = '209942'; // Should not match if search is only by name
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Should return 0 results when searchByNumber is false');
    }

    @isTest
    static void testGetSearchResults_IncludeTnTmSm() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Bright';
        searchInputs.recordType = 'Trademark';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 trademark result');
    }

    @isTest
    static void testGetSearchResults_TradeNameSearch() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Global';
        searchInputs.recordType = 'Trade Name';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;
        searchInputs.includeTransactions = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 trade name result');
    }

    @isTest
    static void testGetSearchResults_ServiceMarkSearch() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Systems';
        searchInputs.recordType = 'Service Mark';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 service mark result');
    }

    @isTest
    static void testGetSearchResultsTnTmSmStatusMappings() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Systems';
        searchInputs.recordType = 'Service Mark';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        searchInputs.status = 'Cancelled (C)';
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Assert.areEqual(1, results.size(), 'Cancelled entity status should map to TN/TM/SM status C');

        searchInputs.status = 'Withdrawn (W)';
        results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Unsupported TN/TM/SM status values should return no records');
    }

    @isTest
    static void testGetSearchResults_CombinedSearch() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Bright';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Integer accountCount = 0;
        Integer tnTmSmCount = 0;
        Integer historicalCount = 0;
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            if (wrapper.sourceObject == 'Account') {
                accountCount++;
            } else if (wrapper.sourceObject == 'breg_TN_TM_SM__c') {
                tnTmSmCount++;
            } else if (wrapper.sourceObject == 'breg_Transaction_Business_Info__c') {
                historicalCount++;
            }
        }

        Assert.isTrue(results.size() > 0, 'Combined search should return at least one result.');
        Assert.isTrue(accountCount > 0, 'Combined search should still include Account matches.');
        Assert.isTrue(
            tnTmSmCount > 0 || historicalCount > 0,
            'Combined search should include at least one non-Account source (TN/TM/SM or historical).'
        );
    }

    @isTest
    static void testGetSearchResults_QueryLimit() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = '';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.queryLimit = 2;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.isTrue(results.size() <= 2, 'Should respect query limit of 2');
    }

    @isTest
    static void testGetSearchResults_ExcludeAccounts() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Bright';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return only TN/TM/SM result when accounts excluded');
        Assert.areEqual('breg_TN_TM_SM__c', results[0].sourceObject, 'Result should be from TN/TM/SM object');
    }

    @isTest
    static void testGetSearchResults_IsOnlyTnTmSmType() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Systems';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = true;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return Account and Service Mark (excludes Publicity Rights Name)');
    }

    @isTest
    static void testGetRecordForNotificationsByIds() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Bright Corp Solutions' LIMIT 1];
        List<breg_TN_TM_SM__c> tnTmSms = [SELECT Id FROM breg_TN_TM_SM__c WHERE Name = 'Bright Trademark' LIMIT 1];
        Assert.areEqual(1, accounts.size(), 'Test data should have Bright Corp Solutions');
        Assert.areEqual(1, tnTmSms.size(), 'Test data should have Bright Trademark');

        List<Id> recordIds = new List<Id>{ accounts[0].Id, tnTmSms[0].Id };

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getRecordForNotificationsByIds(recordIds);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return both Account and TN/TM/SM records');
    }

    @isTest
    static void testGetRecordForNotificationsByIds_EmptyList() {
        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getRecordForNotificationsByIds(new List<Id>());
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Should return empty list for empty input');
    }

    @isTest
    static void testGetCertificate_NotFound() {
        List<BREG_Setting__c> existing = [SELECT Id FROM BREG_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }
        insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), Published_Document_Code_Valid_Days__c = 365);

        Test.startTest();
        breg_Certificate__c result = BREGSearchAndBuyController.getCertificate('INVALID_CODE_123');
        Test.stopTest();

        Assert.areEqual(null, result, 'Should return null when no certificate found');
    }

    @isTest
    static void testGetCertificate_FoundByAuthCode() {
        List<BREG_Setting__c> existing = [SELECT Id FROM BREG_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }
        insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), Published_Document_Code_Valid_Days__c = 365);

        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c doc = new breg_Document__c(Name = 'Test Doc', breg_Account__c = acc.Id);
        insert doc;

        breg_Certificate__c cert = new breg_Certificate__c(
            breg_Document__c = doc.Id,
            breg_Authentication_Code__c = 'AUTH123',
            breg_Published_Timestamp__c = DateTime.now()
        );
        insert cert;

        Test.startTest();
        breg_Certificate__c result = BREGSearchAndBuyController.getCertificate('AUTH123');
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Should return certificate');
        Assert.areEqual(cert.Id, result.Id, 'Should return matching certificate');
    }

    // @isTest
    // static void testGetSearchResultsIncludeTransactionsOnly() {
    //     insert new breg_Transaction__c(breg_Business_Name__c = 'Pending Filing Search', breg_BRIM_TRANS_ID__c = 'TX-001', breg_Status__c = 'A');

    //     BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
    //     searchInputs.searchType = 'contains';
    //     searchInputs.searchInputValue = '';
    //     searchInputs.recordType = 'Pending Filing';
    //     searchInputs.status = 'all';
    //     searchInputs.entityType = 'all';
    //     searchInputs.searchByNumber = false;
    //     searchInputs.includeTnTmSm = false;
    //     searchInputs.includeTransactions = true;
    //     searchInputs.excludeAccounts = true;
    //     searchInputs.isOnlyTnTmSmType = false;

    //     Test.startTest();
    //     List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
    //     Test.stopTest();

    //     Assert.areEqual(1, results.size(), 'Should return the pending filing transaction when only transactions are included');
    //     Assert.areEqual('breg_Transaction__c', results[0].sourceObject, 'Result should come from the transaction object');
    //     Assert.areEqual('Pending Filing', results[0].recordType, 'Transaction wrapper should label the record type as Pending Filing');
    //     Assert.areEqual('TX-001T8', results[0].fileNumber, 'Transaction wrapper should expose the BRIM transaction id as file number');
    // }

    @isTest
    static void testGetSearchResultsExcludeEntityTypesSetting() {
        List<BREG_Setting__c> existing = [SELECT Id FROM BREG_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }
        insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), Exclude_Entity_Types_From_Search_And_Buy__c = 'A1');

        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Bright';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            Assert.areNotEqual('Account', wrapper.sourceObject, 'Accounts with excluded entity types should not be returned');
        }
    }

    @isTest
    static void testGetSearchResults_XrefNameReturnsCorrectRecordType() {
        // Searching for a term that matches breg_Xref_Name_1__c only should return a Cross Reference 1 wrapper
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'XRef One';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Boolean foundAccountXref1 = false;
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            if (
                wrapper.sourceObject == 'Account' &&
                wrapper.recordType == 'Cross Reference 1' &&
                wrapper.businessName == 'Omega XRef One Trading'
            ) {
                foundAccountXref1 = true;
                break;
            }
        }

        Assert.isTrue(foundAccountXref1, 'Expected Account Cross Reference 1 wrapper should be present.');
    }

    @isTest
    static void testGetSearchResults_XrefBothNamesReturnMultipleWrappers() {
        // Searching for a term matching both xref fields (but not breg_Search_Name__c) produces 2 wrappers from same record
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Omega XRef';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 wrappers — one per matching xref field');

        Set<String> recordTypes = new Set<String>();
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            recordTypes.add(wrapper.recordType);
            Assert.areEqual('Account', wrapper.sourceObject, 'sourceObject should remain Account for xref wrappers');
        }
        Assert.isTrue(recordTypes.contains('Cross Reference 1'), 'Should include Cross Reference 1 wrapper');
        Assert.isTrue(recordTypes.contains('Cross Reference 2'), 'Should include Cross Reference 2 wrapper');
    }

    @isTest
    static void testGetCertificateFoundByLegacyCertificateNumber() {
        List<BREG_Setting__c> existing = [SELECT Id FROM BREG_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }
        insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), Published_Document_Code_Valid_Days__c = 365);

        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c doc = new breg_Document__c(Name = 'Legacy Test Doc', breg_Account__c = acc.Id);
        insert doc;

        breg_Certificate__c cert = new breg_Certificate__c(
            breg_Document__c = doc.Id,
            breg_Legacy_Certificate_Number__c = 12345,
            breg_Published_Timestamp__c = DateTime.now()
        );
        insert cert;

        Test.startTest();
        breg_Certificate__c result = BREGSearchAndBuyController.getCertificate('12345');
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Should return certificate when looked up by legacy certificate number');
        Assert.areEqual(cert.Id, result.Id, 'Should return the certificate matching the numeric legacy id');
    }

    @isTest
    static void testGetSearchResults_TnTmSmXrefNameReturnsCorrectRecordType() {
        // Searching for a term that matches breg_Xref_Name1__c only should return a TN/TM/SM XRef 1 wrapper
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Alpha TM XRef One';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return exactly 1 TN/TM/SM xref wrapper');
        Assert.areEqual('Trademark XRef 1', results[0].recordType, 'recordType should be TN/TM/SM type concatenated with XRef 1');
        Assert.areEqual('Alpha TM XRef One', results[0].businessName, 'businessName should be the breg_Xref_Name1__c field value');
        Assert.areEqual('breg_TN_TM_SM__c', results[0].sourceObject, 'sourceObject should remain breg_TN_TM_SM__c for xref wrappers');
    }

    @isTest
    static void testGetSearchResults_TnTmSmXrefBothNamesReturnMultipleWrappers() {
        // Searching for a term matching both xref fields (but not the primary name) produces 2 wrappers from the same record
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Alpha TM XRef';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 wrappers — one per matching xref field');

        Set<String> recordTypes = new Set<String>();
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            recordTypes.add(wrapper.recordType);
            Assert.areEqual('breg_TN_TM_SM__c', wrapper.sourceObject, 'sourceObject should remain breg_TN_TM_SM__c for xref wrappers');
        }
        Assert.isTrue(recordTypes.contains('Trademark XRef 1'), 'Should include Trademark XRef 1 wrapper');
        Assert.isTrue(recordTypes.contains('Trademark XRef 2'), 'Should include Trademark XRef 2 wrapper');
    }

    @isTest
    static void testGetSearchResults_CaseBasicSearch() {
        // includeTransactions drives isIncludeCases(); searchInputs.includeCases is not used
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Alpha Pending';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.includeTransactions = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return exactly 1 pending filing result');
        Assert.areEqual('Pending Filing', results[0].recordType, 'recordType should be Pending Filing');
        Assert.areEqual('Alpha Pending Entity', results[0].businessName, 'businessName should come from breg_New_Entity_Name__c');
        Assert.areEqual('Case', results[0].sourceObject, 'sourceObject should be Case');
        Assert.areEqual('WI-001', results[0].fileNumber, 'fileNumber should come from breg_Workitem_Number__c');
    }

    @isTest
    static void testGetSearchResults_CasePendingFilingRecordType() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = '';
        searchInputs.recordType = 'Pending Filing';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.includeTransactions = true;
        searchInputs.excludeAccounts = false;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return both pending filing cases when recordType is Pending Filing');
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            Assert.areEqual('Case', wrapper.sourceObject, 'All results should come from Case object');
            Assert.areEqual('Pending Filing', wrapper.recordType, 'All results should have Pending Filing record type');
        }
    }

    @isTest
    static void testGetSearchResults_CaseXrefNameReturnsCorrectRecordType() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Beta Case XRef One';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.includeTransactions = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return exactly 1 case xref wrapper');
        Assert.areEqual('Pending Filing XRef 1', results[0].recordType, 'recordType should be Pending Filing XRef 1');
        Assert.areEqual('Beta Case XRef One', results[0].businessName, 'businessName should be the breg_Xref_Name_1__c value');
        Assert.areEqual('Case', results[0].sourceObject, 'sourceObject should remain Case for xref wrappers');
    }

    @isTest
    static void testGetSearchResults_CaseXrefBothNamesReturnMultipleWrappers() {
        BREGSearchAndBuyController.SearchInputsWrapper searchInputs = new BREGSearchAndBuyController.SearchInputsWrapper();
        searchInputs.searchType = 'contains';
        searchInputs.searchInputValue = 'Beta Case XRef';
        searchInputs.recordType = 'all';
        searchInputs.status = 'all';
        searchInputs.entityType = 'all';
        searchInputs.searchByNumber = false;
        searchInputs.includeTnTmSm = false;
        searchInputs.includeTransactions = true;
        searchInputs.excludeAccounts = true;
        searchInputs.isOnlyTnTmSmType = false;

        Test.startTest();
        List<BREGSearchAndBuyController.SearchResultWrapper> results = BREGSearchAndBuyController.getSearchResults(searchInputs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 wrappers — one per matching case xref field');

        Set<String> recordTypes = new Set<String>();
        for (BREGSearchAndBuyController.SearchResultWrapper wrapper : results) {
            recordTypes.add(wrapper.recordType);
            Assert.areEqual('Case', wrapper.sourceObject, 'sourceObject should remain Case for xref wrappers');
        }
        Assert.isTrue(recordTypes.contains('Pending Filing XRef 1'), 'Should include Pending Filing XRef 1 wrapper');
        Assert.isTrue(recordTypes.contains('Pending Filing XRef 2'), 'Should include Pending Filing XRef 2 wrapper');
    }
}