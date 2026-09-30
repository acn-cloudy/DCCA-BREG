public with sharing class BREGDocumentTriggerHandler extends BREGBaseTriggerHandler {
    public final static String COMBINE_DOCS_WORKFLOW = 'BREG Combine Documents';
    private static final String CREATE_CERTIFIED_COPY_WORKFLOW = 'BREG Create Certified Copy';
    private static final String SEND_CERTIFIED_COPY_WORKFLOW = 'BREG Send Certified Copy Email';


    public override void beforeInsert() {
        List<breg_Document__c> newDocuments = (List<breg_Document__c>) this.newList;
        handleEditedCertifiedCopies(newDocuments);
    }

    public override void afterInsert() {
        List<breg_Document__c> newDocuments = (List<breg_Document__c>) this.newList;
        handleCombineDocuments(newDocuments);
        handleCertifiedCopyDocuments(newDocuments);
    }

    public override void afterUpdate() {
        List<breg_Document__c> newDocuments = (List<breg_Document__c>) this.newList;
        Map<Id, breg_Document__c> oldDocumentsMap = (Map<Id, breg_Document__c>) this.oldMap;
        handleSendCertifiedCopy(newDocuments, oldDocumentsMap);
    }

    @TestVisible
    private void handleSendCertifiedCopy(List<breg_Document__c> newDocuments, Map<Id, breg_Document__c> oldDocumentsMap) {
        List<breg_Document__c> justCompletedDocs = new List<breg_Document__c>();
        Set<Id> affectedCaseIds = new Set<Id>();

        for (breg_Document__c doc : newDocuments) {
            breg_Document__c oldDoc = oldDocumentsMap.get(doc.Id);
            if (oldDoc == null) {
                continue;
            }
            
            if (doc.breg_Certified_Copy_Status__c == 'Completed' && oldDoc.breg_Certified_Copy_Status__c != 'Completed' && doc.breg_Case__c != null) {
                affectedCaseIds.add(doc.breg_Case__c);
                justCompletedDocs.add(doc);
            }
        }

       

        // Enqueue send workflow only when all documents for the related case are completed
        Set<Id> caseIdsWithIncompleteDoc = new Set<Id>();
        for (breg_Document__c doc : [
            SELECT breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :affectedCaseIds
            AND ID != :newDocuments
            AND breg_Certified_Copy_Status__c != 'Completed'
        ]) {
            caseIdsWithIncompleteDoc.add(doc.breg_Case__c);
        }

        for (breg_Document__c doc : [
            SELECT breg_Case__c, Name, breg_Docusign_Document_Id__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :affectedCaseIds
            AND breg_Case__c NOT IN :caseIdsWithIncompleteDoc
            AND ID != :newDocuments
            AND breg_Certified_Copy_Status__c = 'Completed'
        ]) {
            justCompletedDocs.add(doc);

        }

         if (justCompletedDocs.isEmpty()) {
            return;
        }

        // Group document names by case, only for fully-completed cases
        Map<Id, List<String>> caseDocDocusignIds = new Map<Id, List<String>>();
        for (breg_Document__c doc : justCompletedDocs) {
            if (!caseIdsWithIncompleteDoc.contains(doc.breg_Case__c)) {
                if (!caseDocDocusignIds.containsKey(doc.breg_Case__c)) {
                    caseDocDocusignIds.put(doc.breg_Case__c, new List<String>());
                }
                caseDocDocusignIds.get(doc.breg_Case__c).add(doc.breg_Docusign_Document_Id__c);
            }
        }

        for (Id caseId : caseDocDocusignIds.keySet()) {
            String params = '<recordId>' + caseId + '</recordId>';
            params += '<documentDocusignIds>' + String.join(caseDocDocusignIds.get(caseId), ',') + '</documentDocusignIds>';
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(caseId, 'Document Trigger Handler, Handle Certify Copy');
            System.enqueueJob(new BREGStartDocusignWorkflow(SEND_CERTIFIED_COPY_WORKFLOW, caseId, params, 'Document Trigger Handler, Handle Certify Copy', workflowLogId));
        }
    }

    private void handleCombineDocuments(List<breg_Document__c> newDocuments) {
        String docIds = '';
        breg_Document__c initialDoc = null;

        for (breg_Document__c doc : newDocuments) {
            if ((doc.Name.contains('Initial Filing') || doc.Name.contains('Resubmittal Filing') || doc.Name.contains('Rejection Package'))) {
                initialDoc = doc;
                List<String> namePrefixes = new List<String>();
                 if (doc.Name.contains('Initial Filing')) {
                    namePrefixes.add('For Initial: ');
                 }
                 if (doc.Name.contains('Resubmittal Filing')) {
                    namePrefixes.add('For Resubmittal: ');
                    namePrefixes.add('For Initial: ');
                 }
                 if (doc.Name.contains('Rejection Package')) {
                    namePrefixes.add('For Rejection: ');
                 }
                List<breg_Document__c> relatedDocs = getRelatedDocs(doc.breg_Case__c, doc.Id, namePrefixes);
                if (!relatedDocs.isEmpty()) {
                    Map<Id, breg_Document__c> relatedDocsMap = new Map<Id, breg_Document__c>(relatedDocs);
                    List<String> docusignIdsList = new List<String>();
                    for (Id docId : relatedDocsMap.keySet()) {
                        docusignIdsList.add(relatedDocsMap.get(docId).breg_Docusign_Document_Id__c);
                    }
                    docIds = String.join(docusignIdsList, ',');
                }
                break;
            }
        }

        if (docIds != '') {
            docIds = initialDoc.breg_Docusign_Document_Id__c + ',' + docIds;
            String params =
                '<recordIds>' +
                docIds +
                '</recordIds><docIdToUpdate>' +
                initialDoc.Id +
                '</docIdToUpdate><recordId>' +
                initialDoc.breg_Case__c +
                '</recordId>';
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(initialDoc.breg_Case__c, 'Document Trigger Handler, Handle Combine Documents');
            System.enqueueJob(new BREGStartDocusignWorkflow(COMBINE_DOCS_WORKFLOW, initialDoc.breg_Case__c, params, 'Document Trigger Handler, Handle Combine Documents', workflowLogId));
        }
    }

    @TestVisible
    private void handleEditedCertifiedCopies(List<breg_Document__c> editedDocuments) {
        Set<Id> caseIds = new Set<Id>();
        for (breg_Document__c doc : editedDocuments) {
            if (doc.breg_Case__c != null && doc.breg_Available_To_Certify__c && doc.breg_Template_Document__c != null && (doc.Name.startsWith('I_') || doc.Name.startsWith('P_'))) {
                caseIds.add(doc.breg_Case__c);
            }
        }

        if (caseIds.isEmpty()) {
            return;
        }

        Set<Id> caseIdsWithCertifiedCopy = getCaseIdsWithCertifiedCopy(caseIds);

        for (breg_Document__c doc : editedDocuments) {
            if (doc.breg_Case__c != null && caseIdsWithCertifiedCopy.contains(doc.breg_Case__c) && doc.breg_Available_To_Certify__c && doc.breg_Template_Document__c != null && (doc.Name.startsWith('I_') || doc.Name.startsWith('P_'))) {
                doc.breg_Available_To_Certify__c = false;
                doc.breg_Is_Certified__c = true;
            }
        }
    }

    @TestVisible
    private Set<Id> getCaseIdsWithCertifiedCopy(Set<Id> caseIds) {
        Set<Id> caseIdsWithCertifiedCopy = new Set<Id>();

        for (breg_Document__c doc : [
            SELECT breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :caseIds AND breg_Available_To_Certify__c = TRUE
        ]) {
            caseIdsWithCertifiedCopy.add(doc.breg_Case__c);
        }

        return caseIdsWithCertifiedCopy;
    }

    private void handleCertifiedCopyDocuments(List<breg_Document__c> newDocuments) {
        Set<Id> availableToCertifyDocIds = new Set<Id>();
        for (breg_Document__c doc : newDocuments) {
            if (doc.breg_Available_To_Certify__c && doc.breg_Template_Document__c != null) {
                availableToCertifyDocIds.add(doc.Id);
            }
        }

        if (availableToCertifyDocIds.isEmpty()) {
            return;
        }

        List<breg_Document__c> certifiedDocs = BREGPortalUtils.getDocuments(availableToCertifyDocIds);

        for (breg_Document__c currentDoc : certifiedDocs) {
            if (currentDoc.breg_Template_Document__r?.breg_Case__c == null) {
                continue;
            }
            String params = '<currentCaseId>' + currentDoc.breg_Template_Document__r.breg_Case__c + '</currentCaseId>';
            params += '<currentDocDocusignId>' + currentDoc.breg_Template_Document__r.breg_Docusign_Document_Id__c + '</currentDocDocusignId>';
            params += '<documentName>' + currentDoc.breg_Template_Document__r.Name + '</documentName>';
            params += '<destinationCaseId>' + currentDoc.breg_Case__c + '</destinationCaseId>';
            params += '<documentDestinationName>' + currentDoc.Name + '</documentDestinationName>';
            params += '<documentDestinationId>' + currentDoc.Id + '</documentDestinationId>';
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(currentDoc.breg_Case__c, 'Document Trigger Handler, Handle Certified Copy');
            System.enqueueJob(new BREGStartDocusignWorkflow(CREATE_CERTIFIED_COPY_WORKFLOW, currentDoc.breg_Case__c, params, 'Document Trigger Handler, Handle Certified Copy', workflowLogId));
        }
    }

    public static List<breg_Document__c> getRelatedDocs(Id caseId, Id excludeDocId, List<String> namePrefixes) {
        if (namePrefixes == null || namePrefixes.isEmpty()) {
            return new List<breg_Document__c>();
        }

        String query = 'SELECT Id, Name, breg_Docusign_Document_Id__c, breg_Case__c '+
            'FROM breg_Document__c '+
            'WHERE breg_Case__c = :caseId AND breg_Is_Irrelevant__c = FALSE AND breg_Is_Uploaded_Attachment__c = TRUE AND Id != :excludeDocId AND (';
        List<String> conditions = new List<String>();
        for (String prefix : namePrefixes) {
            if (String.isBlank(prefix)) {
                continue;
            }
            conditions.add('Name LIKE \'' + String.escapeSingleQuotes(prefix) + '%\'');
        }
        if (conditions.isEmpty()) {
            return new List<breg_Document__c>();
        }
        query += String.join(conditions, ' OR ') + ')';
        return Database.query(query);
    }
  
}