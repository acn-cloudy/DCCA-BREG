/*
 * Ability to calculate transaction's Payment Amount field
 * its basically the rollup sum of the Amount field of the related payment records
 * Created on 9/28/2018.
 * chris.loyola@pacificpointcorp.com
 */
public without sharing class TransactionPaymentAmtCalculator {
    public static void calculate(List<Id> transactionIds) {
        List<AggregateResult> aggregateResults = [SELECT Transaction__c trnId, SUM(pymt__Amount__c) amt
                FROM pymt__PaymentX__c
                WHERE Transaction__c IN:transactionIds
                AND pymt__Status__c='Completed' GROUP BY Transaction__c];

        //reset paymentAmount to 0
        Map<Id, Transaction__c> transactionMap = new Map<Id, Transaction__c>();
        for (Id transactionId : transactionIds) {
            transactionMap.put(transactionId, new Transaction__c(
                    Id = transactionId,
                    PaymentAmount__c = 0
            ));
        }

        for (AggregateResult aggr : aggregateResults) {
            Id trnId = (Id) aggr.get('trnId');
            Transaction__c trn = transactionMap.get(trnId);
            trn.PaymentAmount__c = aggr.get('amt') == null ? 0 : (Decimal)aggr.get('amt');
        }

        update transactionMap.values();
    }
}