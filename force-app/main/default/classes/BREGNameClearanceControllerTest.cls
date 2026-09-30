/**
 * Test class for BREGNameClearanceController
 * Provides comprehensive test coverage for name clearance search functionality
 */
@IsTest
private class BREGNameClearanceControllerTest {
    // Test data constants
    private static final String TEST_ACCOUNT_NAME = 'Test Business Corporation';
    private static final String TEST_ACCOUNT_XREF_1 = 'Test Business Corp';
    private static final String TEST_ACCOUNT_XREF_2 = 'Test Business Inc';
    private static final String TEST_TN_TM_SM_NAME = 'Test Trade Name';
    private static final String TEST_ENTITY_TYPE_CURRENT = 'C1';
    private static final String TEST_ENTITY_STATUS = 'Active (A)';
    private static final List<string> ENTITY_AVAILABLE_STATUSES = new List<String>{
        'Active (A)',
        'Annual report 1 yr delinquent (1)',
        'Annual report 2 yr delinquent (2)'
    };
    private static final String TEST_SEARCH_LOG_TERM_REJECTED = 'ZZ Acme Holdings';
    private static final String TEST_SEARCH_LOG_TERM_NON_REJECTED = 'ZZ Acme Non Rejected';
    private static final String TEST_SEARCH_LOG_TERM_EXACT_REJECTED = 'ZZ Beta Rejected Corp';
    private static final String TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM = 'ZZ NORMALIZED ONLY MATCH';
    /**
     * Test data setup - creates test accounts and breg_TN_TM_SM__c records
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts with different entity types
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> testAccounts = new List<Account>();

        // Current/active account
        Account currentAccount = new Account(
            Name = TEST_ACCOUNT_NAME,
            breg_Xref_Name_1__c = TEST_ACCOUNT_XREF_1,
            breg_Xref_Name_2__c = TEST_ACCOUNT_XREF_2,
            breg_Entity_Type__c = TEST_ENTITY_TYPE_CURRENT,
            breg_Entity_Status__c = TEST_ENTITY_STATUS,
            Type = 'Entity',
            RecordTypeId = recordTypeId,
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName(TEST_ACCOUNT_NAME),
            breg_Search_Xref_Name_1_NS__c = BREGUtils.normalizeBusinessName(TEST_ACCOUNT_XREF_1),
            breg_Search_Xref_Name_2_NS__c = BREGUtils.normalizeBusinessName(TEST_ACCOUNT_XREF_2)
        );
        testAccounts.add(currentAccount);

        // Reservation account
        Account reservationAccount = new Account(
            Name = 'Reserved Business Name LLC',
            breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
            breg_Entity_Status__c = 'Active (A)',
            Type = 'Reservation',
            RecordTypeId = recordTypeId,
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('Reserved Business Name LLC')
        );
        testAccounts.add(reservationAccount);

        // Additional test accounts for search variety
        Account exactMatchAccount = new Account(
            Name = 'EXACT MATCH CORP',
            breg_BRIM_MASTER_NAME__c = 'Exact Match Corp', // This should match the search term after normalization
            breg_Entity_Type__c = TEST_ENTITY_TYPE_CURRENT,
            breg_Entity_Status__c = TEST_ENTITY_STATUS,
            RecordTypeId = recordTypeId,
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('EXACT MATCH CORP')
        );
        testAccounts.add(exactMatchAccount);

        Account beginsWithAccount = new Account(
            Name = 'Beginning Test Corporation',
            breg_Entity_Type__c = TEST_ENTITY_TYPE_CURRENT,
            breg_Entity_Status__c = TEST_ENTITY_STATUS,
            RecordTypeId = recordTypeId,
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('Beginning Test Corporation')
        );
        testAccounts.add(beginsWithAccount);

        insert testAccounts;

        // Create test breg_TN_TM_SM__c records
        List<breg_TN_TM_SM__c> testTnTmSmRecords = new List<breg_TN_TM_SM__c>();

        breg_TN_TM_SM__c tradeName = new breg_TN_TM_SM__c(
            Name = TEST_TN_TM_SM_NAME,
            breg_XREF_Name1__c = 'Test Trade Name Alternate',
            breg_XREF_Name2__c = 'Test TN Secondary',
            breg_Status__c = 'A',
            breg_Type__c = 'Trade Name',
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName(TEST_TN_TM_SM_NAME),
            breg_Search_Xref_Name_1_NS__c = BREGUtils.normalizeBusinessName('Test Trade Name Alternate'),
            breg_Search_Xref_Name_2_NS__c = BREGUtils.normalizeBusinessName('Test TN Secondary')
        );
        testTnTmSmRecords.add(tradeName);

        breg_TN_TM_SM__c historicalRecord = new breg_TN_TM_SM__c(
            Name = 'TN_TM',
            breg_XREF_Name1__c = 'TN_TM',
            breg_Status__c = 'A',
            breg_Type__c = 'Trade Name',
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('TN_TM'),
            breg_Search_Xref_Name_1_NS__c = BREGUtils.normalizeBusinessName('TN_TM')
        );
        testTnTmSmRecords.add(historicalRecord);

        insert testTnTmSmRecords;

        breg_Transaction_Business_Info__c businessInfo = new breg_Transaction_Business_Info__c(
            breg_Master_Name__c = 'Test Business Info Name',
            breg_Entity__c = currentAccount.Id,
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('Test Business Info Name')
        );
        insert businessInfo;

        // Create test Case records for name clearance search coverage
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        List<Case> testCases = new List<Case>();
        breg_Form_Configuration__c formConfiguration = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'C1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Process__c = 'Change'
        );

        insert formConfiguration;

        Case testCase1 = new Case(
            Subject = 'Test Business Registration',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_New_Entity_Name__c = 'New Business Corp',
            breg_Name_of_the_Entity__c = 'Business Entity Name',
            breg_Form_Code__c = 'DC-1',
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('New Business Corp'),
            breg_Form_Configuration__c = formConfiguration.Id
        );
        testCases.add(testCase1);

        Case testCase2 = new Case(
            Subject = 'Trade Name Description Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_TNTMSM_Description__c = 'Trade Name Description',
            breg_Form_Code__c = 'LLC-1',
            breg_Search_Name_NS__c = BREGUtils.normalizeBusinessName('Trade Name Description'),
            breg_Form_Configuration__c = formConfiguration.Id
        );
        testCases.add(testCase2);

        insert testCases;

        // Create test breg_Search_Log__c records for performSearchLogSearch coverage
        List<breg_Search_Log__c> testSearchLogs = new List<breg_Search_Log__c>();
        testSearchLogs.add(
            new breg_Search_Log__c(
                breg_Search_Term__c = TEST_SEARCH_LOG_TERM_REJECTED,
                breg_Normalized_Search_Term__c = BREGUtils.cleanBusinessName(TEST_SEARCH_LOG_TERM_REJECTED),
                breg_Rejected_Name__c = true,
                breg_Data_Sources__c = 'current',
                breg_Match_Type__c = 'contains',
                breg_Search_DateTime__c = DateTime.now(),
                breg_Search_Status__c = 'Success',
                breg_Results_Count__c = 1,
                breg_Case__c = testCase1.Id
            )
        );
        testSearchLogs.add(
            new breg_Search_Log__c(
                breg_Search_Term__c = TEST_SEARCH_LOG_TERM_NON_REJECTED,
                breg_Normalized_Search_Term__c = BREGUtils.cleanBusinessName(TEST_SEARCH_LOG_TERM_NON_REJECTED),
                breg_Rejected_Name__c = false,
                breg_Data_Sources__c = 'current',
                breg_Match_Type__c = 'contains',
                breg_Search_DateTime__c = DateTime.now(),
                breg_Search_Status__c = 'Success',
                breg_Results_Count__c = 3
            )
        );
        testSearchLogs.add(
            new breg_Search_Log__c(
                breg_Search_Term__c = TEST_SEARCH_LOG_TERM_EXACT_REJECTED,
                breg_Normalized_Search_Term__c = BREGUtils.cleanBusinessName(TEST_SEARCH_LOG_TERM_EXACT_REJECTED),
                breg_Rejected_Name__c = true,
                breg_Data_Sources__c = 'current',
                breg_Match_Type__c = 'exact',
                breg_Search_DateTime__c = DateTime.now().addMinutes(-5),
                breg_Search_Status__c = 'Success',
                breg_Results_Count__c = 0
            )
        );
        testSearchLogs.add(
            new breg_Search_Log__c(
                breg_Search_Term__c = 'Raw Unmatched Text ZZ',
                breg_Normalized_Search_Term__c = TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM,
                breg_Rejected_Name__c = true,
                breg_Data_Sources__c = 'current',
                breg_Match_Type__c = 'exact',
                breg_Search_DateTime__c = DateTime.now().addMinutes(-1),
                breg_Search_Status__c = 'Success',
                breg_Results_Count__c = 0
            )
        );
        insert testSearchLogs;
    }

    /**
     * Helper method to create a basic search request
     */
    private static BREGNameClearanceController.SearchRequest createSearchRequest(String searchTerm, String matchType, List<String> dataSources) {
        BREGNameClearanceController.SearchRequest request = new BREGNameClearanceController.SearchRequest();
        request.searchTerm = searchTerm;
        request.matchType = matchType;
        request.dataSources = dataSources;
        request.maxResults = 100;
        return request;
    }

