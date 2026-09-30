/*
 * ___________________________________________________________________________________
 * Controller for PaymentCutOffBatch vf page
 * Covered by: PaymentCutOffBatchControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL030519 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/5/2019
 * __________________________________________________________________________________
 * Updates
 * 
 * EA05063036 -  For Case 00049424: Update "Close Out Day" Button
 * 
 */
public class PaymentCutOffBatchController {
    ApexPages.StandardSetController sc;
    public Boolean success{
        get;set;
    }

    public PaymentCutOffBatchController(ApexPages.StandardSetController controller) {
        sc = controller;
    }

    public PageReference no() {
        ListView allList = [SELECT Id FROM ListView WHERE DeveloperName='All' AND SobjectType='pymt__PaymentX__c'];
        PageReference retUrl = new PageReference('/lightning/o/pymt__PaymentX__c/list');
        retUrl.getParameters().put('filterName', allList.Id);

        return retUrl;
    }

    public PageReference yes() {

        try {

            List<pymt__PaymentX__c> payments = [
                SELECT Id,
                       Transaction__c,
                       (SELECT Id FROM Collections_Allocations__r)
                FROM pymt__PaymentX__c
                WHERE CutOffBatchDate__c = null
                AND OwnerId = :UserInfo.getUserId()
            ];

            List<CollectionsAllocation__c> collectionsAllocationToUpdate = [
                SELECT Id
                FROM CollectionsAllocation__c
                WHERE CutOffBatchDate__c = null
                AND Payment__r.OwnerId = :UserInfo.getUserId()
            ];

            if (!collectionsAllocationToUpdate.isEmpty()) {

                for (CollectionsAllocation__c col : collectionsAllocationToUpdate) {
                    col.CutOffBatchDate__c = Datetime.now();
                }

                update collectionsAllocationToUpdate;
            }

            if (!payments.isEmpty()) {

                for (pymt__PaymentX__c payment : payments) {
                    payment.CutOffBatchDate__c = Datetime.now();
                }

                update payments;
            }

            findAndCreateCollectionsAllocations(payments);

            // RUN BATCH
            ReconciliationBatchJob job =
                new ReconciliationBatchJob(true, UserInfo.getUserId());

            Id jobId = Database.executeBatch(job, 200);

            // REDIRECT TO PROCESSING PAGE
            PageReference pr = Page.PaymentCutOffProcessing;
            pr.getParameters().put('jobId', jobId);

            return pr;

        } catch (Exception e) {

            String error =
                e.getTypeName() +
                ' : ' +
                e.getMessage() +
                ' Line: ' +
                e.getLineNumber();

            ApexPages.Message msg =
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    error
                );

            ApexPages.addMessage(msg);

            return null;
        }
    }
    
    public static void createCollectionAllocations(List<Transaction__c> transactions) {
        //Get transaction Lines for Group Transaction children
        Map<Id, Transaction__c> childTransMap = new Map<Id, Transaction__c>(
            [SELECT Id, (SELECT Id, AmountOutstanding__c FROM TransactionLines__r ORDER BY Sort_By__c) FROM Transaction__c WHERE TransactionGroup__c IN :transactions]
        );

        List<CollectionsAllocation__c> toInsert = new List<CollectionsAllocation__c>();
        for (Transaction__c trans : transactions) {
            if (trans.Payments__r.size() > 0 && (trans.TransactionLines__r.size() > 0 || trans.Transactions__r.size() > 0)) {
                List<TransactionLine__c> eligibleLines = new List<TransactionLine__c>();
                for (TransactionLine__c line : trans.TransactionLines__r) {
                    if (line.AmountOutstanding__c > 0) {
                        eligibleLines.add(line);
                    }
                }
                for (Transaction__c childTr : trans.Transactions__r) {
                    if(childTransMap.containsKey(childTr.Id)){
                        for (TransactionLine__c line : childTransMap.get(childTr.Id).TransactionLines__r) {
                            if (line.AmountOutstanding__c > 0) {
                                eligibleLines.add(line);
                            }
                        }
                    }
                    else{
                        System.debug('Shouldn\'t have gotten here.');
                    }
                }

                if (!eligibleLines.isEmpty()) {
                    integer paymentIteration = 0;
                    integer transactionLineIteration = 0;
                    decimal paymentLeft = trans.Payments__r[paymentIteration].RemainingAmounttoAllocate__c;
                    decimal transactionLeft = eligibleLines[transactionLineIteration].AmountOutstanding__c;
                    while (paymentIteration < trans.Payments__r.size() && transactionLineIteration < eligibleLines.size()) {
                        pymt__PaymentX__c payment = trans.Payments__r[paymentIteration];
                        TransactionLine__c line = eligibleLines[transactionLineIteration];
                        
                        decimal allocation = Math.min(transactionLeft, paymentLeft);
                        
                        CollectionsAllocation__c ca = new CollectionsAllocation__c();
                        ca.Payment__c = payment.Id;
                        ca.TransactionLine__c = line.Id;
                        ca.Transaction__c = trans.Id;
                        ca.CutOffBatchDate__c = payment.CutOffBatchDate__c;
                        ca.AmountAllocated__c = allocation;
                        toInsert.add(ca);
                        
                        if (allocation == transactionLeft && allocation == paymentLeft) { //this payment closes out both the transaction line and payment
                            paymentIteration++;
                            if (paymentIteration < trans.Payments__r.size()) //there are more payments still to allocate
                                paymentLeft = trans.Payments__r[paymentIteration].RemainingAmounttoAllocate__c;
                            else //that was the last payment
                                paymentLeft = 0;
                            transactionLineIteration++;
                            if (transactionLineIteration < eligibleLines.size()) //there are more transaction lines still to pay
                                transactionLeft = eligibleLines[transactionLineIteration].AmountOutstanding__c;
                            else //was the final transaction line
                                transactionLeft = 0;
                        } else if (allocation == transactionLeft) { //will use up the entire transaction, but has remaining allocation on payment
                            transactionLineIteration++;
                            paymentLeft -= allocation;
                            if (transactionLineIteration < eligibleLines.size())
                                transactionLeft = eligibleLines[transactionLineIteration].AmountOutstanding__c;
                            else
                                transactionLeft = 0;
                        } else if (allocation == paymentLeft) {//will use up the entire payment, but the transaction has amount still to pay
                            paymentIteration++;
                            if (paymentIteration < trans.Payments__r.size())
                                paymentLeft = trans.Payments__r[paymentIteration].RemainingAmounttoAllocate__c;
                            else
                                paymentLeft = 0;
                            transactionLeft -= allocation;
                        }
                    }
                    if (paymentLeft > 0 && eligibleLines.size() > 0) { //create overpayment if there is more payment available
                        // create last allocation
                        CollectionsAllocation__c ca = new CollectionsAllocation__c();
                        ca.Payment__c = trans.Payments__r[paymentIteration].Id;
                        ca.TransactionLine__c = eligibleLines[eligibleLines.size() - 1].Id;
                        ca.Transaction__c = trans.Id;
                        ca.AmountAllocated__c = paymentLeft;
                        ca.Description__c = 'Overpayment';
                        ca.CutOffBatchDate__c = trans.Payments__r[paymentIteration].CutOffBatchDate__c;
                        toInsert.add(ca);
                    }
                } else { 
                    // no eligible transactions overpayment
                    for (pymt__PaymentX__c payment : trans.Payments__r) {
                        
                        if(trans.TransactionType__c == 'Payment' 
                            ? trans.TransactionLines__r.isEmpty()
                            : !childTransMap.containsKey(trans.Transactions__r[0].Id) || childTransMap.get(trans.Transactions__r[0].Id).TransactionLines__r.isEmpty())
                        { } else {
                            List<TransactionLine__c> transactionLines = trans.TransactionType__c == 'Group' ? childTransMap.get(trans.Transactions__r[0].Id).TransactionLines__r : trans.TransactionLines__r;
                                                
                            toInsert.add(new CollectionsAllocation__c(
                                Payment__c = trans.Payments__r[0].Id,
                                TransactionLine__c = transactionLines[transactionLines.size() - 1].Id,
                                Transaction__c = trans.Id,
                                AmountAllocated__c = payment.RemainingAmounttoAllocate__c,
                                CutOffBatchDate__c = payment.CutOffBatchDate__c,
                                Description__c = 'Overpayment'
                            ));
                        }
                    }
                }
            }
        }
        if (toInsert.size() > 0) {
            insert toInsert;
        }
    }

    public static void findAndCreateCollectionsAllocations(List<pymt__PaymentX__c> payments) {
        List<String> transactionIds = new List<String>();
        for (pymt__PaymentX__c payment : payments) {
            if(payment.Collections_Allocations__r == null || payment.Collections_Allocations__r.isEmpty())
                transactionIds.add(payment.Transaction__c);
        }
        List<Transaction__c> transactions = [
                SELECT
                        Id,
                        TransactionType__c,
                        (SELECT
                                 Id
                        FROM Transactions__r),
                        (SELECT
                                 Id,
                                 AmountOutstanding__c
                        FROM TransactionLines__r
                        ORDER BY Sort_By__c),
                        (SELECT
                                 Id,
                                 RemainingAmounttoAllocate__c,
                                 CutOffBatchDate__c
                        FROM Payments__r
                        WHERE PPIFeeAmount__c != null
                        AND pymt__Status__c = 'Completed'
                        AND pymt__Transaction_Type__c != 'Refund'
                        AND RemainingAmounttoAllocate__c > 0
                        ORDER BY Name)
                FROM Transaction__c
                WHERE Id IN :transactionIds
        ];
        createCollectionAllocations(transactions);
    }

}