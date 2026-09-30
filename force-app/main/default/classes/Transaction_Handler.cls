/*
* ─────────────────────────────────────────────────────────
* class for the Transaction Handller used to handle 
* Transaction trigger
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
public class Transaction_Handler implements ITrigger {
    public Transaction_Handler(){}

    public void bulkBefore() {
        List<Transaction__c> tNew = Trigger.new;
        Map<Id, Transaction__c> tOldMap = (Map<Id, Transaction__c>) Trigger.oldMap;

        if (Trigger.isUpdate) {
            List<Transaction__c> bcfGroupTransactions = new List<Transaction__c>();

            for (Transaction__c t : tNew) {
                if (t.TransactionType__c == 'Group' && t.Status__c == 'Pending' && tOldMap.get(t.Id).Status__c != t.Status__c) {
                    bcfGroupTransactions.add(t);
                }
            }


            if (!bcfGroupTransactions.isEmpty()) {
                TransactionService.calculateGroupTransactionTotalAmount(bcfGroupTransactions);
            }
        }
    }

    public void bulkAfter() {
        if (Trigger.isInsert) {
            // case 00032255
            if(!TransactionService.isRenewalTransaction) {
                //00005478 : Trigger to populate Transaction Lines
                TransactionService.generateTransactionLines(Trigger.new);
            }

            //00006398 : Trigger to populate the Outstanding Amount Owed on the Account
            TransactionService.calculateParentAccountsOutstandingAmount(Trigger.new);

            //00010556 : Trigger to share talend user owned records to Delete_Transaction_Record_Public_Group group
            TransactionService.shareTalendUserRecordsToGroup(Trigger.new, 'Delete_Transaction_Record_Public_Group');
        }

        if (Trigger.isUpdate) {
            List<Transaction__c> txnsForParentAccountOutstandingAmtCalc = new List<Transaction__c>();

            //00010556 : Trigger to share talend user owned records to Delete_Transaction_Record_Public_Group group
            List<Transaction__c> transactionsToShare = new List<Transaction__c>();
            for (SObject t : Trigger.new) {
                Transaction__c tx = (Transaction__c) t;
                Transaction__c txOld = (Transaction__c) Trigger.oldMap.get(tx.Id);
                if (tx.OwnerId != txOld.OwnerId) {
                    transactionsToShare.add(tx);
                }

                if (tx.AmountOutstanding__c != txOld.AmountOutstanding__c) {
                    txnsForParentAccountOutstandingAmtCalc.add(tx);
                }
            }

            //00006398 : Trigger to populate the Outstanding Amount Owed on the Account
            TransactionService.calculateParentAccountsOutstandingAmount(txnsForParentAccountOutstandingAmtCalc);

            if (!transactionsToShare.isEmpty()) {
                TransactionService.shareTalendUserRecordsToGroup(Trigger.new, 'Delete_Transaction_Record_Public_Group');
            }
        }
    }
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {
        TransactionService.cacheRecordsForAppAmtCal(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        TransactionService.cacheRecordsForAppAmtCal(oldSo, so);
    }
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {}
    public void andFinally() {
        TransactionService.runFinally(Trigger.new);
    }
}