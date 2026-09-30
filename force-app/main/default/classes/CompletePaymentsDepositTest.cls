/*
 * ******************************************************************************************************
 * Name: CompletePaymentsDepositTest.cls
 * Author: PacificPoint
 * Date: 4/7/2018
 * Class: CompletePaymentsDeposit.cls
 * Updated by:
 * PacPoint-IC071819 - Updated for Phase 2
 * 8/10/2026 Alvin Zhou - case 00047537, coverage for the eCheck chargeback pass
 * ******************************************************************************************************
 */
@IsTest
public class CompletePaymentsDepositTest{
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;

        Deposits__c deposit = new Deposits__c();
        deposit.DepositDate__c = Date.today();
        deposit.DepositNumber__c = '223322';
        deposit.Status__c = 'Draft';
        deposit.EndDatetoPullPayments__c = Date.today();
        insert deposit;

        FeeSchedule__c fs = new FeeSchedule__c();
        fs.Name = '1st Year Fees';
        fs.BeginningDate__c = Date.today().addDays(-20);
        fs.EndingDate__c = Date.today().addDays(15);
        fs.PPIFeePercent__c = 9;
        fs.InflationPercent__c = 0.2;
        fs.HIGETaxPercent__c = 4.712;
        insert fs;

        CashierCode__c cCode = new CashierCode__c();
        cCode.Name = 'Test';
        cCode.Amount__c = 10.00;
        cCode.CashierCode__c = 'TEST';
        insert cCode;

        // Division__c on CollectionsAllocation__c is the formula
        // TEXT(TransactionLine__r.Transaction__r.Division__c), so the division a chargeback
        // allocation lands in is driven by its transaction line's parent transaction.
        List<Transaction__c> trxns = new List<Transaction__c>();

        Transaction__c pucTrxn = new Transaction__c();
        pucTrxn.Division__c = 'PUC';
        pucTrxn.Account__c = acc.Id;
        pucTrxn.ParentTotalAmount__c = 0;
        pucTrxn.TransactionType__c = 'Group';
        trxns.add(pucTrxn);

        Transaction__c dccaTrxn = new Transaction__c();
        dccaTrxn.Division__c = 'BREG';
        dccaTrxn.Account__c = acc.Id;
        dccaTrxn.ParentTotalAmount__c = 0;
        dccaTrxn.TransactionType__c = 'Group';
        trxns.add(dccaTrxn);

        insert trxns;

        List<TransactionLine__c> tLines = new List<TransactionLine__c>();
        for (Transaction__c t : trxns) {
            TransactionLine__c tLine = new TransactionLine__c();
            tLine.Transaction__c = t.Id;
            tLine.CashierCode__c = cCode.Id;
            tLine.Account__c = acc.Id;
            tLines.add(tLine);
        }
        insert tLines;

        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();

        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Amount__c = 1;
        payment.pymt__Date__c = deposit.EndDatetoPullPayments__c.addDays(-5);
        payment.RemitToDCCA__c = 50;
        payment.PPIFeeAmount__c = 100;
        payment.HIGETaxAmount__c = 150;
        payment.pymt__Payment_Type__c = 'Credit Card';
        payment.Transaction__c = pucTrxn.Id;
        payment.pymt__Billing_Email__c = 'test@test.test';
        payments.add(payment);

        insert payments;

        payment.FeeSchedule__c = fs.Id;
        update payment;

