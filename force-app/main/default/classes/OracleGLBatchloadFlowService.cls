public with sharing class OracleGLBatchloadFlowService {

    /*
     * Oracle ORDS Batchload Endpoint
     */
    private static final String ENDPOINT =
        'callout:OracleGL/ords/sfgl/dca_gl_interface/batchload?dateFormat=YYYY-MM-DD';

    /*
     * Flow Action
     * Input: Reconciliation_Batch__c.Id
     */
    @InvocableMethod(
        label='Send Reconciliation Batch to GL'
        description='Uploads Collections Allocations to Oracle GL'
    )
    public static void sendToGL(
        List<RequestWrapper> requests
    ) {

        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> batchIds = new Set<Id>();

        for (RequestWrapper req : requests) {
            if (req.reconciliationBatchId != null) {
                batchIds.add(req.reconciliationBatchId);
            }
        }

        if (batchIds.isEmpty()) {
            return;
        }

        /*
         * Query Reconciliation Batches
         */
        Map<Id, Reconciliation_Batch__c> batchMap =
            new Map<Id, Reconciliation_Batch__c>(
                [
                    SELECT
                        Id,
                        Status__c,
                        ErrorMessage__c,
                        CashierSession__c
                    FROM Reconciliation_Batch__c
                    WHERE Id IN :batchIds
                ]
            );

        /*
         * Query related CollectionsAllocation__c
         */
        List<CollectionsAllocation__c> allocations =
            [
                SELECT
                    Id,
                    TransactionLine__c,
                    TransactionLine__r.Transaction__r.Name,
                    TransactionLine__r.CashierCode__c,
                    TransactionLine__r.CashierCode__r.Name,
                    AmountAllocated__c,
                    PaymentType__c,
                    CutOffBatchDate__c,
                    Reconciliation_Batch__c,
                    Payment__r.pymt__Account__r.Name,
                    Payment__r.pymt__Memo__c
                FROM CollectionsAllocation__c
                WHERE Reconciliation_Batch__c IN :batchIds
                AND PaymentType__c != 'Credit Card'
            ];

        if (allocations.isEmpty()) {

            List<Reconciliation_Batch__c> failedBatches =
                new List<Reconciliation_Batch__c>();

            for (Reconciliation_Batch__c batchRec : batchMap.values()) {

                batchRec.Status__c = 'Failed';
                batchRec.ErrorMessage__c =
                    'No Collections Allocations found';

                failedBatches.add(batchRec);
            }

            update failedBatches;

            return;
        }

        try {

            /*
             * Build CSV Payload
             */
            String csvPayload = buildCsv(
                allocations,
                batchMap
            );

            System.debug(csvPayload);

            /*
             * HTTP Callout
             */
            HttpRequest req = new HttpRequest();

            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');

            req.setHeader('Content-Type', 'text/csv');

            req.setBody(csvPayload);

            req.setTimeout(120000);

            Http http = new Http();

            HttpResponse res = http.send(req);

            System.debug(res.getBody());

            /*
             * Update Batch Status
             */
            List<Reconciliation_Batch__c> batchesToUpdate =
                new List<Reconciliation_Batch__c>();

            for (Reconciliation_Batch__c batchRec : batchMap.values()) {

                if (
                    res.getStatusCode() >= 200 &&
                    res.getStatusCode() < 300
                ) {

                    batchRec.Status__c = 'Sent to 4Gov';
                    batchRec.ErrorMessage__c = null;

                } else {

                    batchRec.Status__c = 'Failed';
                    batchRec.ErrorMessage__c =
                        'HTTP ' +
                        res.getStatusCode() +
                        ': ' +
                        res.getBody();
                }

                batchesToUpdate.add(batchRec);
            }

            update batchesToUpdate;

        } catch (Exception ex) {

            /*
             * Error Handling
             */
            List<Reconciliation_Batch__c> failedBatches =
                new List<Reconciliation_Batch__c>();

            for (Reconciliation_Batch__c batchRec : batchMap.values()) {

                batchRec.Status__c = 'Failed';
                batchRec.ErrorMessage__c =
                    ex.getMessage();

                failedBatches.add(batchRec);
            }

            update failedBatches;
        }
    }

    /*
     * Build CSV Payload
     */
    private static String buildCsv(
        List<CollectionsAllocation__c> allocations,
        Map<Id, Reconciliation_Batch__c> batchMap
    ) {

        List<String> csvLines = new List<String>();

        /*
         * CSV Header
         */
        csvLines.add(
            'GL_INTERFACE_ID,' +
            'COLL_ALLOC_ID,' +
            'TRANSACTION_LINE_ID,' +
            'TRANSACTION_NUM,' +
            'CASHIER_CODE_NAME,' +
            'CASHIER_CODE_ID,' + 
            'AMOUNT,' +
            'PAYMENT_TYPE,' +
            'CASHIER_ID,' +
            'CLOSING_DATE,' +
            'MEMO,' +
            'ACCOUNT_NAME,' +
            'INTF_STATUS'
        );

        /*
         * CSV Rows
         */
        for (CollectionsAllocation__c alloc : allocations) {

            Reconciliation_Batch__c batchRec =
                batchMap.get(
                    alloc.Reconciliation_Batch__c
                );

            List<String> cols =
                new List<String>();

            /*
             * GL_INTERFACE_ID
             * Leave blank for Oracle auto-sequence
             */
            cols.add('');

            /*
             * COLL_ALLOC_ID
             */
            cols.add(
                escapeCsv(
                    String.valueOf(alloc.Id)
                )
            );

            /*
             * TRANSACTION_LINE_ID
             */
            cols.add(
                escapeCsv(
                    String.valueOf(
                        alloc.TransactionLine__c
                    )
                )
            );

            /*
             * TRANSACTION_NUM
             */
            cols.add(
                escapeCsv(
                    alloc.TransactionLine__r
                        ?.Transaction__r?.Name
                )
            );

            /*
             * CASHIER_CODE
             */
            cols.add(
                escapeCsv(
                    alloc.TransactionLine__r?.CashierCode__r?.Name
                )
            );

            /*
             * CASHIER_CODE_ID
             */
            cols.add(
                escapeCsv(
                    alloc.TransactionLine__r?.CashierCode__c
                )
            );

            /*
             * AMOUNT
             */
            cols.add(
                alloc.AmountAllocated__c != null
                ? String.valueOf(
                    alloc.AmountAllocated__c
                  )
                : ''
            );

            /*
             * PAYMENT_TYPE
             */
            cols.add(
                escapeCsv(
                    alloc.PaymentType__c.toUpperCase()
                )
            );

            /*
             * CASHIER_ID
             */
            cols.add(
                escapeCsv(
                    batchRec.CashierSession__c
                )
            );

            /*
             * CLOSING_DATE
             */
            cols.add(
                alloc.CutOffBatchDate__c != null
                ? alloc.CutOffBatchDate__c.format('yyyy-MM-dd')
                : ''
            );

            /*
             * MEMO
             */
            cols.add(
                escapeCsv(
                    alloc.Payment__r?.pymt__Memo__c != null
                    ? alloc.Payment__r?.pymt__Memo__c
                    : ''
                )
            );

            /*
             * ACCOUNT_NAME
             */
            cols.add(
                escapeCsv(
                    alloc.Payment__r?.pymt__Account__r?.Name != null
                    ? alloc.Payment__r?.pymt__Account__r?.Name
                    : ''
                )
            );

            /*
             * INTF_STATUS
             */
            cols.add('NEW');

            csvLines.add(
                String.join(cols, ',')
            );
        }

        return String.join(csvLines, '\r\n');
    }

    /*
    * Escape CSV
    */
    private static String escapeCsv(String value) {

        if (String.isBlank(value)) {
            return '';
        }

        String escaped = value;

        // Normalize line breaks so they do not break Oracle batchload rows
        escaped = escaped.replace('\r\n', ' ');
        escaped = escaped.replace('\n', ' ');
        escaped = escaped.replace('\r', ' ');

        // Escape double quotes
        escaped = escaped.replace('"', '""');

        // Wrap in quotes when needed
        if (
            escaped.contains(',') ||
            escaped.contains('"')
        ) {
            escaped = '"' + escaped + '"';
        }

        return escaped;
    }

    /*
     * Flow Request Wrapper
     */
    public class RequestWrapper {

        @InvocableVariable(
            required=true
            label='Reconciliation Batch Id'
        )
        public Id reconciliationBatchId;
    }
}