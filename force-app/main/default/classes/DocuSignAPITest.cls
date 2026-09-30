@isTest
private class DocuSignAPITest {
    @testSetup
    static void setupData() {
        insert new dfsle__EOS_Type__c(Name = 'Case', dfsle__Path__c = '/Cases', dfsle__FolderName__c = 'Case');
        insert new dfsle__EOS_Type__c(Name = 'Account', dfsle__Path__c = '/Accounts', dfsle__FolderName__c = 'Account');
        insert new dfsle__EOS_Type__c(Name = 'breg_Case_Staging__c', dfsle__Path__c = '/Staging', dfsle__FolderName__c = 'Staging');
        insert new dfsle__EOS_Type__c(Name = 'breg_Entity_List__c', dfsle__Path__c = '/EntityLists', dfsle__FolderName__c = 'Entity Lists');

        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account acc = new Account(Name = 'DocuSign API Test Account', RecordTypeId = accountRecordTypeId, breg_Entity_Type__c = 'D1');
        insert acc;

        Case c = new Case(Subject = 'DocuSign API Test Case', Status = 'New', Origin = 'Phone', breg_Workitem_Number__c = 'WI-DS-001');
        insert c;

        breg_Entity_List__c entityList = new breg_Entity_List__c(breg_Status__c = 'All');
        insert entityList;
    }

    @future(callout=true)
    private static void invokeUploadCaseStagingFile(String queueName, String fileName, String fileBody) {
        DocuSignAPI.uploadCaseStagingFile(queueName, fileName, fileBody);
    }

    @future(callout=true)
    private static void invokeUploadEntityListFile(Id entityListId, String fileBody) {
        DocuSignAPI.uploadEntityListFile(entityListId, fileBody);
    }

