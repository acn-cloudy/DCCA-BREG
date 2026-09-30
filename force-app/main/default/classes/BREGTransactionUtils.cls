public with sharing class BREGTransactionUtils {
    public static Date getOrgDateByUserTimezone() {
        Datetime nowUtc = System.now();
        TimeZone tz = UserInfo.getTimeZone();
        Integer offset = tz.getOffset(nowUtc) / 1000;
        Datetime orgNow = nowUtc.addSeconds(offset);
        return orgNow.date();
    }

    public static breg_Transaction__c buildBaseTransactionForAccount(Account acc, String transactionCode, Date effectiveDate, Date receivedDate, String status) {
        return new breg_Transaction__c(
            breg_Account__c = acc.Id,
            breg_Business_Name__c = getOptionalString(acc, Account.Name),
            breg_File_Suffix__c = getOptionalString(acc, Account.breg_File_Suffix__c),
            breg_Transaction_Code__c = transactionCode,
            breg_Effective_Date__c = effectiveDate,
            breg_Received_Date__c = receivedDate,
            breg_Status__c = status,
            breg_Description__c = getTransactionCodeLabel(transactionCode),
            breg_Remarks__c = transactionCode == 'NC' ? 'FROM: ' + acc.Name : getTransactionCodeLabel(transactionCode)
        );
    }

    public static breg_Transaction__c buildBaseTransactionForRecord(Case c, Id relatedRecordId, String transactionCode, String status) {

        breg_Transaction__c transactionRecord = new breg_Transaction__c(
            breg_Effective_Date__c = c.breg_Effective_Date__c,
            breg_Received_Date__c = c.breg_Received_Date_Formula__c,
            breg_Status__c = status,
            breg_Case__c = c.Id,
            breg_File_Suffix__c = c.breg_File_Suffix__c,
            breg_Form_Code__c = c.breg_Form_Code__c,
            breg_Form_Configuration__c = getOptionalId(c, Case.breg_Form_Configuration__c),
            breg_Business_Name__c = getOptionalString(c, Case.breg_Name_of_the_Entity__c),
            breg_Transaction_Code__c = transactionCode,
            breg_Description__c = getTransactionCodeLabel(transactionCode),
            breg_Remarks__c = transactionCode == 'NC' ? 'FROM: ' + c.breg_Name_of_the_Entity__c : getTransactionCodeLabel(transactionCode)
        );

        if (relatedRecordId == null) {
            return transactionRecord;
        }
        String objectType = getObjectTypeById(relatedRecordId);
        if (objectType == 'Account') {
            transactionRecord.breg_Account__c = relatedRecordId;
        } else if (objectType == 'breg_TN_TM_SM__c') {
            transactionRecord.breg_TN_TM_SM__c = relatedRecordId;
        }

        return transactionRecord;
    }

    public static List<breg_Transaction__c> upsertTransactionRecords(
        Map<Id, Case> casesMap,
        Map<Id, Id> caseToRecordMap,
        String transactionCode,
        String status
    ) {
        List<breg_Transaction__c> transaction_records = new List<breg_Transaction__c>();
        Date orgDate = getOrgDateByUserTimezone();

        Set<Id> relatedRecordIds = new Set<Id>();
        for (Id relatedRecordId : caseToRecordMap.values()) {
            if (relatedRecordId != null) {
                relatedRecordIds.add(relatedRecordId);
            }
        }

        Set<String> transactionCodesToSearch = new Set<String>();
        if (transactionCode != null) {
            transactionCodesToSearch.add(transactionCode);
        } else {
            for (Id caseId : casesMap.keySet()) {
                Case c = casesMap.get(caseId);
                String derivedCode = getOptionalString(c, Case.breg_Transaction_Code__c);
                if (String.isBlank(derivedCode)) {
                    derivedCode = getRelatedTransactionCode(c);
                }
                if (derivedCode != null) {
                    transactionCodesToSearch.add(derivedCode);
                }
            }
        }

        List<breg_Transaction__c> existingTransactions = BREGTransactionUtilsWithoutSharing.getExistingTransactions(
            casesMap.keySet(),
            relatedRecordIds,
            transactionCodesToSearch
        );

        Map<Id, breg_Transaction__c> existingTransactionMap = new Map<Id, breg_Transaction__c>();
        for (breg_Transaction__c existingTransaction : existingTransactions) {
            existingTransactionMap.put(existingTransaction.breg_Case__c, existingTransaction);
        }

        for (Id caseId : casesMap.keySet()) {
            Case c = casesMap.get(caseId);
            breg_Transaction__c transactionRecord = existingTransactionMap.get(caseId) != null
                ? existingTransactionMap.get(caseId)
                : new breg_Transaction__c();

            transactionRecord.breg_Case__c = c.Id;
            transactionRecord.breg_Form_Code__c = getOptionalString(c, Case.breg_Form_Code__c);
            Id relatedRecordId = caseToRecordMap.get(caseId);
            if (relatedRecordId != null ) {
                String objectType = getObjectTypeById(relatedRecordId);
                if (objectType == 'Account') {
                    transactionRecord.breg_Account__c = relatedRecordId;
                    if(c.breg_TN_TM_SM__c != null) {
                        transactionRecord.breg_TN_TM_SM__c = c.breg_TN_TM_SM__c;
                    }
                } else if (objectType == 'breg_TN_TM_SM__c') {
                    transactionRecord.breg_TN_TM_SM__c = relatedRecordId;
                }
            }
            transactionRecord.breg_Start_Date__c = c.breg_Effective_Date__c;
            transactionRecord.breg_Business_Name__c = getOptionalString(c, Case.breg_Name_of_the_Entity__c);
            String transCode = transactionCode != null
                ? transactionCode
                : getCaseTransactionCode(c);
            transactionRecord.breg_Transaction_Code__c = transCode;
            transactionRecord.breg_Form_Configuration__c = getOptionalId(c, Case.breg_Form_Configuration__c);
            transactionRecord.breg_Case__c = caseId;
            transactionRecord.breg_Date__c = orgDate;
            transactionRecord.breg_Effective_Date__c = c.breg_Effective_Date__c;
            transactionRecord.breg_Received_Date__c = c.breg_Received_Date_Formula__c;
            transactionRecord.breg_Status__c = status;
            transactionRecord.breg_Description__c = getTransactionCodeLabel(transCode);
            transactionRecord.breg_Remarks__c = transCode == 'NC' ? 'FROM: ' + c.breg_Name_of_the_Entity__c : getTransactionCodeLabel(transCode);
            transaction_records.add(transactionRecord);
        }

        return transaction_records;
    }

    // Overload: transaction code is derived from the Case record
    public static List<breg_Transaction__c> upsertTransactionRecords(Map<Id, Case> casesMap, Map<Id, Id> caseToRecordMap, String status) {
        return upsertTransactionRecords(casesMap, caseToRecordMap, null, status);
    }

    private static Id getOptionalId(SObject record, SObjectField fieldToken) {
        try {
            Object value = record.get(fieldToken);
            return value == null ? null : (Id)value;
        } catch (Exception e) {
            return null;
        }
    }

    private static String getCaseTransactionCode(Case c) {
        if (c == null) {
            return null;
        }

        String directCode = getOptionalString(c, Case.breg_Transaction_Code__c);
        if (String.isNotBlank(directCode)) {
            return directCode;
        }

        return getRelatedTransactionCode(c);
    }

    private static String getRelatedTransactionCode(Case c) {
        try {
            return c.breg_Form_Configuration__r?.breg_Transaction_Code__c;
        } catch (Exception e) {
            return null;
        }
    }

    private static List<breg_Transaction__c> getTransactionsForUpdate(Map<Id, Case> casesMap, String status){
            List<breg_Transaction__c> transactionsToUpdate = new List<breg_Transaction__c>();
        if (casesMap != null && !casesMap.isEmpty() && !String.isBlank(status)) {
            List<breg_Transaction__c> existingTransactions;
            
            existingTransactions = [
                SELECT Id, breg_Status__c, breg_Case__c, breg_Account__c
                FROM breg_Transaction__c
                WHERE breg_Case__c IN :casesMap.keySet()
            ];
            

            for (breg_Transaction__c transactionRecord : existingTransactions) {
                Case relatedCase = casesMap.get(transactionRecord.breg_Case__c);
                if (relatedCase == null) {
                    continue;
                }
                
                Id accountIdToSet;

                if (relatedCase.breg_Entity__c != null) {
                    accountIdToSet = relatedCase.breg_Entity__c;
                } else if ( relatedCase.breg_Name_Reservation__c != null) {
                    accountIdToSet = relatedCase.breg_Name_Reservation__c;
                }

                if (accountIdToSet != null && relatedCase.breg_Form_Code__c != 'X-12' ) {
                    transactionRecord.breg_Account__c = accountIdToSet;
                }
                if (relatedCase.breg_TN_TM_SM__c != null && new List<string>{'T-1', 'T-2', 'T-3', 'T-4', 'T-7'}.contains(relatedCase.breg_Form_Code__c)) {
                    transactionRecord.breg_TN_TM_SM__c = relatedCase.breg_TN_TM_SM__c;
                }
                transactionRecord.breg_Status__c = status;
                transactionsToUpdate.add(transactionRecord);
            }

            return transactionsToUpdate;
        }

        return transactionsToUpdate;

    }

    public static void updateTransactionStatusByCases(
        Map<Id, Case> casesMap,
        String status
    ) {
       List<breg_Transaction__c> transactionsToUpdate = getTransactionsForUpdate(casesMap, status);
       if (!transactionsToUpdate.isEmpty()) {
           BREGSObjectUpdaterWithoutSharing.upsertRecords(transactionsToUpdate);
       }
    }


    public static void createTransactionsForEntities(Map<Id, Case> casesMap, String status, String transactionCode) {
        if (transactionCode == null) {
            createTransactionsForEntities(casesMap, status);
        } else {
            Map<Id, Id> caseToEntityMap = buildCaseToEntityMap(casesMap);
            List<breg_Transaction__c> transactions = upsertTransactionRecords(casesMap, caseToEntityMap, transactionCode, status);
            if (!transactions.isEmpty()) {
                BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
            }
        }
        
    }

    public static void createTransactionsForEntities(Map<Id, Case> casesMap, String status) {
        Map<Id, Id> caseToEntityMap = buildCaseToEntityMap(casesMap);
        if (status != 'R') {
            List<breg_Transaction__c> transactionsToUpdate = getTransactionsForUpdate(casesMap, status);
            if (!transactionsToUpdate.isEmpty()) {
                BREGSObjectUpdaterWithoutSharing.upsertRecords(transactionsToUpdate);
                return;
            }
        }

        List<breg_Transaction__c> transactions = upsertTransactionRecords(casesMap, caseToEntityMap, status);
        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    private static Map<Id, Id> buildCaseToEntityMap(Map<Id, Case> casesMap) {
        Map<Id, Id> caseToEntityMap = new Map<Id, Id>();
        if (casesMap == null) {
            return caseToEntityMap;
        }

        for (Case c : casesMap.values()) {
            if (c != null && c.breg_Entity__c != null) {
                caseToEntityMap.put(c.Id, c.breg_Entity__c);
            }
        }

        return caseToEntityMap;
    }
    public static void createTransactionsForEntityChildAccounts(Map<Id, Case> casesMap, String status) {
        createTransactionsForEntityChildAccounts(casesMap, status, null);
    }

    public static void createTransactionsForEntityChildAccounts(Map<Id, Case> casesMap, String status, String transactionCode) {
        if (casesMap == null || casesMap.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>(casesMap.keySet());
        Map<Id, Case> freshCases = new Map<Id, Case>([
            SELECT Id, breg_Entity__c, breg_Form_Code__c, breg_Effective_Date__c, breg_Name_of_the_Entity__c,
                   breg_Form_Configuration__c, breg_Transaction_Code__c,
                   breg_Form_Configuration__r.breg_Transaction_Code__c, breg_Received_Date_Formula__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        if (freshCases.isEmpty()) {
            return;
        }

        Map<Id, List<Id>> entityToCaseIds = new Map<Id, List<Id>>();
        for (Case c : freshCases.values()) {
            if (c != null && c.breg_Entity__c != null) {
                if (!entityToCaseIds.containsKey(c.breg_Entity__c)) {
                    entityToCaseIds.put(c.breg_Entity__c, new List<Id>());
                }
                entityToCaseIds.get(c.breg_Entity__c).add(c.Id);
            }
        }
        if (entityToCaseIds.isEmpty()) {
            return;
        }

        List<Account> childAccounts = [
            SELECT Id, ParentId
            FROM Account
            WHERE ParentId IN :entityToCaseIds.keySet()
        ];
        if (childAccounts.isEmpty()) {
            return;
        }

        Map<Id, List<Id>> caseToChildAccountIds = new Map<Id, List<Id>>();
        for (Account child : childAccounts) {
            List<Id> caseIdsForParent = entityToCaseIds.get(child.ParentId);
            if (caseIdsForParent == null || caseIdsForParent.isEmpty()) {
                continue;
            }
            for (Id caseId : caseIdsForParent) {
                if (!caseToChildAccountIds.containsKey(caseId)) {
                    caseToChildAccountIds.put(caseId, new List<Id>());
                }
                caseToChildAccountIds.get(caseId).add(child.Id);
            }
        }
        if (caseToChildAccountIds.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> transactions = upsertTransactionRecordsForChilds(
            freshCases,
            caseToChildAccountIds,
            status,
            transactionCode
        );
        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    public static void createTransactionsForTNTMSM(Map<Id, Case> casesMap, String status) {
        Map<Id, Id> caseToTNTMSMMap = new Map<Id, Id>();
        for (Case c : casesMap.values()) {
            caseToTNTMSMMap.put(c.Id, c.breg_TN_TM_SM__c);
        }
        List<breg_Transaction__c> transactions = upsertTransactionRecords(casesMap, caseToTNTMSMMap, status);
        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    public static List<breg_Transaction__c> upsertTransactionRecordsForChilds(
        Map<Id, Case> casesMap,
        Map<Id, List<Id>> caseToRecordMap,
        String status,
        String transactionCode
    ) {
        List<breg_Transaction__c> transaction_records = new List<breg_Transaction__c>();
        Date orgDate = getOrgDateByUserTimezone();

        List<Id> allRelatedRecordIds = new List<Id>();
        for (Id caseId : caseToRecordMap.keySet()) {
            allRelatedRecordIds.addAll(caseToRecordMap.get(caseId));
        }

        Set<String> transactionCodes = new Set<String>();
        if (String.isNotBlank(transactionCode)) {
            transactionCodes.add(transactionCode);
        } else {
            for (Id caseId : caseToRecordMap.keySet()) {
                Case c = casesMap.get(caseId);
                String transactionCodeToSearch = c.breg_Transaction_Code__c != null
                    ? c.breg_Transaction_Code__c
                    : c.breg_Form_Configuration__r?.breg_Transaction_Code__c;
                if (transactionCodeToSearch != null) {
                    transactionCodes.add(transactionCodeToSearch);
                }
            }
        }

        List<breg_Transaction__c> existingTransactions = [
            SELECT Id, breg_Case__c, breg_TN_TM_SM__c, breg_Account__c
            FROM breg_Transaction__c
            WHERE
                breg_Case__c IN :caseToRecordMap.keySet()
                AND breg_Transaction_Code__c IN :transactionCodes
                AND breg_Status__c = :status
                AND (breg_Account__c IN :allRelatedRecordIds
                OR breg_TN_TM_SM__c IN :allRelatedRecordIds)
            ORDER BY CreatedDate DESC
        ];

        Map<Id, breg_Transaction__c> existingTransactionMap = new Map<Id, breg_Transaction__c>();
        for (breg_Transaction__c existingTransaction : existingTransactions) {
            existingTransactionMap.put(existingTransaction.breg_TN_TM_SM__c ?? existingTransaction.breg_Account__c, existingTransaction);
        }

        for (Id caseId : caseToRecordMap.keySet()) {
            Case c = casesMap.get(caseId);
            List<Id> relatedRecordIds = caseToRecordMap.get(caseId);
            for (Id relatedRecordId : relatedRecordIds) {
                breg_Transaction__c transactionRecord = existingTransactionMap.get(relatedRecordId) != null
                    ? existingTransactionMap.get(relatedRecordId)
                    : new breg_Transaction__c();
                transactionRecord.breg_Case__c = c.Id;
                transactionRecord.breg_Form_Code__c = c.breg_Form_Code__c;
                String objectType = getObjectTypeById(relatedRecordId);
                if (objectType == 'Account') {
                    transactionRecord.breg_Account__c = relatedRecordId;
                } else if (objectType == 'breg_TN_TM_SM__c') {
                    transactionRecord.breg_TN_TM_SM__c = relatedRecordId;
                }

                transactionRecord.breg_Start_Date__c = c.breg_Effective_Date__c;
                String transCode = transactionCode ?? c.breg_Transaction_Code__c ??
                        c.breg_Form_Configuration__r?.breg_Transaction_Code__c;
                transactionRecord.breg_Transaction_Code__c = transCode;
                transactionRecord.breg_Form_Configuration__c = c.breg_Form_Configuration__c;
                transactionRecord.breg_Case__c = caseId;
                transactionRecord.breg_Date__c = orgDate;
                transactionRecord.breg_Effective_Date__c = c.breg_Effective_Date__c;
                transactionRecord.breg_Received_Date__c = c.breg_Received_Date_Formula__c;
                transactionRecord.breg_Status__c = status;
                transactionRecord.breg_Business_Name__c = getOptionalString(c, Case.breg_Name_of_the_Entity__c);
                transactionRecord.breg_Description__c = getTransactionCodeLabel(transCode);
                transactionRecord.breg_Remarks__c = transCode == 'NC' ? 'FROM: ' + c.breg_Name_of_the_Entity__c : getTransactionCodeLabel(transCode);
                transaction_records.add(transactionRecord);
            }
        }

        return transaction_records;
    }

    public static List<breg_Transaction__c> createMassTransactionRecord(
        Map<Id, Case> casesMap,
        Map<Id, List<Id>> caseToRecordIdsMap,
        String transactionCode,
        Boolean includeMergedByDescription,
        String status
    ) {
        List<breg_Transaction__c> transactionRecords = new List<breg_Transaction__c>();
        Date orgDate = getOrgDateByUserTimezone();

        for (Id caseId : caseToRecordIdsMap.keySet()) {
            Case c = casesMap.get(caseId);
            List<Id> relatedRecordIds = caseToRecordIdsMap.get(caseId);
            if (c == null || relatedRecordIds == null || relatedRecordIds.isEmpty()) {
                continue;
            }

            for (Id relatedRecordId : relatedRecordIds) {
                breg_Transaction__c transactionRecord = buildBaseTransactionForRecord(c, relatedRecordId, transactionCode, status);
                transactionRecord.breg_Date__c = orgDate;
                transactionRecord.breg_Received_Date__c = c.breg_Received_Date_Formula__c;
                if (includeMergedByDescription == true) {
                    String description = 'Merged By: ' + c.breg_Entity__r.Name;
                    transactionRecord.breg_Description__c = description;
                    String transactionCodeLabel = getTransactionCodeLabel(transactionCode);
                    if (transactionRecord.breg_Remarks__c == transactionCodeLabel){
                        transactionRecord.breg_Remarks__c = description;
                    }
                }
                transactionRecords.add(transactionRecord);
            }
        }

        return transactionRecords;
    }

    public static String getTransactionCodeLabel(String transactionCode) {
        // Get picklist labels for Transaction Code
        Map<String, String> transactionCodeLabels = BREGUtils.getPicklistLabelMap('breg_Transaction__c', 'breg_Transaction_Code__c');
        String transactionCodeLabel = transactionCodeLabels.get(transactionCode);
        // e.g. ODC - Officer / Director Change -> Officer / Director Change
        transactionCodeLabel = transactionCodeLabel?.replaceFirst('^[A-Z]+\\s-\\s', '');
        return transactionCodeLabel;
    }

    public static String getObjectTypeById(Id recordId) {
        if (recordId == null) {
            return null;
        }
        try {
            return recordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            return null;
        }
    }

    private static String getOptionalString(SObject record, SObjectField fieldToken) {
        try {
            Object value = record.get(fieldToken);
            return value == null ? null : String.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    public static void createTransBusinessInfoRecords(List<Account> accounts, Map<Id, Case> entityToCaseMap) {
        if (accounts == null || accounts.isEmpty() || entityToCaseMap == null || entityToCaseMap.isEmpty()) {
            return;
        }

        // Gather input account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account a : accounts) {
            if (a?.Id != null)
                accountIds.add(a.Id);
        }
        if (accountIds.isEmpty())
            return;

        // Build field list from TBI fieldset (include Id)
        List<String> fieldList = new List<String>{ 'Id' };
        try {
            List<Schema.FieldSetMember> fsmList = Account.SObjectType.getDescribe().fieldSets.getMap().get('BREG_TBI_Fields_Set').getFields();
            for (Schema.FieldSetMember fsm : fsmList) {
                String fp = fsm.getFieldPath();
                if (!fieldList.contains(fp))
                    fieldList.add(fp);
            }
        } catch (Exception e) {
            // If fieldset not available, fall back to Id-only (nothing to map)
        }

        String soql = 'SELECT ' + String.join(fieldList, ', ') + ' FROM Account WHERE Id IN :accountIds';
        List<Account> freshAccounts = Database.query(soql);

        Map<SObjectField, SObjectField> mapping = getAccountToTbiMapping();
        List<breg_Transaction_Business_Info__c> tbiRecordsToInsert = new List<breg_Transaction_Business_Info__c>();

        for (Account acc : freshAccounts) {
            breg_Transaction_Business_Info__c tbi = new breg_Transaction_Business_Info__c();
            tbi.breg_Entity__c = acc.Id;
            Case relatedCase = entityToCaseMap.get(acc.Id);
            if (relatedCase != null) {
                tbi.breg_Start_Date__c = relatedCase.breg_Effective_Date__c;
            }

            for (SObjectField accField : mapping.keySet()) {
                Object val = acc.get(accField);
                if (val == null)
                    continue;
                tbi.put(mapping.get(accField), val);
            }

            tbiRecordsToInsert.add(tbi);
        }

        if (!tbiRecordsToInsert.isEmpty()) {
            insert tbiRecordsToInsert;
        }
    }

    public static void updateEndDateInLastTransBusinessInfoRecords(List<Account> accounts, Map<Id, Case> entityToCaseMap) {
        updateEndDateInLastActiveByEntity(accounts, entityToCaseMap, 'breg_Transaction_Business_Info__c', null, 'breg_Entity__c');
    }

    public static void updateEndDateInLastTransAddressRecords(List<Account> accounts, Map<Id, Case> entityToCaseMap, Map<Id, Id> caseIdToAffiliationId) {
        updateEndDateInLastActiveByEntity(accounts, entityToCaseMap, 'breg_Transaction_Address__c', caseIdToAffiliationId, 'breg_Account__c');
    }

    public static void createR7LinkageTransactions(List<Account> accounts, Map<Id, Case> entityToCaseMap, String status) {
        List<breg_Transaction__c> transactionsToInsert = new List<breg_Transaction__c>();
        for (Account acc : accounts) {
            Case relatedCase = entityToCaseMap.get(acc.Id);
            if (relatedCase == null) {
                continue;
            }
            breg_Transaction__c newTransaction = new breg_Transaction__c(
                breg_Account__c = acc.Id,
                breg_Business_Name__c = relatedCase?.breg_Name_of_the_Entity__c,
                breg_Effective_Date__c = relatedCase?.breg_Effective_Date__c,
                breg_Case__c = relatedCase?.Id,
                breg_File_Suffix__c = acc.breg_File_Suffix__c,
                breg_Form_Code__c = relatedCase?.breg_Form_Code__c,
                breg_Form_Configuration__c = relatedCase?.breg_Form_Configuration__c,
                breg_Transaction_Code__c = 'R7NR',
                breg_Status__c = status,
                breg_Description__c = getTransactionCodeLabel('R7NR'),
                breg_Remarks__c = getTransactionCodeLabel('R7NR')
            );
            transactionsToInsert.add(newTransaction);
        }
        insert transactionsToInsert;
    }

    private static void updateEndDateInLastActiveByEntity(
        List<Account> accounts,
        Map<Id, Case> entityToCaseMap,
        String objectApiName,
        Map<Id, Id> caseIdToAffiliationId,
        String entityLookupField
    ) {
        final String END_DATE_FIELD = 'breg_End_Date__c';
        final String AFFILIATION_LOOKUP_FIELD = 'breg_Account_Affiliation__c';
        if (accounts == null || accounts.isEmpty() || entityToCaseMap == null || entityToCaseMap.isEmpty()) {
            return;
        }

        // 1) Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            if (acc?.Id != null) {
                accountIds.add(acc.Id);
            }
        }
        if (accountIds.isEmpty())
            return;

        // Effective date per account (from Case)
        Map<Id, Date> effectiveDateByAccount = new Map<Id, Date>();
        for (Id accId : entityToCaseMap.keySet()) {
            Case c = entityToCaseMap.get(accId);
            if (c?.breg_Effective_Date__c != null) {
                effectiveDateByAccount.put(accId, c.breg_Effective_Date__c);
            }
        }
        if (effectiveDateByAccount.isEmpty())
            return;

        // Optional affiliation filter
        Set<Id> affiliationIds = new Set<Id>();
        if (caseIdToAffiliationId != null && !caseIdToAffiliationId.isEmpty()) {
            affiliationIds.addAll(caseIdToAffiliationId.values());
        }

        // Dynamic SOQL
        String soql = 'SELECT Id, ' + entityLookupField + ', ' + END_DATE_FIELD;

        if (!affiliationIds.isEmpty()) {
            soql += ', ' + AFFILIATION_LOOKUP_FIELD;
        }

        Date orgDate = getOrgDateByUserTimezone();

        soql +=
            ' FROM ' +
            objectApiName +
            ' WHERE ' +
            entityLookupField +
            ' IN :accountIds' +
            ' AND ( ' +
            END_DATE_FIELD +
            ' = NULL OR ' +
            END_DATE_FIELD +
            ' > :orgDate )';

        if (!affiliationIds.isEmpty()) {
            soql += ' AND ' + AFFILIATION_LOOKUP_FIELD + ' IN :affiliationIds';
        }

        soql += ' ORDER BY ' + entityLookupField + ' ASC, CreatedDate DESC';
        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty())
            return;

        // Last active record per account
        Map<Id, SObject> lastByAccount = new Map<Id, SObject>();
        for (SObject row : rows) {
            Id accId = (Id) row.get(entityLookupField);
            if (!lastByAccount.containsKey(accId)) {
                lastByAccount.put(accId, row);
            }
        }

        // Apply end date
        List<SObject> toUpdate = new List<SObject>();
        for (Id accId : lastByAccount.keySet()) {
            Date eff = effectiveDateByAccount.get(accId);
            if (eff == null)
                continue;

            SObject record = lastByAccount.get(accId);
            record.put(END_DATE_FIELD, eff);
            toUpdate.add(record);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static List<SObjectField> getFieldsFromFieldSet() {
        Map<String, SObjectField> fieldMap = Account.SObjectType.getDescribe().fields.getMap();

        List<SObjectField> fields = new List<SObjectField>();

        for (Schema.FieldSetMember fsm : Account.SObjectType.getDescribe().fieldSets.getMap().get('BREG_TBI_Fields_Set').getFields()) {
            fields.add(fieldMap.get(fsm.getFieldPath()));
        }

        return fields;
    }

    private static Map<SObjectField, SObjectField> getAccountToTbiMapping() {
        Map<SObjectField, SObjectField> mapping = new Map<SObjectField, SObjectField>();

        List<SObjectField> accountFields = getFieldsFromFieldSet();

        Map<String, SObjectField> tbiFields = breg_Transaction_Business_Info__c.SObjectType.getDescribe().fields.getMap();

        for (SObjectField accField : accountFields) {
            String apiName = accField.getDescribe().getName();

            if (apiName == 'Sic') {
                mapping.put(accField, breg_Transaction_Business_Info__c.breg_Sic_Code__c);
            } else if (apiName == 'Name') {
                mapping.put(accField, breg_Transaction_Business_Info__c.breg_Master_Name__c);
            } else {
                if (tbiFields.containsKey(apiName)) {
                    mapping.put(accField, tbiFields.get(apiName));
                }
            }
        }

        return mapping;
        //TODO
    }

    public static List<breg_Transaction_Address__c> createTransactionAdresses(
        Map<Id, Case> casesMap,
        List<breg_Transaction__c> transactions,
        Map<Id, Id> caseToAffiliationMap
    ) {
        List<breg_Transaction_Address__c> result = new List<breg_Transaction_Address__c>();
        Map<String, String> stateCodeValueLabelMap = BREGUtils.getPicklistLabelMap('breg_Transaction_Address__c', 'breg_Address__StateCode__s');
        Map<String, String> countryCodeValueLabelMap = BREGUtils.getPicklistLabelMap('breg_Transaction_Address__c', 'breg_Address__CountryCode__s');
        Map<String, String> countryCodeLabelValueMap = BREGUtils.getPicklistLabelToValueMap('breg_Transaction_Address__c', 'breg_Address__CountryCode__s');

        // If affiliation mapping provided, pre-query affiliation records to use their address fields
        Map<Id, breg_Account_Affiliation__c> affiliationById = new Map<Id, breg_Account_Affiliation__c>();
        if (caseToAffiliationMap != null && !caseToAffiliationMap.isEmpty()) {
            Set<Id> affIds = new Set<Id>();
            affIds.addAll(caseToAffiliationMap.values());
            if (!affIds.isEmpty()) {
                for (breg_Account_Affiliation__c a : [
                    SELECT
                        Id,
                        breg_Address__Street__s,
                        breg_Address_Street_2__c,
                        breg_Address__City__s,
                        breg_Address__StateCode__s,
                        breg_Address__PostalCode__s,
                        breg_Address__CountryCode__s,
                        breg_Address_State_Text__c
                    FROM breg_Account_Affiliation__c
                    WHERE Id IN :affIds
                ]) {
                    affiliationById.put(a.Id, a);
                }
            }
        }

        for (breg_Transaction__c trans : transactions) {
            Case c = casesMap.get(trans.breg_Case__c);
            if (c == null)
                continue;

            breg_Transaction_Address__c newTransAddress = new breg_Transaction_Address__c();

            // If affiliation exists for this case and we have the affiliation record, use affiliation address
            breg_Account_Affiliation__c aff = null;
            if (caseToAffiliationMap != null && caseToAffiliationMap.containsKey(c.Id)) {
                Id affId = caseToAffiliationMap.get(c.Id);
                aff = affiliationById.get(affId);
            }

            if (aff != null) {
                newTransAddress.breg_Address__City__s = aff.breg_Address__City__s;
                newTransAddress.breg_Address__CountryCode__s = aff.breg_Address__CountryCode__s;
                if (stateCodeValueLabelMap.containsKey(aff.breg_Address__StateCode__s)) {
                    newTransAddress.breg_Address__StateCode__s = aff.breg_Address__StateCode__s;
                } else if (aff.breg_Address_State_Text__c != null) {
                    newTransAddress.breg_Address_StateText__c = aff.breg_Address_State_Text__c;
                }

                newTransAddress.breg_Address__Street__s = aff.breg_Address__Street__s;
                newTransAddress.breg_Address__PostalCode__s = aff.breg_Address__PostalCode__s;
                newTransAddress.breg_BRIM_ADDRESS_LINE_1__c = aff.breg_Address__Street__s;
                newTransAddress.breg_BRIM_ADDRESS_LINE_2__c = aff.breg_Address_Street_2__c;
                newTransAddress.breg_Account_Affiliation__c = aff.Id;
            } else {
                newTransAddress.breg_Address__City__s = c.breg_Mailing_Address__City__s;

                if (countryCodeValueLabelMap.containsKey(c.breg_Mailing_Address__CountryCode__s)) {
                    newTransAddress.breg_Address__CountryCode__s = c.breg_Mailing_Address__CountryCode__s;
                } else if (countryCodeLabelValueMap.containsKey(c.breg_Mailing_Address__CountryCode__s)) {
                    newTransAddress.breg_Address__CountryCode__s = countryCodeLabelValueMap.get(c.breg_Mailing_Address__CountryCode__s);
                }

                if (stateCodeValueLabelMap.containsKey(c.breg_Mailing_Address__StateCode__s)) {
                    newTransAddress.breg_Address__StateCode__s = c.breg_Mailing_Address__StateCode__s;
                } else {
                    newTransAddress.breg_Address_StateText__c = c.breg_Mailing_Address_State__c;
                }

                newTransAddress.breg_Address__Street__s = c.breg_Mailing_Address__Street__s;
                newTransAddress.breg_Address__PostalCode__s = c.breg_Mailing_Address__PostalCode__s;
                newTransAddress.breg_BRIM_ADDRESS_LINE_1__c = c.breg_Mailing_Address__Street__s;
                newTransAddress.breg_BRIM_ADDRESS_LINE_2__c = c.breg_Mailing_Address_Number_and_Street_2__c;
            }

            newTransAddress.BREG_Transaction__c = trans.Id;
            newTransAddress.Name = c.CaseNumber + ' - ' + c.breg_Effective_Date__c;
            newTransAddress.breg_Start_Date__c = c.breg_Effective_Date__c;
            newTransAddress.breg_Account__c = c.breg_Entity__c;
            if (caseToAffiliationMap != null && caseToAffiliationMap.containsKey(c.Id)) {
                newTransAddress.breg_Account_Affiliation__c = caseToAffiliationMap.get(c.Id);
            }
            result.add(newTransAddress);
        }
        return result;
    }
}