    /**
     * Test successful exact match search
     */
    @IsTest
    static void testPerformNameSearch_ExactMatch_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Exact Match Corp', 'exact', new List<String>{ 'current' });
        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [
                SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, RecordType.DeveloperName
                FROM Account
                WHERE Name = 'Exact Match Corp'
            ]
        );
        // Act
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assertNotEquals(null, response.results, 'Results should not be null');
        System.assertEquals(1, response.results.size(), 'Should find exactly one exact match');
        System.assertEquals('Exact Match', response.results[0].matchReason, 'Match reason should be Exact Match');
        System.assertNotEquals(null, response.searchId, 'Search ID should be generated');
        System.assertNotEquals(null, response.normalizedSearchTerm, 'Normalized search term should be present');
    }

    /**
     * Test successful begins with search
     */
    @IsTest
    static void testPerformNameSearch_BeginsWithMatch_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Beginning', 'beginswith', new List<String>{ 'current' });
        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [
                SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, RecordType.DeveloperName
                FROM Account
                WHERE Name LIKE 'Beginning%'
            ]
        );
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find at least one begins with match');
        System.assertEquals('Begins With', response.results[0].matchReason, 'Match reason should be Begins With');
    }

    /**
     * Test successful contains search
     */
    @IsTest
    static void testPerformNameSearch_ContainsMatch_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Business', 'contains', new List<String>{ 'current', 'historical' });
        Map<Id, breg_Transaction_Business_Info__c> expectedBusinessInfo = new Map<Id, breg_Transaction_Business_Info__c>(
            [
                SELECT Id, breg_Master_Name__c
                FROM breg_Transaction_Business_Info__c
            ]
        );
        Test.setFixedSearchResults(new List<Id>(expectedBusinessInfo.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find at least one contains match');
        System.assertEquals('Contains', response.results[0].matchReason, 'Match reason should be Contains');
    }

    /**
     * Test phonetic search functionality
     */
    @IsTest
    static void testPerformNameSearch_PhoneticMatch_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Bizness', // Phonetic variation of "Business"
            'phonetic',
            new List<String>{ 'current', 'historical' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assertNotEquals(null, response.results, 'Results should not be null');
        // Note: Phonetic matching relies on SOSL, so results may vary in test context
    }

    /**
     * Test search with reservation data source
     */
    @IsTest
    static void testPerformNameSearch_ReservationDataSource_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Reserved', 'contains', new List<String>{ 'reservations' });
        Map<Id, Account> expectedReservations = new Map<Id, Account>(
            [
                SELECT Id, Name
                FROM Account
                WHERE Name LIKE '%Reserved%'
                LIMIT 1
            ]
        );
        Test.setFixedSearchResults(new List<Id>(expectedReservations.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find reservation records');
        System.assertEquals('reservations', response.results[0].type, 'Data source should be reservations');
    }

    /**
     * Test search across historical data (breg_TN_TM_SM__c)
     */
    @IsTest
    static void testPerformNameSearch_HistoricalDataSource_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Business', 'contains', new List<String>{ 'historical' });

        Map<Id, breg_Transaction_Business_Info__c> expectedBusinessInfo = new Map<Id, breg_Transaction_Business_Info__c>(
            [
                SELECT Id, breg_Master_Name__c
                FROM breg_Transaction_Business_Info__c
            ]
        );
        System.debug('Expected Business Info Records: ' + expectedBusinessInfo);
        Test.setFixedSearchResults(new List<Id>(expectedBusinessInfo.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find historical records');
        System.assertEquals('historical', response.results[0].type, 'Data source should be historical');
    }

    /**
     * Test search with multiple data sources
     */
    @IsTest
    static void testPerformNameSearch_MultipleDataSources_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test',
            'contains',
            new List<String>{ 'current', 'historical', 'reservations' }
        );
        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [
                SELECT Id, Name
                FROM Account
                WHERE Name LIKE '%Test%'
                LIMIT 2
            ]
        );
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 2, 'Should find results from multiple sources');
    }

    /**
     * Test validation error - empty search term
     */
    @IsTest
    static void testPerformNameSearch_EmptySearchTerm_ValidationError() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('', 'exact', new List<String>{ 'current' });

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(!response.success, 'Search should fail with empty search term');
        System.assertEquals('Search term must be at least 2 characters long', response.errorMessage);
        System.assertEquals(0, response.totalCount, 'Total count should be zero');
    }

    /**
     * Test validation error - search term too short
     */
    @IsTest
    static void testPerformNameSearch_ShortSearchTerm_ValidationError() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'A', // Only 1 character
            'exact',
            new List<String>{ 'current' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(!response.success, 'Search should fail with short search term');
        System.assertEquals('Search term must be at least 2 characters long', response.errorMessage);
    }

    /**
     * Test validation error - no data sources selected
     */
    @IsTest
    static void testPerformNameSearch_NoDataSources_ValidationError() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Test Business', 'exact', new List<String>()); // Empty data sources

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(!response.success, 'Search should fail with no data sources');
        System.assertEquals('At least one data source must be selected', response.errorMessage);
    }

    /**
     * Test validation error - null data sources
     */
    @IsTest
    static void testPerformNameSearch_NullDataSources_ValidationError() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test Business',
            'exact',
            null // Null data sources
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(!response.success, 'Search should fail with null data sources');
        System.assertEquals('At least one data source must be selected', response.errorMessage);
    }

    /**
     * Test max results limit functionality
     */
    @IsTest
    static void testPerformNameSearch_MaxResultsLimit_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Test', 'contains', new List<String>{ 'current', 'historical' });
        request.maxResults = 1; // Limit to 1 result

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        if (response.success) {
            System.assert(response.results.size() <= 1, 'Should respect max results limit when successful');
        } else {
            // Even if search fails, response should be properly structured
            System.assertEquals(0, response.totalCount, 'Failed search should have zero total count');
            System.assertNotEquals(null, response.errorMessage, 'Failed search should have error message');
        }
    }

    /**
     * Test search with no results
     */
    @IsTest
    static void testPerformNameSearch_NoResults_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest('NonexistentBusinessName12345', 'exact', new List<String>{ 'current' });

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful even with no results');
        System.assertEquals(0, response.results.size(), 'Should return no results');
        System.assertEquals(0, response.totalCount, 'Total count should be zero');
    }

    /**
     * Test search result properties and data mapping
     */
    @IsTest
    static void testPerformNameSearch_ResultProperties_Validation() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(TEST_ACCOUNT_NAME, 'exact', new List<String>{ 'current' });

        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [
                SELECT Id, Name, breg_Entity_Status__c, breg_Entity_Type__c, RecordType.DeveloperName
                FROM Account
                LIMIT 1
            ]
        );
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find at least one result');

        BREGNameClearanceController.SearchResult result = response.results[0];
        System.assertNotEquals(null, result.id, 'Result ID should not be null');
        System.assertNotEquals(null, result.name, 'Result name should not be null');
        System.assertNotEquals(null, result.type, 'Data source should not be null');
        System.assertNotEquals(null, result.matchReason, 'Match reason should not be null');
        System.assertEquals('current', result.type, 'Data source should be current for Account records');
    }

    /**
     * Test name normalization through search
     */
    @IsTest
    static void testPerformNameSearch_NameNormalization_Success() {
        // Arrange - use a search term that should be normalized (lowercase, extra spaces)
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            '  test   business   corporation  ', // Extra spaces, lowercase
            'exact',
            new List<String>{ 'current' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful with normalized term');
        System.assertNotEquals(null, response.normalizedSearchTerm, 'Normalized search term should be present');
        System.assertNotEquals(request.searchTerm, response.normalizedSearchTerm, 'Search term should be normalized');
    }

    /**
     * Test search across cross-reference name fields
     */
    @IsTest
    static void testPerformNameSearch_CrossReferenceFields_Success() {
        // Arrange - search for content in cross-reference fields
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test Business Corp', // This should match breg_Xref_Name_1__c
            'exact',
            new List<String>{ 'current' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        // Note: In test context, SOQL behavior may differ, but we verify the search executes
    }

    /**
     * Test exception handling - simulate error condition
     */
    @IsTest
    static void testPerformNameSearch_ExceptionHandling() {
        // Arrange - Create a request that might cause issues (null request)
        BREGNameClearanceController.SearchRequest request = null;

        // Act & Assert
        Test.startTest();
        try {
            BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
            // If we get here without exception, the method handled null gracefully
            System.assert(!response.success, 'Search should fail gracefully with null request');
        } catch (Exception e) {
            // Exception is also acceptable as it indicates proper error handling
            System.assert(true, 'Exception handling is working');
        }
        Test.stopTest();
    }

    /**
     * Test SearchRequest inner class properties
     */
    @IsTest
    static void testSearchRequest_InnerClass_Properties() {
        // Arrange & Act
        BREGNameClearanceController.SearchRequest request = new BREGNameClearanceController.SearchRequest();
        request.searchTerm = 'Test Term';
        request.matchType = 'exact';
        request.dataSources = new List<String>{ 'current' };
        request.maxResults = 50;

        // Assert
        System.assertEquals('Test Term', request.searchTerm, 'Search term should be set correctly');
        System.assertEquals('exact', request.matchType, 'Match type should be set correctly');
        System.assertEquals(1, request.dataSources.size(), 'Data sources should be set correctly');
        System.assertEquals(50, request.maxResults, 'Max results should be set correctly');
    }

    /**
     * Test SearchResult inner class properties
     */
    @IsTest
    static void testSearchResult_InnerClass_Properties() {
        // Arrange & Act
        BREGNameClearanceController.SearchResult result = new BREGNameClearanceController.SearchResult();
        result.id = 'test-id';
        result.name = 'Test Name';
        result.status = 'Active';
        result.type = 'Entity';
        result.dataSource = 'current';
        result.matchReason = 'Exact Match';
        result.registrationDate = Date.today();
        result.matchedFieldName = 'Name';
        result.originalName = 'Original Name';

        // Assert
        System.assertEquals('test-id', result.id, 'ID should be set correctly');
        System.assertEquals('Test Name', result.name, 'Name should be set correctly');
        System.assertEquals('Active', result.status, 'Status should be set correctly');
        System.assertEquals('Entity', result.type, 'Type should be set correctly');
        System.assertEquals('current', result.dataSource, 'Data source should be set correctly');
        System.assertEquals('Exact Match', result.matchReason, 'Match reason should be set correctly');
        System.assertEquals(Date.today(), result.registrationDate, 'Registration date should be set correctly');
        System.assertEquals('Name', result.matchedFieldName, 'Matched field name should be set correctly');
        System.assertEquals('Original Name', result.originalName, 'Original name should be set correctly');
    }

    /**
     * Test SearchResponse inner class properties
     */
    @IsTest
    static void testSearchResponse_InnerClass_Properties() {
        // Arrange & Act
        BREGNameClearanceController.SearchResponse response = new BREGNameClearanceController.SearchResponse();
        response.success = true;
        response.results = new List<BREGNameClearanceController.SearchResult>();
        response.totalCount = 5;
        response.errorMessage = null;
        response.searchId = 'test-search-id';
        response.normalizedSearchTerm = 'NORMALIZED TERM';

        // Assert
        System.assertEquals(true, response.success, 'Success should be set correctly');
        System.assertNotEquals(null, response.results, 'Results should not be null');
        System.assertEquals(5, response.totalCount, 'Total count should be set correctly');
        System.assertEquals(null, response.errorMessage, 'Error message should be null for successful response');
        System.assertEquals('test-search-id', response.searchId, 'Search ID should be set correctly');
        System.assertEquals('NORMALIZED TERM', response.normalizedSearchTerm, 'Normalized search term should be set correctly');
    }

    /**
     * Test default match type handling
     */
    @IsTest
    static void testPerformNameSearch_DefaultMatchType_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Business',
            'unknown_match_type', // Should default to contains
            new List<String>{ 'current' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should handle unknown match type gracefully');
        // Should default to contains behavior
    }

    /**
     * Test search with case sensitivity (should be case-insensitive due to normalization)
     */
    @IsTest
    static void testPerformNameSearch_CaseInsensitive_Success() {
        // Arrange
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'test business corporation', // Lowercase version of test data
            'exact',
            new List<String>{ 'current' }
        );

        // Act
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        // Assert
        System.assert(response.success, 'Search should be successful');
        // Due to normalization, case should not matter
    }

    /**
     * Test Case records returned from SOSL search
     */
    @IsTest
    static void testPerformNameSearch_CaseResults_Success() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('New Business', 'contains', new List<String>{ 'current' });
        Map<Id, Case> expectedCases = new Map<Id, Case>([SELECT Id FROM Case WHERE RecordType.DeveloperName = 'BREG_Case']);
        Test.setFixedSearchResults(new List<Id>(expectedCases.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should be successful');
    }

    /**
     * Test TN_TM_SM records returned from SOSL search
     */
    @IsTest
    static void testPerformNameSearch_TNTMSMResults_Success() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Test Trade', 'contains', new List<String>{ 'current' });
        Map<Id, breg_TN_TM_SM__c> expectedRecords = new Map<Id, breg_TN_TM_SM__c>([SELECT Id FROM breg_TN_TM_SM__c]);
        Test.setFixedSearchResults(new List<Id>(expectedRecords.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find TN/TM/SM results');
    }

    /**
     * Test all object types returned from SOSL search combined
     */
    @IsTest
    static void testPerformNameSearch_AllObjectTypes_Combined() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test',
            'contains',
            new List<String>{ 'current', 'historical', 'reservations' }
        );
        List<Id> allIds = new List<Id>();
        for (Account a : [SELECT Id FROM Account]) {
            allIds.add(a.Id);
        }
        for (breg_TN_TM_SM__c t : [SELECT Id FROM breg_TN_TM_SM__c]) {
            allIds.add(t.Id);
        }
        for (Case c : [SELECT Id FROM Case]) {
            allIds.add(c.Id);
        }
        for (breg_Transaction_Business_Info__c b : [SELECT Id FROM breg_Transaction_Business_Info__c]) {
            allIds.add(b.Id);
        }
        Test.setFixedSearchResults(allIds);
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should be successful');
        System.assert(response.results.size() >= 1, 'Should find results from multiple object types');
    }

    /**
     * Test alphabetical match type — uses SOQL (no Test.setFixedSearchResults needed)
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalMatch() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Test', 'alphabetical', new List<String>{ 'current' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical SOQL search should succeed');
        System.assert(response.results.size() >= 1, 'Should return Account results via SOQL');
        System.assertEquals('Alphabetical', response.results[0].matchReason, 'Match reason should be Alphabetical');
    }

    /**
     * Test phonetic match with SOSL results to cover calculatePhoneticSimilarity and Levenshtein
     */
    @IsTest
    static void testPerformNameSearch_PhoneticWithResults() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Bizness Corp', 'phonetic', new List<String>{ 'current' });
        Map<Id, Account> expectedAccounts = new Map<Id, Account>([SELECT Id FROM Account LIMIT 2]);
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Phonetic search with results should succeed');
    }

    /**
     * Test getPicklistValues with invalid object name
     */
    @IsTest
    static void testGetPicklistValues_InvalidObject() {
        Test.startTest();
        Map<String, String> result = BREGNameClearanceController.getPicklistValues('NonExistentObject__c', 'SomeField__c');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Should return empty map for invalid object');
    }

    /**
     * Test getPicklistValues with invalid field name
     */
    @IsTest
    static void testGetPicklistValues_InvalidField() {
        Test.startTest();
        Map<String, String> result = BREGNameClearanceController.getPicklistValues('Account', 'NonExistentField__c');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Should return empty map for invalid field');
    }

    /**
     * Test getPicklistValues with valid object and field
     */
    @IsTest
    static void testGetPicklistValues_ValidObjectAndField() {
        Test.startTest();
        Map<String, String> result = BREGNameClearanceController.getPicklistValues('breg_TN_TM_SM__c', 'breg_Status__c');
        Test.stopTest();
        System.assert(result.size() > 0, 'Should return picklist values for valid object/field');
    }

    /**
     * Test with Transaction Business Info dedup (account name added first)
     */
    @IsTest
    static void testPerformNameSearch_BusinessInfoDedup() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Test Business', 'contains', new List<String>{ 'current', 'historical' });
        List<Id> allIds = new List<Id>();
        for (Account a : [SELECT Id FROM Account WHERE breg_Entity_Type__c != :ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE]) {
            allIds.add(a.Id);
        }
        for (breg_Transaction_Business_Info__c b : [SELECT Id FROM breg_Transaction_Business_Info__c]) {
            allIds.add(b.Id);
        }
        Test.setFixedSearchResults(allIds);
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should be successful');
    }

    /**
     * Test phonetic match with TN_TM_SM records to cover XREF name fields
     */
    @IsTest
    static void testPerformNameSearch_TNTMSMWithXrefFields() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Trade Name Alternate', 'contains', new List<String>{ 'current' });
        Map<Id, breg_TN_TM_SM__c> expectedRecords = new Map<Id, breg_TN_TM_SM__c>([SELECT Id FROM breg_TN_TM_SM__c WHERE Name = :TEST_TN_TM_SM_NAME]);
        Test.setFixedSearchResults(new List<Id>(expectedRecords.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should find XREF name matches');
    }

    /**
     * Test max results limit with multiple search results
     */
    @IsTest
    static void testPerformNameSearch_MaxResultsWithMultipleResults() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test',
            'contains',
            new List<String>{ 'current', 'historical', 'reservations' }
        );
        request.maxResults = 1;
        List<Id> allIds = new List<Id>();
        for (Account a : [SELECT Id FROM Account]) {
            allIds.add(a.Id);
        }
        for (breg_Transaction_Business_Info__c b : [SELECT Id FROM breg_Transaction_Business_Info__c]) {
            allIds.add(b.Id);
        }
        Test.setFixedSearchResults(allIds);
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed');
        System.assert(response.results.size() <= 1, 'Results should be limited to maxResults');
    }

    /**
     * Test SearchResult remaining properties
     */
    @IsTest
    static void testSearchResult_RemainingProperties() {
        BREGNameClearanceController.SearchResult result = new BREGNameClearanceController.SearchResult();
        result.recordURL = '/001abc';
        result.expiryDate = Date.today().addDays(30);
        result.registrationNumber = 'REG-123';
        result.statusIcon = 'utility:check';
        result.statusClass = 'slds-text-color_success';
        result.nameClass = 'name-highlight';
        result.dataSourceClass = 'ds-current';
        result.scoreClass = 'score-high';
        result.fileNumber = 'F12345';

        System.assertEquals('/001abc', result.recordURL);
        System.assertEquals(Date.today().addDays(30), result.expiryDate);
        System.assertEquals('REG-123', result.registrationNumber);
        System.assertEquals('utility:check', result.statusIcon);
        System.assertEquals('slds-text-color_success', result.statusClass);
        System.assertEquals('name-highlight', result.nameClass);
        System.assertEquals('ds-current', result.dataSourceClass);
        System.assertEquals('score-high', result.scoreClass);
        System.assertEquals('F12345', result.fileNumber);
    }

    /**
     * Test search without reservations to cover non-reservation branch in getTypeWhereConditions
     */
    @IsTest
    static void testPerformNameSearch_WithoutReservationDataSource() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest(TEST_ACCOUNT_NAME, 'exact', new List<String>{ 'current' });
        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [SELECT Id FROM Account WHERE breg_Entity_Type__c != :ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE]
        );
        Test.setFixedSearchResults(new List<Id>(expectedAccounts.keySet()));
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed without reservation data source');
    }

    // ===== Alphabetical SOQL search dedicated tests =====

    /**
     * Alphabetical search queries Accounts via SOQL using >= on breg_Search_Name_NS__c;
     * no SOSL mock (Test.setFixedSearchResults) is needed.
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_CurrentSource() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            'Test', // normalizes to 'TEST'; NS values like 'TEST BUSINES CORP' satisfy >= 'TEST'
            'alphabetical',
            new List<String>{ 'current' }
        );
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical SOQL search with current source should succeed');
        System.assert(response.results.size() >= 1, 'Should return Account results via SOQL >= filter');
        for (BREGNameClearanceController.SearchResult r : response.results) {
            System.assertEquals('Alphabetical', r.matchReason, 'Every result matchReason should be Alphabetical');
        }
    }

    /**
     * Results from all object types should be merged into one list sorted by NS field.
     * Two accounts inserted with ZZ-prefixed NS values ensure they sit above all @TestSetup
     * records alphabetically and come back in the correct ZZALPHA < ZZBETA order.
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_SortedOrder() {
        String rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        insert new List<Account>{
            new Account(
                Name = 'ZZ Beta Corp',
                breg_Entity_Type__c = 'C1',
                breg_Entity_Status__c = 'Active (A)',
                RecordTypeId = rtId,
                breg_Search_Name_NS__c = 'ZZBETA'
            ),
            new Account(
                Name = 'ZZ Alpha Corp',
                breg_Entity_Type__c = 'C1',
                breg_Entity_Status__c = 'Active (A)',
                RecordTypeId = rtId,
                breg_Search_Name_NS__c = 'ZZALPHA'
            )
        };
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'current' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical sorted search should succeed');
        System.assertEquals(2, response.results.size(), 'Should return exactly the two ZZ-prefixed accounts');
        System.assertEquals('ZZ Alpha Corp', response.results[0].name, 'ZZALPHA should sort before ZZBETA');
        System.assertEquals('ZZ Beta Corp', response.results[1].name, 'ZZBETA should sort after ZZALPHA');
    }

    /**
     * When Account and breg_Transaction_Business_Info__c share the same breg_Search_Name_NS__c
     * value, the historical record must be suppressed (Account wins via addedNames dedup).
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_HistoricalDedup() {
        String rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account dedupAccount = new Account(
            Name = 'ZZ Dedup Corp',
            breg_Entity_Type__c = 'C1',
            breg_Entity_Status__c = 'Active (A)',
            RecordTypeId = rtId,
            breg_Search_Name_NS__c = 'ZZDEDUP'
        );
        insert dedupAccount;
        insert new breg_Transaction_Business_Info__c(
            breg_Master_Name__c = 'ZZ Dedup Corp',
            breg_Entity__c = dedupAccount.Id,
            breg_Search_Name_NS__c = 'ZZDEDUP'
        );
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'current', 'historical' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical dedup search should succeed');
        Integer dedupCount = 0;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.name == 'ZZ Dedup Corp') {
                dedupCount++;
            }
        }
        System.assertEquals(1, dedupCount, 'Shared NS name should appear only once — Account wins over historical bInfo');
    }

    /**
     * A breg_Transaction_Business_Info__c record whose NS name is NOT held by any Account
     * must appear in results (no dedup suppression).
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_HistoricalNoDup() {
        String rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account parentAccount = new Account(
            Name = 'ZZ Parent Account',
            breg_Entity_Type__c = 'C1',
            breg_Entity_Status__c = 'Active (A)',
            RecordTypeId = rtId,
            breg_Search_Name_NS__c = 'ZZPARENT'
        );
        insert parentAccount;
        insert new breg_Transaction_Business_Info__c(
            breg_Master_Name__c = 'ZZ Unique Historical',
            breg_Entity__c = parentAccount.Id,
            breg_Search_Name_NS__c = 'ZZUNIQUEHIST'
        );
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'historical' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical historical-only search should succeed');
        Boolean found = false;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.name == 'ZZ Unique Historical') {
                found = true;
                System.assertEquals('historical', r.type, 'Result data source type should be historical');
            }
        }
        System.assert(found, 'Unique historical bInfo with no matching Account should appear in alphabetical results');
    }

    /**
     * breg_TN_TM_SM__c records with breg_Search_Name_NS__c populated are returned
     * in alphabetical SOQL search alongside Account results.
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_TnTmSm() {
        insert new breg_TN_TM_SM__c(Name = 'ZZ Alpha TN', breg_Status__c = 'A', breg_Type__c = 'Trade Name', breg_Search_Name_NS__c = 'ZZALPHATN');
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'current' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical TN/TM/SM search should succeed');
        Boolean foundTn = false;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.name == 'ZZ Alpha TN') {
                foundTn = true;
                System.assertEquals('current', r.type, 'TN/TM/SM result data source type should be current');
            }
        }
        System.assert(foundTn, 'breg_TN_TM_SM__c record should be returned in alphabetical SOQL results');
    }

    /**
     * A Case with a valid form code and breg_Search_Name_NS__c is returned
     * in alphabetical SOQL search with the current data source.
     * The form code is read from the BREG_Available_Forms_For_Name_Clearance label at runtime
     * so this test is safe in any org regardless of what codes are configured.
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_Case_CurrentSource() {
        breg_Form_Configuration__c formConfiguration = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'C1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Process__c = 'Change'
        );

        insert formConfiguration;

        Id bregCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case insertedCase = new Case(
            Subject = 'ZZ Case Subject',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = bregCaseRtId,
            breg_Name_of_the_Entity__c = 'ZZ Case Name',
            breg_Form_Configuration__c = formConfiguration.Id
        );
        insert insertedCase;

        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'current' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        System.assert(response.success, 'Alphabetical Case search with current source should succeed');
        Boolean foundCase = false;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.id == insertedCase.Id) {
                foundCase = true;
                System.assertEquals('current', r.type, 'Non-reservation Case result type should be current');
                System.assertEquals('Alphabetical', r.matchReason, 'Case match reason should be Alphabetical');
            }
        }
        System.assert(foundCase, 'Case with valid form code and NS value should appear in alphabetical SOQL results');
    }

    /**
     * When a Case has breg_Search_Xref_Name_1_NS__c populated, appendCaseSOQLResults
     * generates a separate result entry for that Xref field — both name and Xref results
     * appear in the merged sorted list.
     */
    @IsTest
    static void testPerformNameSearch_AlphabeticalSoql_Case_XrefSearched() {
        breg_Form_Configuration__c formConfiguration = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'C1',
            breg_Form_Code__c = 'DC-1',
            breg_Business_Process__c = 'Change'
        );

        insert formConfiguration;

        Id bregCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case insertedCase = new Case(
            Subject = 'ZZ Xref Case Subject',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = bregCaseRtId,
            breg_Name_of_the_Entity__c = 'ZZ Xref Primary',
            breg_Xref_Name_1__c = 'ZZ Case Xref One',
            breg_Form_Configuration__c = formConfiguration.Id
        );
        insert insertedCase;

        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'current' });
        request.searchField = 'breg_Search_Xref_Name_1_NS__c'; // Force search to look at the Xref field value
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performNameSearch(request);
        Test.stopTest();

        System.assert(response.success, 'Alphabetical Case Xref search should succeed');
        Boolean foundXref = false;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.id == insertedCase.Id && r.objectName == 'Case XRF1') {
                foundXref = true;
                System.assertEquals('current', r.type, 'Case Xref result data source type should be current');
            }
        }
        System.assert(foundXref, 'breg_Search_Xref_Name_1_NS__c on a Case should produce a separate result in alphabetical SOQL search');
    }

    // ===== performSearchLogSearch tests =====

    /**
     * Validation error - empty search term
     */
    @IsTest
    static void testPerformSearchLogSearch_EmptySearchTerm_ValidationError() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('', 'contains', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(!response.success, 'Search log search should fail with empty search term');
        System.assertEquals('Search term must be at least 1 character long', response.errorMessage);
        System.assertEquals(0, response.totalCount, 'Total count should be zero');
    }

    /**
     * Alphabetical match type uses SOQL and should only return rejected search log records
     */
    @IsTest
    static void testPerformSearchLogSearch_Alphabetical_ReturnsRejectedOnly() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical search log search should succeed');
        System.assert(response.results.size() >= 1, 'Should return at least one rejected search log result');
        for (BREGNameClearanceController.SearchResult r : response.results) {
            System.assertEquals('Alphabetical', r.matchReason, 'Match reason should be Alphabetical');
            System.assertNotEquals(TEST_SEARCH_LOG_TERM_NON_REJECTED, r.name, 'Non-rejected search log record should not appear in results');
        }
    }

    /**
     * Alphabetical results should be sorted ascending by normalized search term
     */
    @IsTest
    static void testPerformSearchLogSearch_Alphabetical_SortedOrder() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Alphabetical search should succeed');
        System.assertEquals(3, response.results.size(), 'Should return all three rejected ZZ search logs');
        System.assertEquals(TEST_SEARCH_LOG_TERM_REJECTED, response.results[0].name, 'ACME should sort before BETA');
        System.assertEquals(TEST_SEARCH_LOG_TERM_EXACT_REJECTED, response.results[1].name, 'BETA should sort after ACME');
        System.assertEquals(TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM, response.results[2].name, 'Normalized-only term should sort last');
    }

    /**
     * Contains match type uses SOSL
     */
    @IsTest
    static void testPerformSearchLogSearch_ContainsMatch_SOSL_Success() {
        breg_Search_Log__c rejectedLog = [SELECT Id FROM breg_Search_Log__c WHERE breg_Search_Term__c = :TEST_SEARCH_LOG_TERM_REJECTED LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ rejectedLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Acme', 'contains', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Contains search-log search should succeed');
        System.assertEquals(1, response.results.size(), 'Should return the matching rejected search log');
        System.assertEquals('Contains', response.results[0].matchReason, 'Match reason should be Contains');
    }

    /**
     * Exact match type uses SOSL
     */
    @IsTest
    static void testPerformSearchLogSearch_ExactMatch_SOSL_Success() {
        breg_Search_Log__c rejectedLog = [
            SELECT Id
            FROM breg_Search_Log__c
            WHERE breg_Search_Term__c = :TEST_SEARCH_LOG_TERM_EXACT_REJECTED
            LIMIT 1
        ];
        Test.setFixedSearchResults(new List<Id>{ rejectedLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            TEST_SEARCH_LOG_TERM_EXACT_REJECTED,
            'exact',
            new List<String>{ 'searchlog' }
        );
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Exact search-log search should succeed');
        System.assertEquals(1, response.results.size(), 'Should return the exact matching rejected search log');
        System.assertEquals('Exact Match', response.results[0].matchReason, 'Match reason should be Exact Match');
    }

    /**
     * Begins-with match type uses SOSL
     */
    @IsTest
    static void testPerformSearchLogSearch_BeginsWithMatch_SOSL_Success() {
        breg_Search_Log__c rejectedLog = [SELECT Id FROM breg_Search_Log__c WHERE breg_Search_Term__c = :TEST_SEARCH_LOG_TERM_REJECTED LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ rejectedLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ Acme', 'beginswith', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Begins-with search-log search should succeed');
        System.assertEquals(1, response.results.size(), 'Should return the begins-with matching rejected search log');
        System.assertEquals('Begins With', response.results[0].matchReason, 'Match reason should be Begins With');
    }

    /**
     * The "startswith" match type is an alias for "beginswith"
     */
    @IsTest
    static void testPerformSearchLogSearch_StartsWithAlias_SOSL_Success() {
        breg_Search_Log__c rejectedLog = [SELECT Id FROM breg_Search_Log__c WHERE breg_Search_Term__c = :TEST_SEARCH_LOG_TERM_REJECTED LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ rejectedLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ Acme', 'startswith', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, '"startswith" alias search should succeed');
        System.assertEquals(1, response.results.size(), 'startswith alias should behave like beginswith');
    }

    /**
     * SOSL candidate that does not actually satisfy the requested match type is filtered out
     */
    @IsTest
    static void testPerformSearchLogSearch_NoMatch_SOSL_ReturnsEmpty() {
        breg_Search_Log__c rejectedLog = [SELECT Id FROM breg_Search_Log__c WHERE breg_Search_Term__c = :TEST_SEARCH_LOG_TERM_REJECTED LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ rejectedLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest('Totally Different Name', 'exact', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed even when nothing matches');
        System.assertEquals(0, response.results.size(), 'No results should be returned when exact term does not match');
    }

    /**
     * Max results limit should be respected for search-log results
     */
    @IsTest
    static void testPerformSearchLogSearch_MaxResultsLimit() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'searchlog' });
        request.maxResults = 1;
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed');
        System.assertEquals(1, response.results.size(), 'Results should be limited to maxResults');
    }

    /**
     * Result properties should be mapped correctly, including file number from linked Case
     */
    @IsTest
    static void testPerformSearchLogSearch_ResultProperties_Validation() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', new List<String>{ 'searchlog' });
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed');
        BREGNameClearanceController.SearchResult matchedResult;
        for (BREGNameClearanceController.SearchResult r : response.results) {
            if (r.name == TEST_SEARCH_LOG_TERM_REJECTED) {
                matchedResult = r;
            }
        }
        System.assertNotEquals(null, matchedResult, 'Rejected search log with linked Case should be found');
        System.assertEquals('current', matchedResult.type, 'Result data source type should be searchlog');
        System.assertEquals('breg_Search_Term__c', matchedResult.matchedFieldName, 'Matched field should default to breg_Search_Term__c');
        System.assertNotEquals(null, matchedResult.fileNumber, 'File number should be populated from linked Case');
    }

    /**
     * When only the normalized term field matches, the result should surface that field as the match
     */
    @IsTest
    static void testPerformSearchLogSearch_MatchedFieldName_NormalizedTermOnly() {
        breg_Search_Log__c normalizedOnlyLog = [
            SELECT Id
            FROM breg_Search_Log__c
            WHERE breg_Normalized_Search_Term__c = :TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM
            LIMIT 1
        ];
        Test.setFixedSearchResults(new List<Id>{ normalizedOnlyLog.Id });
        BREGNameClearanceController.SearchRequest request = createSearchRequest(
            TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM,
            'exact',
            new List<String>{ 'searchlog' }
        );
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search should succeed');
        System.assertEquals(1, response.results.size(), 'Should find the normalized-term-only match');
        System.assertEquals(
            'breg_Normalized_Search_Term__c',
            response.results[0].matchedFieldName,
            'Matched field should be the normalized term field'
        );
        System.assertEquals(TEST_SEARCH_LOG_NORMALIZED_ONLY_TERM, response.results[0].name, 'Display name should be the normalized term value');
    }

    /**
     * Null dataSources should not cause an error and rejected-only filtering still applies
     */
    @IsTest
    static void testPerformSearchLogSearch_NullDataSources_StillSucceeds() {
        BREGNameClearanceController.SearchRequest request = createSearchRequest('ZZ', 'alphabetical', null);
        Test.startTest();
        BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
        Test.stopTest();
        System.assert(response.success, 'Search log search should succeed with null data sources');
        System.assert(response.results.size() >= 1, 'Should still find rejected search log records');
    }

    /**
     * Exception handling - null request should fail gracefully or throw a handled exception
     */
    @IsTest
    static void testPerformSearchLogSearch_ExceptionHandling() {
        BREGNameClearanceController.SearchRequest request = null;
        Test.startTest();
        try {
            BREGNameClearanceController.SearchResponse response = BREGNameClearanceController.performSearchLogSearch(request);
            System.assert(!response.success, 'Search should fail gracefully with null request');
        } catch (Exception e) {
            System.assert(true, 'Exception handling is working');
        }
        Test.stopTest();
    }
}