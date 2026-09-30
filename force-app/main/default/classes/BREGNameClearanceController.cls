/**
 * Controller for BREG Name Clearance Search functionality
 * Implements name normalization and SOQL/SOSL search across multiple objects
 */
public with sharing class BREGNameClearanceController {
    private static final Integer MAX_SOSL_RESULTS = 2000;
    private static final Integer MAX_SOQL_RESULTS = 2000;
    private static final String ENTITY_TYPE_FIELD = 'breg_Entity_Type__c';
    private static final String ENTITY_STATUS_FIELD = 'breg_Entity_Status__c';
    private static final String HISTORICAL_DATA_SOURCE = 'historical';
    private static final String CURRENT_DATA_SOURCE = 'current';
    private static final String RESERVATION_DATA_SOURCE = 'reservations';
    private static final String SEARCH_LOG_DATA_SOURCE = 'searchlog';
    private static final String CASE_RESERVATION_FORM_CODE = 'X-1';

    private static final List<String> EXCLUDED_FORM_CODES = new List<String>{
        'ANN-AG-1',
        'ANN-CONS-1',
        'ANN-DC-1',
        'ANN-DNP-1',
        'ANN-FC-1',
        'ANN-FLLC-1',
        'ANN-FLLP-1',
        'ANN-FLP-1',
        'ANN-GP-1',
        'ANN-LLC-1',
        'ANN-LLP-1',
        'ANN-LP-1',
        'ANN-PC-1',
        'ANN-SBC-1',
        'ANN-SOLE-1',
        'WD',
        'DOCDLVR'
    };
    private static final List<String> ENTITY_AVAILABLE_STATUSES = new List<String>{
        'Active (A)',
        'Annual report 1 yr delinquent (1)',
        'Annual report 2 yr delinquent (2)',
        'Merged (M)'
    };

    //private static final List<String> TNTMSM_AVAILABLE_STATUSES = new List<String>{ 'A' };
    private static final List<String> CASE_UNAVAILABLE_STATUSES = new List<String>{ 'Purged', 'Pending Submission', 'New' };
    private static final Map<String, String> TNTMSM_STATUS_LABEL_MAP = getPicklistValues('breg_TN_TM_SM__c', 'breg_Status__c');
    private static Set<String> addedNames = new Set<String>();
    /**
     * Main search method - performs name clearance search with specified criteria
     */
    @AuraEnabled(cacheable=false)
    public static SearchResponse performNameSearch(SearchRequest request) {
        Long searchStartTime = System.currentTimeMillis();
        SearchResponse response;

        try {
            // Validate input
            if (String.isBlank(request.searchTerm) || request.searchTerm.length() < 2) {
                response = createErrorResponse('Search term must be at least 2 characters long');
                BREGSearchLogger.logSearchRequest(request, response, searchStartTime);
                return response;
            }

            if (request.dataSources == null || request.dataSources.isEmpty()) {
                response = createErrorResponse('At least one data source must be selected');
                BREGSearchLogger.logSearchRequest(request, response, searchStartTime);
                return response;
            }

            // Normalize the search term
            String normalizedSearchTerm = BREGUtils.cleanBusinessName(request.searchTerm);
            addedNames.clear();
            if (String.isBlank(request.searchField)) {
                request.searchField = 'breg_Search_Name_NS__c';
            }

            List<SearchResult> allResults = new List<SearchResult>();

            // Perform search based on match type
            allResults = performSearchByMatchType(request, normalizedSearchTerm);

            // Filter results based on data sources
            allResults = filterByDataSources(allResults, request.dataSources);

            // Limit results if needed
            Integer defaultMaxResults = request.matchType == 'alphabetical' ? MAX_SOQL_RESULTS : 100;
            Integer maxResults = request.maxResults != null && request.maxResults > 0 ? request.maxResults : defaultMaxResults;
            if (request.matchType == 'alphabetical' && maxResults > MAX_SOQL_RESULTS) {
                maxResults = MAX_SOQL_RESULTS;
            }
            if (allResults.size() > maxResults) {
                allResults = (List<SearchResult>) getSubList(allResults, 0, maxResults);
            }

            response = new SearchResponse();
            response.success = true;
            response.results = allResults;
            response.totalCount = allResults.size();
            response.searchId = generateSearchId();
            response.normalizedSearchTerm = normalizedSearchTerm;

            // Log the successful search
            BREGSearchLogger.logSearchRequest(request, response, searchStartTime);

            return response;
        } catch (Exception e) {
            System.debug('Error in performNameSearch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            response = createErrorResponse('An unexpected error occurred: ' + e.getMessage() + ' Stack trace: ' + e.getStackTraceString());

            // Log the failed search
            BREGSearchLogger.logSearchRequest(request, response, searchStartTime);

            return response;
        }
    }

    /**
     * Searches breg_Search_Log__c records by search term — mirrors performNameSearch
     */
    @AuraEnabled(cacheable=false)
    public static SearchResponse performSearchLogSearch(SearchRequest request) {
        Long searchStartTime = System.currentTimeMillis();
        SearchResponse response;

        try {
            if (String.isBlank(request.searchTerm) || request.searchTerm.length() < 1) {
                response = createErrorResponse('Search term must be at least 1 character long');
                BREGSearchLogger.logSearchRequest(request, response, searchStartTime);
                return response;
            }

            String normalizedSearchTerm = BREGUtils.cleanBusinessName(request.searchTerm);

            List<SearchResult> allResults = querySearchLogRecords(request, normalizedSearchTerm);

            Integer defaultMaxResults = request.matchType == 'alphabetical' ? MAX_SOQL_RESULTS : 100;
            Integer maxResults = request.maxResults != null && request.maxResults > 0 ? request.maxResults : defaultMaxResults;
            if (request.matchType == 'alphabetical' && maxResults > MAX_SOQL_RESULTS) {
                maxResults = MAX_SOQL_RESULTS;
            }
            if (allResults.size() > maxResults) {
                allResults = (List<SearchResult>) getSubList(allResults, 0, maxResults);
            }

            response = new SearchResponse();
            response.success = true;
            response.results = allResults;
            response.totalCount = allResults.size();
            response.searchId = generateSearchId();
            response.normalizedSearchTerm = normalizedSearchTerm;
            return response;
        } catch (Exception e) {
            System.debug('Error in performSearchLogSearch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            response = createErrorResponse('An unexpected error occurred: ' + e.getMessage() + ' Stack trace: ' + e.getStackTraceString());
            BREGSearchLogger.logSearchRequest(request, response, searchStartTime);
            return response;
        }
    }

    private static List<SearchResult> querySearchLogRecords(SearchRequest request, String normalizedSearchTerm) {
        if (request.matchType == 'alphabetical') {
            return querySearchLogRecordsSOQL(request, normalizedSearchTerm);
        }
        return querySearchLogRecordsSOSL(request, normalizedSearchTerm);
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    private static List<SearchResult> querySearchLogRecordsSOQL(SearchRequest request, String normalizedSearchTerm) {
        List<SearchResult> results = new List<SearchResult>();
        Boolean rejectedOnly = request.dataSources != null &&
            request.dataSources.size() == 1 &&
            request.dataSources.contains(SEARCH_LOG_DATA_SOURCE);
        String rejectedFilter = rejectedOnly ? ' AND breg_Rejected_Name__c = true' : '';

        String query =
            'SELECT Id, breg_Search_Term__c, breg_Normalized_Search_Term__c, breg_Rejected_Name__c, ' +
            'breg_Case__c, breg_Case__r.CaseNumber, breg_Data_Sources__c, breg_Match_Type__c, ' +
            'breg_Search_DateTime__c, breg_Search_Status__c, breg_Search_User__c, breg_Results_Count__c ' +
            'FROM breg_Search_Log__c WHERE breg_Rejected_Name__c = true ' +
            'AND breg_Normalized_Search_Term__c >= :normalizedSearchTerm' +
            rejectedFilter +
            ' ORDER BY breg_Normalized_Search_Term__c ASC NULLS LAST LIMIT ' + MAX_SOQL_RESULTS;

        System.debug('Search Log SOQL Query (alphabetical): ' + query);
        List<breg_Search_Log__c> logs = (List<breg_Search_Log__c>) Database.query(query);

        for (breg_Search_Log__c log : logs) {
            if (isSearchLogMatch(log, normalizedSearchTerm, request.matchType)) {
                results.addAll(createSearchLogSearchResults(log, request, normalizedSearchTerm));
            }
        }
        return results;
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    private static List<SearchResult> querySearchLogRecordsSOSL(SearchRequest request, String normalizedSearchTerm) {
        List<SearchResult> results = new List<SearchResult>();
        Boolean rejectedOnly = request.dataSources != null &&
            request.dataSources.size() == 1 &&
            request.dataSources.contains(SEARCH_LOG_DATA_SOURCE);

        String escapedTerm = String.escapeSingleQuotes(normalizedSearchTerm);
        String soslSearch;
        switch on request.matchType {
            when 'exact' {
                soslSearch = '"' + escapedTerm + '"';
            }
            when 'beginswith', 'startswith' {
                List<String> terms = escapedTerm.split(' ');
                soslSearch = String.join(terms, '* AND ') + '*';
            }
            when else {
                List<String> terms = escapedTerm.split(' ');
                String joined = String.join(terms, '* AND *');
                soslSearch = joined.length() <= 1
                    ? '*' + joined + '* OR *' + joined + '*'
                    : '*' + joined + '*';
            }
        }

        String whereClause = 'WHERE breg_Rejected_Name__c = true';

        String soslQuery =
            'FIND \'' + soslSearch + '\' IN ALL FIELDS ' +
            'RETURNING breg_Search_Log__c(' +
            'Id, breg_Search_Term__c, breg_Normalized_Search_Term__c, breg_Rejected_Name__c, ' +
            'breg_Case__c, breg_Case__r.CaseNumber, breg_Data_Sources__c, breg_Match_Type__c, ' +
            'breg_Search_DateTime__c, breg_Search_Status__c, breg_Search_User__c, breg_Results_Count__c ' +
            (String.isNotBlank(whereClause) ? whereClause + ' ' : '') +
            'ORDER BY breg_Search_DateTime__c DESC LIMIT ' + MAX_SOSL_RESULTS +
            ')';

        System.debug('Search Log SOSL Query: ' + soslQuery);
        List<List<SObject>> searchResults = Search.query(soslQuery);

        if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
            List<breg_Search_Log__c> logs = (List<breg_Search_Log__c>) searchResults[0];
            for (breg_Search_Log__c log : logs) {
                if (isSearchLogMatch(log, normalizedSearchTerm, request.matchType)) {
                    results.addAll(createSearchLogSearchResults(log, request, normalizedSearchTerm));
                }
            }
        }
        return results;
    }

    private static Boolean isSearchLogMatch(breg_Search_Log__c log, String normalizedSearchTerm, String matchType) {
        String normalizedSearchTermValue = BREGUtils.cleanBusinessName(log.breg_Search_Term__c);
        String normalizedLogTermValue = BREGUtils.cleanBusinessName(log.breg_Normalized_Search_Term__c);

        if (matchType == 'alphabetical') {
            return String.isNotBlank(normalizedLogTermValue) && normalizedLogTermValue >= normalizedSearchTerm;
        }

        if (matchType == 'startswith') {
            matchType = 'beginswith';
        }

        return isFieldMatch(normalizedSearchTermValue, normalizedSearchTerm, matchType) ||
            isFieldMatch(normalizedLogTermValue, normalizedSearchTerm, matchType);
    }

    private static List<SearchResult> createSearchLogSearchResults(
        breg_Search_Log__c log,
        SearchRequest request,
        String normalizedTerm
    ) {
        List<SearchResult> results = new List<SearchResult>();
        String displayName = String.isNotBlank(log.breg_Search_Term__c) ? log.breg_Search_Term__c : log.breg_Normalized_Search_Term__c;
        if (String.isBlank(displayName)) {
            return results;
        }

        String matchedField = 'breg_Search_Term__c';
        if (
            String.isNotBlank(log.breg_Normalized_Search_Term__c) &&
            !isFieldMatch(BREGUtils.cleanBusinessName(log.breg_Search_Term__c), normalizedTerm, request.matchType) &&
            isFieldMatch(BREGUtils.cleanBusinessName(log.breg_Normalized_Search_Term__c), normalizedTerm, request.matchType)
        ) {
            displayName = log.breg_Normalized_Search_Term__c;
            matchedField = 'breg_Normalized_Search_Term__c';
        }

        SearchResult result = createBaseSearchResult(
            log.breg_Case__c != null ? log.breg_Case__c : log.Id,
            displayName,
            'breg_Search_Log__c',
            log.breg_Rejected_Name__c == true ? 'Rejected Name' : 'Search Log',
            CURRENT_DATA_SOURCE,
            'Rejected',
            log.breg_Search_DateTime__c != null ? log.breg_Search_DateTime__c.date() : null,
            request.matchType
        );
        result.matchedFieldName = matchedField;
        result.originalName = log.breg_Search_Term__c;
        result.searchValue = BREGUtils.cleanBusinessName(displayName);
        result.fileNumber = log.breg_Case__c != null ? log.breg_Case__r.CaseNumber : null;
        results.add(result);

        return results;
    }

    /**
     * Creates SearchResult objects from Case records
     */
    private static List<SearchResult> createCaseSearchResults(Case caseRecord, SearchRequest request, String normalizedTerm) {
        List<SearchResult> results = new List<SearchResult>();
        String caseNameValue = '';
        String caseSourceField = '';
        String currentDataSource = caseRecord.breg_Form_Code__c.equals(CASE_RESERVATION_FORM_CODE) ? RESERVATION_DATA_SOURCE : CURRENT_DATA_SOURCE;
        
         if (String.isNotBlank(caseRecord.breg_TNTMSM_Description__c)) {
            if (
                isFieldMatch(
                    BREGUtils.cleanBusinessName(caseRecord.breg_TNTMSM_Description__c),
                    normalizedTerm,
                   request.matchType
                )
            ) {
                caseNameValue = caseRecord.breg_TNTMSM_Description__c;
                caseSourceField = 'breg_TNTMSM_Description__c';
            }
        } else if (isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.breg_New_Entity_Name__c), normalizedTerm, request.matchType)) {
            caseNameValue = caseRecord.breg_New_Entity_Name__c;
            caseSourceField = 'breg_New_Entity_Name__c';
        } else if (isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.breg_Name_of_the_Entity__c), normalizedTerm, request.matchType)) {
            caseNameValue = caseRecord.breg_Name_of_the_Entity__c;
            caseSourceField = 'breg_Name_of_the_Entity__c';
        } else if (isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.breg_Name_for_Reservation__c), normalizedTerm, request.matchType)) {
            caseNameValue = caseRecord.breg_Name_for_Reservation__c;
            caseSourceField = 'breg_Name_for_Reservation__c';
        } else if (isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.Subject), normalizedTerm, request.matchType)) {
            caseNameValue = caseRecord.Subject;
            caseSourceField = 'Subject';
        }

        if (String.isNotBlank(caseNameValue)) {
            SearchResult result = createBaseSearchResult(
                caseRecord.Id,
                caseNameValue,
                'Case',
                'Case',
                currentDataSource,
                caseRecord.Status,
                caseRecord.breg_Submission_Date__c != null ? caseRecord.breg_Submission_Date__c.date() : null,
                request.matchType
            );
            result.matchedFieldName = caseSourceField;
            result.originalName = caseNameValue;
            result.fileNumber = caseRecord.breg_File__c;
            result.searchValue = BregUtils.cleanBusinessName(caseNameValue);
            results.add(result);
        }

        if (
            String.isNotBlank(caseRecord.breg_Xref_Name_1__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.breg_Xref_Name_1__c), normalizedTerm, request.matchType)
        ) {
            SearchResult result = createBaseSearchResult(
                caseRecord.Id,
                caseRecord.breg_Xref_Name_1__c,
                'Case',
                'Case XRF1',
                currentDataSource,
                caseRecord.Status,
                caseRecord.breg_Submission_Date__c != null ? caseRecord.breg_Submission_Date__c.date() : null,
                request.matchType
            );
            result.matchedFieldName = 'breg_Xref_Name_1__c';
            result.originalName = caseRecord.breg_Xref_Name_1__c;
            result.fileNumber = caseRecord.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(caseRecord.breg_Xref_Name_1__c);
            results.add(result);
        }

        if (
            String.isNotBlank(caseRecord.breg_Xref_Name_2__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(caseRecord.breg_Xref_Name_2__c), normalizedTerm, request.matchType)
        ) {
            SearchResult result = createBaseSearchResult(
                caseRecord.Id,
                caseRecord.breg_Xref_Name_2__c,
                'Case',
                'Case XRF2',
                currentDataSource,
                caseRecord.Status,
                caseRecord.breg_Submission_Date__c != null ? caseRecord.breg_Submission_Date__c.date() : null,
                request.matchType
            );
            result.matchedFieldName = 'breg_Xref_Name_2__c';
            result.originalName = caseRecord.breg_Xref_Name_2__c;
            result.fileNumber = caseRecord.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(caseRecord.breg_Xref_Name_2__c);
            results.add(result);
        }

        return results;
    }

    /**
     * Builds WHERE clause for Account SOQL queries
     */
    private static String buildAccountSOSLWhereClause(SearchRequest request, String normalizedTerm) {
        List<String> conditions = new List<String>();
        conditions.addAll(getTypeWhereConditions(request, normalizedTerm));
        String whereCondition = String.join(conditions, ' OR ');
        return (String.isNotBlank(whereCondition) ? '(' + whereCondition + ') AND' : '') +
            '  RecordType.DeveloperName = \'BREG_Account\' AND breg_Entity_Type__c != \'ZZ\' ';
    }

    /**
     * Builds WHERE clause for Case SOQL queries
     */ private static String buildCaseSOSLWhereClause(SearchRequest request, String normalizedTerm) {
        return ' RecordType.DeveloperName = \'BREG_Case\' AND Status != \'Completed\' AND breg_Form_Code__c NOT IN :EXCLUDED_FORM_CODES AND  breg_Form_Code__c != null AND (Status NOT IN :CASE_UNAVAILABLE_STATUSES OR (Status = \'New\' AND Origin = \'In Person\')) AND Status != null AND breg_Form_Configuration__c != null ';
    }

    /**
     * Builds WHERE clause for Account SOQL queries
     */
    private static List<String> getTypeWhereConditions(SearchRequest request, String normalizedTerm) {
        List<String> conditions = new List<String>();
        if (!request.dataSources.contains(RESERVATION_DATA_SOURCE)) {
            conditions.add('' + ENTITY_TYPE_FIELD + ' != \'' + ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE + '\'');
        } else {
            conditions.add(
                '(' +
                    ENTITY_TYPE_FIELD +
                    ' = \'' +
                    ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE +
                    '\' AND ' +
                    ENTITY_STATUS_FIELD +
                    ' = \'Active (A)\' AND breg_End_Date__c = null) OR ' +
                    ENTITY_TYPE_FIELD +
                    ' != \'' +
                    ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE +
                    '\''
            );
        }

        return conditions;
    }

    /**
     * Builds WHERE clause for breg_TN_TM_SM__c SOQL queries
     */
    private static String buildTNTMSMWhereClause(SearchRequest request, String normalizedTerm) {
        List<String> conditions = new List<String>();
        String searchPattern = getSearchPattern(request.matchType, normalizedTerm);

        // Build conditions for each name field

        return ' breg_End_Date__c = null ';
    }

    /**
     * Generates search pattern based on match type
     */
    private static String getSearchPattern(String matchType, String normalizedTerm) {
        switch on matchType {
            when 'exact' {
                return normalizedTerm;
            }
            when 'beginswith', 'startswith' {
                return normalizedTerm + '%';
            }
            when 'contains' {
                return '%' + normalizedTerm + '%';
            }
            when else {
                return '%' + normalizedTerm + '%'; // Default to contains
            }
        }
    }

    /**
     * Creates SearchResult objects from Account records
     */
    private static List<SearchResult> createAccountSearchResults(Account acc, SearchRequest request, String normalizedTerm) {
        List<SearchResult> results = new List<SearchResult>();
        String entityType = acc.breg_Entity_Type__c != ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE ? CURRENT_DATA_SOURCE : RESERVATION_DATA_SOURCE;

        // Check Name field
        if (String.isNotBlank(acc.Name) && isFieldMatch(BREGUtils.cleanBusinessName(acc.Name), normalizedTerm, request.matchType)) {
            SearchResult result = createBaseSearchResult(
                acc.Id,
                acc.Name,
                'Account',
                'Entity',
                entityType,
                acc.breg_Entity_Status__c,
                acc.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'Name';
            result.originalName = acc.Name;
            result.fileNumber = acc.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(acc.Name);
            results.add(result);
        }

        if (
            (String.isNotBlank(acc.breg_Xref_Name_1__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(acc.breg_Xref_Name_1__c), normalizedTerm, request.matchType))
        ) {
            SearchResult result = createBaseSearchResult(
                acc.Id,
                acc.breg_Xref_Name_1__c,
                'Account',
                'XRF1',
                entityType,
                acc.breg_Entity_Status__c,
                acc.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'breg_Xref_Name_1__c';
            result.originalName = acc.breg_Xref_Name_1__c;
            result.fileNumber = acc.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(acc.breg_Xref_Name_1__c);
            results.add(result);
        }

        if (
            (String.isNotBlank(acc.breg_Xref_Name_2__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(acc.breg_Xref_Name_2__c), normalizedTerm, request.matchType))
        ) {
            SearchResult result = createBaseSearchResult(
                acc.Id,
                acc.breg_Xref_Name_2__c,
                'Account',
                'XRF2',
                entityType,
                acc.breg_Entity_Status__c,
                acc.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'breg_Xref_Name_2__c';
            result.originalName = acc.breg_Xref_Name_2__c;
            result.fileNumber = acc.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(acc.breg_Xref_Name_2__c);
            results.add(result);
        }

        return results;
    }

    /**
     * Creates SearchResult objects from TransactionBusinessInfo records
     */
    private static List<SearchResult> createTransactionBusinessInfoSearchResults(
        breg_Transaction_Business_Info__c bInfo,
        SearchRequest request,
        String normalizedTerm
    ) {
        List<SearchResult> results = new List<SearchResult>();
        // Check Name field
        if (
            String.isNotBlank(bInfo.breg_Master_Name__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(bInfo.breg_Master_Name__c), normalizedTerm, request.matchType)
        ) {
            SearchResult result = createBaseSearchResult(
                bInfo.Id,
                bInfo.breg_Master_Name__c,
                HISTORICAL_DATA_SOURCE,
                'Entity History',
                HISTORICAL_DATA_SOURCE,
                'Nm. Change',
                bInfo.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'Name';
            result.originalName = bInfo.breg_Master_Name__c;
            result.fileNumber = bInfo.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(bInfo.breg_Master_Name__c);
            results.add(result);
        }

        return results;
    }

    /**
     * Creates SearchResult objects from breg_TN_TM_SM__c records
     */
    private static List<SearchResult> createTNTMSMSearchResults(breg_TN_TM_SM__c record, SearchRequest request, String normalizedTerm) {
        List<SearchResult> results = new List<SearchResult>();

        // Check Name field
        String fileNumber = String.isNotBlank(record.breg_File__c) && record.breg_File__c.endsWith(record.breg_File_Suffix__c ?? '')
            ? record.breg_File__c
            : record.breg_File__c + record.breg_File_Suffix__c;
        if (String.isNotBlank(record.Name) && isFieldMatch(BREGUtils.cleanBusinessName(record.Name), normalizedTerm, request.matchType)) {
            SearchResult result = createBaseSearchResult(
                record.Id,
                record.Name,
                'breg_TN_TM_SM__c',
                record.breg_Type__c,
                CURRENT_DATA_SOURCE,
                TNTMSM_STATUS_LABEL_MAP.get(record.breg_Status__c),
                record.breg_Registration_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'Name';
            result.originalName = record.Name;
            result.fileNumber = fileNumber;
            result.searchValue = BREGUtils.cleanBusinessName(record.Name);
            results.add(result);
        }

        if (
            String.isNotBlank(record.breg_XREF_Name1__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(record.breg_XREF_Name1__c), normalizedTerm, request.matchType)
        ) {
            SearchResult result = createBaseSearchResult(
                record.Id,
                record.breg_XREF_Name1__c,
                'breg_TN_TM_SM__c',
                'TNX1',
                CURRENT_DATA_SOURCE,
                TNTMSM_STATUS_LABEL_MAP.get(record.breg_Status__c),
                record.breg_Registration_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'breg_XREF_Name1__c';
            result.originalName = record.breg_XREF_Name1__c;
            result.fileNumber = fileNumber;
            result.searchValue = BREGUtils.cleanBusinessName(record.breg_XREF_Name1__c);
            results.add(result);
        }

        if (
            String.isNotBlank(record.breg_XREF_Name2__c) &&
            isFieldMatch(BREGUtils.cleanBusinessName(record.breg_XREF_Name2__c), normalizedTerm, request.matchType)
        ) {
            SearchResult result = createBaseSearchResult(
                record.Id,
                record.breg_XREF_Name2__c,
                'breg_TN_TM_SM__c',
                'TNX2',
                CURRENT_DATA_SOURCE,
                TNTMSM_STATUS_LABEL_MAP.get(record.breg_Status__c),
                record.breg_Registration_Date__c,
                request.matchType
            );
            result.matchedFieldName = 'breg_XREF_Name2__c';
            result.originalName = record.breg_XREF_Name2__c;
            result.fileNumber = fileNumber;
            result.searchValue = BREGUtils.cleanBusinessName(record.breg_XREF_Name2__c);
            results.add(result);
        }

        return results;
    }

    private static List<SearchResult> performSearchByMatchType(SearchRequest request, String normalizedTerm) {
        if (request.matchType == 'alphabetical') {
            return performSOQLSearch(request, normalizedTerm);
        }

        return performSOSLSearch(request, normalizedTerm);
    }

    /**
     * Performs dynamic SOQL search for alphabetical and other SOQL-compatible match types
     */
    @SuppressWarnings('PMD.ApexSOQLInjection')
    private static List<SearchResult> performSOQLSearch(SearchRequest request, String normalizedTerm) {
        List<SortedSearchResult> sortedResults = new List<SortedSearchResult>();
        String beginsWithPattern = normalizedTerm + '%';
        String containsPattern = '%' + normalizedTerm + '%';

        try {
            String dynamicFieldCondition = buildDynamicSearchCondition(new List<String>{ request.searchField }, request.matchType);

            Boolean shouldQueryCurrentOrReservations =
                request.dataSources.contains(CURRENT_DATA_SOURCE) || request.dataSources.contains(RESERVATION_DATA_SOURCE);
            if (shouldQueryCurrentOrReservations) {
                String accountQuery =
                    'SELECT Id, Name, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Incorporation_Date__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_File__c, breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c ' +
                    'FROM Account WHERE (' +
                    dynamicFieldCondition +
                    ') AND (' +
                    buildAccountSOSLWhereClause(request, normalizedTerm) +
                    ') ORDER BY ' +
                    request.searchField +
                    ' ASC NULLS LAST LIMIT ' +
                    MAX_SOQL_RESULTS;
                System.debug('Account SOQL Query: ' + accountQuery);
                List<Account> accounts = (List<Account>) Database.query(accountQuery);
                for (Account acc : accounts) {
                    Boolean isReservationEntity = acc.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE;
                    if (
                        (isReservationEntity && request.dataSources.contains(RESERVATION_DATA_SOURCE)) ||
                        (!isReservationEntity && request.dataSources.contains(CURRENT_DATA_SOURCE))
                    ) {
                        appendAccountSOQLResults(sortedResults, acc, request, normalizedTerm);
                        String normalizedAccountName = String.isNotBlank(acc.breg_Search_Name_NS__c)
                            ? acc.breg_Search_Name_NS__c
                            : BREGUtils.cleanBusinessName(acc.Name);
                        if (String.isNotBlank(normalizedAccountName)) {
                            addedNames.add(normalizedAccountName);
                        }
                    }
                }

                String caseQuery =
                    'SELECT Id, Subject, breg_Name_of_the_Entity__c,breg_Entity_name__c, breg_Name_for_Reservation__c, breg_Submission_Date__c, breg_New_Entity_Name__c, breg_File__c, breg_Form_Code__c, Status, breg_TNTMSM_Description__c, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c ' +
                    'FROM Case WHERE (' +
                    dynamicFieldCondition +
                    ') AND (' +
                    buildCaseSOSLWhereClause(request, normalizedTerm) +
                    ') ORDER BY ' +
                    request.searchField +
                    ' ASC NULLS LAST LIMIT ' +
                    MAX_SOQL_RESULTS;
                System.debug('Case SOQL Query: ' + caseQuery);
                List<Case> cases = (List<Case>) Database.query(caseQuery);
                for (Case caseRecord : cases) {
                    if (caseRecord.breg_Form_Code__c == CASE_RESERVATION_FORM_CODE && request.dataSources.contains(RESERVATION_DATA_SOURCE)) {
                        appendCaseSOQLResults(sortedResults, caseRecord, request, normalizedTerm);
                    } else if (caseRecord.breg_Form_Code__c != CASE_RESERVATION_FORM_CODE && request.dataSources.contains(CURRENT_DATA_SOURCE)) {
                        appendCaseSOQLResults(sortedResults, caseRecord, request, normalizedTerm);
                    }
                }
            }

            if (request.dataSources.contains(CURRENT_DATA_SOURCE)) {
                String tntmsmQuery =
                    'SELECT Id, Name, breg_XREF_Name1__c, breg_XREF_Name2__c, breg_Trade_Type__c, breg_Type__c, breg_Registration_Date__c, breg_File__c, breg_File_Suffix__c, breg_Status__c, breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c ' +
                    'FROM breg_TN_TM_SM__c WHERE (' +
                    dynamicFieldCondition +
                    ') AND breg_End_Date__c = null ORDER BY ' +
                    request.searchField +
                    ' ASC NULLS LAST LIMIT ' +
                    MAX_SOQL_RESULTS;
                System.debug('breg_TN_TM_SM__c SOQL Query: ' + tntmsmQuery);
                List<breg_TN_TM_SM__c> tntmsmRecords = (List<breg_TN_TM_SM__c>) Database.query(tntmsmQuery);
                for (breg_TN_TM_SM__c record : tntmsmRecords) {
                    appendTNTMSMSOQLResults(sortedResults, record, request, normalizedTerm);
                }
            }

            if (request.dataSources.contains(HISTORICAL_DATA_SOURCE)) {
                String historicalQuery =
                    'SELECT Id, breg_Entity__r.breg_Entity_Status__c, breg_Master_Name__c, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Incorporation_Date__c, breg_File__c, breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c ' +
                    'FROM breg_Transaction_Business_Info__c WHERE (' +
                    dynamicFieldCondition +
                    ') AND breg_Entity__r.breg_Entity_Type__c != \'ZZ\' ORDER BY ' +
                    request.searchField +
                    ' ASC NULLS LAST LIMIT ' +
                    MAX_SOQL_RESULTS;
                System.debug('breg_Transaction_Business_Info__c SOQL Query: ' + historicalQuery);
                List<breg_Transaction_Business_Info__c> historicalRecords = (List<breg_Transaction_Business_Info__c>) Database.query(historicalQuery);
                for (breg_Transaction_Business_Info__c bInfo : historicalRecords) {
                    appendTransactionBusinessInfoSOQLResults(sortedResults, bInfo, request, normalizedTerm);
                }
            }
        } catch (Exception e) {
            System.debug('Error in dynamic SOQL search: ' + e.getMessage());
        }

        return sortAndLimitSearchResults(sortedResults, MAX_SOQL_RESULTS);
    }

    private static void appendAccountSOQLResults(List<SortedSearchResult> sortedResults, Account acc, SearchRequest request, String normalizedTerm) {
        Map<String, String> typeByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => acc.breg_Entity_Type__c != ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE ? 'Entity' : 'Name Reservation',
            'breg_Search_Xref_Name_1_NS__c' => 'XRF1',
            'breg_Search_Xref_Name_2_NS__c' => 'XRF2'
        };

        Map<String, String> nameByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'Name',
            'breg_Search_Xref_Name_1_NS__c' => 'breg_Xref_Name_1__c',
            'breg_Search_Xref_Name_2_NS__c' => 'breg_Xref_Name_2__c'
        };

        String recordOriginalName = acc.get(nameByFieldMap.get(request.searchField)) != null
            ? String.valueOf(acc.get(nameByFieldMap.get(request.searchField)))
            : acc.Name;

        String entityType = acc.breg_Entity_Type__c != ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE ? CURRENT_DATA_SOURCE : RESERVATION_DATA_SOURCE;
        String searchValue = acc.get(request.searchField) != null ? String.valueOf(acc.get(request.searchField)) : '';
        if (String.isNotBlank(searchValue) && searchValue >= normalizedTerm) {
            SearchResult result = createBaseSearchResult(
                acc.Id,
                recordOriginalName,
                'Account',
                typeByFieldMap.containsKey(request.searchField) ? typeByFieldMap.get(request.searchField) : 'Entity',
                entityType,
                acc.breg_Entity_Status__c,
                acc.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = request.searchField;
            result.originalName = recordOriginalName;
            result.fileNumber = acc.breg_File__c;
            result.searchValue = BregUtils.cleanBusinessName(recordOriginalName);
            sortedResults.add(new SortedSearchResult(buildAlphabeticalSortKey(searchValue, recordOriginalName), result));
        }
    }

    private static void appendCaseSOQLResults(List<SortedSearchResult> sortedResults, Case caseRecord, SearchRequest request, String normalizedTerm) {
        String currentDataSource = caseRecord.breg_Form_Code__c == CASE_RESERVATION_FORM_CODE ? RESERVATION_DATA_SOURCE : CURRENT_DATA_SOURCE;
        String caseName = String.isNotBlank(caseRecord.breg_TNTMSM_Description__c)
            ? caseRecord.breg_TNTMSM_Description__c
            : (String.isNotBlank(caseRecord.breg_New_Entity_Name__c)
                  ? caseRecord.breg_New_Entity_Name__c
                  : (String.isNotBlank(caseRecord.breg_Name_of_the_Entity__c)
                        ? caseRecord.breg_Name_of_the_Entity__c
                        : (String.isNotBlank(caseRecord.breg_Name_for_Reservation__c) ? caseRecord.breg_Name_for_Reservation__c : caseRecord.Subject)));

        Map<String, String> typeByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'Case',
            'breg_Search_Xref_Name_1_NS__c' => 'Case XRF1',
            'breg_Search_Xref_Name_2_NS__c' => 'Case XRF2'
        };

        Map<String, String> nameByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'breg_Entity_name__c',
            'breg_Search_Xref_Name_1_NS__c' => 'breg_Xref_Name_1__c',
            'breg_Search_Xref_Name_2_NS__c' => 'breg_Xref_Name_2__c'
        };

         String recordOriginalName;
        if(request.searchField == 'breg_Search_Name_NS__c') {
            recordOriginalName = caseName;
            
        } else {
            recordOriginalName = caseRecord.get(nameByFieldMap.get(request.searchField)) != null
                ? String.valueOf(caseRecord.get(nameByFieldMap.get(request.searchField)))
                : caseRecord.breg_Entity_name__c;
        }

        String searchValue = caseRecord.get(request.searchField) != null ? String.valueOf(caseRecord.get(request.searchField)) : '';

        if (String.isNotBlank(searchValue) && searchValue >= normalizedTerm) {
            SearchResult result = createBaseSearchResult(
                caseRecord.Id,
                caseName,
                'Case',
                typeByFieldMap.get(request.searchField),
                currentDataSource,
                caseRecord.Status,
                caseRecord.breg_Submission_Date__c != null ? caseRecord.breg_Submission_Date__c.date() : null,
                request.matchType
            );
            result.matchedFieldName = request.searchField;
            result.originalName = recordOriginalName;
            result.fileNumber = caseRecord.breg_File__c;
            result.searchValue = BregUtils.cleanBusinessName(recordOriginalName);
            sortedResults.add(new SortedSearchResult(buildAlphabeticalSortKey(searchValue, recordOriginalName), result));
        }
    }

    private static void appendTNTMSMSOQLResults(
        List<SortedSearchResult> sortedResults,
        breg_TN_TM_SM__c record,
        SearchRequest request,
        String normalizedTerm
    ) {
        String fileNumber = String.isNotBlank(record.breg_File__c) && record.breg_File__c.endsWith(record.breg_File_Suffix__c ?? '')
            ? record.breg_File__c
            : record.breg_File__c + record.breg_File_Suffix__c;
        Map<String, String> typeByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => record.breg_Type__c,
            'breg_Search_Xref_Name_1_NS__c' => record.breg_Trade_Type__c + 'X1',
            'breg_Search_Xref_Name_2_NS__c' => record.breg_Trade_Type__c + 'X2'
        };

        Map<String, String> nameByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'Name',
            'breg_Search_Xref_Name_1_NS__c' => 'breg_XREF_Name1__c',
            'breg_Search_Xref_Name_2_NS__c' => 'breg_XREF_Name2__c'
        };

        String recordOriginalName = record.get(nameByFieldMap.get(request.searchField)) != null
            ? String.valueOf(record.get(nameByFieldMap.get(request.searchField)))
            : record.Name;

        String searchValue = record.get(request.searchField) != null ? String.valueOf(record.get(request.searchField)) : '';

        if (String.isNotBlank(searchValue) && searchValue >= normalizedTerm) {
            SearchResult result = createBaseSearchResult(
                record.Id,
                recordOriginalName,
                'breg_TN_TM_SM__c',
                typeByFieldMap.get(request.searchField) != null ? typeByFieldMap.get(request.searchField) : record.breg_Type__c,
                CURRENT_DATA_SOURCE,
                TNTMSM_STATUS_LABEL_MAP.get(record.breg_Status__c),
                record.breg_Registration_Date__c,
                request.matchType
            );
            result.matchedFieldName = request.searchField;
            result.originalName = recordOriginalName;
            result.fileNumber = fileNumber;
            result.searchValue = BregUtils.cleanBusinessName(recordOriginalName);
            sortedResults.add(new SortedSearchResult(buildAlphabeticalSortKey(searchValue, recordOriginalName), result));
        }
    }

    private static void appendTransactionBusinessInfoSOQLResults(
        List<SortedSearchResult> sortedResults,
        breg_Transaction_Business_Info__c bInfo,
        SearchRequest request,
        String normalizedTerm
    ) {
        String normalizedHistoricalName = String.isNotBlank(bInfo.breg_Search_Name_NS__c)
            ? bInfo.breg_Search_Name_NS__c
            : BREGUtils.cleanBusinessName(bInfo.breg_Master_Name__c);
        if (addedNames.contains(normalizedHistoricalName)) {
            return;
        }
        addedNames.add(normalizedHistoricalName);
        Map<String, String> typeByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'Entity History',
            'breg_Search_Xref_Name_1_NS__c' => 'History XRF1',
            'breg_Search_Xref_Name_2_NS__c' => 'History XRF2'
        };

        Map<String, String> nameByFieldMap = new Map<String, String>{
            'breg_Search_Name_NS__c' => 'breg_Master_Name__c',
            'breg_Search_Xref_Name_1_NS__c' => 'breg_XREF_Name1__c',
            'breg_Search_Xref_Name_2_NS__c' => 'breg_XREF_Name2__c'
        };

        String recordOriginalName = bInfo.get(nameByFieldMap.get(request.searchField)) != null
            ? String.valueOf(bInfo.get(nameByFieldMap.get(request.searchField)))
            : bInfo.breg_Master_Name__c;

        String searchValue = bInfo.get(request.searchField) != null ? String.valueOf(bInfo.get(request.searchField)) : '';

        if (String.isNotBlank(searchValue) && searchValue >= normalizedTerm) {
            SearchResult result = createBaseSearchResult(
                bInfo.Id,
                recordOriginalName,
                HISTORICAL_DATA_SOURCE,
                typeByFieldMap.containsKey(request.searchField) ? typeByFieldMap.get(request.searchField) : 'Unknown',
                HISTORICAL_DATA_SOURCE,
                'Nm. Change',
                bInfo.breg_Incorporation_Date__c,
                request.matchType
            );
            result.matchedFieldName = nameByFieldMap.get(request.searchField);
            result.originalName = recordOriginalName;
            result.fileNumber = bInfo.breg_File__c;
            result.searchValue = BREGUtils.cleanBusinessName(recordOriginalName);
            sortedResults.add(new SortedSearchResult(buildAlphabeticalSortKey(searchValue, recordOriginalName), result));
        }
    }

    private static String buildDynamicSearchCondition(List<String> searchFields, String matchType) {
        List<String> clauses = new List<String>();
        for (String fieldName : searchFields) {
            clauses.add(buildMatchFieldCondition(fieldName, matchType));
        }

        return String.join(clauses, ' OR ');
    }

    private static String buildMatchFieldCondition(String fieldName, String matchType) {
        switch on matchType {
            when 'alphabetical' {
                return '(' + fieldName + ' != null AND ' + fieldName + ' >= :normalizedTerm)';
            }
            when 'exact' {
                return fieldName + ' = :normalizedTerm';
            }
            when 'beginswith' {
                return fieldName + ' LIKE :beginsWithPattern';
            }
            when 'contains' {
                return fieldName + ' LIKE :containsPattern';
            }
            when else {
                return fieldName + ' LIKE :containsPattern';
            }
        }
    }

    private static String buildAlphabeticalSortKey(String normalizedFieldValue, String displayValue) {
        String primaryKey = String.isNotBlank(normalizedFieldValue) ? normalizedFieldValue : BREGUtils.cleanBusinessName(String.valueOf(displayValue));
        String secondaryKey = String.isNotBlank(displayValue) ? displayValue : '';
        return primaryKey + '|' + secondaryKey;
    }

    private static List<SearchResult> sortAndLimitSearchResults(List<SortedSearchResult> unsortedResults, Integer maxResults) {
        unsortedResults.sort();
        List<SearchResult> sortedResults = new List<SearchResult>();
        for (SortedSearchResult item : unsortedResults) {
            sortedResults.add(item.result);
            if (sortedResults.size() >= maxResults) {
                break;
            }
        }

        return sortedResults;
    }

    /**
     * Performs SOSL-based phonetic search
     */
    private static List<SearchResult> performSOSLSearch(SearchRequest request, String normalizedTerm) {
        List<SearchResult> results = new List<SearchResult>();

        try {
            System.debug('Performing phonetic search for term: ' + normalizedTerm);
            // Use FIND for phonetic matching
            String accountWhereClause = buildAccountSOSLWhereClause(request, normalizedTerm);
            if (String.isNotEmpty(accountWhereClause)) {
                accountWhereClause = ' WHERE (' + accountWhereClause + ')';
            }

            String caseWhereClause = buildCaseSOSLWhereClause(request, normalizedTerm);
            if (String.isNotEmpty(caseWhereClause)) {
                caseWhereClause = ' WHERE (' + caseWhereClause + ')';
            }

            String tntmsmWhereClause = buildTNTMSMWhereClause(request, normalizedTerm);
            if (String.isNotEmpty(tntmsmWhereClause)) {
                tntmsmWhereClause = ' WHERE (' + tntmsmWhereClause + ')';
            }

            List<String> terms = normalizedTerm.split(' ');

            // Join with AND for stricter matching
            String soslSearch = String.join(terms, '* AND *');

            // Optional: wildcard for partial matches
            soslSearch = '*' + soslSearch + '*';
            String soslQuery =
                'FIND \'' +
                String.escapeSingleQuotes(soslSearch) +
                '\' ' +
                // '~\' ' +
                'IN ALL FIELDS ' +
                'RETURNING Account(Id, Name, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Incorporation_Date__c, Type, CreatedDate, breg_Entity_Type__c, breg_Entity_Status__c, breg_File__c, breg_File_Suffix__c ' +
                accountWhereClause +
                '), ' +
                'Case(Id, Subject, breg_Name_of_the_Entity__c, breg_Name_for_Reservation__c, breg_Submission_Date__c, breg_New_Entity_Name__c, breg_File__c, breg_Form_Code__c, Status, CreatedDate, breg_TNTMSM_Description__c,breg_Xref_Name_1__c, breg_Xref_Name_2__c ' +
                caseWhereClause +
                ') ' +
                (request.dataSources.contains(CURRENT_DATA_SOURCE)
                    ? ', breg_TN_TM_SM__c(Id, Name, breg_XREF_Name1__c, breg_XREF_Name2__c, breg_Type__c, breg_Registration_Date__c, breg_File__c, breg_File_Suffix__c, breg_Status__c, CreatedDate ' +
                      tntmsmWhereClause +
                        ') '
                    : '') +
                (request.dataSources.contains(HISTORICAL_DATA_SOURCE)
                    ? ', breg_Transaction_Business_Info__c(Id, breg_Registrant_Name__c,breg_Entity__r.breg_Entity_Status__c, breg_Xref_Name_1__c, breg_Master_Name__c, breg_Xref_Name_2__c, breg_Incorporation_Date__c, breg_File__c, breg_File_Suffix__c, CreatedDate  WHERE breg_Entity__r.breg_Entity_Type__c != \'ZZ\') '
                    : '') +
                'LIMIT ' +
                MAX_SOSL_RESULTS;
            List<List<SObject>> searchResults = Search.query(soslQuery);

            for (List<SObject> resultList : searchResults) {
                System.debug('Result List: ' + resultList.size() + ' records');
                String objectType = resultList.isEmpty() ? 'Unknown' : String.valueOf(resultList[0].getSObjectType());
                if (objectType == 'Account') {
                    List<Account> accounts = (List<Account>) resultList;
                    for (Account acc : accounts) {
                        if (
                            (acc.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE &&
                            request.dataSources.contains(RESERVATION_DATA_SOURCE)) ||
                            (acc.breg_Entity_Type__c != ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE && request.dataSources.contains(CURRENT_DATA_SOURCE))
                        ) {
                            results.addAll(createAccountSearchResults(acc, request, normalizedTerm));
                            addedNames.add(BREGUtils.cleanBusinessName(acc.Name));
                        }
                    }
                } else if (objectType == 'breg_TN_TM_SM__c') {
                    List<breg_TN_TM_SM__c> records = (List<breg_TN_TM_SM__c>) resultList;
                    for (breg_TN_TM_SM__c record : records) {
                        results.addAll(createTNTMSMSearchResults(record, request, normalizedTerm));
                    }
                } else if (objectType == 'Case') {
                    List<Case> cases = (List<Case>) resultList;
                    for (Case caseRecord : cases) {
                        if (caseRecord.breg_Form_Code__c.equals(CASE_RESERVATION_FORM_CODE) && request.dataSources.contains(RESERVATION_DATA_SOURCE)) {
                            results.addAll(createCaseSearchResults(caseRecord, request, normalizedTerm));
                        } else if (
                            !caseRecord.breg_Form_Code__c?.equals(CASE_RESERVATION_FORM_CODE) && request.dataSources.contains(CURRENT_DATA_SOURCE)
                        ) {
                            results.addAll(createCaseSearchResults(caseRecord, request, normalizedTerm));
                        }
                    }
                } else if (objectType == 'breg_Transaction_Business_Info__c') {
                    List<breg_Transaction_Business_Info__c> bInfos = (List<breg_Transaction_Business_Info__c>) resultList;
                    for (breg_Transaction_Business_Info__c bInfo : bInfos) {
                        String normalizedBInfoName = BREGUtils.cleanBusinessName(bInfo.breg_Master_Name__c);
                        if (addedNames.contains(normalizedBInfoName)) {
                            continue; // Skip if we already have this name from Account results
                        }
                        results.addAll(createTransactionBusinessInfoSearchResults(bInfo, request, normalizedTerm));
                        addedNames.add(normalizedBInfoName);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in phonetic search: ' + e.getMessage());
        }

        return results;
    }

    /**
     * Checks if a field value matches the search criteria
     */
    private static Boolean isFieldMatch(String fieldValue, String searchTerm, String matchType) {
        if (String.isBlank(fieldValue) || String.isBlank(searchTerm)) {
            return false;
        }
        String normalizedFieldValue = fieldValue;
        String normalizedSearchTerm = searchTerm;
        switch on matchType {
            when 'alphabetical' {
                return (normalizedFieldValue > normalizedSearchTerm && normalizedFieldValue.contains(normalizedSearchTerm)) ||
                    normalizedFieldValue.startsWith(normalizedSearchTerm);
            }
            when 'exact' {
                return normalizedFieldValue.equals(normalizedSearchTerm);
            }
            when 'beginswith', 'startswith' {
                return normalizedFieldValue.startsWith(normalizedSearchTerm);
            }
            when 'contains' {
                return normalizedFieldValue.contains(normalizedSearchTerm);
            }
            when 'phonetic' {
                // For phonetic, we rely on SOSL FIND, but this is a fallback check
                return normalizedFieldValue.contains(normalizedSearchTerm) ||
                    calculatePhoneticSimilarity(normalizedFieldValue, normalizedSearchTerm) > 0.7;
            }
            when else {
                return normalizedFieldValue.contains(normalizedSearchTerm);
            }
        }
    }

    /**
     * Creates a base SearchResult object
     */
    private static SearchResult createBaseSearchResult(
        String recordId,
        String name,
        String objectType,
        String objectName,
        String entityType,
        String status,
        Date createdDate,
        String matchType
    ) {
        SearchResult result = new SearchResult();
        result.id = recordId;
        result.name = name;
        result.type = entityType;
        result.recordURL = '/' + recordId;
        result.objectName = objectName;
        result.matchReason = getMatchReasonLabel(matchType);
        result.status = status;
        result.registrationDate = createdDate;
        return result;
    }

    private static String getMatchReasonLabel(String matchType) {
        switch on matchType {
            when 'alphabetical' {
                return 'Alphabetical';
            }
            when 'exact' {
                return 'Exact Match';
            }
            when 'beginswith', 'startswith' {
                return 'Begins With';
            }
            when 'contains' {
                return 'Contains';
            }
            when 'phonetic' {
                return 'Phonetic Match';
            }
            when else {
                return 'Contains';
            }
        }
    }

    /**
     * Simple phonetic similarity calculation (Levenshtein distance based)
     */
    private static Decimal calculatePhoneticSimilarity(String str1, String str2) {
        if (String.isBlank(str1) || String.isBlank(str2)) {
            return 0.0;
        }

        Integer maxLength = Math.max(str1.length(), str2.length());
        if (maxLength == 0) {
            return 1.0;
        }

        Integer distance = calculateLevenshteinDistance(str1, str2);
        return 1.0 - ((Decimal) distance / maxLength);
    }

    /**
     * Calculates Levenshtein distance between two strings
     */
    private static Integer calculateLevenshteinDistance(String str1, String str2) {
        Integer len1 = str1.length();
        Integer len2 = str2.length();

        List<List<Integer>> matrix = new List<List<Integer>>();

        // Initialize matrix
        for (Integer i = 0; i <= len1; i++) {
            List<Integer> row = new List<Integer>();
            for (Integer j = 0; j <= len2; j++) {
                row.add(0);
            }
            matrix.add(row);
        }

        // Fill first row and column
        for (Integer i = 0; i <= len1; i++) {
            matrix[i][0] = i;
        }
        for (Integer j = 0; j <= len2; j++) {
            matrix[0][j] = j;
        }

        // Calculate distances
        for (Integer i = 1; i <= len1; i++) {
            for (Integer j = 1; j <= len2; j++) {
                Integer cost = (str1.substring(i - 1, i).equals(str2.substring(j - 1, j))) ? 0 : 1;
                matrix[i][j] = Math.min(
                    Math.min(
                        matrix[i - 1][j] +
                        1, // deletion
                        matrix[i][j - 1] + 1
                    ), // insertion
                    matrix[i - 1][j - 1] +
                    cost // substitution
                );
            }
        }

        return matrix[len1][len2];
    }

    /**
     * Filters results based on selected data sources
     */
    private static List<SearchResult> filterByDataSources(List<SearchResult> results, List<String> selectedSources) {
        if (selectedSources == null || selectedSources.isEmpty()) {
            return results;
        }

        List<SearchResult> filteredResults = new List<SearchResult>();
        Set<String> sourceSet = new Set<String>(selectedSources);

        for (SearchResult result : results) {
            if (sourceSet.contains(result.type)) {
                filteredResults.add(result);
            }
        }

        return filteredResults;
    }

    /**
     * Generates unique search ID for tracking
     */
    private static String generateSearchId() {
        return 'SEARCH_' + String.valueOf(System.currentTimeMillis());
    }

    /**
     * Returns a map of picklist values and labels for a specified field
     */
    public static Map<String, String> getPicklistValues(String objectName, String fieldName) {
        Map<String, String> picklistMap = new Map<String, String>();

        try {
            SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType == null) {
                return picklistMap;
            }

            SObjectField sObjectField = sObjectType.getDescribe().fields.getMap().get(fieldName);
            if (sObjectField == null) {
                return picklistMap;
            }

            DescribeFieldResult fieldDescribe = sObjectField.getDescribe();
            List<PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();

            for (PicklistEntry entry : picklistEntries) {
                picklistMap.put(entry.getValue(), entry.getLabel());
            }
        } catch (Exception e) {
            System.debug('Error getting picklist values: ' + e.getMessage());
        }

        return picklistMap;
    }

    /**
     * Creates error response
     */
    private static SearchResponse createErrorResponse(String errorMessage) {
        SearchResponse response = new SearchResponse();
        response.success = false;
        response.errorMessage = errorMessage;
        response.results = new List<SearchResult>();
        response.totalCount = 0;
        return response;
    }

    private static List<SearchResult> getSubList(List<SearchResult> objectList, Integer startElement, Integer endElement) {
        List<SearchResult> subList = new List<SearchResult>();
        for (Integer i = startElement; i < endElement && i < objectList.size(); i++) {
            subList.add(objectList[i]);
        }
        return subList;
    }

    private class SortedSearchResult implements Comparable {
        public String sortKey;
        public SearchResult result;

        public SortedSearchResult(String sortKey, SearchResult result) {
            this.sortKey = sortKey;
            this.result = result;
        }

        public Integer compareTo(Object otherItem) {
            SortedSearchResult other = (SortedSearchResult) otherItem;
            String thisKey = this.sortKey != null ? this.sortKey.toLowerCase() : '';
            String otherKey = other.sortKey != null ? other.sortKey.toLowerCase() : '';
            if (thisKey == otherKey) {
                return 0;
            }

            return thisKey < otherKey ? -1 : 1;
        }
    }

    public class SearchRequest {
        @AuraEnabled
        public String searchTerm { get; set; }
        @AuraEnabled
        public String matchType { get; set; }
        @AuraEnabled
        public String searchField { get; set; }
        @AuraEnabled
        public List<String> dataSources { get; set; }
        @AuraEnabled
        public Integer maxResults { get; set; }
    }

    public class SearchResult {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String fileNumber { get; set; }
        @AuraEnabled
        public String recordURL { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public String dataSource { get; set; }
        @AuraEnabled
        public String matchReason { get; set; }
        @AuraEnabled
        public Date registrationDate { get; set; }
        @AuraEnabled
        public Date expiryDate { get; set; }
        @AuraEnabled
        public String registrationNumber { get; set; }
        @AuraEnabled
        public String statusIcon { get; set; }
        @AuraEnabled
        public String statusClass { get; set; }
        @AuraEnabled
        public String nameClass { get; set; }
        @AuraEnabled
        public String dataSourceClass { get; set; }
        @AuraEnabled
        public String scoreClass { get; set; }
        @AuraEnabled
        public String matchedFieldName { get; set; }
        @AuraEnabled
        public String originalName { get; set; }
        @AuraEnabled
        public String objectName { get; set; }
        @AuraEnabled
        public String searchValue { get; set; }
    }

    public class SearchResponse {
        @AuraEnabled
        public Boolean success { get; set; }
        @AuraEnabled
        public List<SearchResult> results { get; set; }
        @AuraEnabled
        public Integer totalCount { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public String searchId { get; set; }
        @AuraEnabled
        public String normalizedSearchTerm { get; set; }
    }
}