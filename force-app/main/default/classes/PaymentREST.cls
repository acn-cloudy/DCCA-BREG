/*
    Author: Chris Zhuang
    Company: pacificpoint
*/
@RestResource(urlMapping='/CreatePayment')
global without sharing class PaymentREST {
    @HttpPost
    global static String createPayment() {
        Savepoint sp = null;
        try {
            sp = Database.setSavepoint();

            RestRequest req = null;
            RestResponse res = null;

            String postParams = '';
            
            RestContext.response.addHeader('Content-Type', 'application/json');
            req = RestContext.request;
            res = RestContext.response;
            
            postParams = req.requestBody.toString();
            JSON2Apex jObject = (JSON2Apex) System.JSON.deserialize(postParams, JSON2Apex.class);
            
            pymt__PaymentX__c newPayment = new pymt__PaymentX__c();
            List<Account> selectedAccount_L = new List<Account>();
            selectedAccount_L = [select Id from Account where External_Id__c =: jObject.AccountExternalId];
            
            List<Transaction__c> selectedTran_L = new List<Transaction__c>();
            selectedTran_L = [select Id from Transaction__c where TransactionId__c =: jObject.TransactionExternalId];
            
            //get Processor Connection: Authorize.Net
            pymt__Processor_Connection__c pConnect = [select Id from pymt__Processor_Connection__c where Name = 'Authorize.Net'];

            if (selectedAccount_L.size() > 0 && selectedTran_L.size() >0) {
                newPayment.Name = jObject.PaymentExternalId;
                newPayment.pymt__Account__c = selectedAccount_L[0].Id;
                newPayment.pymt__Amount__c = jObject.PaymentAmount;
                newPayment.pymt__Date__c = Date.valueOf(jObject.PaymentDate);
                newPayment.pymt__Payment_Type__c = jObject.PaymentType;                 
                newPayment.External_Transaction_ID__c = jObject.TransactionExternalId;
                newPayment.Transaction__c = selectedTran_L[0].Id;
                newPayment.pymt__Status__c = jObject.Status;
                newPayment.Division__c = jObject.Division; 
                
                //Update the processor connection field to default to Authorize.net
                if (pConnect != null) {
                	newPayment.pymt__Processor_Connection__c = pConnect.Id; 
                }
                
                newPayment.pymt__Transaction_Id__c = jObject.AuthorizeNetTransactionId;
                newPayment.pymt__Card_Type__c = jObject.CreditCardType;
                newPayment.pymt__Last_4_Digits__c = jObject.Last4Digits;
                insert newPayment;
                
                return '{"Status": "OK", "StatusCode": 200, "Message": "Payment Created." }';
            }
            return '{"Status": "Error", "StatusCode": 401, "Message": "Account or Transaction does not existed in Salesforce." }';
        } catch (Exception ex) {
            Database.rollback(sp);
            return '{"Status": "Error", "StatusCode": 400, "Message": "' + ex.getMessage() + '"}';
        }
    }
    
    public class JSON2Apex {
        public String PaymentExternalId;
        public String AccountExternalId;
        public String TransactionExternalId;
        public Decimal PaymentAmount;
        public String PaymentDate;
        public String PaymentType;
        public String Division;
        public String Status;
        public String AuthorizeNetTransactionId;
        public String CreditCardType;   
        public String Last4Digits;       
    }     
}