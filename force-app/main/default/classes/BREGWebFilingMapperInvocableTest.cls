@isTest
private class BREGWebFilingMapperInvocableTest {
    @testSetup
    static void setupData() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        insert new breg_WEB_WEB_FILING_INFO__c(breg_WEB_Case__c = testCase.Id, breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Test Company LLC');
    }

    // ─── DTO constructor tests ────────────────────────────────────────────────

    @isTest
    static void testBREGWebFilingWrapperConstructor() {
        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();

        Assert.isNotNull(wrapper.WebCase);
        Assert.isNotNull(wrapper.AccountAffiliations);
        Assert.isNotNull(wrapper.Stocks);
        Assert.isNotNull(wrapper.TradeMarks);
        Assert.isTrue(wrapper.AccountAffiliations.isEmpty());
        Assert.isTrue(wrapper.Stocks.isEmpty());
        Assert.isTrue(wrapper.TradeMarks.isEmpty());
    }

    @isTest
    static void testBREGWebAccountAffiliationWrapperConstructor() {
        BREGWebAccountAffiliationWrapper wrapper = new BREGWebAccountAffiliationWrapper();

        Assert.isNotNull(wrapper.Contact);
        Assert.isNotNull(wrapper.Account);
        Assert.isNotNull(wrapper.accountAffiliation);
    }

    // ─── BREGWebFilingInfo2Case mapper tests ─────────────────────────────────────

