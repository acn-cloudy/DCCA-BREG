global class GenerateRenewalApplicationBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    public List<String> recordIds {set;get;}
    public String pageName = 'OnlineRenewalCopy';
    public String query = 'Select Id, RecordTypeId, LicenseTypeCode__c, LicenseType__r.Name, LicenseType__r.OnlineRenewalCopyTemplate__c from Application__c where Id in: recordIds';
    global GenerateRenewalApplicationBatch(List<String> recordIds, String pageName) {
        this.recordIds = recordIds;
        this.pageName = pageName;
    }
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Application__c> records = (List<Application__c>) scope;

        Set<String> useTemplateFilter = new Set<String>{
            'CT - RME',
            'CT - Sole Proprietor',
            'CT - Entity',
            'OTA',
            'OT',
            'RB - Broker',
            'RS',
            'RB - Entity',
            'RB - Sole Proprietor'
            };

        for(Application__c record: records) {
            String pageNameToUse = pageName;

            if (useTemplateFilter.contains(record.LicenseTypeCode__c) && record.LicenseType__r.OnlineRenewalCopyTemplate__c != null) {
                pageNameToUse = record.LicenseType__r.OnlineRenewalCopyTemplate__c;
            }

            PageReference pageRef = new PageReference('/apex/' + pageNameToUse);
            pageRef.getParameters().put('id', record.Id);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
                // String docName = 'License Post Card(' +index + ').pdf';
                String docName = pageNameToUse + '.pdf';
                List<SpringCMDocument> result = SpringCMConnector.createFile(record.Id, docName, content);
            }
        }
    }
    global void finish(Database.BatchableContext context) {}
}