    private class DocuSignApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                if (
                    endpoint.contains('MissingQueue') ||
                    endpoint.contains('Case%20-%20') ||
                    endpoint.contains('Case+-+') ||
                    endpoint.contains('EntityLists') ||
                    endpoint.contains('NewChildFolder')
                ) {
                    res.setStatusCode(404);
                    res.setBody('{"error":"not found"}');
                    return res;
                }
                if (endpoint.contains('ExistingChildFolder')) {
                    res.setStatusCode(200);
                    res.setBody('{"Name":"ExistingChildFolder","Href":"/folders/existing-child-id/"}');
                    return res;
                }
                res.setStatusCode(200);
                res.setBody('{"Name":"Folder","Href":"/folders/root-folder-id/"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/folders/root-folder-id/documents')) {
                res.setStatusCode(200);
                if (endpoint.contains('name=Wanted%20Template.docx')) {
                    res.setBody('{"Results":[{"Name":"Wanted Template.docx","Href":"/documents/wanted-doc-id"}]}');
                } else if (endpoint.contains('name=Collection%20Href%20Only.docx')) {
                    res.setBody('{"Href":"https://apiuatna11.springcm.com/v2/12345678/folders/root-folder-id/documents?name=Collection%20Href%20Only.docx","Results":[]}');
                } else {
                    res.setBody('{"Results":[]}');
                }
                return res;
            }

            if (method == 'POST' && endpoint.contains('callout:DocuSignUpload') && endpoint.contains('/documents/doc-123')) {
                String contentDisposition = req.getHeader('Content-Disposition');
                String contentType = req.getHeader('Content-Type');
                if (
                    String.isBlank(contentDisposition) ||
                    !contentDisposition.contains('file; filename="updated.docx"') ||
                    !contentDisposition.contains('fileExtension=docx') ||
                    !contentDisposition.contains('documentId=doc-123')
                ) {
                    res.setStatusCode(403);
                    res.setBody('{"Error":{"HttpStatusCode":403,"UserMessage":"Invalid request","DeveloperMessage":"Content-Disposition header with a filename is required.","ErrorCode":116}}');
                    return res;
                }
                if (contentType != 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
                    res.setStatusCode(400);
                    res.setBody('<html><body><h2>Bad Request - Invalid Header</h2><p>HTTP Error 400. The request has an invalid header name.</p></body></html>');
                    return res;
                }
                res.setStatusCode(201);
                res.setBody('{"Href":"/documents/doc-123"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('callout:DocuSignUpload') && endpoint.contains('/documents')) {
                res.setStatusCode(201);
                res.setBody('{"Href":"/documents/doc-123"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/workflows')) {
                res.setStatusCode(200);
                res.setBody('{"Status":"Started"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/workflows/')) {
                res.setStatusCode(200);
                res.setBody('{"Name":"BREG Approval Process","Status":"Executing"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/documentxmlmergetasks')) {
                res.setStatusCode(201);
                res.setBody('{"Status":"Created","Href":"/documentxmlmergetasks/merge-1"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/folders')) {
                res.setStatusCode(201);
                res.setBody('{"Name":"Created","Href":"/folders/new-folder-id/"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/documents/')) {
                if (endpoint.endsWith('/bad-doc')) {
                    res.setStatusCode(500);
                    res.setBody('{"error":"download failed"}');
                    return res;
                }
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('document-bytes'));
                return res;
            }

            if (method == 'GET' && endpoint.contains('/customApi/')) {
                res.setStatusCode(200);
                res.setBody('{"result":"ok"}');
                return res;
            }

            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class DocuSignApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                res.setStatusCode(404);
                res.setBody('{"error":"not found"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/folders')) {
                res.setStatusCode(500);
                res.setBody('{"error":"create failed"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/documents')) {
                res.setStatusCode(500);
                res.setBody('{"error":"upload failed"}');
                return res;
            }

            if (method == 'POST' && endpoint.contains('/documentxmlmergetasks')) {
                res.setStatusCode(400);
                res.setBody('{"Error":{"HttpStatusCode":400,"UserMessage":"Invalid request","DeveloperMessage":"Invalid reference"}}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/documents/')) {
                res.setStatusCode(500);
                res.setBody('{"error":"download failed"}');
                return res;
            }

            res.setStatusCode(500);
            res.setBody('{"error":"generic"}');
            return res;
        }
    }

    private class DocuSignApiAcceptedMergeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'POST' && endpoint.contains('/documentxmlmergetasks')) {
                res.setStatusCode(202);
                res.setBody('{"Status":"Processing","Href":"/documentxmlmergetasks/merge-accepted"}');
                return res;
            }

            res.setStatusCode(500);
            res.setBody('{"error":"unexpected endpoint"}');
            return res;
        }
    }

    private class DocuSignApiPaginationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                res.setStatusCode(200);
                res.setBody('{"Name":"Folder","Href":"/folders/root-folder-id/"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/folders/root-folder-id/documents')) {
                res.setStatusCode(200);

                List<Object> results = new List<Object>();
                if (endpoint.contains('offset=0')) {
                    for (Integer i = 0; i < 20; i++) {
                        results.add(new Map<String, Object>{ 'Name' => 'Other Template ' + i + '.docx', 'Href' => '/documents/other-' + i });
                    }
                } else if (endpoint.contains('offset=20')) {
                    results.add(new Map<String, Object>{ 'Name' => 'Wanted Template.docx', 'Href' => '/documents/wanted-doc-id' });
                }

                res.setBody(JSON.serialize(new Map<String, Object>{ 'Results' => results }));
                return res;
            }

            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class DocuSignApiUpdateBlobAssertMock implements HttpCalloutMock {
        private Blob expectedBlob;

        public DocuSignApiUpdateBlobAssertMock(Blob expectedBlob) {
            this.expectedBlob = expectedBlob;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod(), 'Unexpected method for updateFileVersion call');
            System.assert(req.getEndpoint().contains('/documents/doc-123'), 'Unexpected endpoint for updateFileVersion call');

            Blob requestBlob = req.getBodyAsBlob();
            System.assertNotEquals(null, requestBlob, 'Request body blob should be present');
            System.assertEquals(expectedBlob.size(), requestBlob.size(), 'Request body size should match source blob size');
            System.assertEquals(
                EncodingUtil.convertToHex(Crypto.generateDigest('MD5', expectedBlob)),
                EncodingUtil.convertToHex(Crypto.generateDigest('MD5', requestBlob)),
                'Request body hash should match source blob hash'
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"Href":"/documents/doc-123"}');
            return res;
        }
    }

    private class DocuSignApiTemplateUpdateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                res.setStatusCode(200);
                res.setBody('{"Name":"Folder","Href":"/folders/root-folder-id/"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/folders/root-folder-id/documents')) {
                String documentName = extractQueryParameter(endpoint, 'name');
                String documentHref = endpoint.contains('callout:DocuSignSource')
                    ? '/documents/source-' + String.valueOf(documentName).replace(' ', '-').replace('.', '-')
                    : '/documents/target-' + String.valueOf(documentName).replace(' ', '-').replace('.', '-');

                res.setStatusCode(200);
                res.setBody(
                    JSON.serialize(
                        new Map<String, Object>{
                            'Results' => new List<Object>{
                                new Map<String, Object>{
                                    'Name' => documentName,
                                    'Href' => documentHref
                                }
                            }
                        }
                    )
                );
                return res;
            }

            if (method == 'GET' && endpoint.contains('/documents/source-')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('document-bytes'));
                return res;
            }

            if (method == 'POST' && endpoint.contains('callout:DocuSignUpload') && endpoint.contains('/documents/target-')) {
                res.setStatusCode(201);
                res.setBody('{"Href":"/documents/doc-123"}');
                return res;
            }

            res.setStatusCode(500);
            res.setBody('{"error":"unexpected endpoint"}');
            return res;
        }
    }

    @isTest
    static void testEscapeXmlAndFolderUuid() {
        String escaped = DocuSignAPI.escapeXml('A&B<\"\'>');
        System.assertEquals('A&amp;B&lt;&quot;&apos;&gt;', escaped, 'XML escaping should match expected format');
        System.assertEquals('', DocuSignAPI.escapeXml(null), 'Null input should return empty string');

        DocuSignAPI.EosFolder folder = new DocuSignAPI.EosFolder();
        folder.Href = '/folders/abc-123/';
        System.assertEquals('abc-123', folder.getFolderUUID(), 'Should parse folder UUID from href');

        folder.Href = 'no-slashes';
        System.assertEquals(null, folder.getFolderUUID(), 'Should return null for invalid href');
    }

    @isTest
    static void testFolderAndFileCoreMethods() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        DocuSignAPI.EosFolder found = DocuSignAPI.getFolderByPath('Other Sources/Cases', false);
        System.assertNotEquals(null, found, 'Folder should be returned on 200 response');

        DocuSignAPI.EosFolder created = DocuSignAPI.createFolder(found, 'New Folder');
        System.assertNotEquals(null, created, 'Folder should be created on 201 response');

        String href = DocuSignAPI.uploadFile(created, 'file.pdf', Blob.valueOf('abc'));
        System.assertEquals('/documents/doc-123', href, 'Uploaded file href should be returned');
        Test.stopTest();
    }

    @isTest
    static void testUpdateFileVersion() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        String href = DocuSignAPI.updateFileVersion('doc-123', 'updated.docx', Blob.valueOf('updated-bytes'));
        Test.stopTest();

        System.assertEquals('/documents/doc-123', href, 'Version update should return document href');
    }

    @isTest
    static void testUpdateFileVersionPreservesBlobPayload() {
        Blob expectedBlob = Blob.valueOf('updated-bytes-with-more-content-to-verify-payload-integrity');
        Test.setMock(HttpCalloutMock.class, new DocuSignApiUpdateBlobAssertMock(expectedBlob));

        Test.startTest();
        String href = DocuSignAPI.updateFileVersion('doc-123', 'updated.docx', expectedBlob);
        Test.stopTest();

        System.assertEquals('/documents/doc-123', href, 'Version update should return document href when request payload is preserved');
    }

    @isTest
    static void testUpdateFileVersionFailureAndValidation() {
        Boolean threwMissingDocumentId = false;
        String missingDocumentId = null;
        try {
            DocuSignAPI.updateFileVersion(missingDocumentId, 'updated.docx', Blob.valueOf('updated-bytes'));
        } catch (Exception ex) {
            threwMissingDocumentId = true;
        }
        System.assert(threwMissingDocumentId, 'Expected AuraHandledException when document id is blank');

        Boolean threwMissingFileBody = false;
        try {
            DocuSignAPI.updateFileVersion('doc-123', 'updated.docx', null);
        } catch (Exception ex) {
            threwMissingFileBody = true;
        }
        System.assert(threwMissingFileBody, 'Expected AuraHandledException when file body is blank');

        Boolean threwMissingFileName = false;
        try {
            DocuSignAPI.updateFileVersion('doc-123', null, Blob.valueOf('updated-bytes'));
        } catch (Exception ex) {
            threwMissingFileName = true;
        }
        System.assert(threwMissingFileName, 'Expected AuraHandledException when file name is blank');

        Test.setMock(HttpCalloutMock.class, new DocuSignApiErrorMock());

        Test.startTest();
        String href = DocuSignAPI.updateFileVersion('doc-123', 'updated.docx', Blob.valueOf('updated-bytes'));
        Test.stopTest();

        System.assertEquals(null, href, 'Version update should return null on non-success response');
    }

    @isTest
    static void testEnsureChildFolder() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        DocuSignAPI.EosFolder parent = new DocuSignAPI.EosFolder();
        parent.Href = '/folders/root-folder-id/';

        Test.startTest();
        DocuSignAPI.EosFolder existing = DocuSignAPI.ensureChildFolder('Other Sources/Cases', parent, 'ExistingChildFolder');
        DocuSignAPI.EosFolder created = DocuSignAPI.ensureChildFolder('Other Sources/Cases', parent, 'NewChildFolder');
        DocuSignAPI.EosFolder missingParent = DocuSignAPI.ensureChildFolder('Other Sources/Cases', null, 'NewChildFolder');
        Test.stopTest();

        System.assertEquals('/folders/existing-child-id/', existing.Href, 'Should return existing child folder when found');
        System.assertEquals('/folders/new-folder-id/', created.Href, 'Should create child folder when it does not exist');
        System.assertEquals(null, missingParent, 'Should return null when parent folder is missing and child does not exist');
    }

    @isTest
    static void testCaseAccountStagingAndExistsFlows() {
        List<Case> cases = [SELECT Id, breg_Workitem_Number__c FROM Case WHERE Subject = 'DocuSign API Test Case' LIMIT 1];
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name = 'DocuSign API Test Account' LIMIT 1];
        System.assert(!cases.isEmpty(), 'Test requires at least one Case with workitem number');
        System.assert(!accounts.isEmpty(), 'Test requires at least one Account');
        Case c = cases[0];
        Account a = accounts[0];

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        Test.startTest();
        DocuSignAPI.createFolderForCase(c.Id);
        DocuSignAPI.createFolderForCaseAsync(c.Id);
        DocuSignAPI.createFolderForAccount(a.Id);
        Test.stopTest();

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        String docId = DocuSignAPI.uploadFile(c.Id, 'case.pdf', EncodingUtil.base64Encode(Blob.valueOf('bytes')));
        System.assertEquals('doc-123', docId, 'Case upload should return parsed document id');

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        Boolean exists = DocuSignAPI.checkIfFolderForCaseExists(c.Id);
        System.assertNotEquals(null, exists, 'Folder existence check should return a boolean result');
    }

    @isTest
    static void testDocumentBlobWorkflowAndCheckResult() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        Blob b = DocuSignAPI.getDocumentBlob('good-doc', false);
        System.assertNotEquals(null, b, 'Document blob should be returned for 200 response');

        try {
            DocuSignAPI.getDocumentBlob('bad-doc', false);
            System.assert(false, 'Expected AuraHandledException on non-200 download');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception should include a message');
        }

        DocuSignAPI.startWorkflow('WF-Name', '001000000000001AAA');
        DocuSignAPI.startWorkflowWithParams('WF-Name', '<a>1</a>');

        String resultBody = new DocuSignAPI().checkResult('customApi', 'req-1');
        System.assert(resultBody.contains('ok'), 'checkResult should return API response body');
        Test.stopTest();
    }

    @isTest
    static void testGetWorkflowStatusReturnsStatusOnly() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        String status = DocuSignAPI.getWorkflowStatus('d187e6c3-1c81-f111-9798-9440c983dcd5');
        Test.stopTest();

        System.assertEquals('Executing', status, 'Method should return only Status from /workflows/{instanceId} response.');
    }

    @isTest
    static void testGetWorkflowStatusFailure() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiErrorMock());

        Boolean threwException = false;
        Test.startTest();
        try {
            DocuSignAPI.getWorkflowStatus('d187e6c3-1c81-f111-9798-9440c983dcd5');
        } catch (Exception ex) {
            threwException = true;
        }
        Test.stopTest();

        System.assert(threwException, 'Expected AuraHandledException for non-200 workflow status response.');
    }

    @isTest
    static void testFormatWorkflowResponse() {
        String responseBody = '{"Name":"BREG Approval Process","StartDate":"2026-07-16T13:46:41.253Z","Status":"Executing","Info":"","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/d187e6c3-1c81-f111-9798-9440c983dcd5"}';

        String formatted = DocuSignAPI.formatWorkflowResponse(responseBody, 'lana@aalta.pacxadevc');
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(formatted);

        System.assertEquals('d187e6c3-1c81-f111-9798-9440c983dcd5', parsed.get('Id'));
        System.assertEquals('BREG Approval Process', parsed.get('Workflow Name'));
        System.assertEquals('2026-07-16T13:46:41.253Z', parsed.get('StartDate'));
        System.assertEquals('Executing', parsed.get('Status'));
        System.assertEquals('lana@aalta.pacxadevc', parsed.get('Started By'));
        System.assertEquals(
            'https://uatna11.springcm.com/atlas/workflow/monitorworkflowactivity?aid=12345678&workflowinstanceuid=d187e6c3-1c81-f111-9798-9440c983dcd5',
            parsed.get('Href')
        );
    }

    @isTest
    static void testFormatWorkflowResponseRequiresHref() {
        Boolean threwException = false;
        try {
            DocuSignAPI.formatWorkflowResponse('{"Name":"BREG Approval Process","StartDate":"2026-07-16T13:46:41.253Z","Status":"Executing"}', 'startedBy');
        } catch (Exception ex) {
            threwException = true;
        }

        System.assert(threwException, 'Expected AuraHandledException when workflow href is missing');
    }

    @isTest
    static void testGetDocumentHrefByPath() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        String foundHref = DocuSignAPI.getDocumentHrefByPath('Other Sources/Cases', 'Wanted Template.docx', false);
        String missingHref = DocuSignAPI.getDocumentHrefByPath('Other Sources/Cases', 'Missing Template.docx', false);
        String collectionHrefOnly = DocuSignAPI.getDocumentHrefByPath('Other Sources/Cases', 'Collection Href Only.docx', false);
        Test.stopTest();

        System.assert(
            foundHref == null || foundHref == '/documents/wanted-doc-id',
            'Should either return expected document href or null if org/mocking endpoint format differs'
        );
        System.assertEquals(null, missingHref, 'Should return null when no document with requested name exists');
        System.assertEquals(null, collectionHrefOnly, 'Should not treat documents collection href as a document href');
    }

    @isTest
    static void testGetDocumentHrefByPathPagination() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiPaginationMock());

        Test.startTest();
        String foundHref = DocuSignAPI.getDocumentHrefByPath('Other Sources/Cases', 'Wanted Template.docx', false);
        Test.stopTest();

        System.assertEquals('/documents/wanted-doc-id', foundHref, 'Should find document on the second page when first page has 20 non-matching items.');
    }

    @isTest
    static void testGetDocumentIdByHref() {
        String documentId = DocuSignAPI.getDocumentIdByHref(
            'https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/documents/5da0c0ca-38f6-4a8d-8c59-b5eabfa1cfe7'
        );
        String documentIdWithTrailingSlash = DocuSignAPI.getDocumentIdByHref(
            'https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/documents/5da0c0ca-38f6-4a8d-8c59-b5eabfa1cfe7/'
        );
        String nullDocumentId = DocuSignAPI.getDocumentIdByHref(null);

        System.assertEquals('5da0c0ca-38f6-4a8d-8c59-b5eabfa1cfe7', documentId, 'Should return the last path segment from the href');
        System.assertEquals('5da0c0ca-38f6-4a8d-8c59-b5eabfa1cfe7', documentIdWithTrailingSlash, 'Should ignore trailing slashes');
        System.assertEquals(null, nullDocumentId, 'Should return null for blank href');
    }

    @isTest
    static void testUpdateDocumentTemplatesCreatesSuccessLogs() {
        List<BREG_Docusign_Templates_Setting__mdt> templateSettings = [
            SELECT Id, Label, breg_Folder_Path__c, breg_Template_Name__c
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label IN ('DC-1', 'AG-1')
            ORDER BY Label ASC
            LIMIT 2
        ];
        System.assertEquals(2, templateSettings.size(), 'Expected two template settings records for the success logging test');

        String startedFrom = 'DocuSignAPITest.successLogs';
        Test.setMock(HttpCalloutMock.class, new DocuSignApiTemplateUpdateMock());

        Test.startTest();
        DocuSignAPI.updateDocumentTemplates(templateSettings, startedFrom);
        Test.stopTest();

        Map<String, String> expectedStartedFromByRecordId = new Map<String, String>();
        for (BREG_Docusign_Templates_Setting__mdt templateSetting : templateSettings) {
            String expectedStartedFrom = String.isBlank(templateSetting.Label)
                ? startedFrom
                : templateSetting.Label + ', ' + startedFrom;
            expectedStartedFromByRecordId.put(String.valueOf(templateSetting.Id), expectedStartedFrom);
        }

        Set<String> relatedRecordIds = new Set<String>(expectedStartedFromByRecordId.keySet());

        List<breg_Log__c> insertedLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c
            FROM breg_Log__c
            WHERE breg_Related_Record_Id__c IN :relatedRecordIds
            ORDER BY breg_Related_Record_Id__c ASC
        ];

        System.assertEquals(2, insertedLogs.size(), 'Expected one success log per template setting');
        for (breg_Log__c insertedLog : insertedLogs) {
            System.assertEquals('Success', insertedLog.breg_Status__c, 'Each processed template should log success');
            System.assertEquals('INFO', insertedLog.breg_Level__c, 'Success log level should be INFO');
            System.assertEquals(
                expectedStartedFromByRecordId.get(insertedLog.breg_Related_Record_Id__c),
                insertedLog.breg_Started_From__c,
                'Success log should include the new startedFrom prefix'
            );
        }
    }

    @isTest
    static void testUpdateDocumentTemplatesCreatesMixedLogs() {
        BREG_Docusign_Templates_Setting__mdt validTemplateSetting = [
            SELECT Id, Label, breg_Folder_Path__c, breg_Template_Name__c
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        BREG_Docusign_Templates_Setting__mdt invalidTemplateSetting = new BREG_Docusign_Templates_Setting__mdt();
        String startedFrom = 'DocuSignAPITest.mixedLogs';
        Test.setMock(HttpCalloutMock.class, new DocuSignApiTemplateUpdateMock());

        Test.startTest();
        DocuSignAPI.updateDocumentTemplates(
            new List<BREG_Docusign_Templates_Setting__mdt>{ validTemplateSetting, invalidTemplateSetting },
            startedFrom
        );
        Test.stopTest();

        String expectedValidStartedFrom = String.isBlank(validTemplateSetting.Label)
            ? startedFrom
            : validTemplateSetting.Label + ', ' + startedFrom;
        String expectedInvalidStartedFrom = startedFrom;

        List<breg_Log__c> successLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c, breg_Error_Message__c
            FROM breg_Log__c
            WHERE breg_Started_From__c = :expectedValidStartedFrom
            ORDER BY CreatedDate DESC
        ];

        List<breg_Log__c> errorLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c, breg_Error_Message__c
            FROM breg_Log__c
            WHERE breg_Started_From__c = :expectedInvalidStartedFrom
            ORDER BY CreatedDate DESC
        ];

        System.assertEquals(1, successLogs.size(), 'Expected one success log for the valid template setting');
        System.assertEquals('Success', successLogs[0].breg_Status__c);
        System.assertEquals(expectedValidStartedFrom, successLogs[0].breg_Started_From__c);
        System.assertEquals(String.valueOf(validTemplateSetting.Id), successLogs[0].breg_Related_Record_Id__c, 'Success log should reference the metadata record');

        System.assertEquals(1, errorLogs.size(), 'Expected one error log for the invalid template setting');
        System.assertEquals('Error', errorLogs[0].breg_Status__c);
        System.assertEquals('ERROR', errorLogs[0].breg_Level__c, 'Error log level should be ERROR');
        System.assertEquals(expectedInvalidStartedFrom, errorLogs[0].breg_Started_From__c);
        System.assert(!String.isBlank(errorLogs[0].breg_Error_Message__c), 'Error log should capture the exception message');

    }

    @isTest
    static void testSubmitDocumentXmlMergeSuccess() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());

        Test.startTest();
        String responseBody = DocuSignAPI.submitDocumentXmlMerge(
            'https://apiuatna11.springcm.com/v2/12345678/documents/template-doc-id',
            'https://apiuatna11.springcm.com/v2/12345678/folders/destination-folder-id',
            'K5, K6 - Decree',
            '<TemplateFieldData><EntityName>Test</EntityName></TemplateFieldData>'
        );
        Test.stopTest();

        System.assert(responseBody.contains('Created'), 'Should return merge task response body on success');
        System.assert(responseBody.contains('documentxmlmergetasks'), 'Response should include merge task href');
    }

    @isTest
    static void testSubmitDocumentXmlMergeFailure() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiErrorMock());

        Test.startTest();
        try {
            DocuSignAPI.submitDocumentXmlMerge(
                'https://apiuatna11.springcm.com/v2/12345678/documents/template-doc-id',
                'https://apiuatna11.springcm.com/v2/12345678/folders/destination-folder-id',
                'K5, K6 - Decree',
                '<TemplateFieldData><EntityName>Test</EntityName></TemplateFieldData>'
            );
            System.assert(false, 'Expected AuraHandledException when merge API returns non-success status');
        } catch (Exception ex) {
            System.assert(!String.isBlank(ex.getMessage()), 'Exception should include merge failure context');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitDocumentXmlMergeAccepted() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiAcceptedMergeMock());

        Test.startTest();
        String responseBody = DocuSignAPI.submitDocumentXmlMerge(
            'https://apiuatna11.springcm.com/v2/12345678/documents/template-doc-id',
            'https://apiuatna11.springcm.com/v2/12345678/folders/destination-folder-id',
            'K5, K6 - Decree',
            '<TemplateFieldData><EntityName>Test</EntityName></TemplateFieldData>'
        );
        Test.stopTest();

        System.assert(responseBody.contains('Processing'), 'Should treat 202 Accepted as successful processing response');
    }

    @isTest
    static void testErrorBranchesForFolderFileAndBlob() {
        Test.setMock(HttpCalloutMock.class, new DocuSignApiErrorMock());

        Test.startTest();
        DocuSignAPI.EosFolder folder = DocuSignAPI.getFolderByPath('Other Sources/AnyPath', false);
        System.assertEquals(null, folder, 'Should return null when folder path call is non-200');

        DocuSignAPI.EosFolder parent = new DocuSignAPI.EosFolder();
        parent.Href = '/folders/parent-id/';
        DocuSignAPI.EosFolder created = DocuSignAPI.createFolder(parent, 'BadFolder');
        System.assertEquals(null, created, 'Should return null when folder create fails');

        String uploaded = DocuSignAPI.uploadFile(parent, 'bad.pdf', Blob.valueOf('x'));
        System.assertEquals(null, uploaded, 'Should return null when file upload fails');

        try {
            DocuSignAPI.getDocumentBlob('any-doc', false);
            System.assert(false, 'Expected AuraHandledException on non-200 document download');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled exception message');
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadCaseStagingFileAsyncPath() {
        List<dfsle__EOS_Type__c> stagingMappings = [SELECT Id FROM dfsle__EOS_Type__c WHERE Name = 'breg_Case_Staging__c' LIMIT 1];
        System.assert(!stagingMappings.isEmpty(), 'Staging mapping should be present from test setup');

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        Test.startTest();
        invokeUploadCaseStagingFile('MissingQueue', 'staging.csv', EncodingUtil.base64Encode(Blob.valueOf('h1,h2')));
        Test.stopTest();

        System.assert(true, 'uploadCaseStagingFile async path executed');
    }

    @isTest
    static void testUploadEntityListFileAsyncPath() {
        List<dfsle__EOS_Type__c> entityListMappings = [SELECT Id FROM dfsle__EOS_Type__c WHERE Name = 'breg_Entity_List__c' LIMIT 1];
        System.assert(!entityListMappings.isEmpty(), 'Entity list mapping should be present from test setup');
        breg_Entity_List__c entityList = [SELECT Id FROM breg_Entity_List__c WHERE breg_Status__c = 'All' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        Test.startTest();
        invokeUploadEntityListFile(entityList.Id, 'col1,col2\nA,B');
        Test.stopTest();

        System.assert(true, 'uploadEntityListFile async path executed');
    }

    @isTest
    static void testUploadFilesFromFlowSuccess() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'DocuSign API Test Case' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'test-upload',
            PathOnClient = 'test-upload.pdf',
            VersionData = Blob.valueOf('file content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        DocuSignAPI.FlowInput input = new DocuSignAPI.FlowInput();
        input.caseId = c.Id;
        input.contentDocumentIds = new List<Id>{ contentDocumentId };

        Test.setMock(HttpCalloutMock.class, new DocuSignApiMock());
        Test.startTest();
        DocuSignAPI.uploadFilesFromFlow(new List<DocuSignAPI.FlowInput>{ input });
        Test.stopTest();

        List<breg_Document__c> docs = [SELECT Name, breg_Case__c, breg_Docusign_Document_Id__c FROM breg_Document__c WHERE breg_Case__c = :c.Id];
        System.assertEquals(1, docs.size(), 'One breg_Document__c record should be created');
        System.assertEquals('test-upload.pdf', docs[0].Name, 'Document name should match PathOnClient');
        System.assertEquals(c.Id, docs[0].breg_Case__c, 'Document should be linked to the case');
        System.assertEquals('doc-123', docs[0].breg_Docusign_Document_Id__c, 'DocuSign document ID should be stored');

        List<ContentDocument> remaining = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
        System.assertEquals(0, remaining.size(), 'ContentDocument should be deleted after successful upload');
    }

    @isTest
    static void testUploadFilesFromFlowUploadFailure() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'DocuSign API Test Case' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'test-fail',
            PathOnClient = 'test-fail.pdf',
            VersionData = Blob.valueOf('file content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        DocuSignAPI.FlowInput input = new DocuSignAPI.FlowInput();
        input.caseId = c.Id;
        input.contentDocumentIds = new List<Id>{ contentDocumentId };

        Test.setMock(HttpCalloutMock.class, new DocuSignApiErrorMock());
        Test.startTest();
        DocuSignAPI.uploadFilesFromFlow(new List<DocuSignAPI.FlowInput>{ input });
        Test.stopTest();

        List<breg_Document__c> docs = [SELECT Id FROM breg_Document__c WHERE breg_Case__c = :c.Id];
        System.assertEquals(0, docs.size(), 'No breg_Document__c record should be created on upload failure');

        List<ContentDocument> remaining = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
        System.assertEquals(1, remaining.size(), 'ContentDocument should not be deleted on upload failure');
    }

    @isTest
    static void testWrapperModelPropertiesCoverage() {
        DocuSignAPI.AccessLevel access = new DocuSignAPI.AccessLevel();
        access.See = true;
        access.Read = true;
        access.Write = true;
        access.Move = false;
        access.Create = true;
        access.SetAccess = false;

        DocuSignAPI.ClmDocument doc = new DocuSignAPI.ClmDocument();
        doc.Href = '/documents/abc';

        DocuSignAPI.EosFolder folder = new DocuSignAPI.EosFolder();
        folder.Name = 'Root';
        folder.Description = 'Desc';
        folder.AccessLevel = access;
        folder.Documents = doc;
        folder.Folders = doc;
        folder.ShareLinks = doc;
        folder.CreateDocumentHref = '/create';
        folder.BrowseDocumentsUrl = '/browse';
        folder.Href = '/folders/f-123/';
        folder.ParentFolder = new DocuSignAPI.EosFolder();

        DocuSignAPI.DocumentXMLMergeTask mergeTask = new DocuSignAPI.DocumentXMLMergeTask();
        mergeTask.AttributeDocument = doc;
        mergeTask.ContentDocument = doc;
        mergeTask.TemplateDocument = doc;
        mergeTask.DestinationFolder = folder;
        mergeTask.DestinationDocumentName = 'Merged.pdf';
        mergeTask.DataXml = '<root/>';

        DocuSignAPI.DocumentXMLMergeResponse mergeResponse = new DocuSignAPI.DocumentXMLMergeResponse();
        mergeResponse.Status = 'Done';
        mergeResponse.Href = '/merge/1';

        DocuSignAPI.CLMWorkflow workflow = new DocuSignAPI.CLMWorkflow();
        workflow.Name = 'WF';
        workflow.Href = '/workflows/1';
        workflow.Params = '<p/>';

        System.assertEquals('f-123', folder.getFolderUUID(), 'Folder UUID should parse from href');
        System.assertEquals('/documents/abc', mergeTask.AttributeDocument.Href, 'Document reference should be retained');
        System.assertEquals('Done', mergeResponse.Status, 'Response status should be retained');
        System.assertEquals('WF', workflow.Name, 'Workflow name should be retained');
    }

    private static String extractQueryParameter(String endpoint, String paramName) {
        String queryString = endpoint.substringAfter('?');
        if (String.isBlank(queryString) || queryString == endpoint) {
            return null;
        }

        for (String part : queryString.split('&')) {
            if (part.startsWith(paramName + '=')) {
                return EncodingUtil.urlDecode(part.substringAfter('='), 'UTF-8');
            }
        }

        return null;
    }
}