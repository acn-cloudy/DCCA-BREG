/******
 * Description: customize the payment save method in the payment terminal function
 * created By: Alvin Zhou
 * PC00011302-AZ110520
 * *** */
public class PaymentTerminalController {
    @AuraEnabled
    public static void updatePayment(String paymentStr) {
        updatePaymentAsync(paymentStr);
    }

    @future
    public static void updatePaymentAsync(String paymentStr) {
        pymt__PaymentX__c payment = (pymt__PaymentX__c) JSON.deserialize(paymentStr, pymt__PaymentX__c.class);
        Transaction__c tran = new Transaction__c();
        tran.Id = payment.Transaction__c;
        tran.TempPaymentType__c = payment.pymt__Payment_Type__c;
        update tran;
        update payment;
    }

    @AuraEnabled
    public static void updateTempPayment(String recordId, String paymentType, String memo) {
        Transaction__c record = new Transaction__c();
        record.Id = recordId;
        record.TempPaymentType__c = paymentType;
        record.TempMemo__c = memo;
        update record;
    }

    @AuraEnabled
    public static List<String> validateTransaction(String recordId){
        Transaction__c record = [Select Id, Account__c, Account__r.MostRecentBouncedCheck__c, Account__r.MostRecentDisputedCharge__c, AmountOutstanding__c, TransactionType__c, (Select Id from TransactionLines__r) from Transaction__c where Id =: recordId];
        if(record.AmountOutstanding__c == 0 || record.AmountOutstanding__c == null) {
            String error1 = 'Please make sure the outstanding amount is greater than zero before making a payment.';
            AuraHandledException ex = new AuraHandledException(error1);
            ex.setMessage(error1);
            throw ex;
        }
        if(record.TransactionType__c != 'Group' && (record.TransactionLines__r == null || record.TransactionLines__r.size() == 0)) {
            String error2 = 'Please enter at least one transaction line before making a payment.';
            AuraHandledException ex2 = new AuraHandledException(error2);
            ex2.setMessage(error2);
            throw ex2;
        }
        
        
        List<String> options;
        if(record.Account__c != null && record.Account__r.MostRecentDisputedCharge__c != null) {
            options = new List<String>();
            options.add('disputed charge');

        }else if(record.Account__c != null && record.Account__r.MostRecentBouncedCheck__c != null) {
            options = new List<String>();
            options.add('bounced check');
        } else {
            options = new List<String> {'Check', 'Credit Card', 'ECheck', 'Electronic Funds Transfer', 'Treasury Deposit (TDR)', 'Journal Voucher (JV)', 'Deposit Slipa'};
        }
        return options;
    }
}