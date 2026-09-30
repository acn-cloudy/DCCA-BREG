public with sharing class PaymentAdjustmentController {
    public class Response {
        @InvocableVariable
        public Id reconciliationBatchId;
    }

    @InvocableMethod(label='Generate Payment Adjustment')
    public static List<Response> generatePaymentAdjustment(List<String> requests) {
        // Create Reconciliation Batch
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c();

        rb.Status__c = 'Pending Review';
        rb.OwnerId = UserInfo.getUserId();
        rb.Batch_Time__c = System.now();
        rb.CashierSession__c = UserInfo.getName() + ' ~ ' + System.now().format('M/d/yyyy h:mma');
        rb.Type__c = 'Adjustment';

        insert rb;

        Database.executeBatch(
            new PaymentAdjustmentBatchJob(rb.Id),
            200
        );

        Response res = new Response();
        res.reconciliationBatchId = rb.Id;

        return new List<Response>{ res };
    }
}