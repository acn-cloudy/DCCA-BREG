/*
 * Extension controller for PaymentReceiptPdf VF page.
 * So we can retrieve the related transaction lines.
 * Created on 9/5/2018.
 * Author chris.loyola@pacificpointcorp.com
 * Edited on 18/OCT/2023 By Jonathan Kwok
 * changed amount to amountAllocated from the CollectionAllocation for the vfp
 */
public with sharing class PaymentReceiptPdfExtController {
    public pymt__PaymentX__c payment {set;get;}
    public boolean display {set;get;}
    public List<FormattedTransactionLine> gTransactionLines {set;get;}
    public List<Transaction__c> tAccounts {set;get;}
    public List<FormattedTransactionLine> tLines {set;get;}
    public pymt__PaymentX__c paymentRecord {get;}
    public void setPaymentRecord (pymt__PaymentX__c record) {
        if(record != null && record.Transaction__c != null) {
            payment = record;
            tLines = getTransactionLines();
            tAccounts = getTransactionAccounts();
            gTransactionLines = getGroupedTransactionLines();
            this.display = true;
        }
    }
   
    
    public PaymentReceiptPdfExtController() {
        this.display = false;
    }
    public PaymentReceiptPdfExtController(ApexPages.StandardController stdCtrl) {
        payment = (pymt__PaymentX__c) stdCtrl.getRecord();
    }

    public List<FormattedTransactionLine> getTransactionLines() {
        if(this.payment == null) return new List<FormattedTransactionLine>();
        List<TransactionLine__c> transactionLineList = [SELECT Id,
        Transaction__r.Account__r.Name,
        CashierCodeCode__c,
        Description__c,
        Amount__c,
        CashierCodeName__c,
        AmountCollected__c
        FROM TransactionLine__c
        WHERE Transaction__c = :payment.Transaction__c and Transaction__c != null];
        
        List<CollectionsAllocation__c> collectionsAllocations = [SELECT AmountAllocated__c, TransactionLine__c
                                                             FROM CollectionsAllocation__c
                                                             WHERE TransactionLine__c IN :transactionLineList AND Payment__c = :payment.Id];
        
        Map<Id, CollectionsAllocation__c> collectionsAllocationMap = new Map<Id, CollectionsAllocation__c>();
    		for (CollectionsAllocation__c allocation : collectionsAllocations) {
        collectionsAllocationMap.put(allocation.TransactionLine__c, allocation);
    	}


        List<FormattedTransactionLine> updatedTransactionLines = new List<FormattedTransactionLine>();
        for (TransactionLine__c tl : transactionLineList) {
            CollectionsAllocation__c collectionsAllocation = collectionsAllocationMap.get(tl.Id);
            FormattedTransactionLine ftl = new FormattedTransactionLine(tl,collectionsAllocation, 30);
            updatedTransactionLines.add(ftl);
        }

        return updatedTransactionLines;
    }

    public List<FormattedTransactionLine> getGroupedTransactionLines() {
        // if(this.payment == null) return new List<FormattedTransactionLine>();
        List<Transaction__c> childTransactions = [SELECT Id FROM Transaction__c WHERE TransactionGroup__c = :payment.Transaction__c];

        List<TransactionLine__c> transactionLineList = [SELECT Id,
        Transaction__r.Account__r.Name,
        Account__r.Name,
        CashierCodeCode__c,
        Description__c,
        Amount__c,
        CashierCodeName__c,
		AmountCollected__c
        FROM TransactionLine__c
        WHERE Transaction__c = :childTransactions];
		
        // Fetch CollectionsAllocation records related to the transaction lines
    	Map<Id, CollectionsAllocation__c> collectionsAllocationsMap = new Map<Id, CollectionsAllocation__c>();
    		for (TransactionLine__c tl : transactionLineList) {
        	collectionsAllocationsMap.put(tl.Id, null);
    	}
    	
        // Query for related CollectionsAllocation__c records
    	List<CollectionsAllocation__c> collectionsAllocations = [SELECT AmountAllocated__c,
                                                                 TransactionLine__c
                                                                 FROM CollectionsAllocation__c
                                                                 WHERE TransactionLine__c IN :transactionLineList AND Payment__c = :payment.Id];
		
        // Create a map to associate CollectionsAllocation__c with TransactionLine__c
    	Map<Id, CollectionsAllocation__c> collectionsAllocationMap = new Map<Id, CollectionsAllocation__c>();
    		for (CollectionsAllocation__c allocation : collectionsAllocations) {
        	collectionsAllocationMap.put(allocation.TransactionLine__c, allocation);
    	}
        
        // Create a list of FormattedTransactionLine objects
    	List<FormattedTransactionLine> updatedTransactionLines = new List<FormattedTransactionLine>();
    		for (TransactionLine__c tl : transactionLineList) {
        		CollectionsAllocation__c collectionsAllocation = collectionsAllocationMap.get(tl.Id);
        		FormattedTransactionLine ftl = new FormattedTransactionLine(tl, collectionsAllocation, 30); 
        updatedTransactionLines.add(ftl);
    	}
        /*List<FormattedTransactionLine> updatedTransactionLines = new List<FormattedTransactionLine>();
        for (TransactionLine__c tl : transactionLineList) {
            FormattedTransactionLine ftl = new FormattedTransactionLine(tl, 25);
            updatedTransactionLines.add(ftl);
        }*/
        return updatedTransactionLines;
    }

    public List<Transaction__c> getTransactionAccounts() {
        // if(this.payment == null) return new List<Transaction__c>();

        if(payment.Transaction__c != null) 
        return [SELECT Id,
        Account__r.Name
        FROM Transaction__c
        WHERE TransactionGroup__c = :payment.Transaction__c];
        else return new List<Transaction__c>();
    }

    public class FormattedTransactionLine{
        Integer DEFAULT_LINE_LENGTH = 70;
        String NEW_LINE = '<br/>';
        String SPLIT_CHARS = ' -';

        public Decimal amount{
            get;set;
        }
        public String cashierCode {
            public get;set;
        }
        public String cashierCodeName{
            get;set;
        }
        public String accountName{
            get;set;
        }
        public String description{
            get;set;
        }
		
        public Decimal amountCollected{
            get;set;
        }
        
        public Decimal amountAllocated{
            get;set;
        }
        
        public CollectionsAllocation__c collectionsAllocation { get; set; }
        
        public FormattedTransactionLine(TransactionLine__c transactionLine,CollectionsAllocation__c collectionsAllocation, Integer lineLength) {
            this.collectionsAllocation = collectionsAllocation;
            cashierCode = transactionLine.CashierCodeCode__c;
            amount = transactionLine.Amount__c;
            amountCollected = transactionLine.AmountCollected__c;
            cashierCodeName = LineSplitter(transactionLine.CashierCodeName__c, lineLength);
            accountName = LineSplitter(transactionLine.Transaction__r.Account__r.Name, 17);
            description = transactionLine.Description__c;
            if (collectionsAllocation != null) {
            	this.amountAllocated = collectionsAllocation.AmountAllocated__c;
        	}
        }

        public String LineSplitter(String s, Integer length) {
            String output = splitLines(s, length);
            return output;
        }

        private String splitLines(String input, Integer lineLength) {
            if (input == null) return input;
            List<String> finalLines = new List<String>();
            for (String singleLine : input.split('\n')) {
                finalLines.add(splitLinesSingleLine(singleLine, lineLength));
            }
            return String.join(finalLines, NEW_LINE);
        }

        private String splitLinesSingleLine(String input, Integer lineLength) {
            if (lineLength == null) {
                lineLength = DEFAULT_LINE_LENGTH;
            }
            if (input == null || input.length() <= lineLength) return input;

            String[] words = explode(input, SPLIT_CHARS);

            Integer curLineLength = 0;
            List<String> strBuilder = new List<String>();
            for (Integer i = 0; i < words.size(); i += 1)
                {
                    String word = words[i];
                    if (curLineLength + word.length() > lineLength) {
                        if (curLineLength > 0) {
                            strBuilder.add(NEW_LINE);
                            curLineLength = 0;
                        }

                        while (word.length() > lineLength) {
                            strBuilder.add(word.subString(0, lineLength - 1) + '-');
                            word = word.subString(lineLength - 1);
                            strBuilder.add(NEW_LINE);
                        }

                        // Remove leading whitespace from the word so the new line starts flush to the left.
                        // ??? no trimStart() analogue in apex, trying with trim(), revisit if there are
                        // issues
                        // word = word.TrimStart();
                        word = word.trim();
                    }
                    strBuilder.add(word);
                    curLineLength += word.length();
                }

            String combinedLine = String.join(strBuilder, '');

            combinedLine = combinedLine.replaceAll('\\s*<br/>', '<br/>');
            return combinedLine;
        }

        private String[] explode(String str, String splitCharacters) {
            List<String> parts = new List<String>();
            if (str != null) {
                Integer startIndex = 0;
                while (true) {
                    Integer preIndex = str.subString(startIndex).indexOfAny(splitCharacters);
                    Integer index = startIndex + preIndex;

                    if (preIndex == -1) {
                        parts.add(str.subString(startIndex));
                        break;
                    }

                    String word = str.subString(startIndex, index);
                    String nextChar = str.subString(index, index + 1);

                    // Dashes and the likes should stick to the word occuring before it. Whitespace doesn't have to.
                    if (nextChar.isWhiteSpace()) {
                        parts.Add(word);
                        parts.Add(nextChar);
                    } else {
                        parts.Add(word + nextChar);
                    }

                    startIndex = index + 1;
                }
            }
            return parts;
        }

    }

}