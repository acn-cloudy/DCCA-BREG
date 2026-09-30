/*
* ─────────────────────────────────────────────────────────
* ScheduleOECCreateTest Class
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
* EA04292026 - For Case 00049395
* ───────────────────────────────────────────────────────────
*/
@isTest(seeAllData = false)
public class ReconciliationBatchJobTest {

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
            TotalAmount__c = 100,
            Contact__c = cnt.Id
        );
        insert trn;

        CashierCode__c cc = new CashierCode__c(
            Name = 'Cashier Code',
            Amount__c = 70,
            CashierCode__c = '000011',
            Category__c = 'Cat',
            Division__c = 'BREG'
        );
        insert cc;

        TransactionLine__c tl = new TransactionLine__c(
            Transaction__c = trn.Id,
            Amount__c = 30,
            CashierCode__c = cc.Id,
            Description__c = 'desc',
            PaidStatus__c = 'Paid'
        );
        insert tl;

        pymt__PaymentX__c pay = new pymt__PaymentX__c(
            pymt__Status__c = 'Completed',
            pymt__Date__c = System.today().addDays(-1), // required for batch query
            pymt__Amount__c = 1000,
            Transaction__c = trn.Id,
            Division__c = 'General'
        );
        insert pay;

        CollectionsAllocation__c ca = new CollectionsAllocation__c(
            Transaction__c = trn.Id,
            AmountAllocated__c = 200,
            TransactionLine__c = tl.Id,
            Payment__c = pay.Id,
            CutOffBatchDate__c = System.today().addDays(-1)
            // PaymentType__c NOT set (non-writeable)
        );
        insert ca;
    }

    @isTest
    static void testBatch_DefaultMode() {

        Test.startTest();

        ReconciliationBatchJob job = new ReconciliationBatchJob(false, UserInfo.getUserId());
        Database.executeBatch(job, 50);

        Test.stopTest();
    }

    @isTest
    static void testBatch_CloseOutMode() {

        // Adjust data for close-out mode
        CollectionsAllocation__c ca = [
            SELECT Id, CutOffBatchDate__c
            FROM CollectionsAllocation__c
            LIMIT 1
        ];
        ca.CutOffBatchDate__c = System.today();
        update ca;

        Test.startTest();

        ReconciliationBatchJob job = new ReconciliationBatchJob(true, UserInfo.getUserId());
        Database.executeBatch(job, 50);

        Test.stopTest();
    }

    @isTest
    static void testScheduler() {

        String CRON_EXP = '0 0 0 15 3 ? *';

        Test.startTest();
        String jobId = System.schedule('Test Scheduler', CRON_EXP, new ReconciliationBatchJob());
        Test.stopTest();
    }

    @isTest
    static void testUpdateCSVFileMethod() {

        // Get allocation with required relationships
        CollectionsAllocation__c ca = [
            SELECT Id,
                AmountAllocated__c,
                PaymentType__c,
                CashierCode__c,
                Transaction__r.Account__r.Name,
                Transaction__r.Name,
                Payment__r.pymt__Date__c,
                Payment__r.pymt__Memo__c,
                TransactionLine__r.CostCenter__c,
                TransactionLine__r.CashierCode__r.FAMISSrcCode__c,
                TransactionLine__r.CashierCode__r.FundAccount__c
            FROM CollectionsAllocation__c
            LIMIT 1
        ];

        // Create reconciliation batch
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Batch_Time__c = System.now(),
            Status__c = 'Pending Review'
        );
        insert rb;

        // Create job instance
        ReconciliationBatchJob job = new ReconciliationBatchJob();

        // Build CSV + populate updateCA internally
        job.getCSVFileDetails(ca);

        Test.startTest();

        // Call method under test
        job.UpdateCSVFile(rb);

        Test.stopTest();
    }
}