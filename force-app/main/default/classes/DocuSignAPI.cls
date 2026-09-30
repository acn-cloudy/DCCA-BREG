public inherited sharing class DocuSignAPI {
    private static final Integer STATUS_CODE_OK = 200;
    private static final Integer STATUS_CODE_CREATED = 201;
    private static final Integer STATUS_CODE_ACCEPTED = 202;
    private static final Integer DOCUMENTS_PAGE_SIZE = 20;
    private static final Integer MAX_DOCUMENTS_PAGES_TO_SCAN = 100;
    private static final String BASE_FOLDER_PATH = 'Other Sources';

    private static breg_Docusign_Auth__mdt bregAuth {
        get {
            if (bregAuth == null) {
                bregAuth = !Test.isRunningTest()
                    ? breg_Docusign_Auth__mdt.getInstance('DocuSignAuth')
                    : new breg_Docusign_Auth__mdt(Docusign_API_Account_Id__c = '12345678');
            }
            return bregAuth;
        }
        set {
            bregAuth = value;
        }
    }

    private static breg_Docusign_Auth__mdt bregSourceAuth {
        get {
            if (bregSourceAuth == null) {
                bregSourceAuth = !Test.isRunningTest()
                    ? breg_Docusign_Auth__mdt.getInstance('SourceDocusignAuth')
                    : new breg_Docusign_Auth__mdt(Docusign_API_Account_Id__c = '12345678');
            }
            return bregSourceAuth;
        }
        set {
            bregSourceAuth = value;
        }
    }

    @future(callout=true)
    public static void createFolderForCaseAsync(Id caseId) {
        DocuSignAPI.createFolderForCase(caseId);
    }
    
    public static void updateDocumentTemplates(List<BREG_Docusign_Templates_Setting__mdt> templateSettings) {
        updateDocumentTemplates(templateSettings, 'DocuSignAPI.updateDocumentTemplates');
    }

    public static void updateDocumentTemplates(List<BREG_Docusign_Templates_Setting__mdt> templateSettings, String startedFrom) {
        if (templateSettings == null || templateSettings.isEmpty()) {
            return;
        }

        List<breg_Log__c> logsToInsert = new List<breg_Log__c>();

        for (BREG_Docusign_Templates_Setting__mdt templateSetting : templateSettings) {
            Id relatedRecordId = templateSetting == null ? null : templateSetting.Id;
            try {
                if (templateSetting == null) {
                    throw new DocuSignApiException('Template setting record is null');
                }

                String fileName = templateSetting.breg_Template_Name__c;
                String folderPath = templateSetting.breg_Folder_Path__c;
                if (String.isBlank(fileName) || String.isBlank(folderPath)) {
                    throw new DocuSignApiException('Template name and folder path are required');
                }
                String startedFromForLog = String.isBlank(templateSetting.Label)
                    ? startedFrom
                    : templateSetting.Label + ', ' + startedFrom;

                String sourceFileHref = DocusignAPI.getDocumentHrefByPath(folderPath, fileName, true);
                String sourceDocumentId = DocusignAPI.getDocumentIdByHref(sourceFileHref);
                Blob fileBlob = DocusignAPI.getDocumentBlob(sourceDocumentId, true);
                String targetFileHref = DocusignAPI.getDocumentHrefByPath(folderPath, fileName, false);
                String targetDocumentId = DocusignAPI.getDocumentIdByHref(targetFileHref);
                String result = DocusignAPI.updateFileVersion(targetDocumentId, fileName, fileBlob);

                if (String.isBlank(result)) {
                    throw new DocuSignApiException('Template update returned empty result');
                }

                logsToInsert.add(BREGUtils.buildTemplateSettingsExecutionLog(
                    relatedRecordId,
                    startedFromForLog,
                    'Success',
                    null,
                    null,
                    'INFO'
                ));
            } catch (Exception ex) {
                String startedFromForLog = templateSetting == null || String.isBlank(templateSetting.Label)
                    ? startedFrom
                    : templateSetting.Label + ', ' + startedFrom;
                logsToInsert.add(BREGUtils.buildTemplateSettingsExecutionLog(
                    relatedRecordId,
                    startedFromForLog,
                    'Error',
                    ex.getMessage(),
                    ex.getStackTraceString(),
                    'ERROR'
                ));
            }
        }

        BREGUtils.insertTemplateSettingsExecutionLogs(logsToInsert);
    }

    public static void createFolderForCase(Id caseId) {
        Case newCase = [SELECT breg_Workitem_ID__c FROM Case WHERE Id = :caseId];
        dfsle__EOS_Type__c mapping = [SELECT dfsle__Path__c, dfsle__FolderName__c FROM dfsle__EOS_Type__c WHERE Name = 'Case'];
        EosFolder parentFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
        createFolder(parentFolder, 'Case - ' + newCase.breg_Workitem_ID__c);
    }

    @future(callout=true)
    public static void createFolderForAccount(Id accountId) {
        Account newAccount = [SELECT Name FROM Account WHERE Id = :accountId];
        dfsle__EOS_Type__c mapping = [SELECT dfsle__Path__c, dfsle__FolderName__c FROM dfsle__EOS_Type__c WHERE Name = 'Account'];
        EosFolder parentFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
        createFolder(parentFolder, newAccount.Name + ' - ' + newAccount.Id);
    }

    public static String uploadCaseStagingFile(String queueName, String fileName, String fileBody) {
        dfsle__EOS_Type__c mapping = [
            SELECT dfsle__Path__c, dfsle__FolderName__c
            FROM dfsle__EOS_Type__c
            WHERE Name = 'breg_Case_Staging__c'
        ];
        String targetFolderName = queueName + ' Staging';
        EosFolder folder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c + '/' + targetFolderName, false);
        EosFolder parentFolder = folder;
        if (folder == null) {
            EosFolder rootFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
            parentFolder = createFolder(rootFolder, targetFolderName);
        }
        Blob fileBlob = EncodingUtil.base64Decode(fileBody);
        String fileHref = uploadFile(parentFolder, fileName, fileBlob);
        return fileHref;
    }

    public static String uploadFile(String caseId, String fileName, String fileBody) {
        Case newCase = [SELECT breg_Workitem_ID__c FROM Case WHERE Id = :caseId];
        dfsle__EOS_Type__c mapping = [SELECT dfsle__Path__c, dfsle__FolderName__c FROM dfsle__EOS_Type__c WHERE Name = 'Case'];
        EosFolder folder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c + '/Case - ' + newCase.breg_Workitem_ID__c, false);
        EosFolder parentFolder = folder;
        if (folder == null) {
            EosFolder rootFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
            parentFolder = createFolder(rootFolder, 'Case - ' + newCase.breg_Workitem_ID__c);
        }
        Blob fileBlob = EncodingUtil.base64Decode(fileBody);
        String fileHref = uploadFile(parentFolder, fileName, fileBlob); //TODO: refactor this
        if (String.isBlank(fileHref)) {
            return null;
        }
        fileHref = fileHref.split('/')[fileHref.split('/').size() - 1];
        return fileHref;
    }

    public static String updateFileVersion(String documentId, Blob fileBlob) {
        return updateFileVersion(documentId, documentId + '.docx', fileBlob);
    }

    public static String updateFileVersion(String documentId, String fileNameWithExtension, Blob fileBlob) {
        if (String.isBlank(documentId)) {
            throw new DocuSignApiException('Document id is required.');
        }
        if (String.isBlank(fileNameWithExtension)) {
            throw new DocuSignApiException('File name is required.');
        }
        if (fileBlob == null) {
            throw new DocuSignApiException('File body is required.');
        }

        String sanitizedfileNameWithExtension = sanitizeHeaderfileNameWithExtension(fileNameWithExtension);
        String fileExtension = getFileExtension(sanitizedfileNameWithExtension);

        HttpRequest request = prepareHttpRequest('POST', 'documents', true, false);
        request.setEndpoint(request.getEndpoint() + '/' + EncodingUtil.urlEncode(documentId, 'UTF-8'));
        request.setTimeout(120000);
        request.setHeader('Content-Type', getUploadContentType(fileExtension));
        request.setHeader(
            'Content-Disposition',
            'file; filename="' +
            sanitizedfileNameWithExtension +
            '"; fileExtension=' +
            fileExtension +
            '; documentId=' +
            sanitizeHeaderToken(documentId)
        );
        request.setBodyAsBlob(fileBlob);

        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request);

        if (response.getStatusCode() == STATUS_CODE_CREATED || response.getStatusCode() == STATUS_CODE_OK) {
            ClmDocument updatedFile = (ClmDocument) JSON.deserialize(response.getBody(), ClmDocument.class);
            return updatedFile.Href;
        }

        return null;
    }

    public static String uploadEntityListFile(Id entityListId, String fileBody) {
        breg_Entity_List__c el = [
            SELECT OwnerId, Owner.Name, breg_DocuSign_Formatted_Date_Time__c
            FROM breg_Entity_List__c
            WHERE Id = :entityListId
        ];
        dfsle__EOS_Type__c mapping = [
            SELECT dfsle__Path__c, dfsle__FolderName__c
            FROM dfsle__EOS_Type__c
            WHERE Name = 'breg_Entity_List__c'
        ];
        String folderName = el.OwnerId + ' - ' + el.Owner.Name;
        EosFolder folder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c + '/' + folderName, false);
        EosFolder parentFolder = folder;
        if (folder == null) {
            EosFolder rootFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
            parentFolder = createFolder(rootFolder, folderName);
        }
        Blob fileBlob = Blob.valueOf(fileBody);
        String fileName = entityListId + '-' + el.breg_DocuSign_Formatted_Date_Time__c + '.csv';
        //Name contains invalid formatting. Please remove any of the following invalid characters: \\ / : * ? \" < > &#124;.
        String fileHref = uploadFile(parentFolder, fileName, fileBlob);
        return fileHref;
    }

    public static String uploadAgentSearchFile(Id agentSearchListId, String fileBody) {
        breg_Agent_Search_List__c asl = [
            SELECT OwnerId, Owner.Name, breg_DocuSign_Formatted_Date_Time__c
            FROM breg_Agent_Search_List__c
            WHERE Id = :agentSearchListId
        ];
        dfsle__EOS_Type__c mapping = [
            SELECT dfsle__Path__c, dfsle__FolderName__c
            FROM dfsle__EOS_Type__c
            WHERE Name = 'breg_Agent_Search_List__c'
        ];
        String folderName = asl.OwnerId + ' - ' + asl.Owner.Name;
        EosFolder folder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c + '/' + folderName, false);
        EosFolder parentFolder = folder;
        if (folder == null) {
            EosFolder rootFolder = getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c, false);
            parentFolder = createFolder(rootFolder, folderName);
        }
        Blob fileBlob = Blob.valueOf(fileBody);
        String fileName = agentSearchListId + '-' + asl.breg_DocuSign_Formatted_Date_Time__c + '.csv';
        String fileHref = uploadFile(parentFolder, fileName, fileBlob);
        return fileHref;
    }

    public static Boolean checkIfFolderForCaseExists(String caseId) {
        Case newCase = [SELECT breg_Workitem_ID__c FROM Case WHERE Id = :caseId];
        dfsle__EOS_Type__c mapping = [SELECT dfsle__Path__c, dfsle__FolderName__c FROM dfsle__EOS_Type__c WHERE Name = 'Case'];
        String folderName = 'Case - ' + newCase.breg_Workitem_ID__c;
        return getFolderByPath(BASE_FOLDER_PATH + mapping.dfsle__Path__c + '/' + folderName, false) != null;
    }

    public static EosFolder getFolderByPath(String folderPath, Boolean isSourceDocument) {
        HttpRequest request = prepareHttpRequest('GET', 'folders/path', false, isSourceDocument);
        request.setEndpoint(request.getEndpoint() + '/?path=' + EncodingUtil.urlEncode(folderPath, 'UTF-8'));

        //instantiate an Http instance
        Http httpProtocol = new Http();

        //Make the request and capture the response
        HttpResponse response = httpProtocol.send(request);
        if (response.getStatusCode() == STATUS_CODE_OK) {
            return (EosFolder) JSON.deserializeStrict(response.getBody(), EosFolder.class);
        }
        return null;
    }

    public static EosFolder createFolder(EosFolder parentFolder, String folderName) {
        HttpRequest request = prepareHttpRequest('POST', 'folders', false, false);

        EosFolder newFolder = new EosFolder();
        newFolder.Name = folderName;
        newFolder.ParentFolder = parentFolder;

        request.setBody(JSON.serialize(newFolder, true));
        //instantiate an Http instance
        Http httpProtocol = new Http();
        //Make the request and capture the response
        HttpResponse response = httpProtocol.send(request);
        if (response.getStatusCode() == STATUS_CODE_CREATED) {
            newFolder = (EosFolder) JSON.deserialize(response.getBody(), EosFolder.class);
            return newFolder;
        } else {
            System.debug('*** createFolder error: ' + response.getBody());
        }

        return null;
    }

    public static EosFolder ensureChildFolder(String parentPath, EosFolder parentFolder, String childFolderName) {
        EosFolder existingChildFolder = getFolderByPath(parentPath + '/' + childFolderName, false);
        if (existingChildFolder != null) {
            return existingChildFolder;
        }

        if (parentFolder == null || String.isBlank(parentFolder.Href)) {
            return null;
        }

        return createFolder(parentFolder, childFolderName);
    }

    public static String uploadFile(EosFolder parentFolder, String fileName, Blob fileBody) {
        HttpRequest request = prepareHttpRequest('POST', 'folders', true, false);

        request.setEndpoint(request?.getEndpoint() + '/' + parentFolder?.getFolderUUID() + '/documents?name=' + EncodingUtil.urlEncode(fileName, 'UTF-8'));
        request.setTimeout(120000); // Set timeout to 2 minutes
        request.setBodyAsBlob(fileBody);

        //instantiate an Http instance
        Http httpProtocol = new Http();

        //Make the request and capture the response
        HttpResponse response = httpProtocol.send(request);

        if (response.getStatusCode() == STATUS_CODE_CREATED) {
            CLMDocument newFile = (CLMDocument) JSON.deserialize(response.getBody(), ClmDocument.class);
            return newFile.Href;
        } else {
            System.debug('*** upload file error: ' + response.getBody());
            System.debug('*** upload file status code: ' + response.getStatusCode());
            System.debug('*** upload file status: ' + response.getStatus());
        }

        return null;
    }

    public String checkResult(String apiName, String requestId) {
        HttpRequest request = prepareHttpRequest('GET', apiName, false, false);

        request.setEndpoint(request.getEndpoint() + '/' + requestId);

        //instantiate an Http instance
        Http httpProtocol = new Http();

        //Make the request and capture the response
        HttpResponse response = httpProtocol.send(request);
        System.debug(LoggingLevel.INFO, '***response.getBody() ' + response.getBody());
        return response.getBody();
    }

    public static Blob getDocumentBlob(String documentId, Boolean isSourceDocument) {
        HttpRequest request = prepareHttpRequest('GET', 'documents', true, isSourceDocument);
        request.setEndpoint(request.getEndpoint() + '/' + documentId);
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request);
        if (response.getStatusCode() == STATUS_CODE_OK) {
            Blob documentBlob = response.getBodyAsBlob();
            return documentBlob;
        } else {
            throw new DocuSignApiException('Failed to download document. Status: ' + response.getStatusCode());
        }
    }

    public static String getDocumentHrefByPath(String folderPath, String documentName, Boolean isSourceDocument) {
        if (String.isBlank(folderPath)) {
            throw new DocuSignApiException('Folder path is required.');
        }
        if (String.isBlank(documentName)) {
            throw new DocuSignApiException('Document name is required.');
        }

        EosFolder folder = getFolderByPath(folderPath, isSourceDocument);
        if (folder == null || String.isBlank(folder.Href)) {
            return null;
        }

        String folderUuid = folder.getFolderUUID();
        if (String.isBlank(folderUuid)) {
            return null;
        }

        String encodedDocumentName = EncodingUtil.urlEncode(documentName, 'UTF-8');
        Integer offset = 0;
        Integer pageNumber = 0;

        while (pageNumber < MAX_DOCUMENTS_PAGES_TO_SCAN) {
            HttpRequest request = prepareHttpRequest('GET', 'folders', false, isSourceDocument);
            request.setEndpoint(
                request.getEndpoint() +
                '/' +
                folderUuid +
                '/documents?name=' +
                encodedDocumentName +
                '&offset=' +
                offset +
                '&limit=' +
                DOCUMENTS_PAGE_SIZE
            );

            Http httpProtocol = new Http();
            HttpResponse response = httpProtocol.send(request);
            if (response.getStatusCode() != STATUS_CODE_OK) {
                return null;
            }

            Object parsedBody = JSON.deserializeUntyped(response.getBody());
            String foundHref = findDocumentHrefInResponse(parsedBody, documentName);
            if (!String.isBlank(foundHref)) {
                return foundHref;
            }

            Integer itemCount = getDocumentsItemsCount(parsedBody);
            if (itemCount < DOCUMENTS_PAGE_SIZE) {
                break;
            }

            pageNumber++;
            offset += DOCUMENTS_PAGE_SIZE;
        }
        return null;
    }

    public static String getDocumentIdByHref(String documentHref) {
        if (String.isBlank(documentHref)) {
            return null;
        }

        String normalizedHref = documentHref.trim();
        if (normalizedHref.contains('?')) {
            normalizedHref = normalizedHref.substringBefore('?');
        }

        while (normalizedHref.endsWith('/')) {
            normalizedHref = normalizedHref.left(normalizedHref.length() - 1);
        }

        if (String.isBlank(normalizedHref)) {
            return null;
        }

        return normalizedHref.contains('/') ? normalizedHref.substringAfterLast('/') : normalizedHref;
    }

    private static Integer getBlobSize(Blob blobValue) {
        return blobValue == null ? null : blobValue.size();
    }

    private static String getBlobDigest(Blob blobValue) {
        return blobValue == null ? null : EncodingUtil.convertToHex(Crypto.generateDigest('MD5', blobValue));
    }

    private static Integer getDocumentsItemsCount(Object parsedBody) {
        if (!(parsedBody instanceof Map<String, Object>)) {
            return 0;
        }

        Map<String, Object> responseMap = (Map<String, Object>) parsedBody;
        Object itemsNode = responseMap.get('Items');
        if (itemsNode instanceof List<Object>) {
            return ((List<Object>) itemsNode).size();
        }

        Object resultsNode = responseMap.get('Results');
        if (resultsNode instanceof List<Object>) {
            return ((List<Object>) resultsNode).size();
        }

        return 0;
    }

    private static String findDocumentHrefInResponse(Object node, String documentName) {
        if (node == null) {
            return null;
        }

        if (node instanceof Map<String, Object>) {
            Map<String, Object> objectNode = (Map<String, Object>) node;
            String name = (String) objectNode.get('Name');
            String href = (String) objectNode.get('Href');

            if (
                !String.isBlank(name) &&
                !String.isBlank(href) &&
                    name.equals(documentName) &&
                href.contains('/documents/') &&
                !href.endsWith('/documents') &&
                !href.contains('/documents?')
            ) {
                return href;
            }

            for (String key : objectNode.keySet()) {
                String foundHref = findDocumentHrefInResponse(objectNode.get(key), documentName);
                if (!String.isBlank(foundHref)) {
                    return foundHref;
                }
            }
        }

        if (node instanceof List<Object>) {
            for (Object item : (List<Object>) node) {
                String foundHref = findDocumentHrefInResponse(item, documentName);
                if (!String.isBlank(foundHref)) {
                    return foundHref;
                }
            }
        }

        return null;
    }

    // Add this method inside the existing DocuSignAPI class.
