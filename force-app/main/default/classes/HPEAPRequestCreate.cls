/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the HPEAPRequest Record Create component - Used to create specific for HPEAP Request
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* PacPoint-LC250717 - Created for PQB phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class HPEAPRequestCreate {
    @AuraEnabled
    public static void checkPaymentStatus(String paymentId) {
        if(paymentId == null || paymentId.length() == 0) {
        	AuraHandledException exp = new AuraHandledException('NO PAYMENT ID');
            exp.setMessage('NO PAYMENT ID');
        	throw exp;    
        }
        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Id=: paymentId and pymt__Status__c='Completed'];
        if(payments.isEmpty()) {
            AuraHandledException exp = new AuraHandledException('PAYMENT NOT COMPLETED');
            exp.setMessage('PAYMENT NOT COMPLETED');
        	throw exp;    
        }
    }
    @AuraEnabled
    public static String loadGenericContact(String contactId) {
        List<Contact> contacts = [Select Id, AccountId from Contact where Id=: contactId];
        Contact con = new Contact();
        if(!contacts.isEmpty()) {
            con = contacts.get(0);
        }
        return JSON.serialize(con);
    }
    @AuraEnabled
    public static String loadCashierCode(String cashierCodeId) {
        List<CashierCode__c> cashierCodes = [Select Id, CashierCode__c, Description__c, Amount__c from CashierCode__c where Id=: cashierCodeId];
        CashierCode__c record = new CashierCode__c();
        if(!cashierCodes.isEmpty()) {
            record = cashierCodes.get(0);
        }
        return JSON.serialize(record);
    }
    
    // Invoked by the createScript method from lighnting component HPEAPRequest to save record
    @AuraEnabled
    public static String createTranscript(String transcriptStr, String contactStr, 
                    String cashierStr, String division, String currencyCode) {
        try{
            HPEAPRequest__c transcript = (HPEAPRequest__c) JSON.deserialize(transcriptStr, HPEAPRequest__c.class);
            Contact conRecord = (Contact) JSON.deserialize(contactStr, Contact.class);
            CashierCode__c cashierRecord = (CashierCode__c) JSON.deserialize(cashierStr, CashierCode__c.class);
            insert transcript;
            return createTransaction(transcript, conRecord, cashierRecord, division, currencyCode);
        } catch(Exception ex) {
            AuraHandledException aEx = new AuraHandledException(ex.getMessage());
            aEx.setMessage(ex.getMessage());
            throw aEx;
        }

    }
    // Create Transaction record after HPEAP Request has been created. 
    public static String createTransaction(HPEAPRequest__c transcript, Contact con, 
                CashierCode__c cashier, String division, String currencyCode) {
		                    
        Transaction__c transactionRecord = new Transaction__c();
        transactionRecord.HPEAPRequest__c = transcript.Id;
		transactionRecord.Account__c = con.AccountId;
		transactionRecord.Contact__c = con.Id;
		transactionRecord.Division__c = division;
		transactionRecord.TransactionType__c = 'Payment';
        transactionRecord.Date__c = Date.today();
		transactionRecord.Status__c = 'New';
        insert transactionRecord;
		String quantityStr = transcript.TranscriptQuantity__c;
                    
		Integer quantity = 1;
        try{
            // if the quantity fails to be parsed. 
            // use 1 as default.
			quantity = Integer.valueOf(quantityStr);
        } catch(Exception ex) {
            
        }
                    
        TransactionLine__c transactionLine = new TransactionLine__c();
        transactionLine.Transaction__c = transactionRecord.Id;
        transactionLine.CashierCode__c = cashier.Id;
        transactionLine.Amount__c = cashier.Amount__c * quantity;
        insert transactionLine;
        return createPayment(transactionRecord.Id, transcript, cashier, currencyCode);
    }
    // Create Payment record after HPEAP Request has been created. 
    public static String createPayment(String transactionId, 
            HPEAPRequest__c transcript, CashierCode__c cashier, String currencyCode){
        Transaction__c transactionRecord = [Select Id, Account__c, 
            Name, Contact__c, TotalAmount__c from Transaction__c where Id =: transactionId];
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.Name = cashier.Description__c;
        payment.pymt__Account__c = transactionRecord.Account__c;
        payment.pymt__Amount__c = transactionRecord.TotalAmount__c;
        payment.pymt__Contact__c = transactionRecord.Contact__c;
        payment.Transaction__c = transactionId;
        payment.pymt__Billing_First_Name__c = transcript.FirstName__c;
        payment.pymt__Billing_Last_Name__c = transcript.LastName__c;
        payment.pymt__Billing_Email__c =transcript.Email__c;
        
        payment.pymt__Currency_ISO_Code__c = currencyCode;
        insert payment;
        return payment.Id;
    }
}