public without sharing class BREGPaymentReceiptPdfController {
    // Data
    public pymt__PaymentX__c payment {get; set;}
    public List<TransactionLine__c> transactionLineItems {get; set;}
    public List<TransactionLineItemWrapper> transactionLineItemWrappers {get; set;}

    // --PAYMENT RECEIPT INFORMATION--
    public String transactionDate {get; set;}
    public String transactionAmount {get; set;}

    // Custom controller constructor
    public BREGPaymentReceiptPdfController() {
        // Get the payment ID from URL parameters
        String paymentId = ApexPages.currentPage().getParameters().get('id');
        if (String.isNotBlank(paymentId)) {
            this.payment = getPayment(paymentId);
            initializeReceiptData();
        }
    }
    
    // Initialize receipt data based on payment information
    private void initializeReceiptData() {
        if (this.payment != null) {
            this.transactionDate = this.payment.pymt__Date__c != null ? this.payment.pymt__Date__c.format() : '';
            this.transactionAmount = this.payment.pymt__Amount__c != null ? '$' + String.valueOf(this.payment.pymt__Amount__c.setScale(2)) : '';
            this.transactionLineItems = BREGPaymentController.getTransactionLines(new Set<Id>{ this.payment.Id });
            List<BREGPaymentController.TransactionLineWrapper> consolidatedWrappers = BREGPaymentController.getTransactionLineWrappers(this.transactionLineItems);
            this.transactionLineItemWrappers = mapToTransactionLineItemWrappers(consolidatedWrappers);
        }
    }

    private List<TransactionLineItemWrapper> mapToTransactionLineItemWrappers(List<BREGPaymentController.TransactionLineWrapper> consolidatedWrappers) {
        List<TransactionLineItemWrapper> result = new List<TransactionLineItemWrapper>();
        for (BREGPaymentController.TransactionLineWrapper wrapper : consolidatedWrappers) {
            TransactionLineItemWrapper itemWrapper = new TransactionLineItemWrapper();
            itemWrapper.workItemNumber = wrapper.workItemNumber != null ? wrapper.workItemNumber : 'N/A';
            
            String item = wrapper.description != null ? wrapper.description : 'N/A';
            if (wrapper.description != null && (wrapper.isCertified == true || wrapper.isExpedited == true)) {
                List<String> tags = new List<String>();

                if (wrapper.isCertified == true) {
                    tags.add('Certified');
                }
                if (wrapper.isExpedited == true) {
                    tags.add('Expedited');
                }

                if (!tags.isEmpty()) {
                    item += ' (' + String.join(tags, ', ') + ')';
                }
            }

            itemWrapper.item = item;            
            itemWrapper.quantity = wrapper.quantity != null ? String.valueOf(wrapper.quantity) : 'N/A';
            itemWrapper.amount = wrapper.price != null ? '$' + String.valueOf(wrapper.price.setScale(2)) : 'N/A';
            result.add(itemWrapper);
        }
        return result;
    }

    private static pymt__PaymentX__c getPayment(Id paymentId) {
        return [
            SELECT 
                Id, 
                pymt__Date__c,
                pymt__Transaction_Id__c,
                pymt__Amount__c,
                pymt__Payment_Type__c,
                pymt__Card_Type__c,
                pymt__Last_4_Digits__c,
                pymt__Authorization_Id__c,
                pymt__Billing_First_Name__c,
                pymt__Billing_Last_Name__c,
                breg_Case__c,
                Transaction__r.Name
            FROM 
                pymt__PaymentX__c 
            WHERE 
                Id = :paymentId
        ];
    }

    public class TransactionLineItemWrapper {
        @AuraEnabled
        public String workItemNumber {get; set;}
        @AuraEnabled
        public String item {get; set;}
        @AuraEnabled
        public String quantity {get; set;}
        @AuraEnabled
        public String amount {get; set;}
    }
}