    @isTest
    static void testBREGWebFilingInfo2CaseMapsCompanyName() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');
        Assert.isFalse(results.get(testCase.Id).isEmpty(), 'There should be at least one source record');
        Assert.areEqual(
            'Test Company LLC',
            wrapperMap.get(testCase.Id).WebCase.breg_Name_of_the_Entity__c,
            'Company name should be mapped to the Case wrapper'
        );
    }

    @isTest
    static void testBREGWebFilingInfo2CaseNoSourceRecord() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no source record exists');
        Assert.isNull(wrapperMap.get(emptyCase.Id).WebCase.breg_Name_of_the_Entity__c, 'Company name should remain null when no filing info found');
    }

    // ─── Base mapper edge cases ───────────────────────────────────────────────

    @isTest
    static void testBaseMapperNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testBaseMapperEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }

    // ─── BREGWebFilingMapperInvocable tests ──────────────────────────────────────

    @isTest
    static void testInvocableMapsNameOfEntity() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        BREGWebFilingMapperInvocable.InvocableRequest request = new BREGWebFilingMapperInvocable.InvocableRequest();
        request.workitemId = testCase.Id;

        Test.startTest();
        List<BREGWebFilingMapperInvocable.InvocableResult> results = BREGWebFilingMapperInvocable.mapFilingDataToCase(
            new List<BREGWebFilingMapperInvocable.InvocableRequest>{ request }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual('Test Company LLC', results[0].nameOfEntity);

        Case updatedCase = [SELECT breg_Override_Payment__c FROM Case WHERE Id = :testCase.Id LIMIT 1];
        Assert.areEqual(true, updatedCase.breg_Override_Payment__c, 'Successful mapping should force override payment on the Case');

        breg_WEB_WEB_FILING_INFO__c filingInfo = [
            SELECT breg_Mapped_Date__c, breg_Mapping_Status__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c = :testCase.Id
            LIMIT 1
        ];
        Assert.isNotNull(filingInfo.breg_Mapped_Date__c, 'Mapped date should be written after mapping completes');
        Assert.areEqual(Date.today(), filingInfo.breg_Mapped_Date__c.date(), 'Mapped date should be written using the current date');
        Assert.areEqual('Completed', filingInfo.breg_Mapping_Status__c, 'Successful mapping should set Completed status');
        Map<String, Object> mappingLog = getMappingLog(filingInfo.breg_Mapping_Log__c);
        Assert.isTrue(mappingLog.containsKey('originalCase'), 'Mapping log should include original case JSON');
        Assert.isTrue(mappingLog.containsKey('updatedCase'), 'Mapping log should include updated case JSON');
        Assert.isTrue(mappingLog.containsKey('debugMessages'), 'Mapping log should include debug messages');

        Map<String, Object> originalCaseLog = (Map<String, Object>) mappingLog.get('originalCase');
        Assert.areEqual('Case', (String) originalCaseLog.get('objectApiName'), 'Case snapshots should identify the object type');
        Assert.isTrue(originalCaseLog.containsKey('fields'), 'Case snapshots should store field values in a dedicated fields node');
    }

    @isTest
    static void testInvocableBulkRecords() {
        Case case1 = [SELECT Id FROM Case LIMIT 1];

        Case case2 = new Case(Status = 'New', Origin = 'Web');
        insert case2;
        insert new breg_WEB_WEB_FILING_INFO__c(breg_WEB_Case__c = case2.Id, breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Second Company Inc');

        BREGWebFilingMapperInvocable.InvocableRequest req1 = new BREGWebFilingMapperInvocable.InvocableRequest();
        req1.workitemId = case1.Id;
        BREGWebFilingMapperInvocable.InvocableRequest req2 = new BREGWebFilingMapperInvocable.InvocableRequest();
        req2.workitemId = case2.Id;

        Test.startTest();
        List<BREGWebFilingMapperInvocable.InvocableResult> results = BREGWebFilingMapperInvocable.mapFilingDataToCase(
            new List<BREGWebFilingMapperInvocable.InvocableRequest>{ req1, req2 }
        );
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return one result per request');
        Assert.areEqual('Test Company LLC', results[0].nameOfEntity, 'First result should map case1');
        Assert.areEqual('Second Company Inc', results[1].nameOfEntity, 'Second result should map case2');
    }

    @isTest
    static void testInvocableNoMatchingFilingInfo() {
        Case caseWithoutFiling = new Case(Status = 'New', Origin = 'Web');
        insert caseWithoutFiling;

        BREGWebFilingMapperInvocable.InvocableRequest request = new BREGWebFilingMapperInvocable.InvocableRequest();
        request.workitemId = caseWithoutFiling.Id;

        Test.startTest();
        List<BREGWebFilingMapperInvocable.InvocableResult> results = BREGWebFilingMapperInvocable.mapFilingDataToCase(
            new List<BREGWebFilingMapperInvocable.InvocableRequest>{ request }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isNull(results[0].nameOfEntity, 'nameOfEntity should be null when no filing info exists');
    }

    @isTest
    static void testInvocableBlocksRelatedRecordInsertsWhenLogContainsRelatedRecords() {
        Account entity = createTestEntityAccount('Affiliation Entity', '55555-D1', 1);

        Case testCase = createTestRelatedRecordsCase('Affiliation Entity', entity.Id);

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = entity.Name,
            breg_Mapping_Status__c = 'Completed',
            breg_Mapping_Log__c = '{"relatedRecords":{"accountAffiliations":[{"Name":"Existing Affiliation"}],"stocks":[],"tradeMarks":[]}}'
        );
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_PERSON_NAME__c = 'Jane Doe',
            breg_WEB_PERSON_SEQ__c = 1,
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_COUNTRY_CODE_2__c = 'US',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_ADDRESS_LINE_1__c = '123 Main St'
        );

        BREGWebFilingMapperInvocable.InvocableRequest request = new BREGWebFilingMapperInvocable.InvocableRequest();
        request.workitemId = testCase.Id;

        Test.startTest();
        BREGWebFilingMapperInvocable.mapFilingDataToCase(new List<BREGWebFilingMapperInvocable.InvocableRequest>{ request });
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT count() FROM breg_Account_Affiliation__c WHERE breg_Case__c = :testCase.Id],
            'Related record inserts should be blocked when the mapping log contains related records'
        );

        breg_WEB_WEB_FILING_INFO__c filingInfo = [
            SELECT breg_Mapping_Status__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c = :testCase.Id
            LIMIT 1
        ];
        Assert.areEqual('Completed', filingInfo.breg_Mapping_Status__c, 'Case mapping should still complete when inserts are blocked');
        Map<String, Object> mappingLog = getMappingLog(filingInfo.breg_Mapping_Log__c);
        Map<String, Object> relatedRecords = (Map<String, Object>) mappingLog.get('relatedRecords');
        Assert.isTrue(relatedRecords.containsKey('accountAffiliations'), 'Mapping log should include related records JSON');
        Assert.isTrue(
            getDebugMessages(mappingLog).contains('Insert operations were blocked because the existing mapping log already contains related records.'),
            'Mapping log should explain why inserts were skipped'
        );
    }

    @isTest
    static void testInvocableBlocksRelatedRecordInsertsWhenParsedLogContainsRelatedRecords() {
        Account entity = createTestEntityAccount('Parsed Affiliation Entity', '55556-D1', 2);

        Case testCase = createTestRelatedRecordsCase('Parsed Affiliation Entity', entity.Id);

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = entity.Name,
            breg_Mapping_Status__c = 'Completed',
            breg_Mapping_Log__c = '{"relatedRecords":{"accountAffiliations":["Existing Affiliation"],"stocks":[],"tradeMarks":[]}}'
        );
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_PERSON_NAME__c = 'Parsed Jane Doe',
            breg_WEB_PERSON_SEQ__c = 1,
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_COUNTRY_CODE_2__c = 'US',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_ADDRESS_LINE_1__c = '123 Parsed Main St'
        );

        BREGWebFilingMapperInvocable.InvocableRequest request = new BREGWebFilingMapperInvocable.InvocableRequest();
        request.workitemId = testCase.Id;

        Test.startTest();
        BREGWebFilingMapperInvocable.mapFilingDataToCase(new List<BREGWebFilingMapperInvocable.InvocableRequest>{ request });
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT count() FROM breg_Account_Affiliation__c WHERE breg_Case__c = :testCase.Id],
            'Parsed related-record logs should still block inserts.'
        );

        breg_WEB_WEB_FILING_INFO__c filingInfo = [
            SELECT breg_Mapping_Status__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c = :testCase.Id
            LIMIT 1
        ];
        Assert.areEqual('Completed', filingInfo.breg_Mapping_Status__c, 'Case mapping should still complete when parsed inserts are blocked');
        Assert.isTrue(
            getDebugMessages(getMappingLog(filingInfo.breg_Mapping_Log__c))
                .contains('Insert operations were blocked because the existing mapping log already contains related records.'),
            'Parsed related-record logs should still produce the skip debug message.'
        );
    }

    @isTest
    static void testInvocableInsertsRelatedRecordsWhenExistingLogIsEmpty() {
        Account entity = createTestEntityAccount('Insert Affiliation Entity', '66666-D1', 1);

        Case testCase = createTestRelatedRecordsCase('Insert Affiliation Entity', entity.Id);

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = entity.Name
        );
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_PERSON_NAME__c = 'John Smith',
            breg_WEB_PERSON_SEQ__c = 1,
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_COUNTRY_CODE_2__c = 'US',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_ADDRESS_LINE_1__c = '456 Main St'
        );
        insert buildWebStock(testCase.Id, 345239, '100');

        BREGWebFilingMapperInvocable.InvocableRequest request = new BREGWebFilingMapperInvocable.InvocableRequest();
        request.workitemId = testCase.Id;

        Test.startTest();
        BREGWebFilingMapperInvocable.mapFilingDataToCase(new List<BREGWebFilingMapperInvocable.InvocableRequest>{ request });
        Test.stopTest();

        breg_WEB_WEB_FILING_INFO__c filingInfo = [
            SELECT breg_Mapping_Status__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c = :testCase.Id
            LIMIT 1
        ];

        Assert.areEqual(
            1,
            [SELECT count() FROM breg_Account_Affiliation__c WHERE breg_Case__c = :testCase.Id],
            filingInfo.breg_Mapping_Log__c + 'Related record inserts should run when no existing related-record log exists'
        );
        Assert.areEqual(
            1,
            [SELECT count() FROM breg_Stock__c WHERE breg_Case__c = :testCase.Id],
            'Stock inserts should run when no existing related-record log exists'
        );

        Assert.areEqual('Completed', filingInfo.breg_Mapping_Status__c, 'Case mapping should remain completed when related inserts succeed');
        Map<String, Object> mappingLog = getMappingLog(filingInfo.breg_Mapping_Log__c);
        Assert.isTrue(
            getDebugMessages(mappingLog).contains('Inserted related records: affiliations=1, stocks=1, tradeMarks=0.'),
            'Mapping log should capture the executed related-record inserts'
        );
    }

    @isTest
    static void testInvocableBulkInsertsRelatedRecordsForMultipleRequests() {
        Account entityOne = createTestEntityAccount('Bulk Entity One', '77777-D1', 1);
        Account entityTwo = createTestEntityAccount('Bulk Entity Two', '88888-D1', 2);

        Case firstCase = createTestRelatedRecordsCase('Bulk Entity One', entityOne.Id);
        Case secondCase = createTestRelatedRecordsCase('Bulk Entity Two', entityTwo.Id);

        insert new List<breg_WEB_WEB_FILING_INFO__c>{
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = firstCase.Id,
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = entityOne.Name
            ),
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = secondCase.Id,
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = entityTwo.Name
            )
        };

        insert new List<breg_WEB_WEB_PERSONS__c>{
            new breg_WEB_WEB_PERSONS__c(
                breg_WEB_Case__c = firstCase.Id,
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_PERSON_TYPE__c = 'OFCR',
                breg_WEB_PERSON_FL__c = 'Y',
                breg_WEB_PERSON_NAME__c = 'Bulk Person One',
                breg_WEB_PERSON_SEQ__c = 1,
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_COUNTRY_CODE_2__c = 'US',
                breg_WEB_CITY__c = 'Honolulu',
                breg_WEB_POSTAL_CODE__c = '96813',
                breg_WEB_ADDRESS_LINE_1__c = '111 Bulk St'
            ),
            new breg_WEB_WEB_PERSONS__c(
                breg_WEB_Case__c = secondCase.Id,
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_PERSON_TYPE__c = 'OFCR',
                breg_WEB_PERSON_FL__c = 'Y',
                breg_WEB_PERSON_NAME__c = 'Bulk Person Two',
                breg_WEB_PERSON_SEQ__c = 1,
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_COUNTRY_CODE_2__c = 'US',
                breg_WEB_CITY__c = 'Honolulu',
                breg_WEB_POSTAL_CODE__c = '96813',
                breg_WEB_ADDRESS_LINE_1__c = '222 Bulk St'
            )
        };
        insert new List<breg_WEB_WEB_STOCKS__c>{
            buildWebStock(firstCase.Id, 445001, '100'),
            buildWebStock(secondCase.Id, 445002, '200')
        };

        BREGWebFilingMapperInvocable.InvocableRequest firstRequest = new BREGWebFilingMapperInvocable.InvocableRequest();
        firstRequest.workitemId = firstCase.Id;
        BREGWebFilingMapperInvocable.InvocableRequest secondRequest = new BREGWebFilingMapperInvocable.InvocableRequest();
        secondRequest.workitemId = secondCase.Id;

        Test.startTest();
        BREGWebFilingMapperInvocable.mapFilingDataToCase(
            new List<BREGWebFilingMapperInvocable.InvocableRequest>{ firstRequest, secondRequest }
        );
        Test.stopTest();

        Assert.areEqual(1, [SELECT count() FROM breg_Account_Affiliation__c WHERE breg_Case__c = :firstCase.Id]);
        Assert.areEqual(1, [SELECT count() FROM breg_Account_Affiliation__c WHERE breg_Case__c = :secondCase.Id]);
    Assert.areEqual(1, [SELECT count() FROM breg_Stock__c WHERE breg_Case__c = :firstCase.Id]);
    Assert.areEqual(1, [SELECT count() FROM breg_Stock__c WHERE breg_Case__c = :secondCase.Id]);

        Map<Id, breg_WEB_WEB_FILING_INFO__c> filingInfosByCaseId = new Map<Id, breg_WEB_WEB_FILING_INFO__c>();
        for (breg_WEB_WEB_FILING_INFO__c filingInfo : [
            SELECT breg_WEB_Case__c, breg_Mapping_Status__c, breg_Mapping_Log__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c IN :new Set<Id>{ firstCase.Id, secondCase.Id }
        ]) {
            filingInfosByCaseId.put(filingInfo.breg_WEB_Case__c, filingInfo);
        }

        Assert.areEqual('Completed', filingInfosByCaseId.get(firstCase.Id).breg_Mapping_Status__c);
        Assert.areEqual('Completed', filingInfosByCaseId.get(secondCase.Id).breg_Mapping_Status__c);
        Assert.isTrue(
            getDebugMessages(getMappingLog(filingInfosByCaseId.get(firstCase.Id).breg_Mapping_Log__c))
                .contains('Inserted related records: affiliations=1, stocks=1, tradeMarks=0.'),
            'First request should log its related-record insert summary.'
        );
        Assert.isTrue(
            getDebugMessages(getMappingLog(filingInfosByCaseId.get(secondCase.Id).breg_Mapping_Log__c))
                .contains('Inserted related records: affiliations=1, stocks=1, tradeMarks=0.'),
            'Second request should log its related-record insert summary.'
        );
    }

    private static breg_WEB_WEB_STOCKS__c buildWebStock(Id caseId, Decimal stockId, String sharesCount) {
        return new breg_WEB_WEB_STOCKS__c(
            breg_Web_Case__c = caseId,
            breg_WEB_STOCK_ID__c = stockId,
            breg_WEB_STOCK_CLASS__c = 'Common',
            breg_WEB_STOCK_AMOUNT__c = sharesCount,
            breg_WEB_SHARES_CNT__c = sharesCount,
            breg_WEB_PAID_SHARES__c = sharesCount,
            breg_WEB_PAR_VALUE__c = '1',
            breg_WEB_WEB_ACTION_CODE__c = 'N'
        );
    }

    private static Account createTestEntityAccount(String name, String fileNumber, Integer sequence) {
        String uniqueSuffix = String.valueOf(sequence) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account entity = new Account(
            Name = name + ' ' + uniqueSuffix,
            RecordTypeId = bregAccountRecordTypeId,
            BillingPostalCode = uniqueSuffix.left(5),
            breg_Incorporation_Date__c = Date.today(),
            breg_Entity_Type__c = 'D1',
            breg_File__c = fileNumber,
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;
        return entity;
    }

    private static Case createTestRelatedRecordsCase(String entityName, Id entityId) {
        Account entity = [SELECT Name FROM Account WHERE Id = :entityId LIMIT 1];
        breg_Form_Configuration__c formConfiguration = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Transaction_Code__c = 'ART'
        );
        insert formConfiguration;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Invocable Related Records Test',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfiguration.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Name_of_the_Entity__c = entity != null ? entity.Name : entityName,
            breg_Effective_Date__c = Date.today(),
            breg_Entity__c = entityId
        );
        insert testCase;
        return testCase;
    }

    private static Map<String, Object> getMappingLog(String mappingLogJson) {
        Assert.isNotNull(mappingLogJson, 'Mapping log should be written');
        return (Map<String, Object>) JSON.deserializeUntyped(normalizeMappingLogJson(mappingLogJson));
    }

    private static String normalizeMappingLogJson(String mappingLogJson) {
        return mappingLogJson
            .replace('&quot;', '"')
            .replace('&#39;', '\'')
            .replace('&amp;', '&')
            .replace('&lt;', '<')
            .replace('&gt;', '>');
    }

    private static List<String> getDebugMessages(Map<String, Object> mappingLog) {
        List<String> debugMessages = new List<String>();
        if (mappingLog == null || !(mappingLog.get('debugMessages') instanceof List<Object>)) {
            return debugMessages;
        }

        for (Object debugMessage : (List<Object>) mappingLog.get('debugMessages')) {
            debugMessages.add((String) debugMessage);
        }
        return debugMessages;
    }
}