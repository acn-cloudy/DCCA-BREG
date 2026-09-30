public with sharing class CollectionsAllocationDomain extends SObjectDomain{
    public CollectionsAllocationDomain(List<CollectionsAllocation__c> records) {
        super(records);
    }
    public Map<String, Decimal> summarizeAllocationRecordAmount(String paymentType) {
        Map<String, Decimal> cashierCodeAmount = new Map<String, Decimal>();
        for(CollectionsAllocation__c record : (List<CollectionsAllocation__c>) records) {
            String uniqueKey = record.TransactionLine__r.CashierCode__r.FundAccount__c +
                record.TransactionLine__r.CashierCode__r.FAMISSrcCode__c +
                record.TransactionLine__r.CashierCode__r.CostCenter__c;
            Decimal amount = 0;
            amount = record.AmountAllocated__c;
            if(paymentType == 'Credit Card') {
                amount = record.NetCollectionsafterFeesAllocated__c;
            }
            Decimal totalAmount = 0;
            if(cashierCodeAmount.containsKey(uniqueKey)) {
                totalAmount = cashierCodeAmount.get(uniqueKey);
            }
            if(amount == null) 
                amount = 0;
            totalAmount = amount + totalAmount;
            cashierCodeAmount.put(uniqueKey, totalAmount);
        }
        return cashierCodeAmount;
    }
    public void checkJVProcessed() {
        for(CollectionsAllocation__c record: (List<CollectionsAllocation__c>) records) {
            record.JVProcessed__c = true;
        }
    }

    public List<FiscalFormFeed.DataFeed> getDataFeeds(Map<String, Decimal> cashierCodeAmount, String year) {
        Set<String> cashierCodeSet = new Set<String>();
    
        List<FiscalFormFeed.DataFeed> dataFeeds = new List<FiscalFormFeed.DataFeed>();
        for(CollectionsAllocation__c record: (List<CollectionsAllocation__c>) records) {
            String uniqueKey = record.TransactionLine__r.CashierCode__r.FundAccount__c +
                record.TransactionLine__r.CashierCode__r.FAMISSrcCode__c +
                record.TransactionLine__r.CashierCode__r.CostCenter__c;

            if(cashierCodeSet.contains(uniqueKey)) {
                continue;
            }
            
            FiscalFormFeed.DataFeed feed = new FiscalFormFeed.DataFeed();
            
            feed.tcValue = '011';
            feed.recordId = record.Id;
            if(record.TransactionLine__r.CashierCode__r.FundAccount__c != null) {
                feed.sValue = record.TransactionLine__r.CashierCode__r.FundAccount__c.split('-')[0];
            }
            
            feed.yrValue = year;
            if(record.TransactionLine__r.CashierCode__r.FundAccount__c != null) 
                feed.appValue = record.TransactionLine__r.CashierCode__r.FundAccount__c.split('-')[1];
            // feed.dValue = record.TransactionLine__r.CashierCode__r.Division__c.substring(0, 1);
            feed.dValue = 'R';
            feed.sourceObjValue = record.TransactionLine__r.CashierCode__r.FAMISSrcCode__c;
            feed.costCenterValue = record.TransactionLine__r.CashierCode__r.CostCenter__c;
            if (String.isBlank(feed.costCenterValue)) {
                feed.costCenterValue = '0';
            }
            feed.amount = cashierCodeAmount.get(uniqueKey);
            dataFeeds.add(feed);
            cashierCodeSet.add(uniqueKey);
            
        }
        return dataFeeds;
    }
    public List<FiscalFormFeed.DataFeed> getJVFeeds(String year) {
        Map<String, List<CollectionsAllocation__c>> collectionAllocationMap = new Map<String, List<CollectionsAllocation__c>>();
        for(CollectionsAllocation__c record: (List<CollectionsAllocation__c>) records) {
            String transactionId = record.Transaction__c;
            List<CollectionsAllocation__c> allocations = new List<CollectionsAllocation__c>();
            if(collectionAllocationMap.containsKey(transactionId)) {
                allocations = collectionAllocationMap.get(transactionId);
            }
            allocations.add(record);
            collectionAllocationMap.put(transactionId, allocations);
        }
        Integer lastValue = 0;
        Integer index = 1;
        List<FiscalFormFeed.DataFeed> dataFeeds = new List<FiscalFormFeed.DataFeed>();
        for(String transactionId: collectionAllocationMap.keySet()) {
            List<CollectionsAllocation__c> allocations = collectionAllocationMap.get(transactionId);
            if((lastValue + allocations.size()) > 14 && allocations.size() <= 14) {
                for(Integer i = 0;i< (14 - lastValue); i++) {
                    FiscalFormFeed.DataFeed feed = new FiscalFormFeed.DataFeed();
                    feed.indexValue = '';
                    feed.tcValue = '';
                    feed.sValue = '';
                    feed.yrValue = '';
                    feed.appValue = '';
                    feed.dValue = '';
                    feed.sourceObjValue = '';
                    feed.costCenterValue = '';
                    dataFeeds.add(feed);
                }
                lastValue = allocations.size();

            } else {
                lastValue = lastValue + allocations.size();
            }
            for(CollectionsAllocation__c record: allocations) {
                String indexValue = '' + index;
                if(indexValue.length() == 1) {
                    indexValue = '0' + indexValue;
                }
                FiscalFormFeed.DataFeed feed = new FiscalFormFeed.DataFeed();
                feed.indexValue = indexValue;
                feed.tcValue = '011';
                feed.fValue = record.TransactionLine__r.CashierCode__r.FundAccount__c.split('-')[0];
                feed.yrValue = year;
                feed.appValue = record.TransactionLine__r.CashierCode__r.FundAccount__c.split('-')[1];
                // feed.dValue = record.TransactionLine__r.CashierCode__r.Division__c.substring(0, 1);
                feed.recordId = record.Id;
                feed.dValue = 'R';
                feed.sourceObjValue = record.TransactionLine__r.CashierCode__r.FAMISSrcCode__c;
                feed.costCenterValue = record.TransactionLine__r.CashierCode__r.CostCenter__c;
                feed.projectNumValue = record.TransactionLine__r.CashierCode__r.CashierCode__c;
                Decimal amount = record.AmountAllocated__c;
                System.debug('##########Payment Name##########' + record.Payment__r.Name + '#####Cashier Code####' + record.TransactionLine__r.CashierCode__r.CashierCode__c 
                    + '#####amount####' + amount + '#####recordId####' + record.Id);
                if(amount != null) {
                    amount = amount.abs();
                    feed.jVAmount1 = amount.intValue() + '';
                    String amount2 = ((amount - amount.intValue()) * 100 ).intValue() + '';
                    feed.jVAmount2 = amount2;
                }
                feed.transactionId = record.Transaction__c;
                dataFeeds.add(feed);
                index ++;
            }   
        }
        return dataFeeds;

    } 
}