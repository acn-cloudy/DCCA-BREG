public with sharing class WebMultiDocumentExt {
    public String content {set;get;}
    public WebMultiDocumentExt() {
        content = '';
        String queryIds = System.currentPageReference().getParameters().get('queryIds');
        List<String> queryIdList = new List<String>();
        queryIdList  = queryIds.split(',');
        // query notification
        List<Notification__c> records = [Select Id, Content__c from Notification__c where Id in: queryIdList order by CreatedDate, Name];
        for(Notification__c record: records) {
            content += record.Content__c;
        }
        
    }
}