public without sharing class TransactionLineHandler 
{
    public static void UpdateParentTotalAmount(List<TransactionLine__c> transactionLineList) {
        Set<Id> transactionIds = new Set<Id>();

        for (TransactionLine__c transactionLine : transactionLineList) {
            if (transactionLine.PaidStatus__c != 'BCF') {
                transactionIds.add(transactionLine.Transaction__c);
            }
        }

        if (transactionIds.size() == 0) {
            return;
        }

        List<Transaction__c> transactionList = [ 
                SELECT
                        Id,
                        TotalAmount__c,
                        (SELECT Id, Amount__c
                        FROM TransactionLines__r)
                FROM Transaction__c
                WHERE Id = :transactionIds
                AND TransactionType__c != 'Group'
        ];

        for (Transaction__c transactionItem : transactionList) {
            Decimal totalAmount = 0;
            for (TransactionLine__c transactionLine : transactionItem.TransactionLines__r) {
                totalAmount += transactionLine.Amount__c == null ? 0 : transactionLine.Amount__c;
            }

            if(Trigger.isDelete && totalAmount == 0) totalAmount = null;
            
            transactionItem.TotalAmount__c = totalAmount;
        }

        update transactionList; 
    }

    public static void updatePartialStatus(List<TransactionLine__c> records, 
        Map<Id, TransactionLine__c> oldRecords) {
        for(TransactionLine__c record: records) {
            TransactionLine__c oldRecord = oldRecords.get(record.Id);
            if(record.PaidStatus__c == 'Paid' 
                && record.AmountCollected__c != oldRecord.AmountCollected__c
                && record.AmountCollected__c == 0
                && record.RequestRefund__c == true) {
                record.PaidStatus__c = 'Refunded';
                record.RequestRefund__c = false;
                record.RefundDate__c = Date.today();
            } else if(record.PaidStatus__c == 'Paid' 
                && record.AmountCollected__c != oldRecord.AmountCollected__c
                && record.AmountCollected__c != 0
                && record.RequestRefund__c == true) {
                record.PaidStatus__c = 'Refunded';
                record.RequestRefund__c = false;
                record.RefundDate__c = Date.today();
            }
            if(record.PaidStatus__c != 'Refunded' && record.PaidStatus__c != 'Paid' 
                && record.AmountCollected__c != oldRecord.AmountCollected__c) {
                if(record.Amount__c > record.AmountCollected__c) {
                    record.PaidStatus__c = 'Pending';
                } else {
                    record.PaidStatus__c = 'Paid';
                    record.Partial_Payment_Apply__c = false;
                }
            }   
        }
    }

    public static void checkFranchiseTransactionLines(List<TransactionLine__c> records){
        
        Map<Id, TransactionLine__c> tTLMap = new Map<Id, TransactionLine__c>();
        Map<Id, TransactionLine__c> ccTLMap = new Map<Id, TransactionLine__c>();
        for(TransactionLine__c tl:records){
            tTLMap.put(tl.Transaction__c, tl);
            ccTLMap.put(tl.CashierCode__c, tl);
        }

        // Check Franchise Applications
        Map<Id, Integer> tlFranchiseAgreementMap = new Map<Id, Integer>();
        for(Transaction__c trnsc: [
            SELECT Id, Application__r.FranchiseAgreements__c 
            FROM Transaction__c 
            WHERE Application__r.FranchiseAgreements__c > 0
            AND Application__r.LicenseType__r.Name IN ('DIS', 'F')
            AND Application__r.Type__c IN ('RNEW - Renewal', 'RSTR - Restore - No A/I Status')
            AND Id IN :tTLMap.keySet()
        ]){
            TransactionLine__c tl = tTLMap.get(trnsc.Id);
            tlFranchiseAgreementMap.put(tl.Id, Integer.valueOf(trnsc.Application__r.FranchiseAgreements__c));
        }
        
        // Check Casheir Code
        if(!tlFranchiseAgreementMap.isEmpty()){
            for(CashierCode__c cc: [
                SELECT Id, Amount__c 
                FROM CashierCode__c 
                WHERE CashierCode__c = '331'
                AND Id IN :ccTLMap.keySet()
            ]){
                TransactionLine__c tl = ccTLMap.get(cc.Id);
                Integer fa = Integer.valueOf(tlFranchiseAgreementMap.get(tl.Id));
                tl.Amount__c = cc.Amount__c * fa;
            }
        }
    }
}