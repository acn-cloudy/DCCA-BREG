public without sharing class BREGSearchAndBuyController {
    private static String BEGINS_SEARCH_TYPE_OPTION_VALUE = 'begins';
    private static String CONTAINS_SEARCH_TYPE_OPTION_VALUE = 'contains';
    private static String ALL_VALUE = 'all';
    private static String RESERVATION_VALUE = 'Reservation';
    private static String TRADE_NAME_VALUE = 'Trade Name';
    private static String TRADEMARK_VALUE = 'Trademark';
    private static String SERVICE_MARK_VALUE = 'Service Mark';
    private static String PUBLICITY_RIGHTS_NAME_VALUE = 'Publicity Rights Name';
    private static String ENTITY_VALUE = 'Entity';
    private static String PENDING_FILING_VALUE = 'Pending Filing';
    private static String CASE_VALUE = 'Case';
    private static String ENTITY_HISTORY_SOURCE_OBJECT_VALUE = 'breg_Transaction_Business_Info__c';
    private static String CROSS_REFERENCE_1_VALUE = 'Cross Reference 1';
    private static String CROSS_REFERENCE_2_VALUE = 'Cross Reference 2';
    private static String REFERENCE_1_VALUE = 'XRef 1';
    private static String REFERENCE_2_VALUE = 'XRef 2';

    private static final List<String> CASE_SEARCH_STATUSES = new List<String>{
        'Received',
        'Approved',
        'Rejected',
        'Pending Withdrawal',
        'Filing'
    };
    private static String FILING_CASE_STATUS_VALUE = 'Filing';
    private static String APPROVED_CASE_STATUS_VALUE = 'Approved';
    private static final Set<String> EXCLUDED_CASE_FORM_CODES = new Set<String>{
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
    private static Integer DEFAULT_QUERY_LIMIT = 300;
    private static String NEW_ENTITY_STATUS_VALUE = 'New (Y)';
    private static String ACTIVE_ENTITY_STATUS_VALUE = 'Active (A)';
    private static String EXPIRED_ENTITY_STATUS_VALUE = 'Expired (E)';
    private static String CANCELED_ENTITY_STATUS_VALUE = 'Cancelled (C)';
    private static String INV_REVOKED_ENTITY_STATUS_VALUE = 'Inv. Revoked (R)';

    @AuraEnabled(cacheable=true)
    public static List<SearchResultWrapper> getSearchResults(SearchInputsWrapper searchInputs) {
        List<Account> accounts = new List<Account>();
        List<breg_TN_TM_SM__c> tnTmSms = new List<breg_TN_TM_SM__c>();
        List<breg_Transaction_Business_Info__c> historicalBusinessInfo = new List<breg_Transaction_Business_Info__c>();
        List<Case> cases = new List<Case>();
        List<SearchResultWrapper> results = new List<SearchResultWrapper>();

        try {
            Boolean includeAccount = isIncludeAccount(searchInputs.recordType);
            Boolean includeTnTmSm = isIncludeTnTmSm(searchInputs.includeTnTmSm, searchInputs.recordType, searchInputs.status);
            Boolean includeCases = isIncludeCases(searchInputs.includeTransactions, searchInputs.recordType);
            Integer queryLimit = searchInputs.queryLimit != null ? searchInputs.queryLimit : DEFAULT_QUERY_LIMIT;
            Boolean includeNotifications = searchInputs.includeNotifications != null ? searchInputs.includeNotifications : false;
            Boolean includeHistoricalEntityNames = includeAccount && !searchInputs.excludeAccounts && searchInputs.searchByNumber != true;

            if (includeAccount && !searchInputs.excludeAccounts) {
                accounts = queryAccount(searchInputs, queryLimit);
                //queryLimit -= accounts.size();
                results.addAll(convertAccountsToWrappers(accounts, searchInputs));
            }

            if (includeHistoricalEntityNames) {
                historicalBusinessInfo = queryHistoricalBusinessInfo(searchInputs, queryLimit);
                Set<String> existingEntityIds = new Set<String>();
                for (SearchResultWrapper existingResult : results) {
                    if (String.isNotBlank(existingResult.recordId)) {
                        existingEntityIds.add(existingResult.recordId);
                    }
                }

                List<breg_Transaction_Business_Info__c> filteredHistoricalBusinessInfo = new List<breg_Transaction_Business_Info__c>();
                for (breg_Transaction_Business_Info__c historicalRecord : historicalBusinessInfo) {
                    String historicalEntityId = historicalRecord.breg_Entity__c != null
                        ? String.valueOf(historicalRecord.breg_Entity__c)
                        : String.valueOf(historicalRecord.Id);
                    if (!existingEntityIds.contains(historicalEntityId)) {
                        filteredHistoricalBusinessInfo.add(historicalRecord);
                    }
                }

                results.addAll(convertHistoricalBusinessInfoToWrappers(filteredHistoricalBusinessInfo, searchInputs));
            }

            if (includeTnTmSm) {
                tnTmSms = queryTnTmSm(searchInputs, queryLimit);
                //queryLimit -= tnTmSms.size();
                results.addAll(convertTnTmSmsToWrappers(tnTmSms, searchInputs));
            }

            if (includeCases) {
                cases = queryCases(searchInputs, queryLimit);
                results.addAll(convertCasesToWrappers(cases, searchInputs));
            }

            results.sort(new SearchResultWrapperComparator());

            List<SearchResultWrapper> limitedResults = new List<SearchResultWrapper>();
            for (Integer i = 0; i < results.size() && i < queryLimit; i++) {
                limitedResults.add(results[i]);
            }

            results = limitedResults;

            if (includeNotifications) {
                List<Id> recordIds = new List<Id>();
                for (SearchResultWrapper res : results) {
                    recordIds.add(res.recordId);
                }

                Map<Id, Boolean> missingMap = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(
                    recordIds,
                    searchInputs.notificationCategory
                );
                for (SearchResultWrapper res : results) {
                    Boolean isMissing = missingMap.get(res.recordId);
                    res.notificationsAvailable = isMissing == null ? true : isMissing;
                }
            }
            Integer totalAccountResults = (includeAccount && !searchInputs.excludeAccounts) ? countAccounts(searchInputs) : 0;
            Integer totalHistoricalEntityResults = includeHistoricalEntityNames ? historicalBusinessInfo.size() : 0;
            Integer totalTnTmSmResults = includeTnTmSm ? countTnTmSm(searchInputs) : 0;
            Integer totalCaseResults = includeCases ? countCases(searchInputs) : 0;
            for (SearchResultWrapper res : results) {
                res.totalAccountResults = totalAccountResults + totalHistoricalEntityResults;
                res.totalTnTmSmResults = totalTnTmSmResults;
                res.totalTransactionResults = totalHistoricalEntityResults;
                res.totalCaseResults = totalCaseResults;
                res.totalResults = totalAccountResults + totalHistoricalEntityResults + totalTnTmSmResults + totalCaseResults;
            }
        } catch (Exception e) {
            if (Test.isRunningTest()) {
                throw e;
            }
            throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString());
        }

        return results;
    }

    private static List<Account> queryAccount(SearchInputsWrapper searchInputs, Integer queryLimit) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));
        String recordType = searchInputs.recordType;
        String status = searchInputs.status;
        String entityType = searchInputs.entityType;
        Boolean searchByNumber = searchInputs.searchByNumber;
        Set<String> excludeEntityTypes = getExcludeEntityTypes();

        //base query
        String query = 'SELECT Id, Name, breg_BRIM_MASTER_NAME__c, breg_File__c, breg_File_Suffix__c, breg_Entity_Status__c, breg_Business_Structure__c, breg_Entity_Type__c, CreatedDate, breg_Search_Name__c, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c FROM Account';

        //condition list initialization
        List<String> conditions = new List<String>();

        // breg account record type condition
        conditions.add('RecordType.Name = \'BREG Account\'');

        //name condition
        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            List<String> parts = nameCondition.trim().split('\\s+');
            String escapedFilePart;
            String escapedSuffixPart;
            String fileOnlyPart;

            if (searchByNumber) {
                if (parts.size() == 2) {
                    // Use bind variables :escapedFilePart and :escapedSuffixPart
                    escapedFilePart = parts[0] + '%';
                    escapedSuffixPart = parts[1];
                    // wrap the OR expression in parentheses so it is evaluated together when joined with other AND conditions
                    conditions.add(
                        '((breg_File__c LIKE :escapedFilePart AND breg_File_Suffix__c LIKE :escapedSuffixPart) OR breg_Search_Name__c LIKE :nameCondition)'
                    );
                } else {
                    fileOnlyPart = parts[0];
                    // ensure OR is grouped with parentheses
                    conditions.add('((breg_File__c LIKE :fileOnlyPart OR breg_Search_Name__c LIKE :nameCondition))');
                }
            } else {
                conditions.add(
                    '(breg_Search_Name__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)'
                );
            }
        }
        //record type condition
        // if (String.isNotBlank(recordType) && !ALL_VALUE.equalsIgnoreCase(recordType)) {
        //     if (recordType.equalsIgnoreCase(RESERVATION_VALUE)) {
        //         conditions.add('breg_Entity_Type__c = :RESERVATION_ENTITY_TYPE_VALUE');
        //     } else if (recordType.equalsIgnoreCase(ENTITY_VALUE)) {
        //         conditions.add('breg_Entity_Type__c != :RESERVATION_ENTITY_TYPE_VALUE');
        //     }
        // }
        //status condition
        if (String.isNotBlank(status) && !ALL_VALUE.equalsIgnoreCase(status)) {
            conditions.add('breg_Entity_Status__c = :status');
        }
        //entity type condition
        if (String.isNotBlank(entityType) && !ALL_VALUE.equalsIgnoreCase(entityType)) {
            conditions.add('breg_Business_Structure_Formula__c = :entityType');
        }
        //exclude entity types from
        if (!excludeEntityTypes.isEmpty()) {
            conditions.add('breg_Entity_Type__c NOT IN :excludeEntityTypes');
        }

        conditions.add('breg_Entity_Status__c != \'New (Y)\''); // Exclude records with status 'New (Y)'
        conditions.add('breg_Entity_Status__c != null'); // Exclude records with null status



        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY Name ASC LIMIT ' + queryLimit;
        return Database.query(query);
    }

    private static Integer countAccounts(SearchInputsWrapper searchInputs) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));
        String status = searchInputs.status;
        String entityType = searchInputs.entityType;
        Boolean searchByNumber = searchInputs.searchByNumber;
        Set<String> excludeEntityTypes = getExcludeEntityTypes();

        String query = 'SELECT COUNT() FROM Account';
        List<String> conditions = new List<String>();
        conditions.add('RecordType.Name = \'BREG Account\'');

        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            List<String> parts = nameCondition.trim().split('\\s+');
            String escapedFilePart;
            String escapedSuffixPart;
            String fileOnlyPart;

            if (searchByNumber) {
                if (parts.size() == 2) {
                    escapedFilePart = parts[0] + '%';
                    escapedSuffixPart = parts[1];
                    conditions.add(
                        '((breg_File__c LIKE :escapedFilePart AND breg_File_Suffix__c LIKE :escapedSuffixPart) OR breg_Search_Name__c LIKE :nameCondition)'
                    );
                } else {
                    fileOnlyPart = parts[0];
                    conditions.add('((breg_File__c LIKE :fileOnlyPart OR breg_Search_Name__c LIKE :nameCondition))');
                }
            } else {
                conditions.add(
                    '(breg_Search_Name__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)'
                );
            }
        }

        if (String.isNotBlank(status) && !ALL_VALUE.equalsIgnoreCase(status)) {
            conditions.add('breg_Entity_Status__c = :status');
        } else {
            conditions.add('breg_Entity_Status__c != \'New (Y)\' AND breg_Entity_Status__c != null'); // Exclude records with status 'New (Y)' and null status
        }
        if (String.isNotBlank(entityType) && !ALL_VALUE.equalsIgnoreCase(entityType)) {
            conditions.add('breg_Business_Structure_Formula__c = :entityType');
        }
        if (!excludeEntityTypes.isEmpty()) {
            conditions.add('breg_Entity_Type__c NOT IN :excludeEntityTypes');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        return Database.countQuery(query);
    }

    private static Integer countTnTmSm(SearchInputsWrapper searchInputs) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));
        String recordType = searchInputs.recordType;
        String status = searchInputs.status;
        String entityType = searchInputs.entityType;

        String query = 'SELECT COUNT() FROM breg_TN_TM_SM__c';
        List<String> conditions = new List<String>();

        conditions.add('breg_End_Date__c = null');
        conditions.add(
            'Id IN (SELECT breg_TN_TM_SM__c ' +
            'FROM breg_Transaction__c ' +
            'WHERE breg_TN_TM_SM__c != null ' +
            'AND breg_Case__r.Status = \'Completed\')'
        );

        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            conditions.add('(breg_Search_Name__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)');
        }

        if (String.isNotBlank(recordType) && !ALL_VALUE.equalsIgnoreCase(recordType)) {
            conditions.add('breg_Type__c = :recordType');
        }

        if (searchInputs.isOnlyTnTmSmType) {
            String publicityType = 'Publicity Rights Name';
            conditions.add('breg_Type__c !=: publicityType');
        }

        if (String.isNotBlank(status) && !ALL_VALUE.equalsIgnoreCase(status)) {
            if (status.equalsIgnoreCase(ACTIVE_ENTITY_STATUS_VALUE)) {
                status = 'A';
            } else if (status.equalsIgnoreCase(EXPIRED_ENTITY_STATUS_VALUE)) {
                status = 'E';
            } else if (status.equalsIgnoreCase(CANCELED_ENTITY_STATUS_VALUE)) {
                status = 'C';
            } else if (status.equalsIgnoreCase(INV_REVOKED_ENTITY_STATUS_VALUE)) {
                status = 'R';
            } else {
                return 0;
            }

            if (String.isNotBlank(status)) {
                conditions.add('breg_Status__c = :status');
            }
        }

        if (String.isNotBlank(entityType) && !ALL_VALUE.equalsIgnoreCase(entityType)) {
            conditions.add('breg_Account__r.breg_Business_Structure_Formula__c = :entityType');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        return Database.countQuery(query);
    }

    private static Boolean matchesSearchPattern(String fieldValue, String searchType, String cleanedSearchInput) {
        if (String.isBlank(fieldValue) || String.isBlank(cleanedSearchInput)) return false;
        if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
            return fieldValue.startsWithIgnoreCase(cleanedSearchInput);
        } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
            return fieldValue.containsIgnoreCase(cleanedSearchInput);
        }
        return false;
    }

    private static Set<String> getExcludeEntityTypes() {
        Set<String> excludeEntityTypes = new Set<String>();
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        if (setting != null) {
            String excludeEntityTypesStr = setting.Exclude_Entity_Types_From_Search_And_Buy__c;
            if (String.isNotBlank(excludeEntityTypesStr)) {
                for (String entityType : excludeEntityTypesStr.split(',')) {
                    String trimmed = entityType.trim();
                    if (String.isNotBlank(trimmed)) {
                        excludeEntityTypes.add(trimmed);
                    }
                }
            }
        }
        return excludeEntityTypes;
    }

    @AuraEnabled(cacheable=true)
    public static List<SearchResultWrapper> getRecordForNotificationsByIds(List<Id> recordIds) {
        List<Id> tnIds = new List<Id>();
        List<Id> accountIds = new List<Id>();
        for (Id currentId : recordIds) {
            if (String.valueOf(currentId).startsWith('001')) {
                accountIds.add(currentId);
            } else {
                tnIds.add(currentId);
            }
        }
        List<SearchResultWrapper> results = new List<SearchResultWrapper>();
        results.addAll(convertAccountsToWrappers(getAccountByIds(accountIds), null));
        results.addAll(convertTnTmSmsToWrappers(getTnTmSmByIds(tnIds), null));

        return results;
    }

    @AuraEnabled(cacheable=true)
    public static breg_Certificate__c getCertificate(String authCodeOrDocumentId) {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        Integer validDays = (Integer) setting.Published_Document_Code_Valid_Days__c;
        Date validDate = Date.today().addDays(-validDays);
        Decimal documentId;
        try {
            documentId = Decimal.valueOf(authCodeOrDocumentId);
        } catch (Exception ex) {
            documentId = null;
        }

        String baseQuery = 'SELECT Id, breg_Document__c, breg_Document__r.Name, breg_Document__r.breg_Docusign_Document_Id__c, breg_Document__r.breg_Account__c, breg_Document__r.breg_Account__r.Name, breg_Published_Timestamp__c FROM breg_Certificate__c WHERE breg_Published_Timestamp__c > :validDate';
        if (documentId == null) {
            baseQuery += ' AND breg_Authentication_Code__c = :authCodeOrDocumentId';
        } else {
            baseQuery += ' AND (breg_Authentication_Code__c = :authCodeOrDocumentId OR breg_Legacy_Certificate_Number__c = :documentId)';
        }
        baseQuery += ' LIMIT 1';

        List<breg_Certificate__c> certificates = Database.query(baseQuery);
        if (certificates.isEmpty()) {
            return null;
        }
        return certificates[0];
    }

    private static List<breg_TN_TM_SM__c> getTnTmSmByIds(List<Id> recordIds) {
        return [
            SELECT
                Id,
                Name,
                breg_Trade_Name__c,
                breg_Type__c,
                CreatedDate,
                breg_Status__c,
                breg_Account__r.breg_File__c,
                breg_Account__r.breg_File_Suffix__c,
                breg_Expiration_Date__c,
                breg_Cert_Number__c
            FROM breg_TN_TM_SM__c
            WHERE Id IN :recordIds
        ];
    }

    private static List<Account> getAccountByIds(List<Id> recordIds) {
        return [
            SELECT
                Id,
                Name,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Entity_Status__c,
                breg_Business_Structure__c,
                breg_Entity_Type__c,
                CreatedDate,
                breg_BRIM_MASTER_NAME__c
            FROM Account
            WHERE Id IN :recordIds
        ];
    }
    private static List<breg_TN_TM_SM__c> queryTnTmSm(SearchInputsWrapper searchInputs, Integer queryLimit) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));
        String recordType = searchInputs.recordType;
        String status = searchInputs.status;
        String entityType = searchInputs.entityType;

        //base query
        String query = 'SELECT Id, Name, breg_Trade_Name__c, breg_Type__c, CreatedDate, breg_Status__c, breg_Account__r.breg_File__c, breg_Account__r.breg_File_Suffix__c, breg_Expiration_Date__c, breg_Cert_Number__c, breg_Search_Name__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c, breg_Xref_Name1__c, breg_Xref_Name2__c FROM breg_TN_TM_SM__c';

        //condition list initialization
        List<String> conditions = new List<String>();

        conditions.add('breg_End_Date__c = null');
        conditions.add(
            'Id IN (SELECT breg_TN_TM_SM__c ' +
            'FROM breg_Transaction__c ' +
            'WHERE breg_TN_TM_SM__c != null ' +
            'AND breg_Case__r.Status = \'Completed\')'
        );

        //name condition
        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }

            conditions.add('(breg_Search_Name__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)');
        }
        //record type condition
        if (String.isNotBlank(recordType) && !ALL_VALUE.equalsIgnoreCase(recordType)) {
            conditions.add('breg_Type__c = :recordType');
        }

        if (searchInputs.isOnlyTnTmSmType) {
            String publicityType = 'Publicity Rights Name';
            conditions.add('breg_Type__c !=: publicityType');
        }
        //status condition
        if (String.isNotBlank(status) && !ALL_VALUE.equalsIgnoreCase(status)) {
            if (status.equalsIgnoreCase(ACTIVE_ENTITY_STATUS_VALUE)) {
                status = 'A';
            } else if (status.equalsIgnoreCase(EXPIRED_ENTITY_STATUS_VALUE)) {
                status = 'E';
            } else if (status.equalsIgnoreCase(CANCELED_ENTITY_STATUS_VALUE)) {
                status = 'C';
            } else if (status.equalsIgnoreCase(INV_REVOKED_ENTITY_STATUS_VALUE)) {
                status = 'R';
            } else {
                return new List<breg_TN_TM_SM__c>();
                // status = '';
            }

            if (String.isNotBlank(status)) {
                conditions.add('breg_Status__c = :status');
            }
        }
        //entity type condition
        if (String.isNotBlank(entityType) && !ALL_VALUE.equalsIgnoreCase(entityType)) {
            conditions.add('breg_Account__r.breg_Business_Structure_Formula__c = :entityType');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY Name ASC LIMIT ' + queryLimit;
        return Database.query(query);
    }

    public static List<Case> queryCases(SearchInputsWrapper searchInputs, Integer queryLimit) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));

        String query =
            'SELECT Id, Subject, CaseNumber, breg_Workitem_Number__c, Status, CreatedDate,' +
            ' breg_Search_Name_NS__c, breg_TNTMSM_Description__c, breg_New_Entity_Name__c, breg_Name_of_the_Entity__c,' +
            ' breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c, breg_Xref_Name_1__c, breg_Xref_Name_2__c,' +
            ' breg_Form_Configuration__r.breg_Form_Code__c, breg_Form_Configuration__r.breg_Form_Name__c' +
            ' FROM Case';

        List<String> conditions = new List<String>();
        conditions.add('RecordType.Name = \'BREG Case\'');
        conditions.add('Status IN :CASE_SEARCH_STATUSES');
        conditions.add('breg_Form_Configuration__r.breg_Form_Code__c NOT IN :EXCLUDED_CASE_FORM_CODES');

        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            conditions.add('(breg_Search_Name_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)');
        }

        query += ' WHERE ' + String.join(conditions, ' AND ');
        query += ' ORDER BY breg_Search_Name_NS__c ASC LIMIT ' + queryLimit;
        return Database.query(query);
    }

    private static Integer countCases(SearchInputsWrapper searchInputs) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));

        String query = 'SELECT COUNT() FROM Case';

        List<String> conditions = new List<String>();

        conditions.add('Status IN :CASE_SEARCH_STATUSES');
        conditions.add('breg_Form_Configuration__r.breg_Form_Code__c NOT IN :EXCLUDED_CASE_FORM_CODES');

        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            conditions.add('(breg_Search_Name_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)');
        }

        query += ' WHERE ' + String.join(conditions, ' AND ');
        return Database.countQuery(query);
    }

    private static List<breg_Transaction_Business_Info__c> queryHistoricalBusinessInfo(SearchInputsWrapper searchInputs, Integer queryLimit) {
        String searchType = searchInputs.searchType;
        String searchInputValue = String.escapeSingleQuotes(BREGUtils.cleanBusinessName(searchInputs.searchInputValue));
        String status = searchInputs.status;
        String entityType = searchInputs.entityType;

        String query =
            'SELECT Id, breg_Entity__c, breg_Entity__r.breg_Entity_Status__c, breg_Entity__r.breg_Business_Structure__c, CreatedDate, ' +
            'breg_Master_Name__c, breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_File__c, breg_File_Suffix__c, ' +
            'breg_Search_Name_NS__c, breg_Search_Xref_Name_1_NS__c, breg_Search_Xref_Name_2_NS__c ' +
            'FROM breg_Transaction_Business_Info__c';

        List<String> conditions = new List<String>();
        conditions.add('breg_Entity__r.breg_Entity_Type__c != \'ZZ\'');
        conditions.add('breg_Entity__r.breg_Entity_Status__c != \'New (Y)\'');
        String nameCondition = '%%';
        if (String.isNotBlank(searchType) && String.isNotBlank(searchInputValue)) {
            if (searchType.equalsIgnoreCase(BEGINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = searchInputValue + '%';
            } else if (searchType.equalsIgnoreCase(CONTAINS_SEARCH_TYPE_OPTION_VALUE)) {
                nameCondition = '%' + searchInputValue + '%';
            }
            conditions.add(
                '(Name LIKE :nameCondition OR breg_Search_Name_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_1_NS__c LIKE :nameCondition OR breg_Search_Xref_Name_2_NS__c LIKE :nameCondition)'
            );
        }

        if (String.isNotBlank(status) && !ALL_VALUE.equalsIgnoreCase(status)) {
            conditions.add('breg_Entity__r.breg_Entity_Status__c = :status');
        }

        if (String.isNotBlank(entityType) && !ALL_VALUE.equalsIgnoreCase(entityType)) {
            conditions.add('breg_Entity__r.breg_Business_Structure_Formula__c = :entityType');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        Integer historicalQueryLimit = (queryLimit != null && queryLimit > 0)
            ? Math.min(queryLimit * 5, 2000)
            : DEFAULT_QUERY_LIMIT;
        query += ' ORDER BY breg_Search_Name_NS__c ASC LIMIT ' + historicalQueryLimit;

        List<breg_Transaction_Business_Info__c> queriedRecords = Database.query(query);
        Map<Id, breg_Transaction_Business_Info__c> uniqueByEntityId = new Map<Id, breg_Transaction_Business_Info__c>();

        for (breg_Transaction_Business_Info__c record : queriedRecords) {

            if (record.breg_Entity__c != null && !uniqueByEntityId.containsKey(record.breg_Entity__c)) {
                uniqueByEntityId.put(record.breg_Entity__c, record);
            }
        }

        List<breg_Transaction_Business_Info__c> uniqueRecords = uniqueByEntityId.values();

        if (queryLimit != null && queryLimit > 0 && uniqueRecords.size() > queryLimit) {
            List<breg_Transaction_Business_Info__c> limitedUniqueRecords = new List<breg_Transaction_Business_Info__c>();
            for (Integer i = 0; i < queryLimit; i++) {
                limitedUniqueRecords.add(uniqueRecords[i]);
            }
            uniqueRecords = limitedUniqueRecords;
        }

        return uniqueRecords;
    }

    // Convert Account records to SearchResultWrapper
    private static List<SearchResultWrapper> convertAccountsToWrappers(List<Account> accounts, SearchInputsWrapper searchInputs) {
        List<SearchResultWrapper> wrappers = new List<SearchResultWrapper>();

        // Pre-load picklist label map once before the loop for better performance
        Map<String, String> statusLabels = BREGUtils.getPicklistLabelMap('Account', 'breg_Entity_Status__c');

        String cleanedSearchInput = (searchInputs != null && String.isNotBlank(searchInputs.searchInputValue))
            ? BREGUtils.cleanBusinessName(searchInputs.searchInputValue)
            : null;
        Boolean hasSearchByNameContext = cleanedSearchInput != null && String.isNotBlank(searchInputs.searchType) && !searchInputs.searchByNumber;

        for (Account acc : accounts) {
            String statusLabel = statusLabels.get(acc.breg_Entity_Status__c);
            String resolvedStatus = statusLabel != null ? statusLabel : acc.breg_Entity_Status__c;
            String fileNumber = getFileNumber(acc.breg_File__c, acc.breg_File_Suffix__c);
            String primaryRecordType = acc.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
                ? RESERVATION_VALUE
                : ENTITY_VALUE;

            Boolean xref1Matches = hasSearchByNameContext && matchesSearchPattern(acc.breg_Search_Xref_Name_1_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean xref2Matches = hasSearchByNameContext && matchesSearchPattern(acc.breg_Search_Xref_Name_2_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean searchNameMatches = !hasSearchByNameContext
                || matchesSearchPattern(acc.breg_Search_Name__c, searchInputs.searchType, cleanedSearchInput);

            // When no search context (e.g. lookup by Id), always emit the primary wrapper
            if (!hasSearchByNameContext || searchNameMatches) {
                SearchResultWrapper wrapper = new SearchResultWrapper();
                wrapper.recordId = acc.Id;
                wrapper.businessName = acc.Name;
                wrapper.recordType = primaryRecordType;
                wrapper.fileNumber = fileNumber;
                wrapper.status = resolvedStatus;
                wrapper.sourceObject = 'Account';
                wrapper.createdDate = acc.CreatedDate;
                wrapper.type = acc.breg_Business_Structure__c;
                wrappers.add(wrapper);
            }

            if (xref1Matches) {
                SearchResultWrapper xref1Wrapper = new SearchResultWrapper();
                xref1Wrapper.recordId = acc.Id;
                xref1Wrapper.businessName = acc.breg_Xref_Name_1__c;
                xref1Wrapper.recordType = CROSS_REFERENCE_1_VALUE;
                xref1Wrapper.fileNumber = fileNumber;
                xref1Wrapper.status = resolvedStatus;
                xref1Wrapper.sourceObject = 'Account';
                xref1Wrapper.createdDate = acc.CreatedDate;
                xref1Wrapper.type = acc.breg_Business_Structure__c;
                wrappers.add(xref1Wrapper);
            }

            if (xref2Matches) {
                SearchResultWrapper xref2Wrapper = new SearchResultWrapper();
                xref2Wrapper.recordId = acc.Id;
                xref2Wrapper.businessName = acc.breg_Xref_Name_2__c;
                xref2Wrapper.recordType = CROSS_REFERENCE_2_VALUE;
                xref2Wrapper.fileNumber = fileNumber;
                xref2Wrapper.status = resolvedStatus;
                xref2Wrapper.sourceObject = 'Account';
                xref2Wrapper.createdDate = acc.CreatedDate;
                xref2Wrapper.type = acc.breg_Business_Structure__c;
                wrappers.add(xref2Wrapper);
            }
        }

        return wrappers;
    }

    // Convert breg_TN_TM_SM__c records to SearchResultWrapper
    private static List<SearchResultWrapper> convertTnTmSmsToWrappers(List<breg_TN_TM_SM__c> tnTmSms, SearchInputsWrapper searchInputs) {
        List<SearchResultWrapper> wrappers = new List<SearchResultWrapper>();

        // Pre-load picklist label map once before the loop for better performance
        Map<String, String> statusLabels = BREGUtils.getPicklistLabelMap('breg_TN_TM_SM__c', 'breg_Status__c');

        String cleanedSearchInput = (searchInputs != null && String.isNotBlank(searchInputs.searchInputValue))
            ? BREGUtils.cleanBusinessName(searchInputs.searchInputValue)
            : null;
        Boolean hasSearchByNameContext = cleanedSearchInput != null && searchInputs != null &&
            String.isNotBlank(searchInputs.searchType) && searchInputs.searchByNumber != true;

        for (breg_TN_TM_SM__c tnTmSm : tnTmSms) {
            String fileNumber = getFileNumber(tnTmSm.breg_Account__r?.breg_File__c, tnTmSm.breg_Account__r?.breg_File_Suffix__c);
            String statusLabel = statusLabels.get(tnTmSm.breg_Status__c);
            String resolvedStatus = statusLabel != null ? statusLabel : tnTmSm.breg_Status__c;

            Boolean xref1Matches = hasSearchByNameContext && matchesSearchPattern(tnTmSm.breg_Search_Xref_Name_1_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean xref2Matches = hasSearchByNameContext && matchesSearchPattern(tnTmSm.breg_Search_Xref_Name_2_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean searchNameMatches = !hasSearchByNameContext || matchesSearchPattern(tnTmSm.breg_Search_Name__c, searchInputs.searchType, cleanedSearchInput);

            if (!hasSearchByNameContext || searchNameMatches) {
                SearchResultWrapper wrapper = new SearchResultWrapper();
                wrapper.recordId = tnTmSm.Id;
                wrapper.businessName = tnTmSm.breg_Trade_Name__c != null ? tnTmSm.breg_Trade_Name__c : tnTmSm.Name;
                wrapper.recordType = tnTmSm.breg_Type__c != null ? tnTmSm.breg_Type__c : '';
                wrapper.fileNumber = fileNumber;
                wrapper.status = resolvedStatus;
                wrapper.sourceObject = 'breg_TN_TM_SM__c';
                wrapper.createdDate = tnTmSm.CreatedDate;
                wrapper.type = tnTmSm.breg_Type__c;
                wrapper.expirationDate = tnTmSm.breg_Expiration_Date__c;
                wrapper.certificationNumber = tnTmSm.breg_Cert_Number__c;
                wrappers.add(wrapper);
            }

            if (xref1Matches) {
                SearchResultWrapper xref1Wrapper = new SearchResultWrapper();
                xref1Wrapper.recordId = tnTmSm.Id;
                xref1Wrapper.businessName = tnTmSm.breg_Xref_Name1__c;
                xref1Wrapper.recordType = (tnTmSm.breg_Type__c != null ? tnTmSm.breg_Type__c : '') + ' ' + REFERENCE_1_VALUE;
                xref1Wrapper.fileNumber = fileNumber;
                xref1Wrapper.status = resolvedStatus;
                xref1Wrapper.sourceObject = 'breg_TN_TM_SM__c';
                xref1Wrapper.createdDate = tnTmSm.CreatedDate;
                xref1Wrapper.type = tnTmSm.breg_Type__c;
                xref1Wrapper.expirationDate = tnTmSm.breg_Expiration_Date__c;
                xref1Wrapper.certificationNumber = tnTmSm.breg_Cert_Number__c;
                wrappers.add(xref1Wrapper);
            }

            if (xref2Matches) {
                SearchResultWrapper xref2Wrapper = new SearchResultWrapper();
                xref2Wrapper.recordId = tnTmSm.Id;
                xref2Wrapper.businessName = tnTmSm.breg_Xref_Name2__c;
                xref2Wrapper.recordType = (tnTmSm.breg_Type__c != null ? tnTmSm.breg_Type__c : '') + ' ' + REFERENCE_2_VALUE;
                xref2Wrapper.fileNumber = fileNumber;
                xref2Wrapper.status = resolvedStatus;
                xref2Wrapper.sourceObject = 'breg_TN_TM_SM__c';
                xref2Wrapper.createdDate = tnTmSm.CreatedDate;
                xref2Wrapper.type = tnTmSm.breg_Type__c;
                xref2Wrapper.expirationDate = tnTmSm.breg_Expiration_Date__c;
                xref2Wrapper.certificationNumber = tnTmSm.breg_Cert_Number__c;
                wrappers.add(xref2Wrapper);
            }
        }

        return wrappers;
    }

    private static String getCasePortalDisplayStatus(String caseStatus) {
        return caseStatus == FILING_CASE_STATUS_VALUE ? APPROVED_CASE_STATUS_VALUE : caseStatus;
    }

    private static List<SearchResultWrapper> convertCasesToWrappers(List<Case> cases, SearchInputsWrapper searchInputs) {
        List<SearchResultWrapper> wrappers = new List<SearchResultWrapper>();

        String cleanedSearchInput = (searchInputs != null && String.isNotBlank(searchInputs.searchInputValue))
            ? BREGUtils.cleanBusinessName(searchInputs.searchInputValue)
            : null;
        Boolean hasSearchByNameContext = cleanedSearchInput != null && searchInputs != null &&
            String.isNotBlank(searchInputs.searchType) && searchInputs.searchByNumber != true;

        for (Case c : cases) {
            String fileNumber = String.isNotBlank(c.breg_Workitem_Number__c) ? c.breg_Workitem_Number__c : c.CaseNumber;
            String displayName = String.isNotBlank(c.breg_TNTMSM_Description__c)
                ? c.breg_TNTMSM_Description__c
                : (String.isNotBlank(c.breg_New_Entity_Name__c)
                    ? c.breg_New_Entity_Name__c
                    : (String.isNotBlank(c.breg_Name_of_the_Entity__c)
                        ? c.breg_Name_of_the_Entity__c
                        : c.Subject));

            Boolean xref1Matches = hasSearchByNameContext && matchesSearchPattern(c.breg_Search_Xref_Name_1_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean xref2Matches = hasSearchByNameContext && matchesSearchPattern(c.breg_Search_Xref_Name_2_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean searchNameMatches = !hasSearchByNameContext || matchesSearchPattern(c.breg_Search_Name_NS__c, searchInputs.searchType, cleanedSearchInput);

            if (!hasSearchByNameContext || searchNameMatches) {
                SearchResultWrapper wrapper = new SearchResultWrapper();
                wrapper.recordId = c.Id;
                wrapper.businessName = displayName;
                wrapper.recordType = PENDING_FILING_VALUE;
                wrapper.fileNumber = fileNumber;
                wrapper.status = getCasePortalDisplayStatus(c.Status);
                wrapper.sourceObject = 'Case';
                wrapper.createdDate = c.CreatedDate;
                wrapper.type = c.breg_Form_Configuration__r?.breg_Form_Name__c;
                wrappers.add(wrapper);
            }

            if (xref1Matches) {
                SearchResultWrapper xref1Wrapper = new SearchResultWrapper();
                xref1Wrapper.recordId = c.Id;
                xref1Wrapper.businessName = c.breg_Xref_Name_1__c;
                xref1Wrapper.recordType = PENDING_FILING_VALUE + ' ' + REFERENCE_1_VALUE ;
                xref1Wrapper.fileNumber = fileNumber;
                xref1Wrapper.status = getCasePortalDisplayStatus(c.Status);
                xref1Wrapper.sourceObject = 'Case';
                xref1Wrapper.createdDate = c.CreatedDate;
                xref1Wrapper.type = c.breg_Form_Configuration__r?.breg_Form_Name__c;
                wrappers.add(xref1Wrapper);
            }

            if (xref2Matches) {
                SearchResultWrapper xref2Wrapper = new SearchResultWrapper();
                xref2Wrapper.recordId = c.Id;
                xref2Wrapper.businessName = c.breg_Xref_Name_2__c ;
                xref2Wrapper.recordType = PENDING_FILING_VALUE + ' ' + REFERENCE_2_VALUE;
                xref2Wrapper.fileNumber = fileNumber;
                xref2Wrapper.status = getCasePortalDisplayStatus(c.Status);
                xref2Wrapper.sourceObject = 'Case';
                xref2Wrapper.createdDate = c.CreatedDate;
                xref2Wrapper.type = c.breg_Form_Configuration__r?.breg_Form_Name__c;
                wrappers.add(xref2Wrapper);
            }
        }
        return wrappers;
    }

    private static List<SearchResultWrapper> convertHistoricalBusinessInfoToWrappers(
        List<breg_Transaction_Business_Info__c> historicalRecords,
        SearchInputsWrapper searchInputs
    ) {
        List<SearchResultWrapper> wrappers = new List<SearchResultWrapper>();

        Map<String, String> statusLabels = BREGUtils.getPicklistLabelMap('Account', 'breg_Entity_Status__c');

        String cleanedSearchInput = (searchInputs != null && String.isNotBlank(searchInputs.searchInputValue))
            ? BREGUtils.cleanBusinessName(searchInputs.searchInputValue)
            : null;
        Boolean hasSearchByNameContext = cleanedSearchInput != null && searchInputs != null &&
            String.isNotBlank(searchInputs.searchType) && searchInputs.searchByNumber != true;

        for (breg_Transaction_Business_Info__c record : historicalRecords) {
            String statusLabel = statusLabels.get(record.breg_Entity__r?.breg_Entity_Status__c);
            String resolvedStatus = statusLabel != null ? statusLabel : record.breg_Entity__r?.breg_Entity_Status__c;
            String fileNumber = getFileNumber(record.breg_File__c, record.breg_File_Suffix__c);
            Id targetRecordId = record.breg_Entity__c != null ? record.breg_Entity__c : record.Id;

            Boolean xref1Matches = hasSearchByNameContext &&
                matchesSearchPattern(record.breg_Search_Xref_Name_1_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean xref2Matches = hasSearchByNameContext &&
                matchesSearchPattern(record.breg_Search_Xref_Name_2_NS__c, searchInputs.searchType, cleanedSearchInput);
            Boolean searchNameMatches = !hasSearchByNameContext ||
                matchesSearchPattern(record.breg_Search_Name_NS__c, searchInputs.searchType, cleanedSearchInput);

            if (!hasSearchByNameContext || searchNameMatches) {
                SearchResultWrapper wrapper = new SearchResultWrapper();
                wrapper.recordId = targetRecordId;
                wrapper.businessName = record.breg_Master_Name__c;
                wrapper.recordType = ENTITY_VALUE;
                wrapper.fileNumber = fileNumber;
                wrapper.status = resolvedStatus;
                wrapper.sourceObject = ENTITY_HISTORY_SOURCE_OBJECT_VALUE;
                wrapper.createdDate = record.CreatedDate;
                wrapper.type = record.breg_Entity__r?.breg_Business_Structure__c;
                wrappers.add(wrapper);
            }

            if (xref1Matches) {
                SearchResultWrapper xref1Wrapper = new SearchResultWrapper();
                xref1Wrapper.recordId = targetRecordId;
                xref1Wrapper.businessName = record.breg_Xref_Name_1__c;
                xref1Wrapper.recordType = CROSS_REFERENCE_1_VALUE;
                xref1Wrapper.fileNumber = fileNumber;
                xref1Wrapper.status = resolvedStatus;
                xref1Wrapper.sourceObject = ENTITY_HISTORY_SOURCE_OBJECT_VALUE;
                xref1Wrapper.createdDate = record.CreatedDate;
                xref1Wrapper.type = record.breg_Entity__r?.breg_Business_Structure__c;
                wrappers.add(xref1Wrapper);
            }

            if (xref2Matches) {
                SearchResultWrapper xref2Wrapper = new SearchResultWrapper();
                xref2Wrapper.recordId = targetRecordId;
                xref2Wrapper.businessName = record.breg_Xref_Name_2__c;
                xref2Wrapper.recordType = CROSS_REFERENCE_2_VALUE;
                xref2Wrapper.fileNumber = fileNumber;
                xref2Wrapper.status = resolvedStatus;
                xref2Wrapper.sourceObject = ENTITY_HISTORY_SOURCE_OBJECT_VALUE;
                xref2Wrapper.createdDate = record.CreatedDate;
                xref2Wrapper.type = record.breg_Entity__r?.breg_Business_Structure__c;
                wrappers.add(xref2Wrapper);
            }
        }

        return wrappers;
    }

    private static String getFileNumber(String fileNumber, String fileSuffix) {
        String result = '';
        if (String.isNotBlank(fileNumber)) {
            result = fileNumber;
        } else if (String.isNotBlank(fileSuffix)) {
            result = fileSuffix;
        }
        return result;
    }

    //if includeTnTmSm is true, and recordType is all, trade name, trademark, or service mark, return true
    private static Boolean isIncludeTnTmSm(Boolean includeTnTmSm, String recordType, String status) {
        includeTnTmSm = includeTnTmSm != null ? includeTnTmSm : false;
        return includeTnTmSm &&
            (recordType.equalsIgnoreCase(ALL_VALUE) ||
            recordType.equalsIgnoreCase(TRADE_NAME_VALUE) ||
            recordType.equalsIgnoreCase(TRADEMARK_VALUE) ||
            recordType.equalsIgnoreCase(SERVICE_MARK_VALUE) ||
            recordType.equalsIgnoreCase(PUBLICITY_RIGHTS_NAME_VALUE));
    }

    //if recordType is all, entity, or reservation, return true
    private static Boolean isIncludeAccount(String recordType) {
        return recordType.equalsIgnoreCase(ALL_VALUE) || recordType.equalsIgnoreCase(ENTITY_VALUE);
    }

    private static Boolean isIncludeTransaction(Boolean includeTransactions, String recordType) {
        includeTransactions = includeTransactions != null ? includeTransactions : false;
        return includeTransactions && (recordType.equalsIgnoreCase(ALL_VALUE) || recordType.equalsIgnoreCase(PENDING_FILING_VALUE));
    }

    private static Boolean isIncludeCases(Boolean includeCases, String recordType) {
        includeCases = includeCases != null ? includeCases : false;
        return includeCases && (recordType.equalsIgnoreCase(ALL_VALUE) || recordType.equalsIgnoreCase(PENDING_FILING_VALUE));
    }

    public class SearchResultWrapper {
        @AuraEnabled
        public String recordId { get; set; }
        @AuraEnabled
        public String businessName { get; set; }
        @AuraEnabled
        public String recordType { get; set; }
        @AuraEnabled
        public String fileNumber { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String sourceObject { get; set; }
        @AuraEnabled
        public DateTime createdDate { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public DateTime expirationDate { get; set; }
        @AuraEnabled
        public String certificationNumber { get; set; }
        @AuraEnabled
        public Boolean notificationsAvailable { get; set; }
        @AuraEnabled
        public Integer totalAccountResults { get; set; }
        @AuraEnabled
        public Integer totalTnTmSmResults { get; set; }
        @AuraEnabled
        public Integer totalTransactionResults { get; set; }
        @AuraEnabled
        public Integer totalCaseResults { get; set; }
        @AuraEnabled
        public Integer totalResults { get; set; }
    }

    // Comparator class to sort SearchResultWrapper by businessName in ascending order
    public class SearchResultWrapperComparator implements Comparator<SearchResultWrapper> {
        public Integer compare(SearchResultWrapper a, SearchResultWrapper b) {
            String nameA = a.businessName != null ? a.businessName : '';
            String nameB = b.businessName != null ? b.businessName : '';
            return nameA.compareTo(nameB);
        }
    }

    public class SearchInputsWrapper {
        //possible values: begins, contains
        @AuraEnabled
        public String searchType { get; set; }
        @AuraEnabled
        public String searchInputValue { get; set; }
        @AuraEnabled
        public String recordType { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String entityType { get; set; }
        @AuraEnabled
        public Boolean searchByNumber { get; set; }
        @AuraEnabled
        public Boolean includeTnTmSm { get; set; }
        @AuraEnabled
        public Boolean includeTransactions { get; set; }
        @AuraEnabled
        public Integer queryLimit { get; set; }
        @AuraEnabled
        public Boolean includeNotifications { get; set; }
        @AuraEnabled
        public Boolean excludeAccounts { get; set; }
        @AuraEnabled
        public Boolean isOnlyTnTmSmType { get; set; }
        @AuraEnabled
        public String notificationCategory { get; set; }
        @AuraEnabled
        public Boolean includeCases { get; set; }
    }
}