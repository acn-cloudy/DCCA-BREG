@IsTest
public with sharing class BREGExternalAPIGetDocumentTest {
    @IsTest
    static void testGetDocumentById_Success() {
        // Create a test document record
        breg_Document__c doc = new breg_Document__c(
            Name = 'Test Doc',
            breg_Docusign_Document_Id__c = '123456789'
        );
        insert doc;

        // Prepare a fake blob to return from DocuSignAPI.getDocumentBlob
        Blob testBlob = Blob.valueOf('Test document content');
        // Use System.Test.startTest/stopTest to isolate static mocking
        Test.startTest();
        // Use the built-in Apex Stub API to override the static method
        // But as per instructions, do not use a mock class, so we will use Test.setMock if possible
        // But since we can't, we will just expect the call to fail and check error handling

        // Simulate the request body
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"documentId":"' + doc.Id + '"}');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Use try/catch to handle the expected error since DocuSignAPI.getDocumentBlob will callout
        // and we can't mock it without a mock class
        BREGExternalAPIGetDocument.GetDocumentResponse response;
        try {
            response = BREGExternalAPIGetDocument.getDocumentById();
        } catch (Exception ex) {
            // Should not throw, should handle error and return errorMessage
        }
        Test.stopTest();

        // Query the document again to ensure it exists
        breg_Document__c docCheck = [SELECT Id, breg_Docusign_Document_Id__c FROM breg_Document__c WHERE Id = :doc.Id];
        Assert.areEqual('123456789', docCheck.breg_Docusign_Document_Id__c);

        // Validate the response
        Assert.isNotNull(response, 'Response should not be null');
        Assert.isNotNull(response.base64Document, 'base64Document should not be null');
    }

    @IsTest
    static void testGetDocumentById_MissingParameter() {
        // Simulate the request body with missing documentId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{}');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        BREGExternalAPIGetDocument.GetDocumentResponse response = BREGExternalAPIGetDocument.getDocumentById();

        Assert.areEqual('Missing required parameter: documentId', response.errorMessage, 'Should return missing parameter error');
        Assert.isNull(response.base64Document, 'base64Document should be null when parameter is missing');
    }

    @IsTest
    static void testGetDocumentById_DocumentNotFound() {
        // Simulate the request body with a non-existent documentId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"documentId":"a0A000000000000AAA"}');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        BREGExternalAPIGetDocument.GetDocumentResponse response = BREGExternalAPIGetDocument.getDocumentById();

        Assert.isTrue(response.errorMessage != null && response.errorMessage.contains('Failed to retrieve document from DocuSign'), 'Should return error for missing document');
        Assert.isNull(response.base64Document, 'base64Document should be null when document not found');
    }
}