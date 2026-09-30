public without sharing class PVL_PaymentReceiptController {
    public pymt__PaymentX__c payment {get;set;}
    public List<TransactionLine__c> transactionLine_L {get;set;}
    public Map<Id, String> cashierCode_M {get;set;}
    public string transactionId {get;set;}
    public string transactionDate {get;set;}
    public string paymentId {get;set;}
    public PVL_PaymentReceiptController() {
        paymentId = ApexPages.currentPage().getParameters().get('id');
        transactionId = ApexPages.currentPage().getParameters().get('tranId');
        transactionDate = ApexPages.currentPage().getParameters().get('tranDate');
        transactionLine_L = new List<TransactionLine__c>();
        cashierCode_M = new Map<Id, String>();
        payment = [
                SELECT
                        Id,
                        Transaction__r.Application__r.ApplicantNameText__c,
                        Transaction__r.Application__r.Name,
                        Transaction__r.Application__r.CurrentLicense__r.Name,
                        Transaction__r.Application__r.LicenseTypeDescription__c,
                        Transaction__c,
                        Transaction__r.Name,
                        pymt__Card_Type__c,
                        pymt__Billing_First_Name__c,
                        pymt__Billing_Last_Name__c,
                        pymt__Last_4_Digits__c,
                        Name,
                        pymt__Contact__r.Name,
                        pymt__Contact__r.Phone,
                        pymt__Account__r.RecordType.Name,
                        pymt__Billing_Email__c,
                        pymt__Amount__c,
                        pymt__Transaction_Id__c,
                        pymt__Date__c,
                        Transaction__r.Description__c,
                        pymt__Billing_Street__c,
                        pymt__Billing_City__c,
                        pymt__Billing_Postal_Code__c, pymt__Billing_Country__c
                FROM pymt__PaymentX__c
                WHERE Id =: paymentId
        ];
        getTransactionLine(payment.Transaction__c);
    }

    public void getTransactionLine(Id transactionID) {
        for (TransactionLine__c tl :[SELECT Id, Name, Transaction__c, CashierCodeDescription__c, CashierCode__r.Name, Amount__c FROM TransactionLine__c WHERE Transaction__c =: transactionID]) {
            if (tl.CashierCodeDescription__c != null) {
                if (tl.CashierCodeDescription__c.lastIndexOf('-') != -1) {
                	cashierCode_M.put(tl.Id, tl.CashierCodeDescription__c.substring(0, tl.CashierCodeDescription__c.lastIndexOf('-')));
            	} else {
                	cashierCode_M.put(tl.Id, tl.CashierCodeDescription__c);
            	}
            } else {
                if (tl.CashierCode__r.Name.lastIndexOf('-') != -1) {
                	cashierCode_M.put(tl.Id, tl.CashierCode__r.Name.substring(tl.CashierCode__r.Name.lastIndexOf('-') + 1, tl.CashierCode__r.Name.length()));
            	} else {
                	cashierCode_M.put(tl.Id, '');
            	}
            }
            transactionLine_L.add(tl);
        }
    }
}