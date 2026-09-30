/*
* ─────────────────────────────────────────────────────────
* class for the Transaction Selector
* 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ210819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-08-21
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class TransactionSelector {
    public static List<Transaction__c> getTransactionsByAppIds(List<String> appIds) {
        return [Select Id, AmountOutstanding__c, Application__c from Transaction__c where Application__c in: appIds];
    }
    public static List<Transaction__c> getNewTransactionsByAppIds(List<String> appIds) {
        return [Select Id, AmountOutstanding__c, Application__c, Application__r.LicensePeriod__c, Application__r.Phase__c, Application__r.LicenseType__r.LicenseFees__c, Description__c, Status__c from Transaction__c
            where Application__c in: appIds and Status__c = 'New'  
            order by CreatedDate
        // Changes request from case 8249
         
        ];
    }
}