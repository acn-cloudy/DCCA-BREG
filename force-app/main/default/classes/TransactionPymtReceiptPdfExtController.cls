/*
 * -----------------------------------------------------------------------------------
 * Description
 * Extension controller for TransactionPymetReceiptPdf VF page.
 * -----------------------------------------------------------------------------------
 * Covered by: TransPymtReceiptPdfExtControllerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-TK02142023 - Created for case 00027562
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author takashi.koyama@pacificpointcorp.com
 *
 * @created 02/14/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class TransactionPymtReceiptPdfExtController {
    public Transaction__c transtn {get; set;}
	public Transaction__c transta {get; set;}
    public pymt__PaymentX__c thisPayment {get; set;}
    
    public List<TransactionLine__c> transactionLines {get; set;}    

    // rowspan
    public Map<pymt__PaymentX__c, Integer> tranLineCountMap{get;set;}

    public Map<pymt__PaymentX__c, Integer> collAllocationCountMap{get;set;}

    public Map<pymt__PaymentX__c, List<TransactionLine__c>> tranLineByPayment{get;set;}

    public Map<pymt__PaymentX__c, List<CollectionsAllocation__c>> collAllocationByPayment{get;set;}

    public Set<ID> paymentIDs = new Set<ID>();
    
    public TransactionPymtReceiptPdfExtController(ApexPages.StandardController stdCtrl) {

        tranLineCountMap = new Map<pymt__PaymentX__c, Integer>();
        tranLineByPayment = new Map<pymt__PaymentX__c, List<TransactionLine__c>>();

        collAllocationCountMap = new Map<pymt__PaymentX__c, Integer>();
        collAllocationByPayment = new Map<pymt__PaymentX__c, List<CollectionsAllocation__c>>();

        pymt__PaymentX__c paymt = (pymt__PaymentX__c) stdCtrl.getRecord();
        //Transaction__c tran = (Transaction__c) stdCtrl.getRecord();

        thisPayment = [SELECT Transaction__c FROM pymt__PaymentX__c WHERE ID = :paymt.ID];
        
		transta = [SELECT Name, TransactionType__c FROM Transaction__c WHERE ID = :thisPayment.Transaction__c];
        
        transtn = [SELECT Name, Account__r.Name, TotalAmount__c, Description__c,
            (SELECT Name, pymt__Date__c, pymt__Payment_Type__c, 
             pymt__Amount__c, Transaction__c, pymt__Memo__c, pymt__Card_Type__c, 
             pymt__Last_4_Digits__c, pymt__Check_Number__c FROM Payments__r) FROM 
            Transaction__c WHERE ID = :thisPayment.Transaction__c];

        // transtn = [SELECT Name, Account__r.Name, TotalAmount__c,
        //     (SELECT Name, pymt__Date__c, pymt__Payment_Type__c, 
        //     pymt__Amount__c FROM Payments__r) FROM 
        // Transaction__c WHERE ID = :tran.ID];

        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();
        for (pymt__PaymentX__c p : transtn.Payments__r){       
            payments.add(p);
            paymentIDs.Add(p.ID);
            tranLineCountMap.put(p, getTransactionLineCountByPayment(p));
            tranLineByPayment.put(p, getTransactionLinesByPay(p));

            //collAllocationCountMap.put(p, getCollectionAllocationCountByPay(p));
            //collAllocationByPayment.put(p, getCollectionAllocationByPay(p));
        }
        //transactionLines = [SELECT Payment__c, CashierCodeCode__c, CashierCode__c, Amount__c FROM TransactionLine__c WHERE Payment__c IN :paymentIDs];
    }

    public Integer getTransactionLineCountByPayment(pymt__PaymentX__c pymt){
        Integer tCount = [SELECT COUNT() FROM TransactionLine__c WHERE Payment__c = :pymt.ID];
        tCount++; 
        return tCount;
    }
	/* Commented out because we are not using CollectionAllocation
    public Integer getCollectionAllocationCountByPay(pymt__PaymentX__c pymt){
        Integer tCount = [SELECT COUNT() FROM CollectionsAllocation__c WHERE Payment__c = :pymt.ID];
        tCount++; 
        return tCount;
    }*/


    public List<TransactionLine__c> getTransactionLinesByPay(pymt__PaymentX__c pymt){

        List<TransactionLine__c> tLines = [SELECT Payment__c, CashierCodeCode__c, CashierCode__r.Name, Amount__c, Transaction__r.Account__r.Name FROM TransactionLine__c WHERE Payment__c = :pymt.ID];
        if (tLines.size() > 0){
            return tLines;        
        }
        else {
            return new List<TransactionLine__c>();
        }        
    }    
	/*Commented out because we are not using CollectionAllocation
    public List<CollectionsAllocation__c> getCollectionAllocationByPay(pymt__PaymentX__c pymt){
        
        List<CollectionsAllocation__c> tLines = [SELECT CashierCode__c, TransactionLine__r.CashierCode__r.Name, AmountAllocated__c FROM CollectionsAllocation__c WHERE Payment__c = :pymt.ID];        
        if (tLines.size() > 0){
            return tLines;        
        }
        else {
            return new List<CollectionsAllocation__c>();
        }        
    }*/    
}