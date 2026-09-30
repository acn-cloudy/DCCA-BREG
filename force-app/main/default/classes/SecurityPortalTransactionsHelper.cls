/*
 * -----------------------------------------------------------------------------------
 * Description
 * 
 * Allow Payment for Multiple Filings in BREG Security Portal
 *
 * -----------------------------------------------------------------------------------
 * Covered by: SecurityPortalTransactionsHelperTest
 * -----------------------------------------------------------------------------------
 * PacPoint-EA02232023 - Created for case 00027568
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 02/23/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class SecurityPortalTransactionsHelper {
    public Id userId {get;set;}

    /* 
    * Get all transactions for the passed User ID
    * 
    * @param userId
    * @param accId
    * @param sortBy
    * @param sortDir
    * @return List<Transaction__c>
    */
    @AuraEnabled(cacheable=true)
    public static List<Transaction__c> getUserTransactions(String userId, String accId, String sortBy, String sortDir) {
        if(accId != null){
            String query = 'SELECT Id, Name, AmountOutstanding__c, TotalAmount__c, Filing__r.Name, Filing__r.ApplicationType__c, Filing__r.CreatedDate, Filing__r.AgeDaysFormula__c, Filing__r.Account__r.Name, Filing__r.CreatedBy.Name ';

            query += 'FROM Transaction__c ';
            query += 'WHERE Status__c != \'Completed\' ';
            query += 'AND Filing__r.Status__c != \'Filing Withdrawn\' ';
            query += 'AND TransactionGroup__r.Status__c != \'Completed\' ';
            query += 'AND TransactionType__c != \'Group\' ';            
            query += 'AND AmountOutstanding__c > 0 ';
            query += 'AND Filing__c != null ';
            query += 'AND Filing__c != \'\' ';
            query += 'AND (Filing__r.Account__c =:accId OR Filing__r.CreatedById =: userId) ';
            query += 'ORDER BY  '+ sortBy + ' ' + sortDir + ' ';       

            return Database.query(query);
        } 

        return null;
    }

    /* 
    * Get Account ID of a User
    * 
    * @param userId
    * @return String currentUser.AccountId
    */
    @AuraEnabled(cacheable=true)
    public static Id getUserAccountId(String userId){
        User currentUser = [SELECT Id, AccountId FROM User WHERE Id =: userId];
        if(currentUser != null && currentUser.AccountId != null){
            return currentUser.AccountId;
        } else {
            return null;
        }
    }

    /* 
    * Create Group Transaction and Payment record
    * 
    * @param transactionIDs
    * @param accId
    * @param totalAmount
    * @return sObject
    */
    @AuraEnabled(cacheable=false)
    public static sObject groupTransactions(List<String> transactionIDs, String accId, Decimal totalAmount) {                  
        Contact accContact = [SELECT Id FROM Contact WHERE AccountId =: accId LIMIT 1];
        if(accContact != null){    
            Transaction__c trans = new Transaction__c();
            trans.Status__c = 'New'; 
            trans.TransactionType__c = 'Group';
            trans.Date__c = Date.today();        
            trans.Division__c = 'BREG';      
            trans.TotalAmount__c = totalAmount;    
            trans.Account__c = accId;
        
            Insert trans;

            if(trans.Id != null){
                
                // Update Transactions, set Group Transaction
                List<Transaction__c> childrenTrans = [SELECT Id, Name, TransactionGroup__c FROM Transaction__c WHERE Id IN :transactionIDs];
                if(childrenTrans.size() > 0){
                    for (Transaction__c childTrans : childrenTrans) {
                        childTrans.TransactionGroup__c = trans.Id;
                    }

                    Update childrenTrans;
                }

                

                // Get Processor Connection
                pymt__Processor_Connection__c processor = [SELECT Id, Name FROM pymt__Processor_Connection__c WHERE Name = 'Credit Card (Authorize.Net)'];

                if(processor != null){
                    // Create Payment Record
                    pymt__PaymentX__c pymt = new pymt__PaymentX__c();
                    pymt.Name = 'Multiple Filing Payment';
                    pymt.pymt__Amount__c = totalAmount;
                    pymt.pymt__Account__c = accId;
                    pymt.pymt__Contact__c = accContact.Id;
                    pymt.Division__c = 'BREG';
                    pymt.pymt__Payment_Type__c = 'Credit Card';
                    pymt.pymt__Transaction_Type__c = 'Payment';
                    pymt.pymt__Status__c = 'New';
                    pymt.pymt__Currency_ISO_Code__c = 'USD';
                    pymt.Transaction__c = trans.Id;
                    pymt.pymt__Processor_Connection__c = processor.Id;

                    Insert pymt;

                    return pymt;
        
                }
            }
        }

        return null;
    }
}