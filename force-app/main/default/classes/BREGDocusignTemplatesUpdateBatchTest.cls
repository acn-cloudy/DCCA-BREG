@isTest
private class BREGDocusignTemplatesUpdateBatchTest {
    private class TemplateUpdateSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                response.setStatusCode(200);
                response.setBody('{"Name":"Folder","Href":"/folders/root-folder-id/"}');
                return response;
            }

            if (method == 'GET' && endpoint.contains('/folders/root-folder-id/documents')) {
                String documentName = extractQueryParameter(endpoint, 'name');
                response.setStatusCode(200);
                response.setBody(
                    JSON.serialize(
                        new Map<String, Object>{
                            'Results' => new List<Object>{
                                new Map<String, Object>{
                                    'Name' => documentName,
                                    'Href' => endpoint.contains('callout:DocuSignSource')
                                        ? '/documents/source-doc-id'
                                        : '/documents/target-doc-id'
                                }
                            }
                        }
                    )
                );
                return response;
            }

            if (method == 'GET' && endpoint.contains('/documents/source-doc-id')) {
                response.setStatusCode(200);
                response.setBodyAsBlob(Blob.valueOf('template-content'));
                return response;
            }

            if (method == 'POST' && endpoint.contains('/documents/target-doc-id')) {
                response.setStatusCode(201);
                response.setBody('{"Href":"/documents/target-doc-id"}');
                return response;
            }

            response.setStatusCode(500);
            response.setBody('{"error":"unexpected endpoint"}');
            return response;
        }
    }

    private class TemplateUpdateErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                response.setStatusCode(200);
                response.setBody('{"Name":"Folder","Href":"/folders/root-folder-id/"}');
                return response;
            }

            if (method == 'GET' && endpoint.contains('/folders/root-folder-id/documents')) {
                String documentName = extractQueryParameter(endpoint, 'name');
                response.setStatusCode(200);
                response.setBody(
                    JSON.serialize(
                        new Map<String, Object>{
                            'Results' => new List<Object>{
                                new Map<String, Object>{
                                    'Name' => documentName,
                                    'Href' => '/documents/source-doc-id'
                                }
                            }
                        }
                    )
                );
                return response;
            }

            if (method == 'GET' && endpoint.contains('/documents/source-doc-id')) {
                response.setStatusCode(500);
                response.setBody('{"error":"download failed"}');
                return response;
            }

            response.setStatusCode(500);
            response.setBody('{"error":"unexpected endpoint"}');
            return response;
        }
    }

    @isTest
    static void testBuildTemplateSettingsExecutionLog() {
        BREG_Docusign_Templates_Setting__mdt templateSetting = [
            SELECT Id, Label
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        String expectedStartedFrom = String.isBlank(templateSetting.Label)
            ? 'BREGDocusignTemplatesUpdateBatch'
            : templateSetting.Label + ', BREGDocusignTemplatesUpdateBatch';

        breg_Log__c logRecord = BREGUtils.buildTemplateSettingsExecutionLog(
            templateSetting.Id,
            expectedStartedFrom,
            'Error',
            'test message',
            'test stack',
            'ERROR'
        );

        System.assertEquals('BREG_Docusign_Templates_Setting__mdt', logRecord.breg_Object__c);
        System.assertEquals(String.valueOf(templateSetting.Id), logRecord.breg_Related_Record_Id__c);
        System.assertEquals(expectedStartedFrom, logRecord.breg_Started_From__c);
        System.assertEquals('Error', logRecord.breg_Status__c);
        System.assertEquals('Error', logRecord.breg_Type__c);
        System.assertEquals('ERROR', logRecord.breg_Level__c);
        System.assertEquals('test message', logRecord.breg_Error_Message__c);
        System.assertEquals('test stack', logRecord.breg_Stack_Trace__c);
        System.assertEquals(UserInfo.getUserId(), logRecord.breg_Started_By_User__c);
        System.assertNotEquals(null, logRecord.RecordTypeId);
    }

    @isTest
    static void testInsertTemplateSettingsExecutionLogs() {
        BREG_Docusign_Templates_Setting__mdt templateSetting = [
            SELECT Id
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        String startedFrom = 'BREGDocusignTemplatesUpdateBatchTest.insert';
        List<breg_Log__c> logsToInsert = new List<breg_Log__c>{
            BREGUtils.buildTemplateSettingsExecutionLog(templateSetting.Id, startedFrom, 'Success', null, null, 'INFO'),
            BREGUtils.buildTemplateSettingsExecutionLog(templateSetting.Id, startedFrom, 'Error', 'message', 'stack', 'ERROR')
        };

        Test.startTest();
        BREGUtils.insertTemplateSettingsExecutionLogs(logsToInsert);
        Test.stopTest();

        List<breg_Log__c> insertedLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c, breg_Type__c
            FROM breg_Log__c
            WHERE breg_Started_From__c = :startedFrom
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(2, insertedLogs.size(), 'Expected both template settings execution logs to be inserted');
        System.assertEquals('Success', insertedLogs[0].breg_Status__c);
        System.assertEquals('INFO', insertedLogs[0].breg_Level__c);
        System.assertEquals('Error', insertedLogs[1].breg_Status__c);
        System.assertEquals('ERROR', insertedLogs[1].breg_Level__c);
        System.assertEquals('Error', insertedLogs[1].breg_Type__c);
        System.assertEquals(String.valueOf(templateSetting.Id), insertedLogs[0].breg_Related_Record_Id__c);
    }

    @isTest
    static void testRunBatchCreatesSuccessLog() {
        BREG_Docusign_Templates_Setting__mdt templateSetting = [
            SELECT Id, Label
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        String expectedStartedFrom = String.isBlank(templateSetting.Label)
            ? 'BREGDocusignTemplatesUpdateBatch'
            : templateSetting.Label + ', BREGDocusignTemplatesUpdateBatch';

        Test.setMock(HttpCalloutMock.class, new TemplateUpdateSuccessMock());

        Test.startTest();
        Id jobId = BREGDocusignTemplatesUpdateBatch.runBatch(templateSetting.Label);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch should return a job id');

        List<breg_Log__c> insertedLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c
            FROM breg_Log__c
            WHERE breg_Started_From__c = :expectedStartedFrom
            AND breg_Related_Record_Id__c = :String.valueOf(templateSetting.Id)
        ];

        System.assertEquals(1, insertedLogs.size(), 'Batch should create exactly one log for the filtered metadata record');
        System.assertEquals('Success', insertedLogs[0].breg_Status__c);
        System.assertEquals('INFO', insertedLogs[0].breg_Level__c);
    }

    @isTest
    static void testUpdateDocumentTemplatesCreatesErrorLog() {
        BREG_Docusign_Templates_Setting__mdt templateSetting = [
            SELECT Id, breg_Folder_Path__c, breg_Template_Name__c, Label
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        String expectedStartedFrom = String.isBlank(templateSetting.Label)
            ? 'BREGDocusignTemplatesUpdateBatch'
            : templateSetting.Label + ', BREGDocusignTemplatesUpdateBatch';

        Test.setMock(HttpCalloutMock.class, new TemplateUpdateErrorMock());

        Test.startTest();
        DocuSignAPI.updateDocumentTemplates(
            new List<BREG_Docusign_Templates_Setting__mdt>{ templateSetting },
            'BREGDocusignTemplatesUpdateBatch'
        );
        Test.stopTest();

        List<breg_Log__c> insertedLogs = [
            SELECT breg_Related_Record_Id__c, breg_Status__c, breg_Level__c, breg_Started_From__c, breg_Error_Message__c
            FROM breg_Log__c
            WHERE breg_Started_From__c = :expectedStartedFrom
            AND breg_Related_Record_Id__c = :String.valueOf(templateSetting.Id)
            ORDER BY CreatedDate DESC
        ];

        System.assertEquals(1, insertedLogs.size(), 'Expected an error log to be inserted for the failed template update');
        System.assertEquals('Error', insertedLogs[0].breg_Status__c);
        System.assertEquals('ERROR', insertedLogs[0].breg_Level__c);
        System.assert(!String.isBlank(insertedLogs[0].breg_Error_Message__c), 'Error message should be captured in the log');
    }

    @isTest
    static void testBatchLifecycleWithEmptyScope() {
        BREGDocusignTemplatesUpdateBatch batch = new BREGDocusignTemplatesUpdateBatch();

        Database.QueryLocator queryLocator = batch.start(null);
        System.assertNotEquals(null, queryLocator, 'Start should always return a query locator.');

        Test.startTest();
        batch.execute(null, new List<SObject>());
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Batch lifecycle methods should handle empty scope without errors.');
    }

    @isTest
    static void testStartWithTrimmedListFiltersAndListRunner() {
        BREGDocusignTemplatesUpdateBatch batch = new BREGDocusignTemplatesUpdateBatch(
            new List<String>{ '  DC-1  ', null, '   ', 'AG-1' }
        );

        Database.QueryLocator queryLocator = batch.start(null);
        System.assertNotEquals(null, queryLocator, 'Start should return query locator for list-based filters.');

        Test.setMock(HttpCalloutMock.class, new TemplateUpdateSuccessMock());

        Test.startTest();
        Id jobId = BREGDocusignTemplatesUpdateBatch.runBatch(new List<String>{ 'DC-1' });
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'List overload should return an async job id.');
    }

    @isTest
    static void testStartWithFolderFiltersAndFolderRunner() {
        BREG_Docusign_Templates_Setting__mdt templateSetting = [
            SELECT Id, Label, breg_Folder_Path__c
            FROM BREG_Docusign_Templates_Setting__mdt
            WHERE Label = 'DC-1'
            LIMIT 1
        ];

        BREGDocusignTemplatesUpdateBatch batch = new BREGDocusignTemplatesUpdateBatch(
            new List<String>{ '  ' + templateSetting.breg_Folder_Path__c + '  ', null, '   ' },
            'FOLDER'
        );

        Database.QueryLocator queryLocator = batch.start(null);
        System.assertNotEquals(null, queryLocator, 'Start should return query locator for folder-based filters.');

        Test.setMock(HttpCalloutMock.class, new TemplateUpdateSuccessMock());

        Test.startTest();
        Id jobId = BREGDocusignTemplatesUpdateBatch.runBatch(
            new List<String>{ '__NON_EXISTENT_FOLDER_FOR_TEST__' },
            'FOLDER'
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Folder overload should return an async job id.');
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