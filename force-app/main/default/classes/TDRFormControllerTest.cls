@IsTest
public with sharing class TDRFormControllerTest {
    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;

        date sd = Date.Today();

        Deposits__c xDeposit = new Deposits__c();
        xDeposit.DepositDate__c = sd;
        xDeposit.DepositNumber__c = '223322';
        xDeposit.DepositNumber__c = 'Draft';
        insert xDeposit;

        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();

        pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
        currentYearPayment1.pymt__Status__c = 'Completed';
        currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
        currentYearPayment1.RemitToDCCA__c = 50;
        currentYearPayment1.PPIFeeAmount__c = 100;
        currentYearPayment1.HIGETaxAmount__c = 150;
        currentYearPayment1.DepositBatch__c = xDeposit.Id;
        currentYearPayment1.pymt__Payment_Type__c = 'Cash';
        payments.add(currentYearPayment1);

        pymt__PaymentX__c currentYearPayment2 = new pymt__PaymentX__c();
        currentYearPayment2.pymt__Status__c = 'Completed';
        currentYearPayment2.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
        currentYearPayment2.RemitToDCCA__c = 50;
        currentYearPayment2.PPIFeeAmount__c = 100;
        currentYearPayment2.HIGETaxAmount__c = 150;
        currentYearPayment2.DepositBatch__c = xDeposit.Id;
        currentYearPayment2.pymt__Payment_Type__c = 'Check or Money Order';
        payments.add(currentYearPayment2);

        pymt__PaymentX__c currentYearPayment3 = new pymt__PaymentX__c();
        currentYearPayment3.pymt__Status__c = 'Completed';
        currentYearPayment3.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
        currentYearPayment3.RemitToDCCA__c = 50;
        currentYearPayment3.PPIFeeAmount__c = 100;
        currentYearPayment3.HIGETaxAmount__c = 150;
        currentYearPayment3.DepositBatch__c = xDeposit.Id;
        currentYearPayment3.pymt__Payment_Type__c = 'Credit Card';
        payments.add(currentYearPayment3);

        insert payments;

        Transaction__c trns1 = new Transaction__c();
        trns1.Account__c = acc.Id;
        trns1.WorkitemID__c = '1';
        insert trns1;

        TransactionLine__c trLine = new TransactionLine__c();
        trLine.Transaction__c = trns1.Id;
        insert trLine;

        CollectionsAllocation__c alloc = new CollectionsAllocation__c();
        alloc.Deposit__c = xDeposit.Id;
        alloc.TransactionLine__c = trLine.Id;
        alloc.CutOffBatchDate__c = System.now();
        alloc.Payment__c = currentYearPayment1.Id;
        insert alloc;
    }

    @IsTest
    static void testSearchMethod() {
        List<CollectionsAllocation__c> records = [Select Id, CutOffBatchDate__c,
        TransactionLine__r.CashierCode__r.Division__c, TransactionLine__r.CashierCode__r.FundAccount__c,
        PaymentType__c from CollectionsAllocation__c];
        String division = records.get(0).TransactionLine__r.CashierCode__r.Division__c;
        String paymentType = records.get(0).PaymentType__c;
        String fundAccount = records.get(0).TransactionLine__r.CashierCode__r.FundAccount__c;
        Date cutOffDate = Date.valueOf(records.get(0).CutOffBatchDate__c);
        FiscalFormFeed.SearchFeed feed = new FiscalFormFeed.SearchFeed();
        feed.cutOffDate = cutOffDate;
        feed.paymentType = paymentType;
        feed.fundType = fundAccount;
        feed.division = division;
        feed.startDate = cutOffDate.addDays(-5);
        List<Map<String, Object>> m = (new TDRFormController()).allRecords;
        String results = TDRFormController.searchData(JSON.serialize(feed));
    }

    @IsTest
    static void testSearchMethod2() {
        List<CollectionsAllocation__c> records = [
            SELECT
                Id,
                CutOffBatchDate__c,
                TransactionLine__r.CashierCode__r.Division__c,
                TransactionLine__r.CashierCode__r.FundAccount__c,
                PaymentType__c
            FROM CollectionsAllocation__c
        ];
        String division = records.get(0).TransactionLine__r.CashierCode__r.Division__c;
        String paymentType = records.get(0).PaymentType__c;
        Date cutOffDate = Date.valueOf(records.get(0).CutOffBatchDate__c);
        FiscalFormFeed.SearchFeed feed = new FiscalFormFeed.SearchFeed();
        feed.cutOffDate = cutOffDate;
        feed.paymentType = paymentType;
        feed.fundType = 'Trust';
        feed.fundAccounts = '[]';
        feed.division = division;
        feed.startDate = cutOffDate.addDays(-5);
        String results = TDRFormController.searchData(JSON.serialize(feed));
        feed.paymentType = null;
        String results2 = TDRFormController.searchData(JSON.serialize(feed));
    }

    @IsTest
    static void testController2() {
        ApexPages.currentPage().getParameters().put('copy', '2');
        TDRFormController ctrl = new TDRFormController();
    }

    @IsTest
    static void testController() {
        Schema.DescribeSObjectResult d = Schema.SObjectType.FiscalForm__c;
        Map<String, Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosByName();
        String recordTypeId = rtMapById.get('TDR').getRecordTypeId();
        String str = '[{"fundName":"SPECIAL","detailFund":"BUSINESS REGISTRATION - PVL","dateStr":"11/02/2020","remarks":"02/25.26.27 First Hawaii","totalDeposit":"1306.57","bankDeposit":"1306.57","electronicFundTransfer":"",' +
            '"creditCardProcessing":"","others":"","totalDeposit2":"1306.57","funds":[{"indexValue":"01","tcValue":"011","sValue":"S","yrValue":"21","appValue":"305","dValue":"R","sourceObjValue":"0159","costCenterValue":"0092",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":"1306.57"},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null}]}]';

        String feedStr = '{"fundType":"Special","paymentType":"Credit Card","cutOffDate":"2020-11-01","startDate":"2019-10-29","division":"PVL"}"';

        String recordId ;
        recordId = TDRFormController.submitForFile(str, recordId, recordTypeId, feedStr);
        ApexPages.currentPage().getParameters().put('recordId', recordId);
        ApexPages.currentPage().getParameters().put('copy', '1');
        TDRFormController ctrl = new TDRFormController();

    }

    @IsTest
    static void testSaveAsFile() {
        Schema.DescribeSObjectResult d = Schema.SObjectType.FiscalForm__c;
        Map<String, Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosByName();
        String recordTypeId = rtMapById.get('TDR').getRecordTypeId();
        String str = '[{"fundName":"SPECIAL","detailFund":"BUSINESS REGISTRATION - PVL","dateStr":"11/02/2020","remarks":"02/25.26.27 First Hawaii","totalDeposit":"1306.57","bankDeposit":"1306.57","electronicFundTransfer":"",' +
            '"creditCardProcessing":"","others":"","totalDeposit2":"1306.57","funds":[{"indexValue":"01","tcValue":"011","sValue":"S","yrValue":"21","appValue":"305","dValue":"R","sourceObjValue":"0159","costCenterValue":"0092",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":"1306.57"},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"",' +
            '"tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"",' +
            '"venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"",' +
            '"gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"","dValue":"","sourceObjValue":"","costCenterValue":"",' +
            '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null},{"indexValue":"","tcValue":"","sValue":"","yrValue":"","appValue":"",' +
            '"dValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","venterNumValue":"","venterSFXValue":"","amount":null}]}]';

        String feedStr = '{"fundType":"Special","paymentType":"Credit Card","cutOffDate":"2020-11-01","startDate":"2019-10-29","division":"PVL"}"';

        String recordId ;
        recordId = TDRFormController.submitForFile(str, recordId, recordTypeId, feedStr);
        Test.startTest();
        TDRFormController.saveAsFile(recordId);
        TDRFormController.submitForFile(str, recordId, recordTypeId, feedStr);
    }
}