/********************************************************************************************************
*    Name:  GroupTransactionController.cls
*    Author: PacPoint-MC082818 - Created for phase(???)
*    Date:  8/28/2018
*    
*    TestClass: GroupTransactionControllerTest.cls
********************************************************************************************************/

public without sharing class GroupTransactionController {

    @AuraEnabled
    public static Transaction__c initTransaction() {
        // Parent Transaction initialization
        Transaction__c currentTransaction = new Transaction__c();
        currentTransaction.Date__c = Date.Today();
        currentTransaction.TransactionType__c = 'Payment';
        return currentTransaction;

    }

    @AuraEnabled
    public static List<Transaction__c> getTransactions() {
        // return all transaction to make them available for select
        return [SELECT Id, Name, Account__c, Account__r.Name, TotalAmount__c, TransactionGroup__c FROM Transaction__c WHERE TransactionType__c != 'Group' AND Account__c != null AND Status__c != 'Completed'];
    }

    @AuraEnabled
    public static Id saveTransaction(Transaction__c currenttransaction, string transactions) {
        // get all selected transactions
        List<Transaction__c> xlines = (List<Transaction__c>)JSON.deserialize(transactions, List<Transaction__c>.class);
        // asociate an Account to the parent transaction
        currenttransaction.Account__c = xlines[0].Account__c;
        // set parent transaction Type = "Group"
        currenttransaction.TransactionType__c = 'Group';
        // insert parent transaction

        insert currenttransaction;


        // iterate through all selected Transactions and add The parent Id
        Transaction__c transToUpdate = [SELECT Id, ParentTotalAmount__c FROM Transaction__c WHERE Id =:currentTransaction.Id];
        transToUpdate.ParentTotalAmount__c = 0;
        for (Transaction__c line : xlines) {
            line.TransactionGroup__c = currenttransaction.Id;
            // sum all the amounts and add the total on the parent record
            if(line.TotalAmount__c != null)
                transToUpdate.ParentTotalAmount__c += line.TotalAmount__c;
        }
        update xlines;

        update transToUpdate;
        // return parent record id (redirect to record page)
        return currenttransaction.Id;
        
    }
    
    public class TransactionWrapper {
        
        @AuraEnabled
        public Transaction__c trns { get; set; }
        @AuraEnabled
        public List<Transaction__c> lines { get; set; }
        @AuraEnabled
        public Transaction__c exampleLine { get; set; }
        
        public TransactionWrapper() {
            
            trns = new Transaction__c();
            trns.Date__c = Date.today();
            trns.Status__c = 'New';
            trns.TransactionType__c = 'Payment';
            
            lines = new List<Transaction__c>();
            
            exampleLine = new Transaction__c();
        }
        
    }
    
}