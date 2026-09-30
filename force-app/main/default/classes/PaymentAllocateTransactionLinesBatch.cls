global class PaymentAllocateTransactionLinesBatch implements Schedulable, Database.Batchable <SObject> {

    global static void schedule() {
        List<CronTrigger> existingJobs = [
            SELECT
                Id,
                CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%PaymentAllocTrxnLinesBatch - Scheduled Job%'
        ];

        for (CronTrigger ct : existingJobs) {
            System.abortJob(ct.Id);
        }

        String sch0 = '0 0 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 00', sch0, new PaymentAllocateTransactionLinesBatch());

        String sch1 = '0 5 * * * ?'; 
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 05', sch1, new PaymentAllocateTransactionLinesBatch());

        String sch2 = '0 10 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 10', sch2, new PaymentAllocateTransactionLinesBatch());

        String sch3 = '0 15 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 15', sch3, new PaymentAllocateTransactionLinesBatch());

        String sch4 = '0 20 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 20', sch4, new PaymentAllocateTransactionLinesBatch());

        String sch5 = '0 25 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 25', sch5, new PaymentAllocateTransactionLinesBatch());

        String sch6 = '0 30 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 30', sch6, new PaymentAllocateTransactionLinesBatch());

        String sch7 = '0 35 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 35', sch7, new PaymentAllocateTransactionLinesBatch());

        String sch8 = '0 40 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 40', sch8, new PaymentAllocateTransactionLinesBatch());

        String sch9 = '0 45 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 45', sch9, new PaymentAllocateTransactionLinesBatch());

        String sch10 = '0 50 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 50', sch10, new PaymentAllocateTransactionLinesBatch());

        String sch11 = '0 55 * * * ?';
        System.schedule('PaymentAllocTrxnLinesBatch - Scheduled Job - 55', sch11, new PaymentAllocateTransactionLinesBatch());
    }
    
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new PaymentAllocateTransactionLinesBatch());
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        String integrationProfileId = GlobalUtilities.getIntegrationProfileId();
        String query = 'SELECT Id, ' +
            'Transaction__c, ' +
            'RemainingAmounttoAllocate__c ' +
            'FROM pymt__PaymentX__c ' +
            'WHERE FeeSchedule__c != null ' +
            'AND PPIFeeAmount__c != null ' +
            'AND pymt__Transaction_Type__c != \'Refund\' ' +
            'AND RemainingAmounttoAllocate__c > 0 ' +
            'AND pymt__Status__c = \'Completed\' ' +
            'AND CreatedBy.ProfileId <> \'' + integrationProfileId + '\'';

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<pymt__PaymentX__c> payments)
    {
        Set<Id> transactionIds = new Set<Id>();
        for (pymt__PaymentX__c payment : payments) {
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
                                 RemainingAmounttoAllocate__c
                        FROM Payments__r
                        WHERE FeeSchedule__c != null
                        AND PPIFeeAmount__c != null
                        AND pymt__Status__c = 'Completed'
                        AND pymt__Transaction_Type__c != 'Refund'
                        AND RemainingAmounttoAllocate__c > 0
                        ORDER BY Name)
                FROM Transaction__c
                WHERE Id IN :transactionIds
        ];
        //Get transaction Lines for Group Transaction children
        Map<Id, Transaction__c> childTransMap = new Map<Id, Transaction__c>(
            [SELECT Id, (SELECT Id, AmountOutstanding__c FROM TransactionLines__r ORDER BY Sort_By__c) FROM Transaction__c WHERE TransactionGroup__c IN :transactions]
        );
        
        List<CollectionsAllocation__c> toInsert = new List<CollectionsAllocation__c>();
        List<pymt__PaymentX__c> toUpdate = new List<pymt__PaymentX__c>();
        
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
                        toInsert.add(ca);
                    }
                } else { 
                    // no eligible transactions overpayment
                    for (pymt__PaymentX__c payment : trans.Payments__r) {
                        
                        if(trans.TransactionType__c == 'Payment' 
                            ? trans.TransactionLines__r.isEmpty()
                            : !childTransMap.containsKey(trans.Transactions__r[0].Id) || childTransMap.get(trans.Transactions__r[0].Id).TransactionLines__r.isEmpty())
                        {
                            PaymentAllocationException e = new PaymentAllocationException();
                            e.setMessage('Transaction: ' + trans.Id + ' has no transaction linte items to associate collection allocations to');
                            throw e;
                        }
                        
                        List<TransactionLine__c> transactionLines = trans.TransactionType__c == 'Group' ? childTransMap.get(trans.Transactions__r[0].Id).TransactionLines__r : trans.TransactionLines__r;
                                                
                        toInsert.add(new CollectionsAllocation__c(
                            Payment__c = trans.Payments__r[0].Id,
                            TransactionLine__c = transactionLines[transactionLines.size() - 1].Id,
                            Transaction__c = trans.Id,
                            AmountAllocated__c = payment.RemainingAmounttoAllocate__c,
                            Description__c = 'Overpayment'
                        ));
                    }
                }
            } else if (trans.Payments__r.size() > 0) { //there was nothing to pay against, all payments should be marked as 'unable to allocate'
                for (pymt__PaymentX__c payment : trans.Payments__r) {
                    payment.pymt__Memo__c = 'Unable to Allocate';
                    toUpdate.add(payment);
                }
            }
            
        }
        
        if (toUpdate.size() > 0) {
            update toUpdate;
        }
        
        if (toInsert.size() > 0) {
            insert toInsert;
        }
    }

    global void finish(Database.BatchableContext bc)
    {
        
    }

    public class PaymentAllocationException extends Exception{

    }
}