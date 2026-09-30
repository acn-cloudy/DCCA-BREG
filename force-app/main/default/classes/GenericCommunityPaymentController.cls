/*
 * ___________________________________________________________________________________
 * Controller for GenericCommunityPayment lightning component
 * Covered by: GenericCommunityPaymentControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL02132020 - Created for DFI Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 2/13/2020
 * __________________________________________________________________________________
 */
public without sharing class GenericCommunityPaymentController {
    @AuraEnabled
    public static void checkPaymentStatus(String paymentId) {
        if (paymentId == null || paymentId.length() == 0) {
            AuraHandledException exp = new AuraHandledException('NO PAYMENT ID');
            exp.setMessage('NO PAYMENT ID');
            throw exp;
        }
        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Id=: paymentId and pymt__Status__c='Completed'];
        if (payments.isEmpty()) {
            AuraHandledException exp = new AuraHandledException('PAYMENT NOT COMPLETED');
            exp.setMessage('PAYMENT NOT COMPLETED');
            throw exp;
        }
    }

    @AuraEnabled
    public static String loadGenericContact(String contactId) {
        List<Contact> contacts = [Select Id, AccountId from Contact where Id=: contactId];
        Contact con = new Contact();
        if (!contacts.isEmpty()) {
            con = contacts.get(0);
        }
        return JSON.serialize(con);
    }

    @AuraEnabled
    public static String loadCashierCode(String cashierCodeId) {
        List<CashierCode__c> cashierCodes = [Select Id, CashierCode__c, Description__c, Amount__c from CashierCode__c where Id=: cashierCodeId];
        CashierCode__c record = new CashierCode__c();
        if (!cashierCodes.isEmpty()) {
            record = cashierCodes.get(0);
        }
        return JSON.serialize(record);
    }

    @AuraEnabled
    public static String createSObject(SObject sObj,
                                       String contactStr,
                                       String cashierStr,
                                       String division,
                                       String currencyCode,
                                       String parentLookUpField) {
        try {
            Contact conRecord = (Contact) JSON.deserialize(contactStr, Contact.class);
            CashierCode__c cashierRecord = (CashierCode__c) JSON.deserialize(cashierStr, CashierCode__c.class);
            insert sObj;
            return createTransaction(sObj,
                    conRecord,
                    cashierRecord,
                    division,
                    currencyCode,
                    parentLookUpField);
        } catch (Exception ex) {
            AuraHandledException aEx = new AuraHandledException(ex.getMessage());
            aEx.setMessage(ex.getMessage());
            throw aEx;
        }
    }

    public static String createTransaction(SObject sObj,
                                           Contact con,
                                           CashierCode__c cashier,
                                           String division,
                                           String currencyCode,
                                           String parentLookUpField) {

        Transaction__c transactionRecord = new Transaction__c();
        transactionRecord.put(parentLookUpField, (Id) sObj.get('Id'));
        transactionRecord.Account__c = con.AccountId;
        transactionRecord.Contact__c = con.Id;
        transactionRecord.Division__c = division;
        transactionRecord.TransactionType__c = 'Payment';
        transactionRecord.Date__c = Date.today();
        transactionRecord.Status__c = 'New';
        insert transactionRecord;

        TransactionLine__c transactionLine = new TransactionLine__c();
        transactionLine.Transaction__c = transactionRecord.Id;
        transactionLine.CashierCode__c = cashier.Id;
        transactionLine.Amount__c = cashier.Amount__c;
        insert transactionLine;
        return createPayment(transactionRecord.Id, sObj, cashier, currencyCode);
    }
    // Create Payment record after HPEAP Request has been created.
    public static String createPayment(String transactionId,
                                       SObject sObj,
                                       CashierCode__c cashier,
                                       String currencyCode) {
        Transaction__c transactionRecord = [Select Id, Account__c,
        Name, Contact__c, TotalAmount__c from Transaction__c where Id =: transactionId];
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.Name = cashier.Description__c;
        payment.pymt__Account__c = transactionRecord.Account__c;
        payment.pymt__Amount__c = transactionRecord.TotalAmount__c;
        payment.pymt__Contact__c = transactionRecord.Contact__c;
        payment.Transaction__c = transactionId;

        Map<String, SObjectField> fields = sObj.getSObjectType().getDescribe().fields.getMap();

        if (fields.containsKey('FirstName__c') && sObj.get('FirstName__c') != null) {
            payment.pymt__Billing_First_Name__c = (String)sObj.get('FirstName__c');
        }

        if (fields.containsKey('LastName__c') && sObj.get('LastName__c') != null) {
            payment.pymt__Billing_Last_Name__c = (String)sObj.get('LastName__c');
        }

        if (fields.containsKey('Email__c') && sObj.get('Email__c') != null) {
            payment.pymt__Billing_Email__c = (String)sObj.get('Email__c');
        }

        if (fields.containsKey('EmailAddress__c') && sObj.get('EmailAddress__c') != null) {
            payment.pymt__Billing_Email__c = (String)sObj.get('EmailAddress__c');
        }

        payment.pymt__Currency_ISO_Code__c = currencyCode;
        insert payment;
        return payment.Id;
    }
}