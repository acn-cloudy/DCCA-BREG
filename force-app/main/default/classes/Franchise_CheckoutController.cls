public without sharing class Franchise_CheckoutController {
    // definetion
	public Id paymentId       {get;set;}
	public String overrideDesc     {get;set;}
    public Integer groupFiling     {get;set;}
	
    //construction
    public Franchise_CheckoutController() {
        
        overrideDesc = '';
        paymentId = apexpages.currentpage().getparameters().get('pid');
        
        // Get Transaction ID from Payment Record
        pymt__PaymentX__c payment = [
            SELECT Id, Transaction__c, Transaction__r.TransactionType__c
            FROM pymt__PaymentX__c 
            WHERE id =: paymentId
        ];
        
        if(payment != null && payment.Transaction__c != null){
            // Get Filing Name of Transaction 
            String transactionId = payment.Transaction__c;
            
            if(payment.Transaction__r.TransactionType__c == 'Group'){
                groupFiling = 1;
                
                // If Transaction Type is "Group", get Filing Name of related Transactions
                List<Transaction__c> transactions = [
                    SELECT Id, TotalAmount__c, Filing__r.Name
               		FROM Transaction__c 
                    WHERE TransactionGroup__c =: transactionId
                ];
                
                overrideDesc += '<table width=\'100%\'>';
                for(Transaction__c transact: transactions){
                    overrideDesc += '<tr>';
                    overrideDesc += '<td>' + transact.Filing__r.Name + '</td>';
                    overrideDesc += '<td class=\'currency_column\'>$' + transact.TotalAmount__c + ' USD</td>';
                    overrideDesc += '</tr>';
                }
                
				overrideDesc += '</table>';               
            } else {
                groupFiling = 0;
                
                // If Transaction Type is "Payment", get Filing Name
                Transaction__c transact = [
                    SELECT Id, Filing__r.Name
               		FROM Transaction__c 
                    WHERE id =: transactionId
                ];
                
                if(transact != null && transact.Filing__r.Name != null){
                    overrideDesc = transact.Filing__r.Name;
                }
            }
        }
    }
}