public static String submitDocumentXmlMerge(
    String templateDocumentHref,
    String destinationFolderHref,
    String destinationDocumentName,
    String dataXml
) {
    if (String.isBlank(templateDocumentHref)) {
        throw new DocuSignApiException('Template document href is required.');
    }
    if (String.isBlank(destinationFolderHref)) {
        throw new DocuSignApiException('Destination folder href is required.');
    }
    if (String.isBlank(destinationDocumentName)) {
        throw new DocuSignApiException('Destination document name is required.');
    }
    if (String.isBlank(dataXml)) {
        throw new DocuSignApiException('Data XML is required.');
    }

    HttpRequest request = prepareHttpRequest('POST', 'documentxmlmergetasks', false, false);
    request.setTimeout(120000);

    DocumentXMLMergeTask task = new DocumentXMLMergeTask();
    task.TemplateDocument = new ClmDocument();
    task.TemplateDocument.Href = templateDocumentHref;

    task.DestinationFolder = new EosFolder();
    task.DestinationFolder.Href = destinationFolderHref;

    task.DestinationDocumentName = destinationDocumentName;
    task.DataXml = dataXml;

    request.setBody(JSON.serialize(task, true));

    Http httpProtocol = new Http();
    HttpResponse response = httpProtocol.send(request);

    if (
        response.getStatusCode() == STATUS_CODE_CREATED ||
        response.getStatusCode() == STATUS_CODE_OK ||
        response.getStatusCode() == STATUS_CODE_ACCEPTED
    ) {
        return response.getBody();
    }

    throw new DocuSignApiException('Document XML merge failed. Status: ' + response.getStatusCode() + '. Body: ' + response.getBody());
}

    public static String startWorkflow(String workflowName, String recordId) {
        String responseBody = startWorkflowInternal(workflowName, '<recordId>' + recordId + '</recordId>');
        return responseBody;
    }

    public static String startWorkflowWithParams(String workflowName, String params) {
        String parameters = '<Parameters>' + params + '</Parameters>';
        String responseBody = startWorkflowInternal(workflowName, parameters);
        return responseBody;
    }

    public static String startWorkflowWithParams(String workflowName, String params, Id caseId) {
        return startWorkflowWithParams(workflowName, params);
    }

    public static String formatWorkflowResponse(String responseBody, String startedBy) {
        if (String.isBlank(responseBody)) {
            throw new DocuSignApiException('Workflow response body is required.');
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        String workflowName = (String) responseMap.get('Name');
        String startDate = (String) responseMap.get('StartDate');
        String status = (String) responseMap.get('Status');
        String href = (String) responseMap.get('Href');

        if (String.isBlank(href)) {
            throw new DocuSignApiException('Workflow href is required.');
        }

        String workflowInstanceUid = href.substringAfterLast('/');
        String monitorHref = 'https://uatna11.springcm.com/atlas/workflow/monitorworkflowactivity?aid=' +
            EncodingUtil.urlEncode(String.valueOf(bregAuth.Docusign_API_Account_Id__c), 'UTF-8') +
            '&workflowinstanceuid=' + EncodingUtil.urlEncode(workflowInstanceUid, 'UTF-8');

        JSONGenerator generator = JSON.createGenerator(false);
        generator.writeStartObject();
        generator.writeStringField('Id', workflowInstanceUid);
        generator.writeStringField('Workflow Name', workflowName);
        generator.writeStringField('StartDate', startDate);
        generator.writeStringField('Status', status);
        if (startedBy == null) {
            generator.writeNullField('Started By');
        } else {
            generator.writeStringField('Started By', startedBy);
        }
        generator.writeStringField('Href', monitorHref);
        generator.writeEndObject();

        return generator.getAsString();
    }

    public static String getWorkflowStatus(String workflowInstanceUid) {
        if (String.isBlank(workflowInstanceUid)) {
            throw new DocuSignApiException('Workflow instance UID is required.');
        }

        HttpRequest request = prepareHttpRequest('GET', 'workflows', false, false);
        request.setEndpoint(request.getEndpoint() + '/' + workflowInstanceUid);

        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request);
        if (response.getStatusCode() == STATUS_CODE_OK) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String status = (String) responseMap.get('Status');
            if (String.isBlank(status)) {
                throw new DocuSignApiException('Workflow status is missing in response.');
            }
            return status;
        }

        throw new DocuSignApiException('Failed to get workflow status. Status: ' + response.getStatusCode() + '. Body: ' + response.getBody());
    }

    public static String escapeXml(String input) {
        if (input == null)
            return '';
        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace('\'', '&apos;');
    }

    private static String startWorkflowInternal(String workflowName, String paramsXml) {
        HttpRequest request = prepareHttpRequest('POST', 'workflows', false, false);
        CLMWorkflow workflow = new CLMWorkflow();
        workflow.Name = workflowName;
        workflow.Params = paramsXml;
        request.setBody(JSON.serialize(workflow, true));
        Http http = new Http();
        HttpResponse response = http.send(request);
        String responseBody = response.getBody();
        return responseBody;
    }

    private static HttpRequest prepareHttpRequest(String methodName, String endpointName, Boolean isUploadEndpoint, Boolean isSourceEndpoint) {
        //instantiate an HttpRequest instance
        HttpRequest request = new HttpRequest();

        // Set the request parameters
        breg_Docusign_Auth__mdt auth = isSourceEndpoint ? bregSourceAuth : bregAuth;
        String endpointPrefix;
        if (isSourceEndpoint){
            endpointPrefix = isUploadEndpoint ? 'callout:DocuSignSourceUpload' : 'callout:DocuSignSource';
        } else {
            endpointPrefix = isUploadEndpoint ? 'callout:DocuSignUpload' : 'callout:DocuSign';
        }
        String endpoint = '/' + auth.Docusign_API_Account_Id__c + '/' + endpointName;

        request.setEndpoint(endpointPrefix + endpoint);
        request.setMethod(methodName);
        if (methodName == 'POST' && !isUploadEndpoint) {
            request.setHeader('Accept', 'application/json');
            request.setHeader('Content-type', 'application/json');
        }

        return request;
    }

    private static String sanitizeHeaderFileNameWithExtension(String fileNameWithExtension) {
        String sanitizedFileNameWithExtension = fileNameWithExtension.trim();
        sanitizedFileNameWithExtension = sanitizedFileNameWithExtension.replace('\r', ' ');
        sanitizedFileNameWithExtension = sanitizedFileNameWithExtension.replace('\n', ' ');
        sanitizedFileNameWithExtension = sanitizedFileNameWithExtension.replace('"', '');
        sanitizedFileNameWithExtension = sanitizedFileNameWithExtension.replace(';', ' ');
        return sanitizedFileNameWithExtension;
    }

    private static String sanitizeHeaderToken(String value) {
        String sanitizedValue = value == null ? '' : value.trim();
        sanitizedValue = sanitizedValue.replace('\r', '');
        sanitizedValue = sanitizedValue.replace('\n', '');
        sanitizedValue = sanitizedValue.replace(';', '');
        sanitizedValue = sanitizedValue.replace('"', '');
        return sanitizedValue;
    }

    private static String getFileExtension(String fileName) {
        if (String.isBlank(fileName) || !fileName.contains('.')) {
            return 'docx';
        }

        String extension = fileName.substringAfterLast('.').toLowerCase();
        return String.isBlank(extension) ? 'docx' : extension;
    }

    private static String getUploadContentType(String fileExtension) {
        if (fileExtension == 'pdf') {
            return 'application/pdf';
        }
        if (fileExtension == 'docx') {
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }
        if (fileExtension == 'doc') {
            return 'application/msword';
        }

        return 'application/octet-stream';
    }

    @InvocableMethod(
        label='Upload Files to DocuSign'
        description='Uploads files from ContentDocuments to the DocuSign folder for a given Case'
        category='DocuSign'
    )
    public static void uploadFilesFromFlow(List<FlowInput> inputs) {
        for (FlowInput input : inputs) {
            List<String> docIds = new List<String>();
            for (Id docId : input.contentDocumentIds) {
                docIds.add(String.valueOf(docId));
            }
            String namePrefix = input.namePrefix;
            uploadFilesAsync(String.valueOf(input.caseId), docIds, namePrefix);
        }
    }

    private static void uploadFilesAsync(String caseId, List<String> contentDocumentIds, String namePrefix) {
        List<ContentVersion> versions = [
            SELECT PathOnClient, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = TRUE
        ];
        List<breg_Document__c> docsToInsert = new List<breg_Document__c>();
        List<ContentDocument> docsToDelete = new List<ContentDocument>();
        for (ContentVersion cv : versions) {
            String fileBody = EncodingUtil.base64Encode(cv.VersionData);
            String docusignDocumentId = DocuSignAPI.uploadFile(caseId, cv.PathOnClient, fileBody);
            if (docusignDocumentId != null) {
                docsToInsert.add(
                    new breg_Document__c(
                        Name = namePrefix != null ? namePrefix + cv.PathOnClient : cv.PathOnClient,
                        breg_Case__c = caseId,
                        breg_Docusign_Document_Id__c = docusignDocumentId,
                        breg_Is_Uploaded_Attachment__c = true
                    )
                );
                docsToDelete.add(new ContentDocument(Id = cv.ContentDocumentId));
            }
        }
        if (!docsToInsert.isEmpty()) {
            insert docsToInsert;
            delete docsToDelete;
        }
    }

    public class FlowInput {
        @InvocableVariable(label='Case Id' required=true)
        public Id caseId;

        @InvocableVariable(label='Content Document Ids' required=true)
        public List<Id> contentDocumentIds;

        @InvocableVariable(label='Name Prefix' required=false)
        public String namePrefix;
    }

    //wrapper class for Folder Search Response

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class EosFolder {
        public String Name { get; set; }
        public DateTime CreatedDate { get; set; }
        public String CreatedBy { get; set; }
        public DateTime UpdatedDate { get; set; }
        public String UpdatedBy { get; set; }
        public String Description { get; set; }
        public EosFolder ParentFolder { get; set; }
        public String BrowseDocumentsUrl { get; set; }
        public AccessLevel AccessLevel { get; set; }
        public ClmDocument Documents { get; set; }
        public ClmDocument Folders { get; set; }
        public ClmDocument ShareLinks { get; set; }
        public String CreateDocumentHref { get; set; }
        public String Href { get; set; }

        public String getFolderUUID() {
            if (Href != null && Href.contains('/')) {
                return Href.substringAfter('/folders/').substringBefore('/');
            }
            return null;
        }
    }

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class AccessLevel {
        public boolean See { get; set; }
        public boolean Read { get; set; }
        public boolean Write { get; set; }
        public boolean Move { get; set; }
        public boolean Create { get; set; }
        public boolean SetAccess { get; set; }
    }

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class ClmDocument {
        public String Href { get; set; }
    }

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class DocumentXMLMergeTask {
        public ClmDocument AttributeDocument { get; set; }
        public ClmDocument ContentDocument { get; set; }
        public ClmDocument TemplateDocument { get; set; }
        public EosFolder DestinationFolder { get; set; }
        public String DestinationDocumentName { get; set; }
        public String DataXml { get; set; }
    }

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class DocumentXMLMergeResponse {
        public String Status { get; set; }
        public String Href { get; set; }
    }

    @SuppressWarnings('PMD.PropertyNamingConventions')
    public class CLMWorkflow {
        public String Name { get; set; }
        public String Href { get; set; }
        public String Params { get; set; }
    }

    public class DocuSignApiException extends Exception {
    }
}