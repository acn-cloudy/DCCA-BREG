public with sharing class BREGSearchLogger {
    /**
     * Logs search request details to breg_Search_Log__c object
     */
    public static void logSearchRequest(
        BREGNameClearanceController.SearchRequest request,
        BREGNameClearanceController.SearchResponse response,
        Long searchStartTime
    ) {
        try {
            Long searchEndTime = System.currentTimeMillis();
            Long searchDuration = searchEndTime - searchStartTime;

            // Create search log record
            breg_Search_Log__c searchLog = new breg_Search_Log__c();
            searchLog.breg_Search_Term__c = request.searchTerm;
            searchLog.breg_Match_Type__c = request.matchType;
            searchLog.breg_Data_Sources__c = request.dataSources != null ? String.join(request.dataSources, ';') : '';
            searchLog.breg_Search_DateTime__c = DateTime.now();
            searchLog.breg_Search_User__c = UserInfo.getUserId();
            searchLog.breg_Results_Count__c = response.totalCount != null ? response.totalCount : 0;
            searchLog.breg_Search_Duration_MS__c = searchDuration;
            searchLog.breg_Search_Status__c = response.success ? 'Success' : 'Error';

            // Create JSON representation of the search request
            Map<String, Object> requestMap = new Map<String, Object>{
                'searchTerm' => request.searchTerm,
                'matchType' => request.matchType,
                'dataSources' => request.dataSources,
                'maxResults' => request.maxResults,
                'searchId' => response.searchId,
                'normalizedTerm' => response.normalizedSearchTerm,
                'timestamp' => DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            };

            // Add error information if search failed
            if (!response.success && String.isNotBlank(response.errorMessage)) {
                requestMap.put('errorMessage', response.errorMessage);
            }

            searchLog.breg_Search_Request_JSON__c = JSON.serialize(requestMap, true);

            // Insert search log record (use Database.insert to avoid exceptions)
            Database.SaveResult saveResult = Database.insert(searchLog, false);

            if (!saveResult.isSuccess()) {
                System.debug('Failed to insert search log: ' + saveResult.getErrors());
            } else {
                System.debug('Search logged successfully with ID: ' + saveResult.getId());
            }
        } catch (Exception e) {
            // Log the error but don't let it fail the search
            System.debug('Error logging search request: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}