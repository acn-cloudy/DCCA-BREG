/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
* Transaction records
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
public without sharing class TransactionDomain extends SObjectDomain{
    public TransactionDomain(List<Transaction__c> transactions) {
        super(transactions);
    }
    
    public Map<String, Transaction__c> getApp2Transaction() {
        Map<String, Transaction__c> app2Transaction = new Map<String, Transaction__c>();
        for (Transaction__c record : (List<Transaction__c> ) this.records) {
			if (record.Application__c != null) {
				app2Transaction.put(record.Application__c, record);
			}
		}
        return app2Transaction;
    }

    //case 00032255
    public List<Transaction__c> getTransactionsForDelete() {
        List<Transaction__c> transactionsForDelete = new List<Transaction__c>();
        for (Transaction__c record : (List<Transaction__c>) this.records) {
            if (record.Description__c.startsWith('Renewal Fees') && record.Application__r.LicensePeriod__c == 'This License Period') {
                transactionsForDelete.add(record);
            }
        }
        return transactionsForDelete;
    }

    // 00008048
    public List<Transaction__c> getTransactionForLicenseFees() {
        List<Transaction__c> filteredTransactions = new List<Transaction__c>();
        Map<String, Transaction__c> app2Transaction = new Map<String, Transaction__c>();
        for(Transaction__c record : (List<Transaction__c>) records) {
            // Commented based on the cae 8249
            if (record.Description__c != null
                && (record.Description__c.startsWith('License Fees') || record.Description__c.startsWith('License + Renewal Fees'))
                && record.Application__r != null && record.Application__r.Phase__c == 'L - License Review') {
                // filteredTransactions.add(record);
                app2Transaction.put(record.Application__c, record);
            }
            if(record.Description__c != null
                && (record.Description__c.startsWith('Application Fees') || record.Description__c.startsWith('Application + Renewal Fees'))
                && record.Application__r != null && record.Application__r.Phase__c == 'A - Application Received') {
                // filteredTransactions.add(record);
                app2Transaction.put(record.Application__c, record);
            }
        }
        filteredTransactions = app2Transaction.values();
        return filteredTransactions;
    }
    public void updateStatus(String status) {
        for(Transaction__c record: (List<Transaction__c> )records) {
            record.Status__c = status;
        }
        
    }
    // Used to get the Amount Outstanding sum per applications.
    public Map<String, Decimal> getSumAmtPerApp() {
        Map<String, Decimal> sumAmtPerApp = new Map<String, Decimal>();
        for(SObject record: records) {
            Transaction__c tran = (Transaction__c) record;
            String appId = tran.Application__c;
            Decimal amt = 0;
            if(appId != null && sumAmtPerApp.containsKey(appId)) {
                amt = sumAmtPerApp.get(appId);
            }
            if(tran.AmountOutstanding__c != null) {
                amt += tran.AmountOutstanding__c;
            }
            sumAmtPerApp.put(appId, amt);
        }
        return sumAmtPerApp;
    }
    
}