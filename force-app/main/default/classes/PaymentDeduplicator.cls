/*
 * ___________________________________________________________________________________
 * When a non Credit Card payment its created (pymt__PaymentX__c.pymt__Payment_Type__c <> "Credit Card" ,
 * check to see if duplicates were also created.
 * Duplicate payments will be other payments that have the following properties:
 * - pymt__PaymentX__c.TransactionId__c is the same
 * - pymt__PaymentX__c.pymt__Amount__c is the same
 * - pymt__PaymentX__c.pymt__Payment_Type__c is the same
 * - Payment Created Date is within 5 seconds of each other.
 * NOTE!! This will only check for records created Today
 * Covered by: PaymentDeduplicatorTest
 * __________________________________________________________________________________
 * PacPoint-CL031919 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/19/2019
 * __________________________________________________________________________________
 */
public class PaymentDeduplicator {
    public static boolean disableTrigger = false;
    public static void deduplicate(Map<Id, pymt__PaymentX__c> newPaymentsMap) {
        if(UserInfo.getUserType() == 'Guest') return;
        List<pymt__PaymentX__c> paymentsToDelete = new List<pymt__PaymentX__c>();        
        List<String> paymentIds = new List<String>();
        Set<String> paymentTypes = new Set<String>();
        Set<String> paymentStatuses = new Set<String>();

        Map<String, pymt__PaymentX__c> paymentMap = new Map<String, pymt__PaymentX__c>();
        for(pymt__PaymentX__c payment : newPaymentsMap.values()) {
        
            paymentMap.put(payment.Name, payment);
        }

        for (pymt__PaymentX__c payment : newPaymentsMap.values()) {
            
            paymentTypes.add(payment.pymt__Payment_Type__c);
            paymentStatuses.add(payment.pymt__Status__c);
        }

        List<pymt__PaymentX__c> possibleDuplicates = [SELECT Id,
            CreatedDate,
            Name,
            CreatedById,
            pymt__Payment_Type__c,
            pymt__Status__c,
            pymt__Amount__c,
            Transaction__c
            FROM pymt__PaymentX__c
            WHERE Name IN :paymentMap.KeySet()
            AND pymt__Payment_Type__c IN :paymentTypes
            AND pymt__Status__c IN :paymentStatuses
            AND CreatedDate = TODAY
            ORDER BY CreatedDate
        ];

        if (possibleDuplicates.isEmpty()) {
            return;
        }
        Map<String, List<pymt__PaymentX__c>> paymentMaps = new Map<String, List<pymt__PaymentX__c>>();
        Map<String, String> paymentTransactionIds = new Map<String, String>();
        for (pymt__PaymentX__c payment : possibleDuplicates) {
            String paymentName = payment.Name;
            if(payment.Transaction__c != null) {
                paymentTransactionIds.put(paymentName, payment.Transaction__c);
            }
            List<pymt__PaymentX__c> unitPayments = new List<pymt__PaymentX__c>();
            if(paymentMaps.containsKey(paymentName)) {
                unitPayments = paymentMaps.get(paymentName);
            }
            unitPayments.add(payment);
            paymentMaps.put(paymentName, unitPayments);
        }
        List<pymt__PaymentX__c> recordsForUpdate = new List<pymt__PaymentX__c>();
        for(String paymentName : paymentMaps.keySet()) {
            List<pymt__PaymentX__c> unitPayments = paymentMaps.get(paymentName);
            pymt__PaymentX__c currentPayment = unitPayments.get(unitPayments.size() -1);
            if(currentPayment.Transaction__c == null) {
                currentPayment.Transaction__c = paymentTransactionIds.get(currentPayment.Name);
                recordsForUpdate.add(currentPayment);
            }
            for(Integer i = 0 ;i< unitPayments.size(); i ++ ) {
                pymt__PaymentX__c payment = unitPayments.get(i);
                Datetime startStart = payment.CreatedDate;
                Datetime endTime = currentPayment.CreatedDate;
                
                Long diff = (endTime.getTime() - startStart.getTime()) / 1000;
                
                if(diff < 0 ) {
                    continue;
                }
                if (payment.Id != currentPayment.Id && 
                    payment.CreatedById == currentPayment.CreatedById &&
                        payment.pymt__Amount__c == currentPayment.pymt__Amount__c &&
                        payment.pymt__Payment_Type__c == currentPayment.pymt__Payment_Type__c &&
                        payment.pymt__Status__c == currentPayment.pymt__Status__c 
                        && Math.abs(diff) <= 40
                        ) {
                    paymentsToDelete.add(payment);
                }

            }
        }
        
        if(!paymentsToDelete.isEmpty()) {
            Database.delete( paymentsToDelete, true);
        }
        if(!recordsForUpdate.isEmpty()) {
            disableTrigger = true;
            Database.update(recordsForUpdate, false);
            disableTrigger = false;
        }
    }


