@IsTest
private class BREGSearchLoggerTest {
    @IsTest
    static void testLogSearchRequestSuccess() {
        BREGNameClearanceController.SearchRequest request = new BREGNameClearanceController.SearchRequest();
        request.searchTerm = 'Acme';
        request.matchType = 'exact';
        request.dataSources = new List<String>{ 'current', 'historical' };
        request.maxResults = 25;

        BREGNameClearanceController.SearchResponse response = new BREGNameClearanceController.SearchResponse();
        response.success = true;
        response.totalCount = 3;
        response.searchId = 'SEARCH-001';
        response.normalizedSearchTerm = 'ACME';

        Long searchStartTime = System.currentTimeMillis() - 50;

        Test.startTest();
        BREGSearchLogger.logSearchRequest(request, response, searchStartTime);
        Test.stopTest();

        breg_Search_Log__c searchLog = [
            SELECT
                breg_Search_Term__c,
                breg_Match_Type__c,
                breg_Data_Sources__c,
                breg_Search_User__c,
                breg_Results_Count__c,
                breg_Search_Duration_MS__c,
                breg_Search_Status__c,
                breg_Search_Request_JSON__c
            FROM breg_Search_Log__c
            WHERE breg_Search_Term__c = 'Acme'
            LIMIT 1
        ];

        System.assertEquals('Acme', searchLog.breg_Search_Term__c, 'Search term should be logged');
        System.assertEquals('exact', searchLog.breg_Match_Type__c, 'Match type should be logged');
        System.assertEquals('current;historical', searchLog.breg_Data_Sources__c, 'Data sources should be joined with semicolons');
        System.assertEquals(UserInfo.getUserId(), searchLog.breg_Search_User__c, 'Current user should be logged');
        System.assertEquals(3, searchLog.breg_Results_Count__c, 'Result count should be logged');
        System.assertEquals('Success', searchLog.breg_Search_Status__c, 'Successful searches should be marked as success');
        System.assert(searchLog.breg_Search_Duration_MS__c >= 0, 'Search duration should be populated');

        Map<String, Object> requestJson = (Map<String, Object>) JSON.deserializeUntyped(searchLog.breg_Search_Request_JSON__c);
        System.assertEquals('Acme', (String) requestJson.get('searchTerm'), 'Request JSON should include the search term');
        System.assertEquals('SEARCH-001', (String) requestJson.get('searchId'), 'Request JSON should include the search id');
        System.assertEquals('ACME', (String) requestJson.get('normalizedTerm'), 'Request JSON should include the normalized term');
    }

    @IsTest
    static void testLogSearchRequestError() {
        BREGNameClearanceController.SearchRequest request = new BREGNameClearanceController.SearchRequest();
        request.searchTerm = 'Beta';
        request.matchType = 'contains';
        request.dataSources = null;
        request.maxResults = 10;

        BREGNameClearanceController.SearchResponse response = new BREGNameClearanceController.SearchResponse();
        response.success = false;
        response.totalCount = null;
        response.errorMessage = 'Search service unavailable';
        response.searchId = 'SEARCH-ERR';
        response.normalizedSearchTerm = 'BETA';

        Test.startTest();
        BREGSearchLogger.logSearchRequest(request, response, System.currentTimeMillis());
        Test.stopTest();

        breg_Search_Log__c searchLog = [
            SELECT
                breg_Data_Sources__c,
                breg_Results_Count__c,
                breg_Search_Status__c,
                breg_Search_Request_JSON__c
            FROM breg_Search_Log__c
            WHERE breg_Search_Term__c = 'Beta'
            LIMIT 1
        ];

        System.assertEquals(null, searchLog.breg_Data_Sources__c, 'Null data sources are stored as null on the multiselect picklist');
        System.assertEquals(0, searchLog.breg_Results_Count__c, 'Null result counts should default to zero');
        System.assertEquals('Error', searchLog.breg_Search_Status__c, 'Failed searches should be marked as error');

        Map<String, Object> requestJson = (Map<String, Object>) JSON.deserializeUntyped(searchLog.breg_Search_Request_JSON__c);
        System.assertEquals('Search service unavailable', (String) requestJson.get('errorMessage'), 'Request JSON should include the error message for failed searches');
    }
}