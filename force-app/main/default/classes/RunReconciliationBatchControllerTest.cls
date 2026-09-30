/*
* ─────────────────────────────────────────────────────────
* RunReconciliationBatchControllerTest Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ171019 - Created for PVL 4Gov Integration
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-10-17
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
@isTest(seeAllData = false)
public class RunReconciliationBatchControllerTest {

    @TestSetup
    static void setup() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact cnt = new Contact(
            AccountId = acc.Id,
            LastName = 'Test Contact'
        );
        insert cnt;

        Transaction__c trn = new Transaction__c(
            Account__c = acc.Id,
            TotalAmount__c = 100.00,
            Contact__c = cnt.Id
        );
        insert trn;

        CashierCode__c cc1 = new CashierCode__c(
            Name = 'Cashier Code 1',
            Amount__c = 70,
            CashierCode__c = '000011',
            Category__c = 'Categ1',
            Division__c = 'BREG'
        );
        insert cc1;

        TransactionLine__c tl1 = new TransactionLine__c(
            Transaction__c = trn.Id,
            Amount__c = 30,
            CashierCode__c = cc1.Id,
            Description__c = 'aaa',
            PaidStatus__c = 'Paid'
        );
        insert tl1;

        // Payment in allowed division (BREG → included in query)
        pymt__PaymentX__c pay1 = new pymt__PaymentX__c(
            pymt__Status__c = 'Completed',
            pymt__Date__c = System.today(),
            CreditCardFee__c = 20,
            pymt__Transaction_Fee__c = 50,
            pymt__Amount__c = 1000,
            Transaction__c = trn.Id,
            Division__c = 'BREG'
        );
        insert pay1;

        // Payment excluded by controller filter (PUC)
        pymt__PaymentX__c pay2 = new pymt__PaymentX__c(
            pymt__Status__c = 'Completed',
            pymt__Date__c = System.today(),
            CreditCardFee__c = 20,
            pymt__Transaction_Fee__c = 50,
            pymt__Amount__c = 1000,
            Transaction__c = trn.Id,
            Division__c = 'PUC'
        );
        insert pay2;

        CollectionsAllocation__c ca1 = new CollectionsAllocation__c(
            Transaction__c = trn.Id,
            AmountAllocated__c = 200,
            TransactionLine__c = tl1.Id,
            Payment__c = pay1.Id,
            CutOffBatchDate__c = System.today()
        );

        CollectionsAllocation__c ca2 = new CollectionsAllocation__c(
            Transaction__c = trn.Id,
            AmountAllocated__c = 150,
            TransactionLine__c = tl1.Id,
            Payment__c = pay2.Id,
            CutOffBatchDate__c = System.today()
        );

        insert new List<CollectionsAllocation__c>{ ca1, ca2 };

        Reconciliation_Batch__c rbPayment = new Reconciliation_Batch__c(
            Status__c = 'Pending Review',
            Batch_Time__c = System.today(),
            Type__c = 'Payment'
        );

        Reconciliation_Batch__c rbAdjustment = new Reconciliation_Batch__c(
            Status__c = 'Pending Review',
            Batch_Time__c = System.today(),
            Type__c = 'Adjustment'
        );

        insert new List<Reconciliation_Batch__c>{ rbPayment, rbAdjustment };
    }

    @IsTest
    static void testAdjustmentPath() {

        Reconciliation_Batch__c rb = [
            SELECT Id, Type__c, Status__c
            FROM Reconciliation_Batch__c
            WHERE Type__c = 'Adjustment'
            LIMIT 1
        ];

        Test.startTest();

        ApexPages.StandardController sc =
            new ApexPages.StandardController(rb);

        RunReconciliationBatchController ctrl =
            new RunReconciliationBatchController(sc);

        PageReference pr = Page.RunReconciliationBatch;
        pr.getParameters().put('id', rb.Id);
        Test.setCurrentPage(pr);

        ctrl.reRunBatchProcess();
        ctrl.doCancel();

        Test.stopTest();
    }

    @IsTest
    static void testPaymentPath() {

        Reconciliation_Batch__c rb = [
            SELECT Id, Type__c, Status__c
            FROM Reconciliation_Batch__c
            WHERE Type__c = 'Payment'
            LIMIT 1
        ];

        Test.startTest();

        ApexPages.StandardController sc =
            new ApexPages.StandardController(rb);

        RunReconciliationBatchController ctrl =
            new RunReconciliationBatchController(sc);

        PageReference pr = Page.RunReconciliationBatch;
        pr.getParameters().put('id', rb.Id);
        Test.setCurrentPage(pr);

        ctrl.reRunBatchProcess();
        ctrl.doCancel();

        Test.stopTest();
    }
}