public without sharing class TransactionHandler
{
    public static void UpdateParentTotalAmount(List<Transaction__c> updatedTransactionList,
                                               Map<Id, Transaction__c> oldMap) {
        Set<String> parentTransactionIds = new Set<String>();

        for (Transaction__c transactionItem : updatedTransactionList) {
            if (!oldMap.isEmpty() &&
                            transactionItem.TransactionGroup__c != null &&
                            transactionItem.TotalAmount__c != oldMap.get(transactionItem.Id).TotalAmount__c) {
                parentTransactionIds.add(transactionItem.TransactionGroup__c);
            } else if (oldMap.isEmpty() && transactionItem.TransactionGroup__c != null) {
                parentTransactionIds.add(transactionItem.TransactionGroup__c);
            }
        }

        if (parentTransactionIds.isEmpty()) {
            return;
        }

        List<Transaction__c> transactionList = [
                SELECT
                        Id,
                        TotalAmount__c,
                        Status__c,
                        (SELECT Id, TotalAmount__c, Status__c
                        FROM Transactions__r)
                FROM Transaction__c
                WHERE Id IN :parentTransactionIds
                AND TransactionType__c = 'Group'
        ];

        for (Transaction__c transactionItem : transactionList) {
            Decimal totalAmount = 0;

            for (Transaction__c childTransactionItem : transactionItem.Transactions__r) {
                if (childTransactionItem.TotalAmount__c != null) {
                    totalAmount += childTransactionItem.TotalAmount__c;
                }
            }

            transactionItem.TotalAmount__c = totalAmount;
        }

        update transactionList;
    }


    public static void UpdateRelatedTransactionStatus(List<Transaction__c> updatedTransactionList) {
        Set<Id> transactionIds = new Set<Id>();

        for (Transaction__c transactionItem : updatedTransactionList) {
            if (transactionItem.Status__c == 'Completed' && transactionItem.TransactionType__c == 'Group') {
                transactionIds.add(transactionItem.Id);
            }
        }

        if (transactionIds.isEmpty()) return;
        List<Transaction__c> transactionList = [
                SELECT
                        Id,
                        Status__c
                FROM Transaction__c
                WHERE TransactionGroup__c IN :transactionIds
        ];

        List<Transaction__c> toUpdate = new List<Transaction__c>();        
        for (Transaction__c transactionItem : transactionList) {
            if (transactionItem.Status__c != 'Completed') {
                transactionItem.Status__c = 'Completed';
                toUpdate.add(transactionItem);
            }
        }
        
        if(!toUpdate.isEmpty()) {
            TransactionService.isGroupTransaction = true;
            update toUpdate;
            TransactionService.isGroupTransaction = false;
        }
    }

    public static void PermitToPracticePaymentAmountSync(List<Transaction__c> transactions,
                                                         Map<Id, Transaction__c> oldTransactions) {
        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        for (Transaction__c iTransaction : transactions) {
            if (iTransaction.TotalAmount__c != oldTransactions.get(iTransaction.Id).TotalAmount__c &&
                            iTransaction.Application__c != null) {
                transactionsToUpdate.add(iTransaction);
            }
        }

        if (transactionsToUpdate.isEmpty()) return;
        List<pymt__PaymentX__c> payments = [
                SELECT
                        Transaction__c,
                        Transaction__r.TotalAmount__c,
                        pymt__Amount__c
                FROM pymt__PaymentX__c
                WHERE Transaction__c IN :(new Map<Id, Transaction__c>(transactionsToUpdate)).keySet()
                AND pymt__Status__c = null
        ];

        for (pymt__PaymentX__c payment : payments) {
            payment.pymt__Amount__c = payment.Transaction__r.TotalAmount__c;
        }
        update payments;
    }
}