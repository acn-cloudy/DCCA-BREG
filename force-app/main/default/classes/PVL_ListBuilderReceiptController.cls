public without sharing class PVL_ListBuilderReceiptController {
    public pymt__PaymentX__c payment {get;set;}
    public string paymentId {get;set;}
    public string transactionId {get;set;}
    public string transactionDate {get;set;}
    public PVL_ListBuilderReceiptController() {
        paymentId = ApexPages.currentPage().getParameters().get('Id');
        transactionId = ApexPages.currentPage().getParameters().get('tranId');
        transactionDate = ApexPages.currentPage().getParameters().get('tranDate');
        payment = [SELECT Id, Transaction__c, Transaction__r.Name, pymt__Card_Type__c, pymt__Last_4_Digits__c, Name, pymt__Contact__r.Name, pymt__Contact__r.Phone, pymt__Account__r.RecordType.Name, pymt__Billing_Email__c, pymt__Amount__c, pymt__Transaction_Id__c, pymt__Date__c, Transaction__r.Description__c, pymt__Billing_Street__c, pymt__Billing_City__c, pymt__Billing_Postal_Code__c, pymt__Billing_Country__c
                   FROM pymt__PaymentX__c 
                   WHERE Id =: paymentId];
    }
}