global class PaymentAdjustmentBatchJob
implements Database.Batchable<SObject>, Database.Stateful {

    global Id reconciliationBatchId;

    global Integer totalCount = 0;
    global Decimal totalAmount = 0;

    global Map<String, Decimal> cashierTotals = new Map<String, Decimal>();

    global PaymentAdjustmentBatchJob(Id reconciliationBatchId) {
        this.reconciliationBatchId = reconciliationBatchId;
    }

    global PaymentAdjustmentBatchJob(){}

    /*
     * START
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT
                Id,
                AmountAllocated__c,
                CashierCode__c,
                Reconciliation_Batch__c,
                PaymentType__c,
                CutOffBatchDate__c
            FROM CollectionsAllocation__c
            WHERE PaymentType__c IN (
                'Cash',
                'Check',
                'Cashier\'s Check',
                'Money Order'
            )
            AND CutOffBatchDate__c = TODAY
            AND AmountAllocated__c < 0
            AND Reconciliation_Batch__c = null
        ]);
    }

    /*
     * EXECUTE
     */
    global void execute(
        Database.BatchableContext bc,
        List<CollectionsAllocation__c> scope
    ) {

        List<CollectionsAllocation__c> updates =
            new List<CollectionsAllocation__c>();

        for (CollectionsAllocation__c ca : scope) {

            ca.Reconciliation_Batch__c = reconciliationBatchId;

            updates.add(ca);

            totalCount++;

            totalAmount += ca.AmountAllocated__c;

            String cashierCode = String.isBlank(ca.CashierCode__c)
                ? 'UNKNOWN'
                : ca.CashierCode__c;

            if (!cashierTotals.containsKey(cashierCode)) {
                cashierTotals.put(cashierCode, 0);
            }

            cashierTotals.put(
                cashierCode,
                cashierTotals.get(cashierCode) + ca.AmountAllocated__c
            );
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /*
     * FINISH
     */
    global void finish(Database.BatchableContext bc) {

        List<String> cashierSummary = new List<String>();

        for (String cashier : cashierTotals.keySet()) {
            cashierSummary.add(
                cashier + ':$' + String.valueOf(cashierTotals.get(cashier))
            );
        }

        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Id = reconciliationBatchId,
            Number_of_Collection_Allocations__c = totalCount,
            Sum_of_Cashier_Code__c = String.join(cashierSummary, ', '),
            Sum_of_Non_Credit_Card_Payments__c = totalAmount
        );

        update rb;
    }
}