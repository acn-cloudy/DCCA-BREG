/*
* ─────────────────────────────────────────────────────────
* class for the Transaction Line Selector
* 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ280420 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2020-04-28
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class TransactionLineSelector {
    public static List<TransactionLine__c> getTransactionLinesByIds(List<String> transactionIds) {
        TransactionLine__c[] txLines = [Select Id, Transaction__c, Transaction__r.Application__c from TransactionLine__c 
        where Transaction__c in: transactionIds and PaidStatus__c != 'Paid'];
        return txLines;
    }    
}