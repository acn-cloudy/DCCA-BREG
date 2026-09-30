global with sharing class InvestigationCallsBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    public List<String> recordIds = new List<String>();  
    public String query = 'SELECT Id, Name, SEBCase__c FROM Investigation__c ';

    global InvestigationCallsBatch(String recordId) {
        this();
        this.recordIds.add(recordId);
        query += ' WHERE Id IN :recordIds AND SEBCase__c != NULL';
    }

    global InvestigationCallsBatch(List<String> recordIds) {
        this();
        this.recordIds = recordIds;
        query += ' WHERE Id IN :recordIds AND SEBCase__c != NULL';
    }

    global InvestigationCallsBatch() {  
        recordIds.clear();    
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Investigation__c> scope){
        Map<String, Blob> springcmFiles = new Map<String, Blob>();
        for(Investigation__c inv:scope){
            PageReference pdf = Page.InvestigationCallsTemplate;
            pdf.getParameters().put('id', inv.Id);
        
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pdf.getContent();
            }

            //Save to SpringCM
            try{                    
                List<SpringCMDocument> result = SpringCMConnector.createFile(inv.Id, 'Calls for '+ inv.Name +'.pdf', content);
            }catch(Exception ex){
                System.debug('InvestigationCallsBatch: SpringCMConnector.createFile');
                System.debug(ex.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext BC) {}
}