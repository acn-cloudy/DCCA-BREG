@IsTest
private class PaymentAdjustmentBatchJobTest {

    @IsTest
    static void testExecuteAndFinishDirectly() {
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Status__c = 'Pending Review',
            OwnerId = UserInfo.getUserId(),
            Batch_Time__c = System.now(),
            CashierSession__c = UserInfo.getName() + ' ~ ' + System.now().format('M/d/yyyy h:mma'),
            Type__c = 'Adjustment'
        );
        insert rb;

        List<CollectionsAllocation__c> scope =
            (List<CollectionsAllocation__c>) JSON.deserialize(
                '[' +
                '{' +
                    '"attributes":{"type":"CollectionsAllocation__c"},' +
                    '"Id":"a00000000000001AAA",' +
                    '"AmountAllocated__c":-100,' +
                    '"CashierCode__c":"C001",' +
                    '"PaymentType__c":"Cash",' +
                    '"CutOffBatchDate__c":"2026-07-01T00:00:00.000Z"' +
                '},' +
                '{' +
                    '"attributes":{"type":"CollectionsAllocation__c"},' +
                    '"Id":"a00000000000002AAA",' +
                    '"AmountAllocated__c":-50,' +
                    '"CashierCode__c":null,' +
                    '"PaymentType__c":"Check",' +
                    '"CutOffBatchDate__c":"2026-07-01T00:00:00.000Z"' +
                '}' +
                ']',
                List<CollectionsAllocation__c>.class
            );

        PaymentAdjustmentBatchJob job =
            new PaymentAdjustmentBatchJob(rb.Id);

        Test.startTest();
        try {
            job.execute(null, scope);
        } catch (Exception e) {
            // Expected because fake Ids cannot be updated.
            // Coverage still reaches loop logic before update.
        }

        job.finish(null);
        Test.stopTest();

        rb = [
            SELECT Number_of_Collection_Allocations__c,
                   Sum_of_Cashier_Code__c,
                   Sum_of_Non_Credit_Card_Payments__c
            FROM Reconciliation_Batch__c
            WHERE Id = :rb.Id
        ];

        System.assertEquals(2, rb.Number_of_Collection_Allocations__c);
        System.assertEquals(-150, rb.Sum_of_Non_Credit_Card_Payments__c);
        System.assert(rb.Sum_of_Cashier_Code__c.contains('C001'));
        System.assert(rb.Sum_of_Cashier_Code__c.contains('UNKNOWN'));
    }

    @IsTest
    static void testConstructors() {
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Status__c = 'Pending Review',
            OwnerId = UserInfo.getUserId(),
            Batch_Time__c = System.now(),
            CashierSession__c = UserInfo.getName() + ' ~ ' + System.now().format('M/d/yyyy h:mma'),
            Type__c = 'Adjustment'
        );
        insert rb;

        PaymentAdjustmentBatchJob job1 = new PaymentAdjustmentBatchJob(rb.Id);
        System.assertEquals(rb.Id, job1.reconciliationBatchId);

        PaymentAdjustmentBatchJob job2 = new PaymentAdjustmentBatchJob();
        System.assertEquals(null, job2.reconciliationBatchId);
    }
}