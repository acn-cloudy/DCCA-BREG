/*
    Author: Chris Zhuang
    Company: pacificpoint
*/
@RestResource(urlMapping='/CreateTransaction')
global without sharing class TransactionREST {
    @HttpPost
    global static String createTransaction() {
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
            
            Transaction__c newTran = new Transaction__c();
            
            List<Account> selectedAccount_L = new List<Account>();
            selectedAccount_L = [select Id from Account where External_Id__c =: jObject.AccountExternalId];

            
            List<Transaction__c> selectedTran_L = new List<Transaction__c>();
            selectedTran_L = [select Id from Transaction__c where TransactionId__c =: jObject.TransactionExternalId];
            
            if (selectedTran_L.size() > 0) {
                return '{"Status": "Error", "StatusCode": 401, "Message": "Insertion Failed. Transaction Already Exists." }';
            } else {
                if (selectedAccount_L.size() > 0) {
                    //if account exist, then we add transaction to the account
                    newTran.AccountName__c = jObject.BusinessName != null ? jObject.BusinessName : jObject.AccountFirstName + ' ' + jObject.AccountLastName;
                    newTran.Account__c = selectedAccount_L[0].Id;
                    newTran.TransactionId__c = jObject.TransactionExternalId;         
                    newTran.Date__c = Date.valueOf(jObject.TransactionDate);            
                    newTran.Description__c = jObject.Description;
                    newTran.Division__c = jObject.Division;
                    insert newTran;
                } else {
                    //create new account
                    Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
                    Id businssAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();

                    Account newAcc = new Account();
                    if (jObject.AccountType == null) jObject.AccountType = 'Person Account';
                    
                    if (jObject.AccountType == 'Business Account') {
                        newAcc.Name = jObject.BusinessName;
                        newAcc.RecordTypeId = businssAccRecordTypeId;
                    } else if (jObject.AccountType == 'Person Account') {
                        newAcc.FirstName = jObject.AccountFirstName;
                        newAcc.LastName  = jObject.AccountLastName;
                        newAcc.RecordTypeId = personAccRecordTypeId;
                    }
                    
                    newAcc.External_Id__c = jObject.AccountExternalId;
                    insert newAcc;
                    
                    newTran.AccountName__c = jObject.BusinessName != null ? jObject.BusinessName : jObject.AccountFirstName + ' ' + jObject.AccountLastName;
                    newTran.Account__c = newAcc.Id;
                    newTran.TransactionId__c = jObject.TransactionExternalId;         
                    newTran.Date__c = Date.valueOf(jObject.TransactionDate);            
                    newTran.Description__c = jObject.Description;
                    newTran.Division__c = jObject.Division;
                    insert newTran;
                }
                
                //add transaction line item                  
                if (jObject.TransactionLineItems.size() > 0) {
                    Set<String> CaseCodeName_S = new Set<String>();
                    Map<String, Id> CaseCodeName_M = new Map<String, Id>();
                    List<TransactionLine__c> newTranLines = new List<TransactionLine__c>();
                    
                    for (TransactionLineWrap tlw : jObject.TransactionLineItems) {
                        if (tlw.CashierCodeName != null)
                            CaseCodeName_S.add(tlw.CashierCodeName);
                    }
                    
                    for (CashierCode__c cCode : [select Id, Name from CashierCode__c where Name in: CaseCodeName_S]) {
                        CaseCodeName_M.put(cCode.Name, cCode.Id);
                    }
                    
                    Boolean flag = false;
                    for (TransactionLineWrap tlw : jObject.TransactionLineItems) {
                        TransactionLine__c tempTL = new TransactionLine__c();
                        
                        if (CaseCodeName_M.containsKey(tlw.CashierCodeName)) {
                            tempTL.CashierCodeFromSource__c = tlw.CashierCodeName;
                            tempTL.CashierCode__c = CaseCodeName_M.get(tlw.CashierCodeName);
                            tempTL.PaidStatus__c = tlw.PaidStatus;
                            tempTL.Amount__c = tlw.Amount;
                            tempTL.Description__c = tlw.Description;
                            tempTL.Transaction__c = newTran.Id;
                            tempTL.Account__c = newTran.Account__c;
                            newTranLines.add(tempTL);
                        } else {
                            flag = true;
                        }
                    }
                        
                    if (newTranLines.size() > 0 && flag == false)
                        insert newTranLines;
                    else {
                        Database.rollback(sp);
                        return '{"Status": "Error", "StatusCode": 402, "Message": "Insert failed, Please check your Cashier Code Name from the Transaction Line Items." }';
                    }
                }
                return '{"Status": "OK", "StatusCode": 200, "Message": "Transaction Created." }';    
            }
        } catch (Exception ex) {
            Database.rollback(sp);
            return '{"Status": "Error", "StatusCode": 400, "Message": "' + ex.getMessage() + '"}';
        }
    }
    
    public class JSON2Apex {
        public String AccountFirstName;
        public String AccountLastName;
        public String BusinessName;
        public String AccountType;
        public String AccountExternalId;
        public String TransactionExternalId;
        public Date   TransactionDate;
        public String Division;
        public String Description;

        public List<TransactionLineWrap> TransactionLineItems;
    }
    
    public class TransactionLineWrap {
        public String CashierCodeName;
        public String PaidStatus;
        public Decimal Amount;
        public String Description;
    }       
}