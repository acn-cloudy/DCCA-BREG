public without sharing class PaymentDisplayController {
    @AuraEnabled
    public static String getTransactionLines(String recordId) {
        try {
            Application__c cache =  [Select Id from Application__c where DraftApplication__c =: recordId limit 1];
            List<Transaction__c> transactions = [Select Id, Application__c from Transaction__c where Application__c =: cache.Id];
            if(!transactions.isEmpty()) {
                String transactionId = transactions.get(0).Id;
                List<TransactionLine__c> lineItems = [Select Id, CashierCode__r.Name, Amount__c from TransactionLine__c where Transaction__c=: transactionId];
                return JSON.serialize(lineItems);
            }
            return '';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getPaymentLink(String recordId) {
        try {
            Application__c cache =  [Select Id from Application__c where DraftApplication__c =: recordId limit 1];
            List<Transaction__c> transactions = [Select Id, Application__c from Transaction__c where Application__c =: cache.Id];
            if(!transactions.isEmpty()) {
                String transactionId = transactions.get(0).Id;
                pymt__PaymentX__c payment = [Select Id, SubscriberPaymentLink__c from pymt__PaymentX__c where Transaction__c =: transactionId limit 1];
                return payment.SubscriberPaymentLink__c;
            }
            return '';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean transactionAdjustmentInProgress(String recordId) {
        try {
            Application__c app =  [Select Id, LastModifiedDate from Application__c where DraftApplication__c =: recordId limit 1];
            Datetime currentTime = Datetime.now();
            // If it was just changed, return false
            if(app.LastModifiedDate != null && app.LastModifiedDate.addSeconds(10) >= currentTime){
                return false;
            }
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}