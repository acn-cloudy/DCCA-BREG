/*
 * ___________________________________________________________________________________
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL08272020 - Created for DCCA - Fiscal Forms CR
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 8/27/2020
 * __________________________________________________________________________________
 */
public class PaymentRecwkstCmpController {
    @AuraEnabled
    public static Date getCutOffDate(String recordId){
        FiscalForm__c record = [Select Id, Request__c from FiscalForm__c where Id =: recordId];
        Object des = JSON.deserializeUntyped(record.Request__c);
        Map<String, Object> data = (Map<String, Object>) des;
        String batchDate = (String)data.get('batchDate');

        return Date.valueOf(batchDate) ;
    }

    @AuraEnabled
    public static Id saveAndCreateFile(String recordId, String data, String recordTypeId) {
        FiscalForm__c ff = new FiscalForm__c();
        ff.Request__c = data;
        ff.RecordTypeId = recordTypeId;
        
        // 
        if(recordId == null) {
            ff.Name = FiscalFormsController.getFormName(ff);
            List<FiscalForm__c> existingForms = [Select Id, Name from FiscalForm__c where Name =: ff.Name] ;
            if(!existingForms.isEmpty()) {
                ff.Id = existingForms.get(0).Id;
                update ff;
            } else {
                insert ff;
            }
            
        } else {
            ff.Id = recordId;
            update ff;

        }
    
        generateRecwkst(ff.Id);

        return ff.Id;
    }
    @AuraEnabled
    public static void generateFiles(String recordId){
        PageReference pageRef = Page.Recwkst;
        pageRef.getParameters().put('id', recordId);
        Blob content = pageRef.getContent();
        String fileName = 'RECWKST.pdf';
        List<SpringCMDocument> result = SpringCMConnector.createFile(recordId, fileName, content);

    }

    @Future(callout = true)
    public static void generateRecwkst(String recwkstRecordId) {
        PageReference pageRef = Page.Recwkst;
        pageRef.getParameters().put('id', recwkstRecordId);
        Blob content = Test.isRunningTest()? Blob.valueOf('test') : pageRef.getContent();
        String fileName = 'RECWKST.pdf';
        List<SpringCMDocument> result = SpringCMConnector.createFile(recwkstRecordId, fileName, content);

        // ContentVersion cv = new ContentVersion();
        // cv.ContentLocation = 'S';
        // cv.VersionData = content;
        // cv.Title = fileName;
        // cv.PathOnClient = '/' + fileName;
        // insert cv;

        // ContentVersion cDoc = [Select ContentDocumentId from ContentVersion Where Id =: cv.Id];

        // ContentDocumentLink cDe = new ContentDocumentLink();
        // cDe.ContentDocumentId = cDoc.ContentDocumentId;
        // cDe.LinkedEntityId = recwkstRecordId;
        // cDe.ShareType = 'I';
        // cDe.Visibility = 'AllUsers';
        // insert cDe;
    }

    @AuraEnabled
    public static String runReport(Date filterDate) {
        Set<String> paymentTypeFilter = new Set<String>{
                'Cash',
                'Check',
                'Cashier\'s Check',
                'Money Order'
                };
        List<pymt__PaymentX__c> payments = [
                SELECT
                        Id,
                        pymt__Payment_Type__c,
                        pymt__Amount__c,
                        CreatedBy.Terminal__c
                FROM pymt__PaymentX__c
                WHERE CutOffBatchDt__c = :filterDate
                AND CreatedBy.Terminal__c != null
                AND pymt__Status__c = 'Completed'
                AND pymt__Transaction_Type__c = 'Payment'
                AND pymt__Payment_Type__c IN :paymentTypeFilter
                ORDER BY CreatedBy.Terminal__c ASC
        ];

        RecwkstReport result = new RecwkstReport(payments);
        result.runningUser = new User();
        result.runningUser.FirstName = UserInfo.getFirstName();
        result.runningUser.LastName = UserInfo.getLastName();
        result.batchDate = filterDate;
        
        
        return JSON.serialize(result);
}
        
    

    public class RecwkstReport{
        @AuraEnabled
        public User runningUser{set;get;}

