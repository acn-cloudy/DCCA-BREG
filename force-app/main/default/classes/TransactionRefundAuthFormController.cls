public without sharing class TransactionRefundAuthFormController {
    public String payorNameRefund{set;get;}
    public List<TransactionLine__c>  lines{set;get;}
    public TransactionRefundAuthFormController(ApexPages.StandardController std) {
        String recordId = std.getId();
        payorNameRefund = '';
        List<pymt__PaymentX__c> payments = [Select Id, PayorNameRefund__c 
            from pymt__PaymentX__c where Transaction__c =: recordId and PayorNameRefund__c != null];
        for(pymt__PaymentX__c payment: payments) {
            payorNameRefund = payment.PayorNameRefund__c;
        }
        lines = [Select Id, Name, CashierCodeCode__c, CashierCodeNameText__c, IneligibleorRejected__c, 
            NoFeeRequired__c, Overpayment__c, Withdrawal__c, OtherRefundReason__c,
          CashierCode__r.Name, OtherRefundReasonText__c, RefundAmount__c, RequestRefund__c,
         RefundReqDate__c from TransactionLine__c where Transaction__c =: recordId];
        for(TransactionLine__c line: lines) {
            line.CashierCodeNameText__c = line.CashierCode__r.Name;
            if(line.CashierCodeNameText__c != null) {
                List<String> cashierCodesStr = line.CashierCodeNameText__c.split(' ');
                
                String codeNameStr = '';
                // for(integer i=0;i<line.CashierCodeNameText__c.length(); i += 17) {
                //     Integer size = 17;
                //     if((i+17) >  line.CashierCodeNameText__c.length()) {
                //         size = line.CashierCodeNameText__c.length() - i;
                //     }
                //     String str = line.CashierCodeNameText__c.substring(i, (i+size));
                //     codeNameStr = codeNameStr + str + ' ';
                // }
                Integer index = 0;
                for(integer i=0;i<line.CashierCodeNameText__c.length(); i++) {
                    String str = line.CashierCodeNameText__c.substring(i, (i+1));
                    if(str == ' ') {
                        index = 0;
                    }
                    codeNameStr = codeNameStr + str;
                    if(index > 17) {
                        codeNameStr = codeNameStr + ' ';
                        index = 0;
                    } 
                    index ++;
                }
                line.CashierCodeNameText__c  = codeNameStr;
                if(String.isBlank(line.CashierCodeNameText__c )) {
                    line.CashierCodeNameText__c = line.CashierCode__r.Name;
                }
                
                
                // line.CashierCodeNameText__c = line.CashierCodeNameText__c.replace('/', '/ ');
            }
            
        }
    }

}