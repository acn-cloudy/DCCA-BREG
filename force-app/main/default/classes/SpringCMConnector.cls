public without sharing class SpringCMConnector {
    private static String refreshToken;
    private static String accessToken;
    private static SpringCMApiManager springcmApi;
    public class CMDocument {
        public String Description {set;get;}
        public SpringCMFolder ParentFolder {set;get;}
    }
    public class AuthResponse{
        public String access_token {set;get;}
        public String refresh_token {set;get;}
        public Integer expires_in {set;get;}
    }

    public static SpringCLM_Session__c getSession() {
        List<SpringCLM_Session__c> sessions = [Select Id, AccessToken__c, RefreshToken__c from SpringCLM_Session__c];
        SpringCLM_Session__c result;
        if(sessions.isEmpty()) {
            result = new SpringCLM_Session__c();
            result.AccessToken__c = accessToken;
            result.RefreshToken__c = refreshToken;
        } else {
            result = sessions.get(0);
        }
        return result;
    }
    public static HttpResponse initiateConnection() {
        SpringCLMSetting__mdt api = SpringCMApiEnvironment.getApiEnvironment();
        SpringCLM_Session__c session = getSession();
        Map<String, String> params = new Map<String, String>();
        params.put('client_id', api.Client_Id__c);
        params.put('client_secret', api.Client_Secret__c);

        String refreshToken = session.RefreshToken__c;

        params.put('refresh_token', refreshToken);
        params.put('grant_type', 'refresh_token');
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setEndPoint(api.AuthEndpoint__c );
        req.setMethod('POST');
        req.setBody(JSON.serialize(params));
        Http h = new Http();
        HttpResponse res;
        if(Test.isRunningTest() ) {
            res = new HttpResponse();
            res.setBody('{"access_token": "asdfasdfsadf"}');
        } else {
            res = h.send(req);
        }
        
        return res;
    }

    public static void cacheSession(String access_Token, String refresh_token, Integer expiresIn) {
        refreshToken = refresh_token;
        accessToken = access_Token;
        springcmApi = new SpringCMApiManager();
        springcmApi.authenticate(accessToken);
    }

    @AuraEnabled
    public static String getToken() {
        String accessToken = getAccessToken();
        saveToken();
        return accessToken;

    }
    public static String getAccessToken() {
        if(SpringCMConnector.accessToken != null) return SpringCMConnector.accessToken;
        HttpResponse res = initiateConnection();
        String body = res.getBody();
        AuthResponse authResult = (AuthResponse) JSON.deserialize(body, AuthResponse.class);
        String refreshToken = authResult.refresh_token;
        String accessToken = authResult.access_token;
        Integer expire = authResult.expires_in;
        cacheSession(accessToken, refreshToken, expire);
        
        return authResult.access_token;
    }

    public static List<SpringCMDocument> createFile(String recordId, String fileName, Blob fileContent) {
        Map<String, Blob> files = new Map<String, Blob>();
        files.put(fileName, fileContent);
        return createFiles(recordId, files);
    }

    public static List<SpringCMDocument> createFiles(String recordId, Map<String, blob> files) {
        SpringCMFolder folder = findOrCreateEosFolder(recordId);
        if(Test.isRunningTest()) return null; 
        List<SpringCMDocument> documents = uploadDocuments(folder, files);
        saveToken();
        return documents;
    }

    /* UTILITIES */
	private static String fixPrefixResponseKeywords(String responseBody) {
		return fixPrefixResponseKeywords(responseBody, 'scm');
    }

	private static String fixPrefixResponseKeywords(String responseBody, String prefix) {
		return responseBody.replaceAll('Limit', prefix + 'Limit');
    }

    /** Upload 1 or many documents within a SpringCM Folder
	 *
	 *  @param {SpringCMFolder} folder - SpringCM Folder to store document
	 *  @param {Map<String, Blob>} documentsToStore - Map of document names and blob
	 *      representation of document to be stored in SpringCM
	 *  @returns {List<SpringCMDocument>} - List of SpringCMDocument objects representing those
	 *      documents requested to be uploaded
	 *  @throws SpringCMException - An error validating file name is missing
	 *  @throws SpringCMException - An error validating no file content was provided
	 *  @throws SpringCMException - An error validating the file is too large for Salesforce to process
	 *  @throws SpringCMException - An error during the request (i.e. network related, SpringCM
	 *      validation such as folder name is duplicate with duplicates turned off, etc.)
	 */
	public static List<SpringCMDocument> uploadDocuments(SpringCMFolder folder, Map<String, Blob> documentsToStore) {
		if (documentsToStore.isEmpty()) return null;

		System.debug('uploadDocuments called for folder:' + folder.CreateDocumentHref);
		String endpoint = folder.CreateDocumentHref.replace('{?name}', '');

		// String boundary = '----------------------------741e90d31eff';
		String boundary = '----------------------------332211223f';
		String footer = '--' + boundary + '--';

		String attachmentsStr = '';
		String lastPrepend = '';
		for (String documentName : documentsToStore.keySet()) {
			Blob fileBlob = documentsToStore.get(documentName);
			if (String.IsBlank(documentName))
				throw new SpringCMException('No document name provided');
			if (fileBlob.size() <= 0)
				throw new SpringCMException('No document or zero byte document provided');
			if (fileBlob.size() > 5242880)
				throw new SpringCMException('Document provided too large for Salesforce upload');
			String fHeader = lastPrepend + '--' + boundary + '\r\n';
			fHeader += String.format('Content-Disposition: form-data; name="files[{0}]"; filename="{0}"\r\nContent-Type: application/octet-stream',
					new String[] { documentName });
			String fHeaderEncoded = EncodingUtil.base64Encode(Blob.valueOf(fHeader + '\r\n\r\n'));
			while (fHeaderEncoded.endsWith('=')) {
				fHeader += ' ';
				fHeaderEncoded = EncodingUtil.base64Encode(Blob.valueOf(fHeader + '\r\n\r\n'));
				}
			String fBodyEncoded = EncodingUtil.base64Encode(fileBlob);
			String last4Bytes = fBodyEncoded.substring(fBodyEncoded.length() - 4, fBodyEncoded.length());
			if (last4Bytes.endsWith('==')) {
				last4Bytes = last4Bytes.substring(0, 2) + '0K';
				fBodyEncoded = fBodyEncoded.substring(0, fBodyEncoded.length() - 4) + last4Bytes;
				lastPrepend = '';
				}
			else if (last4Bytes.endsWith('=')) {
				last4Bytes = last4Bytes.substring(0, 3) + 'N';
				fBodyEncoded = fBodyEncoded.substring(0, fBodyEncoded.length() - 4) + last4Bytes;
				lastPrepend = '\n';
				}
			else {
				lastPrepend = '\r\n';
				}
			attachmentsStr += fHeaderEncoded + fBodyEncoded;
			}
		footer = lastPrepend + footer;
		
		String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
		Blob bodyBlob = EncodingUtil.base64Decode(attachmentsStr + footerEncoded);
		// String strs = EncodingUtil.base64Encode(bodyBlob);
		String contentType = String.format('multipart/form-data; boundary={0}', new String[] { boundary });
		System.debug('#####contentType####' + contentType);
		String responseBody = null;
        if(!Test.isRunningTest()) responseBody = springcmApi.postBlob(bodyBlob, endpoint, contentType);
		
		if (responseBody == null) return null;
		responseBody = !responseBody.startsWith('[') ? String.format('[{0}]', new String[] { responseBody }) : responseBody;
		List<SpringCMDocument> documents = (List<SpringCMDocument>)JSON.deserialize(fixPrefixResponseKeywords(responseBody), Type.forName('List<SpringCMDocument>'));
		return documents;	
    }


    @AuraEnabled
    public static string getFolderURL(String recordId){
        try {
            String folderURL =  findOrCreateEosFolder(recordId).CreateDocumentHref;
            saveToken();
            return folderURL;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static SpringCMFolder findOrCreateEosFolder(String recordId) {
        SpringCLMSetting__mdt api = SpringCMApiEnvironment.getApiEnvironment();
        Map<String,String> keys = new Map<String,String>();
        Map<String,Schema.SobjectType> describe = Schema.getGlobalDescribe();
        for(String s:describe.keyset()) {
            keys.put(describe.get(s).getDescribe().getKeyPrefix(),describe.get(s).getDescribe().getName());
        }
        String prefix = recordId.substring(0,3);
        String sobjectName = keys.get(prefix);
        HttpRequest req= new HttpRequest();
        String token = getAccessToken();
        System.debug('token: ' + token);
        req.setHeader('Authorization','bearer '+token);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', '*/*');
        req.setEndpoint(api.API_URL__c + '/v2/'+api.Account_Id__c+'/folders');
        req.setMethod('POST');
        
        // Query EOS Type configuration
        List<SpringCMEos__EOS_Type__c> eosTypes = [SELECT Id, SpringCMEos__Folder_Name_Format__c, SpringCMEos__Variables__c, 
                                                  SpringCMEos__Path__c, Name 
                                                  FROM SpringCMEos__EOS_Type__c 
                                                  WHERE Name = :sobjectName LIMIT 1];
        
        // Build dynamic query based on required fields
        Set<String> fieldsToQuery = new Set<String>();
        String sName;
        String path;
        SObject record;

        if(!eosTypes.isEmpty()) {
            SpringCMEos__EOS_Type__c eosType = eosTypes[0];
            Set<String> allFields = new Set<String>();
            
            // Add fields from Variables to query
            if(String.isNotBlank(eosType.SpringCMEos__Variables__c)) {
                allFields.addAll(eosType.SpringCMEos__Variables__c.split(','));
            }
            
            // Extract fields from Path if it contains bindings
            if(String.isNotBlank(eosType.SpringCMEos__Path__c)) {
                String pathStr = eosType.SpringCMEos__Path__c;
                Pattern p = Pattern.compile('\\{!(.*?)\\}');
                Matcher m = p.matcher(pathStr);
                while(m.find()) {
                    String field = m.group(1);
                    if(field.contains('.')) {
                        allFields.add(field);
                    }
                }
            }
            
            fieldsToQuery.addAll(allFields);
            
            // Build and execute dynamic query
            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ',') + 
                          ' FROM ' + sobjectName + ' WHERE Id = :recordId';
            
            System.debug('#####Recordid#####' + recordId);
            record = Database.query(query);
            
            // Process folder name format
            if(String.isNotBlank(eosType.SpringCMEos__Folder_Name_Format__c)) {
                String format = eosType.SpringCMEos__Folder_Name_Format__c;
                List<String> fieldNames = eosType.SpringCMEos__Variables__c?.split(',');
                
                // Replace placeholders with field values
                if(fieldNames != null) {
                    for(Integer i = 0; i < fieldNames.size(); i++) {
                        String fieldPath = fieldNames[i].trim();
                        Object fieldValue = record.get(fieldPath.substringAfter('.'));
                        format = format.replace('{' + i + '}', String.valueOf(fieldValue));
                    }
                }
                sName = format;
            }
            
            // Process path
            if(String.isNotBlank(eosType.SpringCMEos__Path__c)) {
                path = eosType.SpringCMEos__Path__c;
                // Replace field bindings in path
                Pattern p = Pattern.compile('\\{!(.*?)\\}');
                Matcher m = p.matcher(path);
                while(m.find()) {
                    String fullMatch = m.group(0);
                    String fieldPath = m.group(1);
                    if(fieldPath.contains('.')) {
                        Object fieldValue = record.get(fieldPath.substringAfter('.'));
                        path = path.replace(fullMatch, String.valueOf(fieldValue));
                    }
                }
            }
        }
        
        // Fallback to default behavior if no EOS Type found or format processing failed
        if(String.isBlank(sName)) {
            String query = 'SELECT Id, ' + (sobjectName == 'Case' ? 'CaseNumber' : 'Name') + 
                          ' FROM ' + sobjectName + ' WHERE Id = :recordId';
            record = Database.query(query);
            sName = (String) record.get(sobjectName == 'Case' ? 'CaseNumber' : 'Name');
        }

        // SpringCM needs complete ID characters
        if(recordId.length() < 18){
            String query = 'SELECT Id FROM ' + sobjectName + ' WHERE Id = :recordId';
            record = Database.query(query);
            recordId = (String) record.get('Id');
        }
        
        EOSFeed feed = new EOSFeed();
        feed.EosInfo = new EOSINFO();
        feed.EosInfo.ObjectId = recordId;
        feed.EosInfo.Name = sName;
        feed.EosInfo.Path = path;
        feed.EosInfo.ObjectType = 'Salesforce.'+sobjectName;
        req.setBody(JSON.serialize(feed));

        Http h = new Http();
        HttpResponse res;
        if(Test.isrunningTest()) {
            res = new HttpResponse();
            res.setBody('{"Items": [{"Name":"'+sobjectName+'", "CreateDocumentHref":"https://www.testFileLInk.com"}]}');
        } else {
            res = h.send(req);
        } 
        String str = res.getBody();
        
        SpringCMFolder result = (SpringCMFolder)JSON.deserialize(str, SpringCMFolder.class);

        
        // If error caused by an existing folder; get existing folder
        if((result == null || result.CreateDocumentHref == null)){
            req.setEndpoint(api.API_URL__c + '/v2/'+api.Account_Id__c+'/folders/eos?eosObjectType=Salesforce.' + sobjectName + '&eosObjectId=' + recordId);
            req.setMethod('GET');
            
            if(!Test.isrunningTest()) res = h.send(req);
            if(!Test.isrunningTest()) str = res.getBody();        
            result = (SpringCMFolder)JSON.deserialize(str, SpringCMFolder.class);
        }
            
        
        return result;
    }

    public static void saveToken() {
        List<SpringCLM_Session__c> sessions = [Select Id, RefreshToken__c, AccessToken__c from SpringCLM_Session__c];
        SpringCLM_Session__c session = new SpringCLM_Session__c();
        if(!sessions.isEmpty()) {
            session = sessions.get(0);
        }
        session.RefreshToken__c = refreshToken;
        session.AccessToken__c = accessToken;
        upsert session;
    }

    public static HttpResponse updateFileDescription(String fileURL, String descString) {
        String accesstoken = getAccessToken();
        Map<String, String> params = new Map<String, String>();
        
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization','bearer '+accesstoken);
        req.setEndpoint(fileURL);
        req.setMethod('PUT');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        params.put('Description', descString);
        
        Http h = new Http();
        req.setBody(JSON.serialize(params));

        HttpResponse res;
        if(Test.isRunningTest() ) {
            res = new HttpResponse();
        } else {
            res = h.send(req);
        }
        saveToken();
        return res;
    }

    @AuraEnabled
    public static Boolean updateDescription(String fileURL, String des) {
        HttpResponse res = updateFileDescription(fileURL, des);
        Integer state = res.getStatusCode();
        if(state == 200 || state == 201) {
            return true;
        } else {
            return false;
        }
    }

    public class EOSFeed {
        public EOSINFO EosInfo;
    }
    
    public class EOSINFO {
        public String ObjectType;
        public String ObjectId;
        public String Name;
        public String Path;
    }
    
    public static String getFolderUploadLink(String folderName) {
        HttpRequest req= new HttpRequest();
        String token = getAccessToken();
        req.setHeader('Authorization','bearer '+token);
        req.setHeader('Accept', '*/*');
        req.setEndpoint('https://apiuatna11.springcm.com/v2/folders?search='+ EncodingUtil.URLEncode(folderName, 'UTF-8'));
        req.setMethod('GET');
        Http h = new Http();
        HttpResponse res;
        if(Test.isrunningTest()) {
            res = new HttpResponse();
            res.setBody('{"Items": [{"Name":"'+folderName+'", "CreateDocumentHref":"https://www.testFileLInk.com"}]}');
        } else {
            res = h.send(req);
        } 
        String str = res.getBody();
        SpringFeed.FolderResult result = (SpringFeed.FolderResult)JSON.deserialize(str, SpringFeed.FolderResult.class);
        List<SpringFeed.Folder> folders = result.Items;
        SpringFeed.Folder record = new SpringFeed.Folder();
        for(SpringFeed.Folder folder: folders) {
            if(folder.Name == folderName) {
                record = folder;
                break; 
            }
        }
        return record.CreateDocumentHref;
    }

    //add by Chris Zhuang 08/24/2020
    public static void deletListBuilderFiles(String recordId) {
        //query folder by record Id
        SpringCMFolder folder = findOrCreateEosFolder(recordId);

        //now query the list of documents
        HttpRequest req = new HttpRequest();
        String token = getAccessToken();
        req.setHeader('Authorization','bearer '+token);
        req.setHeader('Accept', '*/*');
        if(!Test.isRunningTest()) {
            req.setEndpoint(folder.Documents.Href);    
        } else {
            req.setEndpoint('https://test.salesfor.com');    
        }
        
        req.setMethod('GET');
        Http h = new Http();
        HttpResponse res;
        if(Test.isRunningTest()) {
            res = new HttpResponse();
        } else {
            res = h.send(req);
        }
        String str = res.getBody();
        System.debug('######str####' + str);

        //now delete those files
        List<String> deleteDoc_L = new List<String>();
        SpringCMDocumentItem documents = new SpringCMDocumentItem();
        if(Test.isRunningTest() ) {
            str = '{"Items": []}';
        }
        documents = (SpringCMDocumentItem)JSON.deserialize(str, SpringCMDocumentItem.class);    
        
        
        for(SpringCMDocument doc : documents.Items) {
            if (doc.Description == 'PVL - List Builder Generation') {
                deleteDoc_L.add(doc.Href);
            }
        }
        for (String s : deleteDoc_L) {
            deleteFile(s);
        }
        saveToken();
    }

    public static HttpResponse deleteFile(String url) {
        String token = getAccessToken();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization','bearer '+token);
        req.setHeader('Accept', '*/*');
        req.setMethod('DELETE');
        req.setEndpoint(url);

        Http h = new Http();
        HttpResponse res = new HttpResponse();
        if(!Test.isRunningTest() ) {
            res = h.send(req);
        }
        return res;
    }

    @AuraEnabled
    public static Boolean deleteDocument(String url) {
        HttpResponse res = deleteFile(url);
        saveToken();
        if(res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return true;
        } else {
            return false;
        }
    }

    @future(callout=true)
    public static void updateFilesAndFolderAsync(List<String> fileURLs, String recordId) {
        updateFilesAndFolder(fileUrls, recordId);
    }

    @AuraEnabled
    public static String updateFileDesAndFolder(String fileURL, String desString, String recordId) {
        CMDocument doc = new CMDocument();
        doc.Description = desString;
        doc.ParentFolder = new SpringCMFolder();
        doc.ParentFolder.Href = getFolder(recordId).Href;
        HttpResponse res = updateFileInfo(fileURL, doc);
        System.debug('###res###' + res.getBody());
        saveToken();
        return res.getBody();
    }

    @AuraEnabled
    public static void updateFilesAndFolder(List<String> fileURLs, String recordId) {
        String parentFolderHref = getFolder(recordId).Href;
        for(String fileURL: fileURLs) {
            CMDocument doc = new CMDocument();
            doc.ParentFolder = new SpringCMFolder();
            doc.ParentFolder.Href = parentFolderHref;
            HttpResponse res = updateFileInfo(fileURL, doc);
            System.debug('###res###' + res.getBody());
        }
        saveToken();
    }

    public static HttpResponse updateFileInfo(String fileURL, CMDocument doc) {
        String accesstoken = getAccessToken();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization','bearer '+accesstoken);
        req.setEndpoint(fileURL);
        req.setMethod('PUT');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        Http h = new Http();
        req.setBody(JSON.serialize(doc));
        HttpResponse res;
        if(Test.isRunningTest() ) {
            res = new HttpResponse();
        } else {
            res = h.send(req);
        }
        return res;
    }

    public static SpringCMFolder getFolder(String recordId) {
        return findOrCreateEosFolder(recordId);
    }
}