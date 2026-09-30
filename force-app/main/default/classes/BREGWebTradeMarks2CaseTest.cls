@isTest
private class BREGWebTradeMarks2CaseTest {
    private static final String BASE_CASE_SUBJECT = 'BREGWebTradeMarks2CaseTest Base';

    @testSetup
    static void setupData() {
        Case testCase = new Case(Status = 'New', Origin = 'Web', Subject = BASE_CASE_SUBJECT);
        insert testCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_FORM_TYPE__c = 'T2'
        );

        insert new breg_WEB_WEB_TRADE_MARKS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_TRADE_TYPE__c = 'TN',
            breg_WEB_CERTIFICATE_NO__c = 12345,
            breg_WEB_TRADE_NAME__c = 'Island Trade Name',
            breg_WEB_TRADE_MARK_DESC__c = 'A quality trade mark',
            breg_WEB_PURPOSE__c = 'Retail goods and services',
            breg_WEB_NOTES__c = 'Store front signage'
        );
    }

    // ─── Case TNTMSM field mapping ────────────────────────────────────────────

    @isTest
    static void testMapsCaseFields() {
        Case testCase = getBaseCase();
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebTradeMarks2Case mapper = new BREGWebTradeMarks2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');
        Assert.isFalse(results.get(testCase.Id).isEmpty(), 'There should be at least one source record');

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('Trade Name', webCase.breg_TNTMSM_Type__c, 'TNTMSM Type should be mapped from trade type TN');
        Assert.areEqual('12345', webCase.breg_TNTMSM_Certificate__c, 'Certificate number should be mapped as string');
        Assert.areEqual('Island Trade Name', webCase.breg_TNTMSM_Description__c, 'Description should be mapped from TRADE_NAME');
        Assert.areEqual('Retail goods and services', webCase.breg_TNTMSM_Goods_Or_Services__c, 'Goods or services should be mapped from PURPOSE');
        Assert.areEqual('Store front signage', webCase.breg_TNTMSM_Mode_Or_Manner__c, 'Mode or manner should be mapped from NOTES');
    }

    @isTest
    static void testMapsCertificateFromLatestActiveMatchingTnTmSmWhenSourceCertificateMissing() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_CERTIFICATE_NO__c = null;
        update tmRecord;

        Date expirationDate = Date.today().addYears(1);
        breg_TN_TM_SM__c olderActiveRecord = new breg_TN_TM_SM__c(
            Name = 'Island Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Cert_Number__c = 'CERT-OLD',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_Expiration_Date__c = expirationDate 
        );
        breg_TN_TM_SM__c latestActiveRecord = new breg_TN_TM_SM__c(
            Name = 'Island Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Cert_Number__c = 'CERT-LATEST',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_Expiration_Date__c = expirationDate
        );
        insert new List<breg_TN_TM_SM__c>{ olderActiveRecord, latestActiveRecord };

        Test.setCreatedDate(olderActiveRecord.Id, Datetime.newInstance(2024, 1, 1, 0, 0, 0));
        Test.setCreatedDate(latestActiveRecord.Id, Datetime.newInstance(2024, 2, 1, 0, 0, 0));

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(
            'Renewal',
            wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Registration_Type__c,
            'Registration type should be set to Renewal when certificate is sourced from active TNTMSM record'
        );
        Assert.areEqual(
            'CERT-LATEST',
            wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Certificate__c,
            'Latest matching active TNTMSM record should provide the certificate number when the source certificate is blank'
        );
    }

    @isTest
    static void testExpiredMatchingTnTmSmDoesNotTriggerRenewal() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_CERTIFICATE_NO__c = null;
        update tmRecord;

        insert new breg_TN_TM_SM__c(
            Name = 'Island Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Cert_Number__c = 'CERT-EXPIRED',
            breg_Status__c = 'E',
            breg_End_Date__c = Date.today().addDays(-1)
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(
            wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Certificate__c,
            'Expired matching TNTMSM records should not provide a certificate number'
        );
        Assert.areEqual('New', wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Registration_Type__c, 'Expired matching TNTMSM records should leave the filing as New');
    }

    @isTest
    static void testActiveMatchingDifferentTradeTypeDoesNotTriggerRenewal() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_CERTIFICATE_NO__c = null;
        update tmRecord;

        insert new breg_TN_TM_SM__c(
            Name = 'Island Trade Name',
            breg_Type__c = 'Trademark',
            breg_Cert_Number__c = 'CERT-TM',
            breg_Status__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Certificate__c, 'Different active trade type should not provide a certificate number');
        Assert.areEqual('New', wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Registration_Type__c, 'Different active trade type should leave the filing as New');
    }

    // ─── Trade type mapping to Case.breg_TNTMSM_Type__c ──────────────────────

    @isTest
    static void testTradeTypeTMMapsToTNTMSMType() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_TRADE_TYPE__c = 'TM';
        update tmRecord;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual('Trademark', wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Type__c, 'TM should map to Trademark');
    }

    @isTest
    static void testTradeTypeSMMapsToTNTMSMType() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_TRADE_TYPE__c = 'SM';
        update tmRecord;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual('Service Mark', wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Type__c, 'SM should map to Service Mark');
    }

    @isTest
    static void testTradeTypePRMapsToTNTMSMType() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_TRADE_TYPE__c = 'PR';
        update tmRecord;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual('Publicity Rights Name', wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Type__c, 'PR should map to Publicity Rights Name');
    }

    @isTest
    static void testUnknownTradeTypeResultsInNullTNTMSMType() {
        Case testCase = getBaseCase();

        breg_WEB_WEB_TRADE_MARKS__c tmRecord = [SELECT Id FROM breg_WEB_WEB_TRADE_MARKS__c LIMIT 1];
        tmRecord.breg_WEB_TRADE_TYPE__c = 'XX';
        update tmRecord;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(wrapperMap.get(testCase.Id).WebCase.breg_TNTMSM_Type__c, 'Unknown trade type should result in null TNTMSM_Type__c');
    }

    // ─── Only first record is used for Case fields ────────────────────────────

    @isTest
    static void testOnlyFirstRecordMappedToCaseFields() {
        Case testCase = getBaseCase();

        insert new breg_WEB_WEB_TRADE_MARKS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_TRADE_TYPE__c = 'TM',
            breg_WEB_TRADE_NAME__c = 'Second Trade Name',
            breg_WEB_TRADE_MARK_DESC__c = 'Second record description'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebTradeMarks2Case(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // The first-inserted record (TRADE_TYPE = TN) should be used for Case fields
        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('Island Trade Name', webCase.breg_TNTMSM_Description__c, 'Only the first record should set Case fields');
    }

    // ─── Edge cases ───────────────────────────────────────────────────────────

    @isTest
    static void testNoSourceRecordsLeavesNullCaseFields() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebTradeMarks2Case mapper = new BREGWebTradeMarks2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no source records exist');
        Assert.isNull(wrapperMap.get(emptyCase.Id).WebCase.breg_TNTMSM_Type__c, 'Case TNTMSM fields should remain null when no source records exist');
    }

    @isTest
    static void testNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebTradeMarks2Case mapper = new BREGWebTradeMarks2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebTradeMarks2Case mapper = new BREGWebTradeMarks2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }

    private static Case getBaseCase() {
        return [SELECT Id FROM Case WHERE Subject = :BASE_CASE_SUBJECT LIMIT 1];
    }
}