        CollectionsAllocation__c allocation = new CollectionsAllocation__c();
        allocation.Transaction__c = pucTrxn.Id;
        allocation.Payment__c = payment.Id;
        allocation.TransactionLine__c = tLines[0].Id;
        insert allocation;
    }

    // ---------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------

    private static Deposits__c getDeposit() {
        return [
            SELECT
                Id,
                EndDatetoPullPayments__c,
                PUCDeposit__c
            FROM Deposits__c
            LIMIT 1
        ];
    }

    private static Deposits__c getDeposit(Boolean isPuc) {
        Deposits__c dep = getDeposit();
        dep.PUCDeposit__c = isPuc;
        update dep;
        return dep;
    }

    private static Transaction__c getTransaction(String division) {
        return [SELECT Id FROM Transaction__c WHERE Division__c = :division LIMIT 1];
    }

    private static TransactionLine__c getTransactionLine(String division) {
        return [
            SELECT Id
            FROM TransactionLine__c
            WHERE Transaction__r.Division__c = :division
            LIMIT 1
        ];
    }

    /*
     * A chargeback payment as it looks after the bounce has been processed: already
     * stamped with a deposit from the original run, and no longer in 'Completed'.
     */
    private static pymt__PaymentX__c createPayment(String paymentType, String status, Id depositBatchId) {
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.pymt__Status__c = status;
        payment.pymt__Amount__c = 300;
        payment.pymt__Date__c = Date.today().addDays(-5);
        payment.pymt__Payment_Type__c = paymentType;
        payment.pymt__Billing_Email__c = 'test@test.test';
        payment.DepositBatch__c = depositBatchId;
        insert payment;
        return payment;
    }

    private static CollectionsAllocation__c createAllocation(String division, Id paymentId, Decimal amount) {
        CollectionsAllocation__c alloc = new CollectionsAllocation__c();
        alloc.Transaction__c = getTransaction(division).Id;
        alloc.TransactionLine__c = getTransactionLine(division).Id;
        alloc.Payment__c = paymentId;
        alloc.AmountAllocated__c = amount;
        insert alloc;
        return alloc;
    }

    private static void runChargebackPass(Id depositId) {
        Test.startTest();
        Database.executeBatch(new AsyncCompletePaymentsDeposit(depositId, true), 200);
        Test.stopTest();
    }

    private static Id getDepositOn(Id allocationId) {
        return [SELECT Deposit__c FROM CollectionsAllocation__c WHERE Id = :allocationId].Deposit__c;
    }

    // ---------------------------------------------------------------------------------
    // Existing completed-payment pass (regression)
    // ---------------------------------------------------------------------------------

    @IsTest
    static void nonPucTest() {
        Deposits__c dep = getDeposit();

        pymt__PaymentX__c p = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        p.Division__c = 'BREG';
        update p;

        ApexPages.StandardController sc = new ApexPages.StandardController(dep);
        CompletePaymentsDeposit depositor = new CompletePaymentsDeposit(sc);
        depositor.AddCompletePayments();
    }

    @IsTest
    static void pucTest() {
        Deposits__c dep = getDeposit(true);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(dep);
        CompletePaymentsDeposit depositor = new CompletePaymentsDeposit(sc);
        depositor.AddCompletePayments();
        Test.stopTest();
    }

    @IsTest
    static void completedPaymentPassStampsPaymentAndChildAllocations() {
        Deposits__c dep = getDeposit(true);

        pymt__PaymentX__c p = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        p.Division__c = 'PUC';
        update p;

        Test.startTest();
        Database.executeBatch(new AsyncCompletePaymentsDeposit(dep.Id), 20);
        Test.stopTest();

        pymt__PaymentX__c updated = [SELECT DepositBatch__c FROM pymt__PaymentX__c WHERE Id = :p.Id];
        System.assertEquals(dep.Id, updated.DepositBatch__c, 'Completed payment should be stamped with the deposit');

        CollectionsAllocation__c alloc = [
            SELECT Deposit__c FROM CollectionsAllocation__c WHERE Payment__c = :p.Id LIMIT 1
        ];
        System.assertEquals(dep.Id, alloc.Deposit__c, 'Child allocation should be stamped with the deposit');
    }

    // ---------------------------------------------------------------------------------
    // PUC chargeback rule
    // ---------------------------------------------------------------------------------

    @IsTest
    static void pucChargebackEcheckClaimed() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(dep.Id, getDepositOn(alloc.Id), 'PUC negative eCheck allocation should be claimed');
    }

    @IsTest
    static void pucChargebackCreditCardClaimed() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('Credit Card', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -125.50);

        runChargebackPass(dep.Id);

        System.assertEquals(dep.Id, getDepositOn(alloc.Id), 'PUC negative credit card allocation should be claimed');
    }

    @IsTest
    static void pucChargebackIgnoresPaymentStatus() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'Completed', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -75);

        runChargebackPass(dep.Id);

        System.assertEquals(
            dep.Id,
            getDepositOn(alloc.Id),
            'PUC rule intentionally has no BCF filter, so a Completed parent payment still qualifies'
        );
    }

    @IsTest
    static void pucChargebackExcludesOtherPaymentTypes() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('Cash', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'Cash allocation should not be claimed');
    }

    @IsTest
    static void pucChargebackExcludesNonPucDivision() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('BREG', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'Non-PUC allocation should not be claimed by a PUC deposit');
    }

    // ---------------------------------------------------------------------------------
    // DCCA chargeback rule
    // ---------------------------------------------------------------------------------

    @IsTest
    static void dccaChargebackBcfEcheckClaimed() {
        Deposits__c dep = getDeposit(false);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('BREG', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(dep.Id, getDepositOn(alloc.Id), 'DCCA BCF eCheck allocation should be claimed');
    }

    @IsTest
    static void dccaChargebackExcludesCreditCard() {
        Deposits__c dep = getDeposit(false);
        pymt__PaymentX__c payment = createPayment('Credit Card', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('BREG', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'DCCA rule covers eCheck only, not credit card');
    }

    @IsTest
    static void dccaChargebackRequiresBcfStatus() {
        Deposits__c dep = getDeposit(false);
        pymt__PaymentX__c payment = createPayment('ECheck', 'Completed', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('BREG', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'DCCA rule requires the parent payment to be in BCF');
    }

    @IsTest
    static void dccaChargebackExcludesPucDivision() {
        Deposits__c dep = getDeposit(false);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'PUC allocation should not be claimed by a DCCA deposit');
    }

    // ---------------------------------------------------------------------------------
    // Shared guarantees
    // ---------------------------------------------------------------------------------

    @IsTest
    static void chargebackIgnoresPositiveAllocations() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, 300);

        runChargebackPass(dep.Id);

        System.assertEquals(null, getDepositOn(alloc.Id), 'Positive allocation should never be claimed by the chargeback pass');
    }

    @IsTest
    static void chargebackDoesNotReassignClaimedAllocation() {
        Deposits__c dep = getDeposit(true);

        Deposits__c priorDeposit = new Deposits__c();
        priorDeposit.DepositDate__c = Date.today().addDays(-30);
        priorDeposit.DepositNumber__c = '111111';
        priorDeposit.Status__c = 'Draft';
        priorDeposit.EndDatetoPullPayments__c = Date.today().addDays(-30);
        insert priorDeposit;

        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);
        alloc.Deposit__c = priorDeposit.Id;
        update alloc;

        runChargebackPass(dep.Id);

        System.assertEquals(
            priorDeposit.Id,
            getDepositOn(alloc.Id),
            'An allocation already on a deposit should not be reassigned'
        );
    }

    @IsTest
    static void chargebackDoesNotRestampParentPayment() {
        Deposits__c dep = getDeposit(true);

        Deposits__c originalDeposit = new Deposits__c();
        originalDeposit.DepositDate__c = Date.today().addDays(-30);
        originalDeposit.DepositNumber__c = '111112';
        originalDeposit.Status__c = 'Draft';
        originalDeposit.EndDatetoPullPayments__c = Date.today().addDays(-30);
        insert originalDeposit;

        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', originalDeposit.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(dep.Id, getDepositOn(alloc.Id), 'Allocation should be claimed by the current deposit');

        pymt__PaymentX__c reloaded = [SELECT DepositBatch__c FROM pymt__PaymentX__c WHERE Id = :payment.Id];
        System.assertEquals(
            originalDeposit.Id,
            reloaded.DepositBatch__c,
            'Parent payment must keep its original deposit - re-stamping would double-count the original amount'
        );
    }

    @IsTest
    static void chargebackCutoffIsInclusiveOfEndDate() {
        Deposits__c dep = getDeposit();
        dep.PUCDeposit__c = true;
        dep.EndDatetoPullPayments__c = Date.today().addDays(-5);
        update dep;

        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c onEndDate = createAllocation('PUC', payment.Id, -300);
        CollectionsAllocation__c afterEndDate = createAllocation('PUC', payment.Id, -400);

        // Late on the end date itself - in scope.
        Test.setCreatedDate(
            onEndDate.Id,
            Datetime.newInstance(Date.today().addDays(-5), Time.newInstance(23, 30, 0, 0))
        );
        // Early the following day - out of scope.
        Test.setCreatedDate(
            afterEndDate.Id,
            Datetime.newInstance(Date.today().addDays(-4), Time.newInstance(0, 30, 0, 0))
        );

        runChargebackPass(dep.Id);

        System.assertEquals(
            dep.Id,
            getDepositOn(onEndDate.Id),
            'Allocation created on the end date should be in scope'
        );
        System.assertEquals(
            null,
            getDepositOn(afterEndDate.Id),
            'Allocation created after the end date should be out of scope'
        );
    }

    @IsTest
    static void chargebackIsIdempotent() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', dep.Id);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        // First pass claims it.
        Test.startTest();
        Database.executeBatch(new AsyncCompletePaymentsDeposit(dep.Id, true), 200);
        Test.stopTest();

        System.assertEquals(dep.Id, getDepositOn(alloc.Id), 'First pass should claim the allocation');

        Integer claimedAfterFirstPass = [
            SELECT COUNT() FROM CollectionsAllocation__c WHERE Deposit__c = :dep.Id
        ];

        // Second pass finds nothing new - candidacy requires Deposit__c = null.
        Database.executeBatch(new AsyncCompletePaymentsDeposit(dep.Id, true), 200);

        Integer claimedAfterSecondPass = [
            SELECT COUNT() FROM CollectionsAllocation__c WHERE Deposit__c = :dep.Id
        ];

        System.assertEquals(
            claimedAfterFirstPass,
            claimedAfterSecondPass,
            'Re-running the chargeback pass should not claim anything additional'
        );
    }

    // ---------------------------------------------------------------------------------
    // Parent payment must already be deposited (case 00047537 follow-up)
    // ---------------------------------------------------------------------------------

    @IsTest
    static void pucChargebackRequiresParentPaymentDeposited() {
        Deposits__c dep = getDeposit(true);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', null);
        CollectionsAllocation__c alloc = createAllocation('PUC', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(
            null,
            getDepositOn(alloc.Id),
            'Parent payment was never deposited, so there is no original amount to offset'
        );
    }

    @IsTest
    static void dccaChargebackRequiresParentPaymentDeposited() {
        Deposits__c dep = getDeposit(false);
        pymt__PaymentX__c payment = createPayment('ECheck', 'BCF', null);
        CollectionsAllocation__c alloc = createAllocation('BREG', payment.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(
            null,
            getDepositOn(alloc.Id),
            'Parent payment was never deposited, so there is no original amount to offset'
        );
    }

    @IsTest
    static void chargebackClaimsOnlyTheDepositedParentPayment() {
        Deposits__c dep = getDeposit(true);

        Deposits__c originalDeposit = new Deposits__c();
        originalDeposit.DepositDate__c = Date.today().addDays(-30);
        originalDeposit.DepositNumber__c = '111113';
        originalDeposit.Status__c = 'Draft';
        originalDeposit.EndDatetoPullPayments__c = Date.today().addDays(-30);
        insert originalDeposit;

        // Same shape apart from the parent payment's deposit lookup.
        pymt__PaymentX__c deposited = createPayment('ECheck', 'BCF', originalDeposit.Id);
        pymt__PaymentX__c neverDeposited = createPayment('ECheck', 'BCF', null);
        CollectionsAllocation__c claimable = createAllocation('PUC', deposited.Id, -300);
        CollectionsAllocation__c skipped = createAllocation('PUC', neverDeposited.Id, -300);

        runChargebackPass(dep.Id);

        System.assertEquals(dep.Id, getDepositOn(claimable.Id), 'Deposited parent payment should be claimed');
        System.assertEquals(null, getDepositOn(skipped.Id), 'Undeposited parent payment should be skipped');
    }
}