/*
* ─────────────────────────────────────────────────────────
* Used for the logics for the Docusign Service
* ─────────────────────────────────────────────────────────
* PacPoint-AZ011119 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2020-08-12
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class DocusignStatusService {
    @future(callout=true)
    public static void createStatusFiles(Map<String, String> contentDocumentId2StatusId) {
        List<String> statusIds = contentDocumentId2StatusId.values();
        List<dsfs__DocuSign_Status__c> statuses = DocusignStatusSelector.getDocusignStatus(statusIds);
        
        System.debug('#####statuses######' + statuses);
        Set<String> contentDocumentIdSet = contentDocumentId2StatusId.keySet();
        Map<String, ContentVersion> documentId2ContentVesion = new Map<String, ContentVersion>();
        List<ContentVersion> cVersions = [Select Id, Description, Title, FileExtension,  ContentDocumentId, VersionData from ContentVersion where ContentDocumentId =: contentDocumentIdSet];
        System.debug('#####cVersions######' + cVersions);
        for(ContentVersion versionRec: cVersions) {
            documentId2ContentVesion.put(contentDocumentId2StatusId.get(versionRec.ContentDocumentId), versionRec);
        }
        System.debug('#####documentId2ContentVesion######' + documentId2ContentVesion);
        Set<String> documentIdToBeDeleted = (new DocusignStatusDomain(statuses)).createFiles(documentId2ContentVesion);
        System.debug('#####documentIdToBeDeleted######' + documentIdToBeDeleted);
        delete [Select Id from ContentDocument where Id in: documentIdToBeDeleted];
    }
}