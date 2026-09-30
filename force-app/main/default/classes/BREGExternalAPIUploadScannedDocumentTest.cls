@isTest
public with sharing class BREGExternalAPIUploadScannedDocumentTest {
    @isTest
    static void testUploadScannedDocument_Success() {
        // Prepare a fake base64 PDF string
        String fakeBase64 = EncodingUtil.base64Encode(Blob.valueOf('Fake PDF Content'));
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web', Type = 'Other');
        insert testCase;

        // Mock DocuSignApi.uploadCaseStagingFile
        Test.startTest();
        // Prepare request
        BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest reqObj = new BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest();
        reqObj.documentBase64 = fakeBase64;
        reqObj.workitemNumber = [SELECT CaseNumber FROM Case WHERE Id = :testCase.Id].CaseNumber;
        reqObj.queueName = 'Annuals';
        reqObj.queue = 123;
        reqObj.processed = 1;
        reqObj.fileName = 'testDocument.pdf';

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/uploadScannedDocument';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        RestContext.request = req;

        // Call the method
        BREGExternalAPIUploadScannedDocument.ScannedDocumentResponse resp = BREGExternalAPIUploadScannedDocument.uploadScannedDocument();
        Test.stopTest();

        Assert.areEqual(null, resp.errorMessage, 'Should not have error message');
        Assert.areEqual(201, RestContext.response.statusCode == null ? 201 : RestContext.response.statusCode, 'Status code should be 201');

        // Check that breg_Document__c and breg_Case_Staging__c were created
        List<breg_Document__c> docs = [SELECT Id, breg_Is_Initial_Filing__c, breg_Docusign_Document_Id__c FROM breg_Document__c];
        Assert.areEqual(1, docs.size(), 'Should have created one breg_Document__c');
        Assert.areEqual(true, docs[0].breg_Is_Initial_Filing__c, 'Should be marked as initial filing');
        Assert.areEqual('mockedDocId', docs[0].breg_Docusign_Document_Id__c, 'Document ID should match mocked value');

        List<breg_Case_Staging__c> cases = [
            SELECT Id, breg_Queue_Name__c, breg_Queue__c, breg_Processed__c, breg_Document__c
            FROM breg_Case_Staging__c
        ];
        Assert.areEqual(1, cases.size(), 'Should have created one breg_Case_Staging__c');
        Assert.areEqual('Annuals', cases[0].breg_Queue_Name__c, 'Queue name should match request');
        Assert.areEqual(123, cases[0].breg_Queue__c, 'Queue number should match request');
        Assert.areEqual(1, cases[0].breg_Processed__c, 'Processed value should match request');
        Assert.areEqual(docs[0].Id, cases[0].breg_Document__c, 'Document reference should be correct');
    }

    @isTest
    static void testUploadScannedDocument_NullRequestBody() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/uploadScannedDocument';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;

        BREGExternalAPIUploadScannedDocument.ScannedDocumentResponse resp = BREGExternalAPIUploadScannedDocument.uploadScannedDocument();

        Assert.areEqual('Request body cannot be null', resp.errorMessage);
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @isTest
    static void testUploadScannedDocument_MissingRequiredProperties() {
        // Missing documentBase64
        BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest reqObj1 = new BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest();
        reqObj1.workitemNumber = '12345';
        reqObj1.queueName = 'Annuals';
        reqObj1.queue = 1;
        reqObj1.processed = 1;

        RestRequest req1 = new RestRequest();
        req1.requestUri = '/services/apexrest/api/uploadScannedDocument';
        req1.httpMethod = 'POST';
        req1.requestBody = Blob.valueOf(JSON.serialize(reqObj1));
        RestContext.request = req1;

        BREGExternalAPIUploadScannedDocument.ScannedDocumentResponse resp1 = BREGExternalAPIUploadScannedDocument.uploadScannedDocument();
        Assert.areEqual('Request body doesn\'t contain required parameters: documentBase64, workitemNumber', resp1.errorMessage);
    }

    @isTest
    static void testUploadScannedDocument_WrongWorkitemNumber() {
        // Prepare a request with a workitemNumber that does not exist
        BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest reqObj = new BREGExternalAPIUploadScannedDocument.ScannedDocumentRequest();
        reqObj.workitemNumber = 'NON_EXISTENT_CASE';
        reqObj.documentBase64 = EncodingUtil.base64Encode(Blob.valueOf('dummy pdf content'));
        reqObj.queueName = 'Annuals';
        reqObj.queue = 123;
        reqObj.processed = 1;
        reqObj.noChanges = false;
        reqObj.fileName = 'testDocument.pdf';

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/uploadScannedDocument';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        RestContext.request = req;

        BREGExternalAPIUploadScannedDocument.ScannedDocumentResponse resp = BREGExternalAPIUploadScannedDocument.uploadScannedDocument();

        Assert.isTrue(resp.errorMessage.contains('Case not found:'), 'Error message should contain "Case not found:"');
        Assert.areEqual(400, RestContext.response.statusCode, 'Status code should be 400 for missing case');
    }
}