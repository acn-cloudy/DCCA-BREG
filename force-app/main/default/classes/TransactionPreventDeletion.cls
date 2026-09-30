/*
 * Prevent from deleting a Transaction if a related Transaction Line has a Paid Status of either Paid Or Refunded
 * Created on 11/16/2018.
 * Author irene.cahilo@pacificpointcorp.com
 */
public class TransactionPreventDeletion {
    public static void validateTransaction(List<Transaction__c> transactionList) {
        Set<Id> transactionIds = new Set<Id>();
        for (Transaction__c t : transactionList) {
            transactionIds.add(t.Id);
        }
        Profile adminProfile = [SELECT Id from Profile where Name='System Administrator' LIMIT 1];

        Map<Id, Transaction__c> transactions = new Map<Id, Transaction__c>([SELECT Id,
                (SELECT Id FROM TransactionLines__r Where PaidStatus__c = 'Paid' OR PaidStatus__c = 'Refunded')
                FROM Transaction__c
                WHERE Id IN:transactionIds]);

        for (Transaction__c transactionRecord : transactionList) {
            if (!transactions.get(transactionRecord.Id).TransactionLines__r.isEmpty() && UserInfo.getProfileId() != adminProfile.Id) {
                transactionRecord.addError('Cannot delete record if related Transaction Lines has a Paid Status of Paid or Refunded.');
            }
        }
    }
}