        @AuraEnabled
        public Date batchDate{set;get;}

        @AuraEnabled
        public Map<String, List<pymt__PaymentX__c>> cashPaymentsByTerminalMap{set;get;}

        @AuraEnabled
        public Map<String, List<pymt__PaymentX__c>> checkPaymentsByTapeByTerminalMap{set;get;}
        @AuraEnabled
        public Map<String, Decimal> terminalTotalReceipts{set;get;}
        @AuraEnabled
        public Map<String, Decimal> terminalTotalCheck{set;get;}

        @AuraEnabled
        public Map<String, Decimal> terminalTotalCash{set;get;}

        @AuraEnabled
        public Map<String, Decimal> terminalTotalCoins{set;get;}


        public RecwkstReport(List<pymt__PaymentX__c> payments) {
            cashPaymentsByTerminalMap = new Map<String, List<pymt__PaymentX__c>>();
            checkPaymentsByTapeByTerminalMap = new Map<String, List<pymt__PaymentX__c>>();
            terminalTotalCheck = new Map<String, Decimal>();
            terminalTotalCash = new Map<String, Decimal>();
            terminalTotalCoins = new Map<String, Decimal>();
            terminalTotalReceipts = new Map<String, Decimal>();
            for (pymt__PaymentX__c p : payments) {
                String t = p.CreatedBy.Terminal__c;
                if (p.pymt__Payment_Type__c == 'Cash') {
                    if (!cashPaymentsByTerminalMap.containsKey(t)) {
                        cashPaymentsByTerminalMap.put(t, new List<pymt__PaymentX__c>());
                    }
    
                    cashPaymentsByTerminalMap.get(t).add(p);
    
                    if (!terminalTotalCash.containsKey(t)) {
                        terminalTotalCash.put(t, 0);
                    }
    
                    Decimal currentTotalCash = terminalTotalCash.get(t);
                    terminalTotalCash.put(t, currentTotalCash += p.pymt__Amount__c);
                }
                if (p.pymt__Payment_Type__c == 'Cash' || p.pymt__Payment_Type__c == 'Check' 
                    || p.pymt__Payment_Type__c == 'Money order' ||p.pymt__Payment_Type__c == 'Cashier\'s Check') {
                    // String terminal = p.CreatedBy.Terminal__c;
                    // List<String> terminals = terminal.split(';');
                    // for (String k : terminals) { 
                    Decimal amountVar = 0;
                    if(terminalTotalReceipts.containsKey(t)) {
                        amountVar = terminalTotalReceipts.get(t);
    
                    }
                    amountVar += p.pymt__Amount__c;
                    terminalTotalReceipts.put(t, amountVar);
                    // }
                }
                if (p.pymt__Payment_Type__c == 'Check' || p.pymt__Payment_Type__c == 'Cashier\'s Check' ||
                                p.pymt__Payment_Type__c == 'Money Order') {
                    if (!checkPaymentsByTapeByTerminalMap.keySet().contains(t)) {
                        checkPaymentsByTapeByTerminalMap.put(t, new List<pymt__PaymentX__c>());
                    }
    
                    checkPaymentsByTapeByTerminalMap.get(t).add(p);
    
                    if (!terminalTotalCheck.containsKey(t)) {
                        terminalTotalCheck.put(t, 0);
                    }
    
                    Decimal terminalCheckAmt = terminalTotalCheck.get(t);
                    terminalCheckAmt += p.pymt__Amount__c;
                    terminalTotalCheck.put(t, terminalCheckAmt);
                }
            }
    
            for (String k : terminalTotalCash.keySet()) {
                if (!terminalTotalCoins.containsKey(k)) {
                    terminalTotalCoins.put(k, 0);
                    Decimal totalCash = terminalTotalCash.get(k);
                    String cashString = String.valueOf(totalCash);
                    String cashPart = cashString.substringBefore('.');
                    String coinPart = '.' + cashString.substringAfter('.');
                    Decimal cash = Decimal.valueOf(cashPart);
                    Decimal coin = Decimal.valueOf(coinPart);
                    terminalTotalCash.put(k, cash);
                    terminalTotalCoins.put(k, coin);
                }
            }
        }
    }
}