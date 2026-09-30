/*
 * Prevent from deleting a transaction line if the Paid Status is either Paid Or Refunded
 * Created on 11/16/2018.
 * Author irene.cahilo@pacificpointcorp.com
 * Updated by Alvin Zhou 14/12/2023 to add validation to prevent deletion when there has been a paid payment records
 * 
 */
public class TransactionLinePreventDeletion {
    public static Boolean skipValidation = false;
    public static void validateTransactionLine(List<TransactionLine__c> transactionLinesList) {
        if(skipValidation ) return;
        Set<Id> transactionLineIds = new Set<Id>();
        Set<String> transactionIds = new Set<String>();
        for (TransactionLine__c tl : transactionLinesList) {
            transactionLineIds.add(tl.Id);
            transactionIds.add(tl.Transaction__c);
        }
        Profile adminProfile = [SELECT Id from Profile where Name='System Administrator' LIMIT 1];

        Map<Id, TransactionLine__c> transactionLines = new Map<Id, TransactionLine__c>(
                [Select Id from TransactionLine__c Where Id in :transactionLineIds AND (PaidStatus__c = 'Paid' OR PaidStatus__c = 'Refunded')]);
        List<pymt__PaymentX__c> records = [Select Id, Transaction__c from pymt__PaymentX__c where Transaction__c in: transactionIds];
        Set<String> transactionIdsHasPayment = new Set<String>();
        for(pymt__PaymentX__c record: records) {
            transactionIdsHasPayment.add(record.Transaction__c);
        }
        for (TransactionLine__c transactionLine : transactionLinesList) {
            if (transactionLines.containsKey(transactionLine.Id) && UserInfo.getProfileId() != adminProfile.Id){
                transactionLine.addError('Cannot delete record if Transaction Line has a Paid Status of Paid or Refunded.');
            }
            if(transactionIdsHasPayment.contains(transactionLine.Transaction__c) && UserInfo.getProfileId() != adminProfile.Id){
                transactionLine.addError('Cashier Codes can not be deleted since payment has been made.');
            }
        }
        
    }
}