    // public static void deduplicate(Map<Id, pymt__PaymentX__c> newPaymentsMap) {
    //     Set<String> transactionIds = new Set<String>();
    //     Set<String> paymentTypes = new Set<String>();
    //     Set<String> paymentStatuses = new Set<String>();
    //     Map<Id, pymt__PaymentX__c> transactionNewPaymentMap = new Map<Id, pymt__PaymentX__c>();
    //     List<String> paymentNames = new List<String>();
    //     List<String> paymentIds = new List<String>();
    //     for(pymt__PaymentX__c payment : newPaymentsMap.values()) {
    //         paymentNames.add(payment.Name);
    //         paymentIds.add(payment.Id);
    //     }
    //     Map<String, String> transactionNames = new Map<String, String>();
    //     List<Transaction__c> transactions = [Select Id, Name from Transaction__c where Name in: paymentNames];
    //     for(Transaction__c record: transactions) {
    //         transactionNames.put(record.Name, record.Id);
    //     }
    //     for (pymt__PaymentX__c payment : newPaymentsMap.values()) {
    //         String transactionId = payment.Transaction__c;
    //         if(transactionNames.get(payment.Name) != null) {
    //             transactionId = transactionNames.get(payment.Name);
    //         }
    //         transactionIds.add(transactionId);
    //         paymentTypes.add(payment.pymt__Payment_Type__c);
    //         paymentStatuses.add(payment.pymt__Status__c);
    //         transactionNewPaymentMap.put(transactionId, payment);
    //     }

    //     System.debug('paymentsMap---');
    //     System.debug(transactionIds);
    //     System.debug(paymentTypes);
    //     System.debug(paymentStatuses);
    //     System.debug(newPaymentsMap);
    //     System.debug('paymentsMap---');

    //     List<pymt__PaymentX__c> possibleDuplicates = [SELECT Id,
    //     CreatedDate,
    //     Name,
    //     pymt__Payment_Type__c,
    //     pymt__Status__c,
    //     pymt__Amount__c,
    //     Transaction__c
    //     FROM pymt__PaymentX__c
    //     WHERE Name IN :paymentNames
    //     AND pymt__Payment_Type__c IN :paymentTypes
    //     AND pymt__Status__c IN :paymentStatuses
    //     AND CreatedDate = TODAY
    //     ORDER BY CreatedDate DESC];

    //     System.debug('possibleDuplicates---');
    //     System.debug(possibleDuplicates);

    //     if (possibleDuplicates.isEmpty()) {
    //         return;
    //     }

    //     Map<Id, Map<Id, pymt__PaymentX__c>> transactionPaymentsMap = new Map<Id, Map<Id, pymt__PaymentX__c>>();

    //     for (pymt__PaymentX__c payment : possibleDuplicates) {
    //         String transactionId = payment.Transaction__c;
    //         if(transactionNames.get(payment.Name) != null) {
    //             transactionId = transactionNames.get(payment.Name);
    //         }
    //         if (!transactionPaymentsMap.keySet().contains(transactionId)) {
    //             transactionPaymentsMap.put(transactionId, new Map<Id, pymt__PaymentX__c>());
    //         }

    //         transactionPaymentsMap.get(transactionId).put(payment.Id, payment);
    //     }

    //     List<pymt__PaymentX__c> paymentsToDelete = new List<pymt__PaymentX__c>();
    //     Set<Id> paymentsToDeleteIds = new Set<Id>();

    //     for (String transId : transactionIds) {
    //         List<pymt__PaymentX__c> payments = transactionPaymentsMap.get(transId).values();

    //         for (Integer i = 0; i < payments.size(); i++) {
    //             if (transactionNewPaymentMap.get(transId).Id == payments[i].Id ||
    //                             transactionNewPaymentMap.get(transId).pymt__Amount__c != payments[i].pymt__Amount__c) {
    //                 continue;
    //             }

    //             pymt__PaymentX__c currPayment = payments[i];
    //             pymt__PaymentX__c prevPayment = (i == 0) ? transactionNewPaymentMap.get(transId) : payments[i - 1];

    //             Datetime startStart = currPayment.CreatedDate;
    //             Datetime endTime = prevPayment.CreatedDate;

    //             Long diff = (endTime.getTime() - startStart.getTime()) / 1000;

    //             System.debug(diff);
    //             if (currPayment.pymt__Amount__c == prevPayment.pymt__Amount__c &&
    //                             currPayment.pymt__Payment_Type__c == prevPayment.pymt__Payment_Type__c &&
    //                             currPayment.pymt__Status__c == prevPayment.pymt__Status__c &&
    //                     Math.abs(diff) <= 5
    //             ) {
    //                 if (!paymentsToDeleteIds.contains(payments[i].Id)) {
    //                     paymentsToDelete.add(payments[i]);
    //                     paymentsToDeleteIds.add(payments[i].Id);
    //                 }
    //             }
    //         }
    //     }

    //     if (!paymentsToDelete.isEmpty()) {
    //         System.debug('paymentsToDelete-----');
    //         System.debug(paymentsToDelete);
    //         delete paymentsToDelete;
    //     }
    // }
}