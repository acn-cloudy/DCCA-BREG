@RestResource(urlMapping='/api/uploadScannedDocument')
global with sharing class BREGExternalAPIUploadScannedDocument {
    global class ScannedDocumentRequest {
        public String workitemNumber { get; set; }
        public Boolean noChanges { get; set; }
        public String documentBase64 { get; set; }
        public String queueName { get; set; }
        public Integer queue { get; set; }
        public Integer processed { get; set; }
        public String fileName { get; set; }
    }

    global class ScannedDocumentResponse {
        public String errorMessage { get; set; }
        public String documentId { get; set; }
    }

    static final String INITIAL_FILE_NAME = '{0} - Initial Filing.pdf';

    @HttpPost
    global static ScannedDocumentResponse uploadScannedDocument() {
        ScannedDocumentResponse response = new ScannedDocumentResponse();
        RestContext.response = new RestResponse();

        if (RestContext.request.requestBody == null) {
            response.errorMessage = 'Request body cannot be null';
            RestContext.response.statusCode = 400;
            return response;
        }
        ScannedDocumentRequest request = (ScannedDocumentRequest) JSON.deserialize(
            RestContext.request.requestBody.toString(),
            ScannedDocumentRequest.class
        );

        if (request.documentBase64 == null || request.workitemNumber == null) {
            response.errorMessage = 'Request body doesn\'t contain required parameters: documentBase64, workitemNumber';
            return response;
        }
        // Call DocuSignApi.uploadFile to upload the document and get the documentId

        String docusignDocumentHref;
        String datetimeFormatted = DateTime.now().formatGmt('yyyy-MM-dd HH-mm-ss');
        try {
            docusignDocumentHref = Test.isRunningTest()
                ? 'https://docusign.com/documents/mockedDocId'
                : DocuSignApi.uploadCaseStagingFile(
                      request.queueName,
                      String.format(INITIAL_FILE_NAME, new List<String>{ request.workitemNumber }),
                      request.documentBase64
                  );
        } catch (Exception ex) {
            response.errorMessage = 'Exception calling Docusign: ' + ex.getMessage();
            RestContext.response.statusCode = 400;
            return response;
        }

        // 3. Create record of breg_Document__c object and store docusign document id in there.
        breg_Document__c doc = new breg_Document__c(
            breg_Docusign_Document_Id__c = docusignDocumentHref?.substringAfterLast('/'),
            breg_Is_Initial_Filing__c = true,
            name = String.format(INITIAL_FILE_NAME, new List<String>{ request.workitemNumber }).left(80)
        );
        insert doc;

        // Get the generic record type Id for breg_Case_Staging__c
        Id genericRecordTypeId = Schema.SObjectType.breg_Case_Staging__c.getRecordTypeInfosByName().get('Generic').getRecordTypeId();
        breg_Case_Staging__c caseStaging = new breg_Case_Staging__c(
            breg_Status__c = 'New',
            breg_Queue_Name__c = request.queueName,
            breg_Queue__c = request.queue,
            breg_Processed__c = request.processed,
            breg_No_Changes__c = request.noChanges != null ? request.noChanges : false,
            breg_Workitem_Number__c = request.workitemNumber,
            RecordTypeId = genericRecordTypeId,
            breg_Document__c = doc.Id,
            breg_Document_Creation_Date_Time__c = datetimeFormatted
        );

        Case workitem;
        try {
            workitem = [SELECT Id, breg_No_Changes__c, Origin, Status, breg_Annual__c FROM Case WHERE CaseNumber = :request.workitemNumber];
        } catch (Exception e) {
            caseStaging.breg_Status__c = 'Error';
            String errorMessage = 'Case not found: ' + e.getMessage();
            caseStaging.breg_Error_Message__c = errorMessage;
            response.errorMessage = errorMessage;
            RestContext.response.statusCode = 400;
            return response;
        }
        caseStaging.breg_Case__c = workitem.Id;
        insert caseStaging;

        doc.breg_Case__c = workitem.Id;
        update doc;

        workitem.breg_No_Changes__c = caseStaging.breg_No_Changes__c;
        //update workitem;
        if (workitem.Status == 'Received' && workitem.Origin == 'In Person') {
            BREGSObjectUpdaterWithoutSharing.updateRecords(BREGCaseStatusHandlerConversion.updateCaseWithAssignmentRules(new List<Case>{ workitem }));
        }

        if (workitem.breg_Annual__c != null) {
            breg_Annual__c annual = new breg_Annual__c(Id = workitem.breg_Annual__c, breg_No_Changes__c = caseStaging.breg_No_Changes__c);
            update annual;
        }
        //Start Docusign workflow
        if (!Test.isRunningTest())
            System.enqueueJob(new BREGStartDocusignWorkflow('BREG Case Staging Process', caseStaging.Id, null, 'External API Upload Scanned Document', false)); //TODO add param for related case for log record

        response.documentId = doc.Id; //docusignDocumentHref?.substringAfterLast('/');
        return response;
    }
}