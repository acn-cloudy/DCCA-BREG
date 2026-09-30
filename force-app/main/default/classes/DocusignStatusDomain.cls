public with sharing class DocusignStatusDomain extends SObjectDomain {
    public DocusignStatusDomain(List<dsfs__DocuSign_Status__c> records) {
        super(records);
    }
    public Set<String> createFiles(Map<String, ContentVersion> documentId2ContentVesion) {
        Set<String> documentIdToBeDeleted = new Set<String>();
        for(dsfs__DocuSign_Status__c record: (List<dsfs__DocuSign_Status__c>) records) {
            String travelApprovalId = record.TravelApproval__c;
            String workSheetId = record.WorkSheet__c;
            if(documentId2ContentVesion.containsKey(record.Id)) {
                ContentVersion documentData = documentId2ContentVesion.get(record.Id);
                String fileName = documentData.title+ '.'+ documentData.FileExtension;

                if(workSheetId != null || travelApprovalId != null) {
                    if(workSheetId != null) {
                        SpringCMConnector.createFile(workSheetId, fileName, documentData.VersionData);
                    }
                    if(travelApprovalId != null) {
                        SpringCMConnector.createFile(travelApprovalId, fileName, documentData.VersionData);
                    }
                    documentIdToBeDeleted.add(documentData.ContentDocumentId);
                }
            }
        }
        return documentIdToBeDeleted;
    }
}