public without sharing class UploadCaseFileToDocSignQueueable implements System.Queueable, Database.AllowsCallouts{
    static List<String> shouldUploadCaseRecordTypes = new List<String> {'CATV_Complaint', 'DCA_Complaint', 'DFI_Complaint', 'General_Complaint'};
    static Integer BATCH_SIZE = 20;
    List<Id> contentDocumentLinkIds = new List<Id>();
    public UploadCaseFileToDocSignQueueable(List<Id> contentDocumentLinkIds) {
        this.contentDocumentLinkIds = contentDocumentLinkIds;
    }

    public void execute(System.QueueableContext ctx) {
        
        Integer total = this.contentDocumentLinkIds.size();
        List<Id> chunk = new List<Id>();
        for(Integer i = 0; i < BATCH_SIZE && i < total; i++) {
            chunk.add(this.contentDocumentLinkIds.remove(0));
        }

        List<ContentDocumentLink> links = [SELECT Id, ContentDocumentId, ContentDocument.Title, LinkedEntityId,
                                                  ContentDocument.LatestPublishedVersion.VersionData, ContentDocument.LatestPublishedVersion.PathOnClient  
                                           FROM ContentDocumentLink 
                                           WHERE Id = :chunk];
        Set<Id> caseIds = new Set<Id>();
        for(ContentDocumentLink link : links) {
            caseIds.add(link.LinkedEntityId);
        }
        System.debug('--- caseIds: ' + caseIds);
        SpringCMService springcm = new SpringCMService();
        Map<Id, Case> cases = new Map<Id, Case>([SELECT Id, CaseNumber, RecordType.DeveloperName 
                                                 FROM Case WHERE Id IN: caseIds AND RecordType.DeveloperName IN :shouldUploadCaseRecordTypes]); 
        System.debug('--- cases: ' + cases);

        List<Id> contentDocumentIds = new List<Id>();
        for(ContentDocumentLink link : links) {
            if(!cases.containsKey(link.LinkedEntityId)) continue;
            contentDocumentIds.add(link.ContentDocumentId);
            Case c = cases.get(link.LinkedEntityId);
            upload(c.Id, link.ContentDocument.LatestPublishedVersion);

            // SpringCMConnector.createFile(c.Id, link.ContentDocument.LatestPublishedVersion.PathOnClient, link.ContentDocument.LatestPublishedVersion.VersionData);
            
            // SpringCMFolder folder = springcm.findOrCreateEosFolder(c.Id, 'Case');
            // String folderUploadLink = folder.CreateDocumentHref;
            // SpringCMConnector.createDocument(folderUploadLink, link.ContentDocument.LatestPublishedVersion.PathOnClient, link.ContentDocument.LatestPublishedVersion.VersionData);
        }

        cleanUp(contentDocumentIds);
        if(!this.contentDocumentLinkIds.isEmpty()) System.enqueueJob(this);
    }

    public void upload(Id caseId, ContentVersion cv) {
        String token = SpringCMConnector.getAccessToken();
        SpringCMFolder folder = SpringCMConnector.getFolder(caseId);
        if(Test.isRunningTest()) folder.CreateDocumentHref = 'docSin://{?name}';
        String endpoint = folder.CreateDocumentHref.replace('{?name}', '?name=' + EncodingUtil.urlEncode(cv.PathOnClient, 'utf-8') );
        Http client = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setHeader('Authorization','oauth ' + token);
        req.setHeader('Content-Type', 'multipart/form-data');
        req.setHeader('Accept', '*/*');
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setBodyAsBlob(cv.VersionData);
        HttpResponse res = Test.isRunningTest() ? new HttpResponse() : client.send(req);
    }

    @future
    static void cleanUp(List<Id> contentDocumentIds) {
        Database.delete(contentDocumentIds);
    }
}