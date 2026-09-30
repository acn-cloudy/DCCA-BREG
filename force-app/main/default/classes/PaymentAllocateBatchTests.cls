@isTest
public class PaymentAllocateBatchTests {

    @isTest
    static void TestNormal() {

        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        FeeSchedule__c fs = new FeeSchedule__c();
        fs.Name = '1st Year Fees';
        fs.BeginningDate__c = Date.today().addDays(-1);
        fs.EndingDate__c = Date.today().addDays(5);
        fs.PPIFeePercent__c = 9;
        fs.InflationPercent__c = 0.2;
        fs.HIGETaxPercent__c = 4.712;
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Description__c = 'Test';
        dummyCashierCode.Amount__c = 100;
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c();
        dummyTransactionLine.PaidStatus__c = 'Paid';
        dummyTransactionLine.Transaction__c = trn.Id;
        dummyTransactionLine.CashierCode__c = dummyCashierCode.Id;
        dummyTransactionLine.Amount__c = 100;
        insert dummyTransactionLine;

        // Run the code
        Test.startTest();
        PaymentAllocateBatchProgress ctrl =
                new PaymentAllocateBatchProgress(new Apexpages.StandardSetController(new List<pymt__PaymentX__c>()));
        ctrl.StartPaymentAllocationBatch();
        ctrl.BacktolistView();
        PaymentAllocateTransactionLinesBatch.schedule();
        Test.stopTest();
        ctrl.StartPaymentAllocationBatch();

        // Verify Results
        System.assertEquals(2, [SELECT COUNT() FROM CollectionsAllocation__c]);
    }

    @isTest
    static void TestGroup() {

        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        Transaction__c trn2 = new Transaction__c();
        trn2.TransactionGroup__c = trn.Id;
        trn2.Account__c = acc.Id;
        trn2.Contact__c = cnt.Id;
        insert trn2;

        FeeSchedule__c fs = new FeeSchedule__c();
        fs.Name = '1st Year Fees';
        fs.BeginningDate__c = Date.today().addDays(-1);
        fs.EndingDate__c = Date.today().addDays(5);
        fs.PPIFeePercent__c = 9;
        fs.InflationPercent__c = 0.2;
        fs.HIGETaxPercent__c = 4.712;
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Description__c = 'Test';
        dummyCashierCode.Amount__c = 100;
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c();
        dummyTransactionLine.PaidStatus__c = 'Paid';
        dummyTransactionLine.Transaction__c = trn2.Id;
        dummyTransactionLine.CashierCode__c = dummyCashierCode.Id;
        dummyTransactionLine.Amount__c = 100;
        insert dummyTransactionLine;

        // Run the code
        Test.startTest();
        PaymentAllocateBatchProgress ctrl =
                new PaymentAllocateBatchProgress(new Apexpages.StandardSetController(new List<pymt__PaymentX__c>()));
        ctrl.StartPaymentAllocationBatch();
        ctrl.BacktolistView();
        Test.stopTest();
        ctrl.StartPaymentAllocationBatch();

        // Verify Results
        System.assertEquals(2, [SELECT COUNT() FROM CollectionsAllocation__c]);
    }

    @isTest
    static void TestGroupWithoutTransactionLines() {

        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        Transaction__c trn2 = new Transaction__c();
        trn2.TransactionGroup__c = trn.Id;
        trn2.Account__c = acc.Id;
        trn2.Contact__c = cnt.Id;
        insert trn2;

        FeeSchedule__c fs = new FeeSchedule__c();
        fs.Name = '1st Year Fees';
        fs.BeginningDate__c = Date.today().addDays(-1);
        fs.EndingDate__c = Date.today().addDays(5);
        fs.PPIFeePercent__c = 9;
        fs.InflationPercent__c = 0.2;
        fs.HIGETaxPercent__c = 4.712;
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Description__c = 'Test';
        dummyCashierCode.Amount__c = 100;
        insert dummyCashierCode;

        Boolean exceptionThrown = false;
        try{
            // Run the code
            Test.startTest();
            PaymentAllocateBatchProgress ctrl =
                    new PaymentAllocateBatchProgress(new Apexpages.StandardSetController(new List<pymt__PaymentX__c>()));
            ctrl.StartPaymentAllocationBatch();
            ctrl.BacktolistView();
            ctrl.StartPaymentAllocationBatch();
            Test.stopTest();
        }
        catch(PaymentAllocateTransactionLinesBatch.PaymentAllocationException e){
            exceptionThrown = true;
        }
        catch(Exception e){
            System.assert(false, 'The wrong expextion type was thrown');
        }

        // Verify Results
        System.assertEquals(0, [SELECT COUNT() FROM CollectionsAllocation__c]);
    }

    @isTest
    static void TestNoEligibleLines() {

        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        FeeSchedule__c fs = new FeeSchedule__c();
        fs.Name = '1st Year Fees';
        fs.BeginningDate__c = Date.today().addDays(-1);
        fs.EndingDate__c = Date.today().addDays(5);
        fs.PPIFeePercent__c = 9;
        fs.InflationPercent__c = 0.2;
        fs.HIGETaxPercent__c = 4.712;
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 100;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Description__c = 'Test';
        dummyCashierCode.Amount__c = 100;
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c();
        dummyTransactionLine.PaidStatus__c = 'Paid';
        dummyTransactionLine.Transaction__c = trn.Id;
        dummyTransactionLine.CashierCode__c = dummyCashierCode.Id;
        dummyTransactionLine.Amount__c = 0;
        insert dummyTransactionLine;

        // Run the code
        Test.startTest();
        PaymentAllocateBatchProgress ctrl =
                new PaymentAllocateBatchProgress(new Apexpages.StandardSetController(new List<pymt__PaymentX__c>()));
        ctrl.StartPaymentAllocationBatch();
        ctrl.BacktolistView();
        Test.stopTest();
        ctrl.StartPaymentAllocationBatch();

        // Verify Results
        System.assertEquals(1, [SELECT COUNT() FROM CollectionsAllocation__c]);
    }

    @isTest
    static void TestNoLines() {

        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        FeeSchedule__c fs = new FeeSchedule__c();
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 100;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        insert pymt;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Description__c = 'Test';
        dummyCashierCode.Amount__c = 100;
        insert dummyCashierCode;

        // Run the code
        Test.startTest();
        PaymentAllocateBatchProgress ctrl =
                new PaymentAllocateBatchProgress(new Apexpages.StandardSetController(new List<pymt__PaymentX__c>()));
        ctrl.StartPaymentAllocationBatch();
        ctrl.BacktolistView();
        Test.stopTest();
        ctrl.StartPaymentAllocationBatch();

        // Verify Results
        System.assertEquals(0, [SELECT COUNT() FROM CollectionsAllocation__c]);
    }
}