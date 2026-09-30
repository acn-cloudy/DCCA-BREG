public with sharing class BREGWebFilingMapperInvocable {
    @TestVisible
    private static final List<String> CASE_LOG_FIELDS = new List<String>{
        'Id',
        'ContactId',
        'RecordTypeId',
        'Status',
        'Origin',
        'Priority',
        'breg_Form_Code__c',
        'breg_Entity__c',
        'breg_Expiration_Date__c',
        'breg_Name_of_the_Entity__c',
        'breg_Effective_Date__c',
        'breg_Filing_Date__c',
        'breg_Submission_Date__c',
        'breg_Signed_By__c',
        'breg_Signed_By_First_Name__c',
        'breg_Signed_By_Last_Name__c',
        'breg_Signed_By_Name__c',
        'breg_Signed_By_Entity_Name__c',
        'breg_Signature__c',
        'breg_Signed_By_Office_Held__c',
        'breg_Signed_By_Title_Text__c',
        'breg_Processing_Speed__c',
        'breg_No_Changes__c',
        'breg_Annual__c',
        'breg_BRIM_FILE_NO__c',
        'breg_File_Suffix__c',
        'breg_Date_Of_Formation__c',
        'breg_Entity_Jurisdiction__c',
        'breg_Entity_Nature_Of_Business__c',
        'breg_Entity_Type__c',
        'breg_Is_Manager_Managed__c',
        'breg_BRIM_LIMIT_1__c',
        'breg_BRIM_LIMIT_2__c',
        'breg_BRIM_LIMIT_DT__c',
        'breg_Purposes__c',
        'breg_Formation_State__c',
        'breg_Number_of_initial_members__c',
        'breg_Duration_Period__c',
        'breg_Mailing_Address__Street__s',
        'breg_Mailing_Address_Number_and_Street_2__c',
        'breg_Mailing_Address__City__s',
        'breg_Mailing_Address__StateCode__s',
        'breg_Mailing_Address__PostalCode__s',
        'breg_Mailing_Address__CountryCode__s',
        'breg_Company_Address__Street__s',
        'breg_Company_Address_Street2__c',
        'breg_Company_Address__City__s',
        'breg_Company_Address__StateCode__s',
        'breg_Company_Address__PostalCode__s',
        'breg_Company_Address__CountryCode__s',
        'breg_Stock_Type__c',
        'breg_Par_Value_Of_Each_Share__c',
        'breg_Partnership_Begin_Business_Date__c',
        'breg_Number_of_common_shares__c',
        'breg_Number_of_copies_to_be_certified__c',
        'breg_The_Corporation_Has_Members__c',
        'breg_TNTMSM_Type__c',
        'breg_TNTMSM_Certificate__c',
        'breg_TNTMSM_Description__c',
        'breg_TNTMSM_Goods_Or_Services__c',
        'breg_TNTMSM_Mode_Or_Manner__c'
    };

    @InvocableMethod(
        label='Map Web Filing Data to Case'
        description='Runs all web filing mappers for the given work item and returns the populated Case fields'
    )
    public static List<InvocableResult> mapFilingDataToCase(List<InvocableRequest> requests) {
        MappingExecutionContext context = initializeContext(requests);
        loadExistingData(context);

        if (runMappersSafely(context)) {
            updateCases(context);
            processRelatedRecords(context);
            finalizeMappingStates(context);
        }

        persistMappingAudit(context);
        return buildResults(requests, context.wrappersByWorkitemId);
    }

    private static MappingExecutionContext initializeContext(List<InvocableRequest> requests) {
        MappingExecutionContext context = new MappingExecutionContext();
        if (requests == null) {
            return context;
        }

        for (InvocableRequest request : requests) {
            if (request == null || String.isBlank(request.workitemId)) {
                continue;
            }
            BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
            context.wrappersByWorkitemId.put(request.workitemId, wrapper);
            context.statesByWorkitemId.put(request.workitemId, new WorkitemMappingState(request.workitemId, wrapper));
        }
        return context;
    }

    private static void loadExistingData(MappingExecutionContext context) {
        if (context == null || context.wrappersByWorkitemId.isEmpty()) {
            return;
        }

        Set<String> workitemIds = context.wrappersByWorkitemId.keySet();
        loadFilingInfos(context, workitemIds);
        loadCases(context, workitemIds);
    }

    private static void loadFilingInfos(MappingExecutionContext context, Set<String> workitemIds) {
        for (breg_WEB_WEB_FILING_INFO__c filingInfo : [
            SELECT Id, breg_WEB_Case__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c IN :workitemIds
        ]) {
            WorkitemMappingState state = context.statesByWorkitemId.get(filingInfo.breg_WEB_Case__c);
            if (state != null) {
                state.filingInfo = filingInfo;
                state.hasRelatedRecordsInExistingLog = existingLogHasRelatedRecords(filingInfo.breg_Mapping_Log__c);
            }
        }
    }

    private static void loadCases(MappingExecutionContext context, Set<String> workitemIds) {
        List<Case> casesToQuery = Database.query('SELECT ' + String.join(CASE_LOG_FIELDS, ', ') + ' FROM Case WHERE Id IN :workitemIds');
        for (Case caseRecord : casesToQuery) {
            WorkitemMappingState state = context.statesByWorkitemId.get(caseRecord.Id);
            if (state == null) {
                continue;
            }
            state.wrapper.WebCase = caseRecord;
            state.originalCase = projectCaseFields(caseRecord);
            state.addDebug('Loaded existing Case fields for mapping log.');
        }
    }

    private static Boolean runMappersSafely(MappingExecutionContext context) {
        try {
            runMappers(context.wrappersByWorkitemId, collectDebugMessages(context));
            return true;
        } catch (Exception ex) {
            for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
                state.markFailure(ex.getMessage(), 'Mapping failed before Case update: ' + ex.getMessage());
            }

            return false;
        }
    }

    private static void runMappers(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId, Map<String, List<String>> debugMessagesByWorkitemId) {
        Set<String> workitemIds = wrappersByWorkitemId.keySet();
        for (BREGWebDataItemMapper mapper : buildMappers(wrappersByWorkitemId)) {
            runMapper(workitemIds, debugMessagesByWorkitemId, mapper);
        }
    }

    private static List<BREGWebDataItemMapper> buildMappers(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        return new List<BREGWebDataItemMapper>{
            new BREGWebFilingInfo2Case(wrappersByWorkitemId),
            new BREGWebBusinessInfo2Case(wrappersByWorkitemId),
            new BREGWEBAddress2Case(wrappersByWorkitemId),
            new BREGWebPersons2AccountAffiliations(wrappersByWorkitemId),
            new BREGWebStock2BREGStock(wrappersByWorkitemId),
            new BREGWebTradeMarks2Case(wrappersByWorkitemId)
        };
    }

    private static void runMapper(Set<String> workitemIds, Map<String, List<String>> debugMessagesByWorkitemId, BREGWebDataItemMapper mapper) {
        String mapperName = String.valueOf(mapper).substringBefore(':');
        Map<String, List<SObject>> mapperResults = mapper.PrepareData(workitemIds);
        for (String workitemId : workitemIds) {
            Integer recordCount = mapperResults.containsKey(workitemId) ? mapperResults.get(workitemId).size() : 0;
            addDebugMessage(debugMessagesByWorkitemId, workitemId, mapperName + ' processed ' + String.valueOf(recordCount) + ' source record(s).');
        }
    }

    private static void updateCases(MappingExecutionContext context) {
        List<Case> casesToUpdate = new List<Case>();
        Map<Id, WorkitemMappingState> stateByCaseId = new Map<Id, WorkitemMappingState>();
        for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
            if (state.wrapper != null && state.wrapper.WebCase != null && state.wrapper.WebCase.Id != null) {
                state.wrapper.WebCase.breg_Override_Payment__c = true;
                casesToUpdate.add(state.wrapper.WebCase);
                stateByCaseId.put(state.wrapper.WebCase.Id, state);
            }
        }

        if (casesToUpdate.isEmpty()) {
            return;
        }

        Database.SaveResult[] updateResults = Database.update(casesToUpdate, false);
        for (Integer i = 0; i < updateResults.size(); i++) {
            WorkitemMappingState state = stateByCaseId.get(casesToUpdate[i].Id);
            if (state != null) {
                if (updateResults[i].isSuccess()) {
                    state.markCompleted('Case update completed successfully.');
                    continue;
                }

                String errorMessage = joinErrors(updateResults[i].getErrors());
                state.markFailure(errorMessage, 'Case update failed: ' + errorMessage);
            }
        }
    }

    private static void processRelatedRecords(MappingExecutionContext context) {
        PendingInsertBatch affiliationBatch = new PendingInsertBatch();
        PendingInsertBatch stockBatch = new PendingInsertBatch();
        PendingInsertBatch tradeMarkBatch = new PendingInsertBatch();
        List<WorkitemMappingState> statesWithPendingRelatedInserts = new List<WorkitemMappingState>();

        for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
            if (state == null || state.wrapper == null || !hasRelatedRecords(state.wrapper)) {
                continue;
            }
            if (state.status == 'Error') {
                state.addDebug('Related record insert skipped because Case update failed.');
                continue;
            }
            if (state.hasRelatedRecordsInExistingLog) {
                state.addDebug('Insert operations were blocked because the existing mapping log already contains related records.');
                continue;
            }

            statesWithPendingRelatedInserts.add(state);
            collectAffiliationRecords(state, affiliationBatch);
            collectRecords(state.wrapper == null ? null : state.wrapper.Stocks, state, stockBatch);
            collectRecords(state.wrapper == null ? null : state.wrapper.TradeMarks, state, tradeMarkBatch);
        }

        Map<String, Integer> insertedAffiliationsByWorkitemId = bulkInsertRecords(affiliationBatch, 'Account Affiliation');
        Map<String, Integer> insertedStocksByWorkitemId = bulkInsertRecords(stockBatch, 'Stock');
        Map<String, Integer> insertedTradeMarksByWorkitemId = bulkInsertRecords(tradeMarkBatch, 'Trade Mark');

        for (WorkitemMappingState state : statesWithPendingRelatedInserts) {
            if (state.status != 'Error') {
                state.addDebug(
                    'Inserted related records: affiliations=' +
                        String.valueOf(getInsertedCount(insertedAffiliationsByWorkitemId, state)) +
                        ', stocks=' +
                        String.valueOf(getInsertedCount(insertedStocksByWorkitemId, state)) +
                        ', tradeMarks=' +
                        String.valueOf(getInsertedCount(insertedTradeMarksByWorkitemId, state)) +
                        '.'
                );
            }
        }
    }

    private static void collectAffiliationRecords(WorkitemMappingState state, PendingInsertBatch batch) {
        for (breg_Account_Affiliation__c affiliation : getAffiliationsToInsert(state.wrapper)) {
            batch.records.add(affiliation);
            batch.states.add(state);
        }
    }

    private static List<breg_Account_Affiliation__c> getAffiliationsToInsert(BREGWebFilingWrapper wrapper) {
        List<breg_Account_Affiliation__c> affiliationsToInsert = new List<breg_Account_Affiliation__c>();
        if (wrapper == null || wrapper.AccountAffiliations == null) {
            return affiliationsToInsert;
        }

        for (BREGWebAccountAffiliationWrapper affiliationWrapper : wrapper.AccountAffiliations) {
            if (affiliationWrapper == null || affiliationWrapper.accountAffiliation == null) {
                continue;
            }
            if (affiliationWrapper.accountAffiliation.Id == null) {
                affiliationsToInsert.add(affiliationWrapper.accountAffiliation);
            }
        }
        return affiliationsToInsert;
    }

    private static void collectRecords(List<SObject> records, WorkitemMappingState state, PendingInsertBatch batch) {
        if (records == null) {
            return;
        }

        for (SObject record : records) {
            if (record == null) {
                continue;
            }
            batch.records.add(record);
            batch.states.add(state);
        }
    }

    private static Map<String, Integer> bulkInsertRecords(PendingInsertBatch batch, String recordLabel) {
        Map<String, Integer> successCountsByWorkitemId = new Map<String, Integer>();
        if (batch == null || batch.records.isEmpty()) {
            return successCountsByWorkitemId;
        }

        Database.SaveResult[] saveResults = Database.insert(batch.records, false);
        for (Integer resultIndex = 0; resultIndex < saveResults.size(); resultIndex++) {
            Database.SaveResult saveResult = saveResults[resultIndex];
            WorkitemMappingState state = batch.states[resultIndex];
            if (saveResult.isSuccess()) {
                incrementInsertCount(successCountsByWorkitemId, state);
                continue;
            }

            String errorMessage = joinErrors(saveResult.getErrors());
            state.appendFailure(errorMessage, recordLabel + ' insert failed: ' + errorMessage);
        }
        return successCountsByWorkitemId;
    }

    private static void incrementInsertCount(Map<String, Integer> successCountsByWorkitemId, WorkitemMappingState state) {
        if (state == null || String.isBlank(state.workitemId)) {
            return;
        }

        Integer currentCount = successCountsByWorkitemId.containsKey(state.workitemId) ? successCountsByWorkitemId.get(state.workitemId) : 0;
        successCountsByWorkitemId.put(state.workitemId, currentCount + 1);
    }

    private static Integer getInsertedCount(Map<String, Integer> successCountsByWorkitemId, WorkitemMappingState state) {
        if (state == null || String.isBlank(state.workitemId) || !successCountsByWorkitemId.containsKey(state.workitemId)) {
            return 0;
        }

        return successCountsByWorkitemId.get(state.workitemId);
    }

    private static void finalizeMappingStates(MappingExecutionContext context) {
        for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
            if (!hasRelatedRecords(state.wrapper)) {
                state.addDebug('No related records were produced for insert.');
            }

            state.ensureCompleted();
        }
    }

    private static void persistMappingAudit(MappingExecutionContext context) {
        List<breg_WEB_WEB_FILING_INFO__c> filingInfosToUpdate = new List<breg_WEB_WEB_FILING_INFO__c>();
        for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
            if (state.filingInfo == null) {
                continue;
            }

            state.addDebug(buildFinalStatusMessage(state));
            filingInfosToUpdate.add(
                new breg_WEB_WEB_FILING_INFO__c(
                    Id = state.filingInfo.Id,
                    breg_Mapped_Date__c = System.now(),
                    breg_Mapping_Status__c = String.isBlank(state.status) ? 'Error' : state.status,
                    breg_Mapping_Log__c = JSON.serializePretty(buildMappingLogPayload(state))
                )
            );
        }

        if (!filingInfosToUpdate.isEmpty()) {
            Database.update(filingInfosToUpdate, false);
        }
    }

    private static List<InvocableResult> buildResults(List<InvocableRequest> requests, Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        List<InvocableResult> results = new List<InvocableResult>();
        if (requests == null) {
            return results;
        }

        for (InvocableRequest request : requests) {
            BREGWebFilingWrapper wrapper = wrappersByWorkitemId.get(request.workitemId);
            InvocableResult result = new InvocableResult();
            result.nameOfEntity = wrapper != null && wrapper.WebCase != null ? wrapper.WebCase.breg_Name_of_the_Entity__c : null;
            results.add(result);
        }
        return results;
    }

    private static Map<String, Object> buildMappingLogPayload(WorkitemMappingState state) {
        RelatedRecordsLog relatedRecordsLog = buildRelatedRecordsLog(state.wrapper);
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('originalCase', buildCaseSnapshotPayload(state.originalCase == null ? new Map<String, Object>() : state.originalCase));
        payload.put(
            'updatedCase',
            buildCaseSnapshotPayload(
                state.wrapper != null && state.wrapper.WebCase != null ? projectCaseFields(state.wrapper.WebCase) : new Map<String, Object>()
            )
        );
        payload.put('relatedRecords', buildRelatedRecordsPayload(relatedRecordsLog));
        payload.put('debugMessages', state.debugMessages == null ? new List<String>() : state.debugMessages);
        return payload;
    }

    private static Map<String, Object> buildCaseSnapshotPayload(Map<String, Object> fieldValues) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('objectApiName', 'Case');
        payload.put('fields', fieldValues == null ? new Map<String, Object>() : fieldValues);
        return payload;
    }

    private static Map<String, Object> buildRelatedRecordsPayload(RelatedRecordsLog relatedRecordsLog) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put(
            'accountAffiliations',
            relatedRecordsLog == null ||
                relatedRecordsLog.accountAffiliations == null
                ? new List<Map<String, Object>>()
                : relatedRecordsLog.accountAffiliations
        );
        payload.put('stocks', relatedRecordsLog == null || relatedRecordsLog.stocks == null ? new List<Map<String, Object>>() : relatedRecordsLog.stocks);
        payload.put(
            'tradeMarks',
            relatedRecordsLog == null || relatedRecordsLog.tradeMarks == null ? new List<Map<String, Object>>() : relatedRecordsLog.tradeMarks
        );
        return payload;
    }

    private static RelatedRecordsLog buildRelatedRecordsLog(BREGWebFilingWrapper wrapper) {
        RelatedRecordsLog relatedRecords = new RelatedRecordsLog();
        if (wrapper == null) {
            return relatedRecords;
        }

        addAffiliationRelatedRecords(wrapper.AccountAffiliations, relatedRecords);
        addPopulatedStockRecords(wrapper.Stocks, relatedRecords.stocks);
        addPopulatedTradeMarkRecords(wrapper.TradeMarks, relatedRecords.tradeMarks);
        return relatedRecords;
    }

    private static void addAffiliationRelatedRecords(List<BREGWebAccountAffiliationWrapper> affiliationWrappers, RelatedRecordsLog relatedRecords) {
        for (BREGWebAccountAffiliationWrapper affiliationWrapper : affiliationWrappers) {
            if (affiliationWrapper == null) {
                continue;
            }
            addPopulatedRecord(affiliationWrapper.accountAffiliation, relatedRecords.accountAffiliations);
        }
    }

    private static void addPopulatedStockRecords(List<breg_Stock__c> records, List<Map<String, Object>> target) {
        if (records == null) {
            return;
        }

        for (breg_Stock__c record : records) {
            addPopulatedRecord(record, target);
        }
    }

    private static void addPopulatedTradeMarkRecords(List<breg_TN_TM_SM__c> records, List<Map<String, Object>> target) {
        if (records == null) {
            return;
        }

        for (breg_TN_TM_SM__c record : records) {
            addPopulatedRecord(record, target);
        }
    }

    private static void addPopulatedRecord(SObject record, List<Map<String, Object>> target) {
        if (hasPopulatedFields(record)) {
            target.add(toFieldMap(record));
        }
    }

    private static Boolean hasRelatedRecords(BREGWebFilingWrapper wrapper) {
        return !buildRelatedRecordsLog(wrapper).isEmpty();
    }

    private static Boolean hasPopulatedFields(SObject record) {
        return record != null && !record.getPopulatedFieldsAsMap().isEmpty();
    }

    private static Map<String, Object> projectCaseFields(Case caseRecord) {
        Map<String, Object> projectedCase = new Map<String, Object>();
        if (caseRecord == null) {
            return projectedCase;
        }

        for (String fieldName : CASE_LOG_FIELDS) {
            projectedCase.put(fieldName, caseRecord.get(fieldName));
        }
        return projectedCase;
    }

    private static Map<String, Object> toFieldMap(SObject record) {
        return record == null ? new Map<String, Object>() : record.getPopulatedFieldsAsMap();
    }

    private static String joinErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();
        if (errors == null) {
            return null;
        }

        for (Database.Error error : errors) {
            messages.add(error.getStatusCode() + ': ' + error.getMessage());
        }
        return String.join(messages, ' | ');
    }

    private static void addDebugMessage(Map<String, List<String>> debugMessagesByWorkitemId, String workitemId, String message) {
        if (String.isBlank(workitemId) || String.isBlank(message)) {
            return;
        }
        if (!debugMessagesByWorkitemId.containsKey(workitemId)) {
            debugMessagesByWorkitemId.put(workitemId, new List<String>());
        }
        debugMessagesByWorkitemId.get(workitemId).add(message);
    }

    private static Map<String, List<String>> collectDebugMessages(MappingExecutionContext context) {
        Map<String, List<String>> debugMessagesByWorkitemId = new Map<String, List<String>>();
        for (WorkitemMappingState state : context.statesByWorkitemId.values()) {
            debugMessagesByWorkitemId.put(state.workitemId, state.debugMessages);
        }
        return debugMessagesByWorkitemId;
    }

    private static String buildFinalStatusMessage(WorkitemMappingState state) {
        if (state.status == 'Error' && String.isNotBlank(state.errorMessage)) {
            return 'Final mapping status: Error. ' + state.errorMessage;
        }
        return 'Final mapping status: ' + state.status + '.';
    }

    private static Boolean existingLogHasRelatedRecords(String mappingLogJson) {
        if (String.isBlank(mappingLogJson)) {
            return false;
        }

        String normalizedMappingLogJson = normalizeMappingLogJson(mappingLogJson);
        if (containsSerializedRelatedRecords(normalizedMappingLogJson)) {
            return true;
        }

        try {
            Map<String, Object> mappingLog = parseMappingLog(normalizedMappingLogJson);
            if (mappingLog == null) {
                return false;
            }

            return hasRelatedRecordEntries(getRelatedRecords(mappingLog));
        } catch (Exception ex) {
            return true;
        }
    }

    private static Map<String, Object> parseMappingLog(String mappingLogJson) {
        Object parsedLog = JSON.deserializeUntyped(mappingLogJson);
        return parsedLog instanceof Map<String, Object> ? (Map<String, Object>) parsedLog : null;
    }

    private static Map<String, Object> getRelatedRecords(Map<String, Object> mappingLog) {
        if (mappingLog == null) {
            return null;
        }

        Object relatedRecordsObject = mappingLog.get('relatedRecords');
        return relatedRecordsObject instanceof Map<String, Object> ? (Map<String, Object>) relatedRecordsObject : null;
    }

    private static Boolean hasRelatedRecordEntries(Map<String, Object> relatedRecords) {
        return relatedRecords != null &&
            (hasEntries(relatedRecords.get('accountAffiliations')) ||
            hasEntries(relatedRecords.get('stocks')) ||
            hasEntries(relatedRecords.get('tradeMarks')));
    }

    private static Boolean containsSerializedRelatedRecords(String mappingLogJson) {
        if (String.isBlank(mappingLogJson) || !mappingLogJson.contains('"relatedRecords"')) {
            return false;
        }

        return mappingLogJson.contains('"accountAffiliations" : [{') ||
            mappingLogJson.contains('"accountAffiliations":[{') ||
            mappingLogJson.contains('"stocks" : [{') ||
            mappingLogJson.contains('"stocks":[{') ||
            mappingLogJson.contains('"tradeMarks" : [{') ||
            mappingLogJson.contains('"tradeMarks":[{');
    }

    private static String normalizeMappingLogJson(String mappingLogJson) {
        if (String.isBlank(mappingLogJson)) {
            return mappingLogJson;
        }

        return mappingLogJson.replace('&quot;', '"').replace('&#39;', '\'').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
    }

    private static Boolean hasEntries(Object value) {
        return value instanceof List<Object> && !((List<Object>) value).isEmpty();
    }

    private class MappingExecutionContext {
        public Map<String, BREGWebFilingWrapper> wrappersByWorkitemId = new Map<String, BREGWebFilingWrapper>();
        public Map<String, WorkitemMappingState> statesByWorkitemId = new Map<String, WorkitemMappingState>();
    }

    private class WorkitemMappingState {
        public String workitemId;
        public BREGWebFilingWrapper wrapper;
        public breg_WEB_WEB_FILING_INFO__c filingInfo;
        public Boolean hasRelatedRecordsInExistingLog = false;
        public Map<String, Object> originalCase = new Map<String, Object>();
        public List<String> debugMessages = new List<String>();
        public String status;
        public String errorMessage;

        public WorkitemMappingState(String workitemId, BREGWebFilingWrapper wrapper) {
            this.workitemId = workitemId;
            this.wrapper = wrapper;
        }

        public void addDebug(String message) {
            if (String.isNotBlank(message)) {
                debugMessages.add(message);
            }
        }

        public void markCompleted(String debugMessage) {
            status = 'Completed';
            addDebug(debugMessage);
        }

        public void markFailure(String newErrorMessage, String debugMessage) {
            status = 'Error';
            errorMessage = newErrorMessage;
            addDebug(debugMessage);
        }

        public void appendFailure(String newErrorMessage, String debugMessage) {
            status = 'Error';
            errorMessage = String.isBlank(errorMessage) ? newErrorMessage : errorMessage + ' | ' + newErrorMessage;
            addDebug(debugMessage);
        }

        public void ensureCompleted() {
            if (String.isBlank(status)) {
                status = 'Completed';
            }
        }
    }

    private class RelatedRecordsLog {
        public List<Map<String, Object>> accountAffiliations = new List<Map<String, Object>>();
        public List<Map<String, Object>> stocks = new List<Map<String, Object>>();
        public List<Map<String, Object>> tradeMarks = new List<Map<String, Object>>();

        public Boolean isEmpty() {
            return accountAffiliations.isEmpty() && stocks.isEmpty() && tradeMarks.isEmpty();
        }
    }

    private class PendingInsertBatch {
        public List<SObject> records = new List<SObject>();
        public List<WorkitemMappingState> states = new List<WorkitemMappingState>();
    }

    public class InvocableRequest {
        @InvocableVariable(label='Work Item ID' description='Salesforce Id of the Case (work item)' required=true)
        public String workitemId;
    }

    public class InvocableResult {
        @InvocableVariable(label='Name of Entity' description='Mapped value of breg_Name_of_the_Entity__c on the Case')
        public String nameOfEntity;
    }

    public class BREGWebFilingMapperInvocableException extends Exception {
    }
}