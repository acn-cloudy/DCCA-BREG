@RestResource(urlMapping='/api/uploadBregDocument2')
global with sharing class BREGExternalAPIUploadDocument {
    global class UploadDocumentRequest {
        public String OriginalId;
        public String NewName;
        public Boolean IsPublic;
        public String Base64Data;
        public String Annotation;
    }

    global class UploadDocumentResponse {
        public String documentId;
        public String errorMessage;
    }

    @HttpPost
    global static UploadDocumentResponse uploadDocument() {
        UploadDocumentResponse response = new UploadDocumentResponse();

        // Parse request body
        String reqBody = RestContext.request.requestBody != null ? RestContext.request.requestBody.toString() : null;
        if (String.isBlank(reqBody)) {
            response.errorMessage = 'Request body is empty';
            return response;
        }
        UploadDocumentRequest req = (UploadDocumentRequest) JSON.deserialize(reqBody, UploadDocumentRequest.class);

        // Validate required fields
        if (String.isBlank(req.OriginalId) || String.isBlank(req.NewName) || String.isBlank(req.Base64Data)) {
            response.errorMessage = 'Missing required parameter(s): OriginalId, NewName, Base64Data';
            return response;
        }

        // Query the original breg_Document__c record
        breg_Document__c originalDoc;
        try {
            originalDoc = [
                SELECT
                    Id,
                    Name,
                    breg_Account__c,
                    breg_Annual__c,
                    breg_Availability__c,
                    breg_Available_To_Certify__c,
                    breg_Case__c,
                    breg_File_Number__c,
                    breg_File_Storage_Id__c,
                    breg_File_Storage_URL__c,
                    breg_Is_Certificate_Of_Good_Standing__c,
                    breg_Is_Public__c,
                    breg_Price__c,
                    breg_TN_TM_SM__c,
                    breg_Type__c,
                    breg_Template_Document__c,
                    breg_Is_Template_Copy__c,
                    breg_Docusign_Document_Id__c,
                    breg_Is_Certified__c
                FROM breg_Document__c
                WHERE Id = :req.OriginalId
            ];
        } catch (Exception ex) {
            response.errorMessage = 'Original document not found: ' + ex.getMessage();
            return response;
        }

        // Clone the document (do not copy Id or DocuSign Document Id)
        breg_Document__c newDoc = originalDoc.clone(false, true, false, false);
        String clearNewName = req.NewName.replaceAll('[^A-Za-z0-9 .,()_\'`-]', '');
        newDoc.Name = clearNewName;
        newDoc.breg_Is_Public__c = req.IsPublic;
        newDoc.breg_Annotation__c = EncodingUtil.base64Decode(req.Annotation).toString();
        newDoc.breg_Docusign_Document_Id__c = null;

        // Upload file to DocuSign and get new DocuSign Document Id
        String docusignDocumentId;
        try {
            String fileNameWithExtension = clearNewName;
            if (!fileNameWithExtension.toLowerCase().endsWith('.pdf')) {
                fileNameWithExtension += '.pdf';
            }
            // Call DocuSignAPI.uploadFile(CaseId, fileName, fileBase64)
            // Assume DocuSignAPI.uploadFile returns the DocuSign Document Id as String
            docusignDocumentId = Test.isRunningTest()
                ? 'TEST_DOCUSIGN_DOC_ID'
                : DocuSignAPI.uploadFile(originalDoc.breg_Case__c, fileNameWithExtension, req.Base64Data);
            newDoc.breg_Docusign_Document_Id__c = docusignDocumentId;
        } catch (Exception ex) {
            response.errorMessage = 'Failed to upload file to DocuSign: ' + ex.getMessage();
            return response;
        }

        // Insert the cloned document
        try {
            insert newDoc;
            response.documentId = newDoc.Id;
        } catch (Exception ex) {
            response.errorMessage = 'Failed to insert cloned document: ' + ex.getMessage();
            return response;
        }

        return response;
    }
}