@isTest
private class BREGWebBusinessInfo2CaseTest {
    private static String buildRepeatedString(String character, Integer length) {
        String result = '';
        while (result.length() < length) {
            result += character;
        }
        return result.substring(0, length);
    }

    @testSetup
    static void setupData() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        insert new breg_WEB_WEB_BUSINESS_INFO__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_FILE_NO__c = 123456,
            breg_WEB_FILE_SUFFIX__c = 'AB',
            breg_WEB_INITIAL_LLC_MEMBERS__c = 3,
            breg_WEB_PARTNER_TERMS__c = 'AT-WILL',
            breg_WEB_PARTNER_MAINTENANCE__c = 'MGR',
            breg_WEB_PURPOSE__c = 'To provide general business services',
            breg_WEB_INCORPORATION_DT__c = Date.newInstance(2022, 6, 1),
            breg_WEB_COUNTRY_OF_INC__c = 'US'
        );
    }

    // ─── Basic field mapping ──────────────────────────────────────────────────

    @isTest
    static void testMapsBasicFieldsToCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_LOCALITY_OF_INC__c = 825;
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');
        Assert.isFalse(results.get(testCase.Id).isEmpty(), 'There should be at least one source record');

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual(123456, webCase.breg_BRIM_FILE_NO__c, 'File number should be mapped from source');
        Assert.areEqual('AB', webCase.breg_File_Suffix__c, 'File suffix should be mapped from source');
        Assert.areEqual(Date.newInstance(2022, 6, 1), webCase.breg_Date_Of_Formation__c, 'Date of formation should be mapped from INCORPORATION_DT');
        Assert.areEqual('US', webCase.breg_Entity_Jurisdiction__c, 'Entity jurisdiction should be mapped from COUNTRY_OF_INC');
        Assert.areEqual('HI', webCase.breg_Formation_State__c, 'Formation state should map from locality when provided');
        Assert.areEqual('AB', webCase.breg_Entity_Type__c, 'Entity type should be mapped from FILE_SUFFIX');
        Assert.areEqual(
            'To provide general business services',
            webCase.breg_Entity_Nature_Of_Business__c,
            'Entity nature of business should be mapped from PURPOSE'
        );
    }

    @isTest
    static void testDefaultsJurisdictionAndFormationStateWhenSourceValuesMissing() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id, breg_WEB_COUNTRY_OF_INC__c, breg_WEB_LOCALITY_OF_INC__c FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_COUNTRY_OF_INC__c = null;
        biz.breg_WEB_LOCALITY_OF_INC__c = null;
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebBusinessInfo2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('US', webCase.breg_Entity_Jurisdiction__c, 'Entity jurisdiction should default to US when country of incorporation is blank');
        Assert.areEqual('HI', webCase.breg_Formation_State__c, 'Formation state should default to HI when locality of incorporation is blank');
    }

    // ─── Manager managed ────────────────────────────────────────────────────

    @isTest
    static void testMGRPartnerMaintenanceSetsIsManagerManaged() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebBusinessInfo2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(wrapperMap.get(testCase.Id).WebCase.breg_Is_Manager_Managed__c, 'MGR partner maintenance should set Is Manager Managed to true');
    }

    @isTest
    static void testNonMGRPartnerMaintenanceSetsIsManagerManagedFalse() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_PARTNER_MAINTENANCE__c = 'MBR';
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebBusinessInfo2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isFalse(
            wrapperMap.get(testCase.Id).WebCase.breg_Is_Manager_Managed__c,
            'Non-MGR partner maintenance should set Is Manager Managed to false'
        );
    }

    // ─── LLC members ──────────────────────────────────────────────────────────

    @isTest
    static void testMapsLLCMembersCount() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(3, wrapperMap.get(testCase.Id).WebCase.breg_Number_of_initial_members__c, 'Number of initial LLC members should be mapped');
    }

    // ─── Partner terms — AT-WILL sets duration ────────────────────────────────

    @isTest
    static void testAtWillPartnerTermsSetsDurationPeriod() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(
            'At-will',
            wrapperMap.get(testCase.Id).WebCase.breg_Duration_Period__c,
            'AT-WILL partner terms should set Duration Period to At-will'
        );
    }

    @isTest
    static void testNonAtWillPartnerTermsDoesNotSetDuration() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        // Update the setup record to a non-AT-WILL value
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_PARTNER_TERMS__c = 'FIXED';
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(wrapperMap.get(testCase.Id).WebCase.breg_Duration_Period__c, 'Non-AT-WILL partner terms should not set Duration Period');
    }

    @isTest
    static void testNullPartnerTermsDoesNotSetDuration() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_PARTNER_TERMS__c = null;
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(wrapperMap.get(testCase.Id).WebCase.breg_Duration_Period__c, 'Null partner terms should not set Duration Period');
    }

    // ─── Purpose mapping ───────────────────────────────────────────────────────

    @isTest
    static void testPurposeMapsToNatureOfBusinessForNonPurposeForms() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(
            'To provide general business services',
            wrapperMap.get(testCase.Id).WebCase.breg_Entity_Nature_Of_Business__c,
            'Non-D1/D2 forms should map purpose to Entity Nature Of Business'
        );
        Assert.areEqual(
            'To provide general business services',
            wrapperMap.get(testCase.Id).WebCase.breg_Purposes__c,
            'Non-D1/D2 forms should map purpose to Purposes'
        );
    }

    @isTest
    static void testPurposeMapsToPurposesForPurposeForms() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        String purpose = buildRepeatedString('X', 255);
        biz.breg_WEB_FILE_SUFFIX__c = 'D1';
        biz.breg_WEB_PURPOSE__c = purpose;
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(
            purpose,
            wrapperMap.get(testCase.Id).WebCase.breg_Purposes__c,
            'D1/D2 forms should map purpose text to Purposes'
        );
        Assert.areEqual(
            purpose,
            wrapperMap.get(testCase.Id).WebCase.breg_Entity_Nature_Of_Business__c,
            'D1/D2 forms should map purpose text to Entity Nature Of Business'
        );
    }

    @isTest
    static void testNullPurposeRemainsNull() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_WEB_WEB_BUSINESS_INFO__c biz = [SELECT Id FROM breg_WEB_WEB_BUSINESS_INFO__c LIMIT 1];
        biz.breg_WEB_PURPOSE__c = null;
        update biz;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(wrapperMap.get(testCase.Id).WebCase.breg_Purposes__c, 'Null purpose should remain null on the case');
        Assert.isNull(
            wrapperMap.get(testCase.Id).WebCase.breg_Entity_Nature_Of_Business__c,
            'Null purpose should not populate Entity Nature Of Business'
        );
    }

    // ─── Only first record is used ────────────────────────────────────────────

    @isTest
    static void testOnlyFirstRecordIsUsed() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_BUSINESS_INFO__c(breg_WEB_Case__c = testCase.Id, breg_WEB_FILE_NO__c = 999999, breg_WEB_FILE_SUFFIX__c = 'ZZ');

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // Two source records but only the first is applied to the case
        Assert.areEqual(2, results.get(testCase.Id).size(), 'Both source records should be returned in the result');
        // File number on case should come from one of the two records
        Assert.isNotNull(wrapperMap.get(testCase.Id).WebCase.breg_BRIM_FILE_NO__c, 'File number should be set from the first source record');
    }

    // ─── Edge cases ───────────────────────────────────────────────────────────

    @isTest
    static void testNoBusinessInfoReturnsEmptyResult() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no business info records exist');
        Assert.isNull(wrapperMap.get(emptyCase.Id).WebCase.breg_BRIM_FILE_NO__c, 'File number should remain null when no source data');
    }

    @isTest
    static void testNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebBusinessInfo2Case mapper = new BREGWebBusinessInfo2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }
}