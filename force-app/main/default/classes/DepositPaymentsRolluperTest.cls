/*
 * ___________________________________________________________________________________
 * Code coverage for DepositPaymentsRolluper
 * __________________________________________________________________________________
 * PacPoint-CL082819 - Created for Phase $
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 8/28/2019
 * __________________________________________________________________________________
 */
@IsTest
private class DepositPaymentsRolluperTest {
    @IsTest
    static void testDepositRollupsButton() {
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
        currentYearPayment1.pymt__Payment_Type__c = 'Cash';
        currentYearPayment1.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment1);

        pymt__PaymentX__c currentYearPayment2 = new pymt__PaymentX__c();
        currentYearPayment2.pymt__Status__c = 'Completed';
        currentYearPayment2.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
        currentYearPayment2.RemitToDCCA__c = 50;
        currentYearPayment2.PPIFeeAmount__c = 100;
        currentYearPayment2.HIGETaxAmount__c = 150;
        currentYearPayment2.pymt__Payment_Type__c = 'Check or Money Order';
        currentYearPayment2.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment2);

        pymt__PaymentX__c currentYearPayment3 = new pymt__PaymentX__c();
        currentYearPayment3.pymt__Status__c = 'Completed';
        currentYearPayment3.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
        currentYearPayment3.RemitToDCCA__c = 50;
        currentYearPayment3.PPIFeeAmount__c = 100;
        currentYearPayment3.HIGETaxAmount__c = 150;
        currentYearPayment3.pymt__Payment_Type__c = 'Credit Card';
        currentYearPayment3.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment3);

        insert payments;

        Transaction__c t = new Transaction__c();
        t.Account__c = acc.Id;
        t.Contact__c = cnt.Id;
        insert t;

        TransactionLine__c tl = new TransactionLine__c();
        tl.Transaction__c = t.Id;
        tl.Payment__c = currentYearPayment1.Id;
        insert tl;

        CollectionsAllocation__c collectionsAllocation = new CollectionsAllocation__c();
        collectionsAllocation.Payment__c = currentYearPayment1.Id;
        collectionsAllocation.TransactionLine__c = tl.Id;
        collectionsAllocation.Deposit__c = xDeposit.Id;
        insert collectionsAllocation;

        Test.StartTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(xDeposit);
        DepositRollupsButton DRB = new DepositRollupsButton(sc);
        DRB.StartRollupBatch();
        Test.StopTest();

        Deposits__c deposit = [SELECT Id, NetCollectionsafterFees__c, PPIFeesfromCashCheckMoneyOrders__c, HIGETaxfromCashCheckMoneyOrders__c FROM Deposits__c];

        System.assertEquals(150, deposit.NetCollectionsafterFees__c);
        System.assertEquals(200, deposit.PPIFeesfromCashCheckMoneyOrders__c);
        System.assertEquals(300, deposit.HIGETaxfromCashCheckMoneyOrders__c);
    }
    /*
     * Case 00047537 - TotalReturnsfromeCheck__c must total ONLY the negative eCheck
     * allocations on the deposit, kept negative to match TotalRefundsfromCreditCard__c.
     */
    @IsTest
    static void testTotalReturnsFromECheck() {
        Account acc = new Account(Name = 'Returns Account');
        insert acc;

        Deposits__c dep = new Deposits__c();
        dep.DepositDate__c = Date.today();
        dep.DepositNumber__c = '994455';
        dep.Status__c = 'Draft';
        dep.EndDatetoPullPayments__c = Date.today();
        insert dep;

        // PaymentType__c on the allocation is TEXT(Payment__r.pymt__Payment_Type__c),
        // so the payment type drives which allocations are counted.
        Map<String, pymt__PaymentX__c> byType = new Map<String, pymt__PaymentX__c>();
        List<pymt__PaymentX__c> pmts = new List<pymt__PaymentX__c>();
        for (String payType : new List<String>{ 'ECheck', 'Credit Card', 'Cash' }) {
            pymt__PaymentX__c p = new pymt__PaymentX__c();
            p.pymt__Status__c = 'Completed';
            p.pymt__Amount__c = 300;
            p.pymt__Date__c = Date.today().addDays(-2);
            p.pymt__Payment_Type__c = payType;
            p.pymt__Billing_Email__c = 'test@test.test';
            pmts.add(p);
            byType.put(payType, p);
        }
        insert pmts;

        Transaction__c trxn = new Transaction__c();
        trxn.Account__c = acc.Id;
        insert trxn;

        TransactionLine__c tLine = new TransactionLine__c();
        tLine.Transaction__c = trxn.Id;
        insert tLine;

        List<CollectionsAllocation__c> allocs = new List<CollectionsAllocation__c>();
        // Counted: negative eCheck.
        allocs.add(buildAlloc(dep.Id, tLine.Id, byType.get('ECheck').Id, -300));
        allocs.add(buildAlloc(dep.Id, tLine.Id, byType.get('ECheck').Id, -150));
        // Not counted: positive eCheck, and negative allocations of other payment types.
        allocs.add(buildAlloc(dep.Id, tLine.Id, byType.get('ECheck').Id, 200));
        allocs.add(buildAlloc(dep.Id, tLine.Id, byType.get('Credit Card').Id, -100));
        allocs.add(buildAlloc(dep.Id, tLine.Id, byType.get('Cash').Id, -50));
        insert allocs;

        Test.startTest();
        DepositPaymentsRolluper.rollup(new List<Id>{ dep.Id });
        Test.stopTest();

        Deposits__c result = [
            SELECT TotalReturnsfromeCheck__c, CollectionAllocationPaymentAmount__c
            FROM Deposits__c
            WHERE Id = :dep.Id
        ];

        System.assertEquals(
            -450,
            result.TotalReturnsfromeCheck__c,
            'Only the negative eCheck allocations (-300 and -150) should be totalled'
        );
        System.assertEquals(
            -400,
            result.CollectionAllocationPaymentAmount__c,
            'Existing allocation total should still sum every allocation on the deposit'
        );
    }

    private static CollectionsAllocation__c buildAlloc(Id depositId, Id tLineId, Id paymentId, Decimal amount) {
        CollectionsAllocation__c alloc = new CollectionsAllocation__c();
        alloc.Deposit__c = depositId;
        alloc.TransactionLine__c = tLineId;
        alloc.Payment__c = paymentId;
        alloc.AmountAllocated__c = amount;
        return alloc;
    }
}