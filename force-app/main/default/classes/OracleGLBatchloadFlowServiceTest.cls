@IsTest
private class OracleGLBatchloadFlowServiceTest {

    @IsTest
    static void testSendToGL_Success() {

        Reconciliation_Batch__c batchRec =
            new Reconciliation_Batch__c(
                CashierSession__c = 'SUSAN20260401'
            );
        insert batchRec;

        Transaction__c txn = new Transaction__c();
        insert txn;

        TransactionLine__c txnLine =
            new TransactionLine__c(
                Transaction__c = txn.Id
            );
        insert txnLine;

        pymt__PaymentX__c paymentRec =
            new pymt__PaymentX__c(
                pymt__Payment_Type__c = 'CASH'
            );
        insert paymentRec;

        CollectionsAllocation__c alloc =
            new CollectionsAllocation__c(
                Reconciliation_Batch__c = batchRec.Id,
                TransactionLine__c = txnLine.Id,
                Payment__c = paymentRec.Id,
                CutOffBatchDate__c = Date.today()
            );
        insert alloc;

        Test.setMock(HttpCalloutMock.class, new OracleGLBatchloadMock());

        OracleGLBatchloadFlowService.RequestWrapper req =
            new OracleGLBatchloadFlowService.RequestWrapper();
        req.reconciliationBatchId = batchRec.Id;

        Test.startTest();
        OracleGLBatchloadFlowService.sendToGL(
            new List<OracleGLBatchloadFlowService.RequestWrapper>{ req }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSendToGL_NoAllocations() {

        Reconciliation_Batch__c batchRec =
            new Reconciliation_Batch__c(
                CashierSession__c = 'SUSAN20260401'
            );
        insert batchRec;

        OracleGLBatchloadFlowService.RequestWrapper req =
            new OracleGLBatchloadFlowService.RequestWrapper();
        req.reconciliationBatchId = batchRec.Id;

        Test.startTest();
        OracleGLBatchloadFlowService.sendToGL(
            new List<OracleGLBatchloadFlowService.RequestWrapper>{ req }
        );
        Test.stopTest();
    }

    private class OracleGLBatchloadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }
}