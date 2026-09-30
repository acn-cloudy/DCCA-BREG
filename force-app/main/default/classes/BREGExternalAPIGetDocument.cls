@RestResource(urlMapping='/api/getBregDocument')
global with sharing class BREGExternalAPIGetDocument {
    global class GetDocumentResponse {
        public String base64Document { get; set; }
        public String errorMessage { get; set; }
        public String documentName { get; set; }
        public Boolean isPublic { get; set; }
        public String annotation { get; set; }
        public DateTime dateFiled { get; set; }
    }

    @HttpGet
    global static GetDocumentResponse getDocumentById() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        GetDocumentResponse response = new GetDocumentResponse();

        // Get documentId from query parameter
        Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.request.requestBody.toString());
        if (requestBody.isEmpty()) {
            response.errorMessage = 'Missing required parameter: documentId';
            RestContext.response.statusCode = 500;
            return response;
        }

        String documentId = (String) requestBody.get('documentId');

        // Query breg_Document__c for DocuSign Document Id
        breg_Document__c doc;
        try {
            doc = [
                SELECT Id, Name, breg_Docusign_Document_Id__c, breg_Is_Public__c, breg_Annotation__c, breg_Case__r.breg_Submission_Date__c
                FROM breg_Document__c
                WHERE Id = :documentId
            ];
            response.documentName = doc.Name;
            response.isPublic = doc.breg_Is_Public__c;
            response.annotation = doc.breg_Annotation__c;
            response.dateFiled = doc.breg_Case__r?.breg_Submission_Date__c;
        } catch (Exception ex) {
            response.errorMessage = 'Failed to retrieve document from DocuSign. ' + ex.getMessage();
            RestContext.response.statusCode = 500;
            return response;
        }

        Blob documentBlob;
        try {
            // Get the document blob from DocuSignAPI
            documentBlob = Test.isRunningTest() ? Blob.valueOf('PDF content') : DocuSignAPI.getDocumentBlob(doc.breg_Docusign_Document_Id__c ,false);
        } catch (Exception ex) {
            response.errorMessage = 'Failed to retrieve document from DocuSign. ' + ex.getMessage();
            RestContext.response.statusCode = 500;
            return response;
        }

        try {
            // Encode blob to base64 string
            response.base64Document = EncodingUtil.base64Encode(documentBlob);
        } catch (Exception ex) {
            response.errorMessage = 'Failed to encode document to base64. ' + ex.getMessage();
            RestContext.response.statusCode = 500;
        }

        return response;
    }
}