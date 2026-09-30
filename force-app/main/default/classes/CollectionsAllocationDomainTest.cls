/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: CollectionsAllocationDomainTestTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL03202023 - Created for
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 03/20/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class CollectionsAllocationDomainTest {
    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Test');
        insert a;

        Contact c = new Contact(LastName = 'Test', AccountId = a.Id);
        insert c;

        Transaction__c t = new Transaction__c(Account__c = a.Id);
        insert t;

        CashierCode__c cc = new CashierCode__c(Description__c = 'Test',
            Amount__c = 1.00,
            FAMISSrcCode__c = '1-1',
            CostCenter__c = '1',
            FundAccount__c = '1-1',
            CashierCode__c = '1-1');
        insert cc;

        TransactionLine__c tl = new TransactionLine__c(
            PaidStatus__c = 'Paid',
            Transaction__c = t.Id,
            CashierCode__c = cc.Id
        );
        insert tl;

        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Payment_Type__c = 'Credit Card';
        insert payment;

        CollectionsAllocation__c col = new CollectionsAllocation__c();
        col.Payment__c = payment.Id;
        col.TransactionLine__c = tl.Id;
        col.AmountAllocated__c = 1;
        insert col;
    }

    @IsTest
    static void SummarizeAllocationRecordAmountTest() {
        CollectionsAllocation__c ca = new CollectionsAllocation__c();
        List<CollectionsAllocation__c> cas = [
            SELECT
                Id,
                AmountAllocated__c,
                NetCollectionsafterFeesAllocated__c,
                TransactionLine__r.CashierCode__r.FAMISSrcCode__c,
                TransactionLine__r.CashierCode__r.FundAccount__c,
                TransactionLine__r.CashierCode__r.CostCenter__c,
                TransactionLine__r.CashierCode__r.CashierCode__c,
                Transaction__c
            FROM CollectionsAllocation__c
        ];
        (new CollectionsAllocationDomain(cas)).summarizeAllocationRecordAmount('Credit Card');
    }

    @IsTest
    static void getDataFeedsTest() {
        CollectionsAllocation__c ca = new CollectionsAllocation__c();
        List<CollectionsAllocation__c> cas = [
            SELECT
                Id,
                AmountAllocated__c,
                NetCollectionsafterFeesAllocated__c,
                TransactionLine__r.CashierCode__r.FAMISSrcCode__c,
                TransactionLine__r.CashierCode__r.FundAccount__c,
                TransactionLine__r.CashierCode__r.CostCenter__c,
                TransactionLine__r.CashierCode__r.CashierCode__c,
                Transaction__c
            FROM CollectionsAllocation__c
        ];

        (new CollectionsAllocationDomain(cas)).getDataFeeds(new Map<String, Decimal>{
        '1-1-1-11'=> 1
        }, String.valueOf(Date.today().year()));
    }

    @IsTest
    static void getJVFeedsTest() {
        CollectionsAllocation__c ca = new CollectionsAllocation__c();
        List<CollectionsAllocation__c> cas = [
            SELECT
                Id,
                AmountAllocated__c,
                NetCollectionsafterFeesAllocated__c,
                TransactionLine__r.CashierCode__r.FAMISSrcCode__c,
                TransactionLine__r.CashierCode__r.FundAccount__c,
                TransactionLine__r.CashierCode__r.CostCenter__c,
                TransactionLine__r.CashierCode__r.CashierCode__c,
                Transaction__c,
                Payment__r.Name
            FROM CollectionsAllocation__c
        ];

        (new CollectionsAllocationDomain(cas)).getJVFeeds(String.valueOf(Date.today().year()));
    }

    @IsTest
    static void checkJVProcessedTest() {
        CollectionsAllocation__c ca = new CollectionsAllocation__c();
        List<CollectionsAllocation__c> cas = new List<CollectionsAllocation__c>{ca};
        (new CollectionsAllocationDomain(cas)).checkJVProcessed();
    }
}