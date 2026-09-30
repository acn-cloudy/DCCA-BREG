public without sharing class CreateTransaction {

    @AuraEnabled
    public static TransactionWrapper initTransaction(Id recordId) {
        
       /*User cUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        string division = cUser.Division__c;
        if (division != null && division.contains(';')) {
            division = division.split(';')[0];
        }*/
        TransactionWrapper toReturn = new TransactionWrapper(recordId/*, division*/);
        
        return toReturn;
        
    } 
    
    @AuraEnabled
    public static List<PicklistVal> getSelectOptions(string objName, string fieldName) {
        List<PicklistVal> picklistValues = new List<PicklistVal>();
        SObjectType objectType = Schema.getGlobalDescribe().get(objName);
        List<Schema.PicklistEntry> pick_list_values = objectType.getDescribe()
                                                       .fields.getMap()
                                                       .get(fieldName)
                                                       .getDescribe().getPickListValues();
        for (Schema.PicklistEntry aPickListValue : pick_list_values) {                   
            picklistValues.add(new PicklistVal(aPickListValue));
        }
        return picklistValues;
    }
    
    @AuraEnabled
    public static Id saveTransaction(Transaction__c trns, string lines) { 
        
        
        upsert trns;
        Map<Id, TransactionLine__c> trLinesMap = new Map<Id, TransactionLine__c>([SELECT Id FROM TransactionLine__c WHERE Transaction__c =: trns.Id]);
        List<TransactionLine__c> xlines = (List<TransactionLine__c>)JSON.deserialize(lines, List<TransactionLine__c>.class);
        List<TransactionLine__c> trlinesToInsert = new List<TransactionLine__c>();
        for (TransactionLine__c line : xlines) {
            if(!trLinesMap.containsKey(line.Id))
            { 
                System.debug('Amount ====> ' + line.Amount__c); 
                System.debug('Amount Override ====> ' + line.AmountOverride__c);
                if(line.AmountOverride__c != null && line.AmountOverride__c != 0) {
                    line.Amount__c = line.AmountOverride__c;
                	line.AmountOverride__c = null;
	            }
                line.Transaction__c = trns.Id;
            	trlinesToInsert.add(line);
            } 
        }   
        
        insert trlinesToInsert;
        List<TransactionLine__c> TrLines = [SELECT Id, CashierCode__c, CashierCode__r.Division__c, Amount__c FROM TransactionLine__c WHERE Transaction__c =: trns.Id];
        for(TransactionLine__c tl: TrLines)
        {
            trns.Division__c = tl.CashierCode__r.Division__c;
            System.debug('Amount ====> ' + tl.Amount__c); 
        }
        update trns;
        return trns.Id;
        
    }
    
    @AuraEnabled
    public static List<CashierCode__c> getCashierCodes() {
        User myUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        List<string> divisions = new List<string>();
        if (myuser.Division__c != null)
            divisions = myUser.Division__c.split(';');
        return [SELECT Id, Name, FeeCode__c, Amount__c, FormDescription__c, Description__c, Division__c, Category__c, CashierCode__c FROM CashierCode__c WHERE Division__c IN :divisions ORDER BY Division__c];
    }

    public class TransactionWrapper {
        
        @AuraEnabled
        public Transaction__c trns { get; set; }
        @AuraEnabled
        public List<TransactionLine__c> lines { get; set; }
        @AuraEnabled
        public TransactionLine__c exampleLine { get; set; }
        
        public TransactionWrapper(Id recordId/*, string division*/) {
            if((String.valueOf(recordId)).substring(0,3) == '001')
            {
                trns = new Transaction__c();
                trns.Account__c = recordId;
                trns.Date__c = Date.today();
                trns.Status__c = 'New';
                //trns.DCCASection__c = division;
                trns.TransactionType__c = '';
                
                lines = new List<TransactionLine__c>();
                
                exampleLine = new TransactionLine__c();
            } else {
                trns = [SELECT Id, Name, Account__c, Status__c, TransactionType__c, Date__c, Description__c FROM Transaction__c WHERE Id =: recordId];
            	
                lines = [SELECT Id, CashierCode__c, Amount__c, AmountOverride__c, CashierCode__r.Name, CashierCode__r.FeeCode__c, CashierCode__r.Category__c, CashierCode__r.FormDescription__c, CashierCode__r.Division__c, CashierCode__r.Description__c FROM TransactionLine__c WHERE Transaction__c =: recordId];
                exampleLine = new TransactionLine__c();
            }
        }
        
    }
    
    public class PicklistVal {
        
        @AuraEnabled
        public string value { get; set; }
        @AuraEnabled
        public string label { get; set; }
        
        public PicklistVal(Schema.PicklistEntry pe) {
            value = pe.getValue();
            label = pe.getLabel();
        }
        
    }
    
}