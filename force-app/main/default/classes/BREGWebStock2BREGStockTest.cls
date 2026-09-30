@isTest
private class BREGWebStock2BREGStockTest {
    @testSetup
    static void setupData() {
        Account testAccount = new Account(Name = 'Test Entity');
        insert testAccount;

        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        insert new breg_WEB_WEB_STOCKS__c(
            breg_Web_Case__c = testCase.Id,
            breg_WEB_STOCK_ID__c = 338588,
            breg_WEB_STOCK_CLASS__c = 'Common',
            breg_WEB_STOCK_AMOUNT__c = '1000',
            breg_WEB_SHARES_CNT__c = '500',
            breg_WEB_PAID_SHARES__c = '200',
            breg_WEB_PAR_VALUE__c = '1.00',
            breg_WEB_REMARKS__c = 'Initial issuance',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );
    }

    // ─── Case field mapping ───────────────────────────────────────────────────

    @isTest
    static void testMapsCaseStockFields() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(testCase.Id).WebCase.breg_Entity__c = testAccount.Id;

        Test.startTest();
        new BREGWebStock2BREGStock(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('With Stock', webCase.breg_Stock_Type__c, 'Stock type should be set to With Stock');
        Assert.areEqual(1.00, webCase.breg_Par_Value_Of_Each_Share__c, 'Par value should be mapped from first record PAR_VALUE');
        Assert.areEqual(500, webCase.breg_Number_of_common_shares__c, 'Common shares count should be mapped from Common class record SHARES_CNT');
        Assert.areEqual(
            200,
            webCase.breg_Outstanding_Shares_Count__c,
            'Copies to be certified should be mapped from Common class record PAID_SHARES'
        );
    }

    @isTest
    static void testCaseStockTypeSetEvenWhenEntityIsNull() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebStock2BREGStock(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual('With Stock', wrapperMap.get(testCase.Id).WebCase.breg_Stock_Type__c, 'Case stock fields should be set even when entity is null');
        Assert.isTrue(wrapperMap.get(testCase.Id).Stocks.isEmpty(), 'Stocks should remain empty when entity is null');
    }

    @isTest
    static void testBlankParValueResultsInNullParValue() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        breg_WEB_WEB_STOCKS__c stockRecord = [SELECT Id FROM breg_WEB_WEB_STOCKS__c LIMIT 1];
        stockRecord.breg_WEB_PAR_VALUE__c = null;
        update stockRecord;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(testCase.Id).WebCase.breg_Entity__c = testAccount.Id;

        Test.startTest();
        new BREGWebStock2BREGStock(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isNull(
            wrapperMap.get(testCase.Id).WebCase.breg_Par_Value_Of_Each_Share__c,
            'Null par value should result in null breg_Par_Value_Of_Each_Share__c'
        );
    }

    // ─── Single stock (child record) mapping ───────────────────────────────────

    @isTest
    static void testMapsWebStockToBREGStock() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(testCase.Id).WebCase.breg_Entity__c = testAccount.Id;

        Test.startTest();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');
        Assert.isFalse(results.get(testCase.Id).isEmpty(), 'There should be at least one source record');

        List<breg_Stock__c> stocks = wrapperMap.get(testCase.Id).Stocks;
        Assert.areEqual(1, stocks.size(), 'There should be one stock record in the wrapper');

        breg_Stock__c stock = stocks[0];
        Assert.areEqual(testCase.Id, stock.breg_Case__c, 'Case lookup should be set');
        Assert.areEqual(testAccount.Id, stock.breg_Account__c, 'Account lookup should be set from WebCase entity');
        Assert.areEqual(338588, stock.breg_BRIM_STOCK_ID__c, 'BRIM Stock ID should be mapped from source Number field');
        Assert.areEqual('Common', stock.breg_Stock_Class__c, 'Stock class should be mapped');
        Assert.areEqual('1000', stock.breg_Stock_Amount__c, 'Stock amount should be mapped as text');
        Assert.areEqual('500', stock.breg_Number_of_Issued_Shares__c, 'Issued shares count should be mapped as text');
        Assert.areEqual('200', stock.breg_Paid_Shares__c, 'Paid shares should be mapped as text');
        Assert.areEqual('1.00', stock.breg_Per_Value__c, 'Par value should be mapped as text');
        Assert.areEqual('Initial issuance', stock.breg_Remarks__c, 'Remarks should be mapped');
    }

    // ─── Null entity skips child records ──────────────────────────────────────

    @isTest
    static void testNullEntitySkipsStock() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        // Do not set breg_Entity__c on the wrapper — stocks should not be added
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(wrapperMap.get(testCase.Id).Stocks.isEmpty(), 'No stocks should be added when WebCase.breg_Entity__c is null');
    }

    // ─── Action code — no filtering ───────────────────────────────────────────

    @isTest
    static void testAllActionCodesAreMapped() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        insert new breg_WEB_WEB_STOCKS__c(breg_Web_Case__c = testCase.Id, breg_WEB_STOCK_CLASS__c = 'Preferred', breg_WEB_WEB_ACTION_CODE__c = 'N');

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(testCase.Id).WebCase.breg_Entity__c = testAccount.Id;

        Test.startTest();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(2, wrapperMap.get(testCase.Id).Stocks.size(), 'All stock records should be mapped regardless of action code');
    }

    // ─── Multiple stocks ──────────────────────────────────────────────────────

    @isTest
    static void testMapsMultipleStocks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        insert new breg_WEB_WEB_STOCKS__c(
            breg_Web_Case__c = testCase.Id,
            breg_WEB_STOCK_CLASS__c = 'Preferred',
            breg_WEB_STOCK_AMOUNT__c = '500',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(testCase.Id).WebCase.breg_Entity__c = testAccount.Id;

        Test.startTest();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(2, wrapperMap.get(testCase.Id).Stocks.size(), 'Each stock record should produce one breg_Stock__c in the wrapper');
    }

    // ─── Edge cases ───────────────────────────────────────────────────────────

    @isTest
    static void testNoStocksReturnsEmptyList() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no stock records exist');
        Assert.isTrue(wrapperMap.get(emptyCase.Id).Stocks.isEmpty(), 'Stocks should remain empty when no web stock records exist');
    }

    @isTest
    static void testNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebStock2BREGStock mapper = new BREGWebStock2BREGStock(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }
}