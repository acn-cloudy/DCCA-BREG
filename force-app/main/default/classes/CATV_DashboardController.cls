public with sharing class CATV_DashboardController {
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [SELECT Id, Name FROM Account WHERE Type = 'Provider' ORDER BY Name];
    }

    @AuraEnabled
    public static List<INET_Request__c> fetchINETRequestData(String account, String searchTerm){
    
    String searchKey = '%' + (searchTerm == null ? '' : searchTerm) + '%';
       return [SELECT Id, Name, INET_Request_Number__c,Address__c, Approval_Status__c, Approval_Comments__c, City__c, Completed_Date__c, 
              Island__c, Provider__c, Provider__r.Name, Provider_Contact_Name__c, Provider_Contact_Name__r.Name, Provider_Contact_Name__r.Email, 
              Provider_Contact_Name__r.Phone, Quote_Subtype__c, Rejection_Comments__c, Request_Date__c, Requestor__c, Requestor__r.Name, 
              Requestor_Contact_Name__c, Requestor_Contact_Name__r.Name, Requestor_Contact_Name__r.Email,  Requestor_Contact_Name__r.Phone,
              Site_Name__c, Sow_Needed__c, State__c, Status__c, Target_Date__c, Work_Completed_Date__c, Work_Start_Date__c, Zip_Code__c, IROC_Id__c, 
              Permit_Status__c, Projected_Deployment_Date__c, Scheduled_Deployment_Date__c, Deployment_Start_Date__c, Mileage__c
              FROM INET_Request__c WHERE (Provider__c =: account OR Requestor__c =: account) AND Status__c != 'Cancelled' 
              AND (Name LIKE :searchKey OR INET_Request_Number__c LIKE :searchKey) 
              WITH USER_MODE ORDER BY LastModifiedDate DESC]; 
    }
    
    @AuraEnabled
    public static void updateRequestStatus(Id requestId, String subtype, String status){
        INET_Request__c inetrequestRecord = new INET_Request__c(Id = requestId,  Quote_Subtype__c = subtype, Status__c = status);
        update as user inetrequestRecord;
    }
    
    @AuraEnabled
    public static void updateQuote(Id quoteId, String status, String rejectionReason){
        Quotes__c quoteRecord = new Quotes__c(Id = quoteId, Status__c = status);
    
        if (String.isNotBlank(rejectionReason)) {
            quoteRecord.Rejection_Reason__c = rejectionReason;
        }

        if(status == 'Accepted'){
            quoteRecord.Quote_Accepted_Date__c = Date.today();
        }

        update as user quoteRecord;
    }
    
    @AuraEnabled
    public static void updateInvoice(Id requestId){
        List<Invoice__c> updateInvoiceRecords = new List<Invoice__c>();
        List<Invoice__c> invoiceList =  fetchInvoiceData(requestId);
        for(Invoice__c invoiceRecord : invoiceList){
            if(!invoiceList.IsEmpty()){
                Invoice__c invoice = new Invoice__c(Id = invoiceRecord.Id,  Status__c = 'Paid', Invoice_Paid_Date__c = Date.today());
                updateInvoiceRecords.add(invoice);
            }
        }
        
        update as user updateInvoiceRecords;
    }
  
    @AuraEnabled
    public static List<Quotes__c> fetchQuoteData(Id requestId){
        return [SELECT Id, Name, Description__c, Status__c, Submitted_Date__c, Amount__c, 
           Quote_Accepted_Date__c, Rejection_Reason__c,
           INET_Request__r.Name, Provider__r.Name, Requestor__r.Name, INET_Request__r.INET_Request_Number__c
           FROM Quotes__c WHERE INET_Request__c =: requestId WITH USER_MODE ORDER BY CreatedDate DESC NULLS LAST];
    }
    
    @AuraEnabled
    public static List<Purchase_Order__c> fetchPurchaseData(Id requestId){
        String query = 'SELECT Id, Name, PO_Amount__c, PO_Date__c, PO_Submitted_Date__c, Provider__c, Quote__c, Requestor__c, INET_Request__c FROM Purchase_Order__c';
        if(requestId != null){
            query = query + ' WHERE INET_Request__c ='+'\''+requestId +'\' WITH USER_MODE ORDER BY LastModifiedDate DESC';
        }
        return Database.query(query);
    }
    
    @AuraEnabled
    public static List<Invoice__c> fetchInvoiceData(Id requestId){
        String query = 'SELECT Id, Name, Invoice_Amount__c, Invoice_Date__c, Status__c, Invoice_Paid_Date__c, INET_Request__c FROM Invoice__c';
        if(requestId != null){
            query = query + ' WHERE INET_Request__c ='+'\''+requestId +'\' WITH USER_MODE ORDER BY LastModifiedDate DESC';
        }
        return Database.query(query);
    }
    
    @AuraEnabled
    public static void changeOwnerToQueue(Id recordId) {
        INET_Request__c request = [SELECT Id, OwnerId FROM INET_Request__c WHERE Id = :recordId];
        Group queue = [SELECT Id, Name, DeveloperName, Type FROM Group WHERE Type = 'Queue' AND DeveloperName = 'CATV_Staff_Reviewers'];
        if(queue != null){
        	request.OwnerId = queue.Id;
        }
        update as user request;
    }

    @AuraEnabled
    public static String uploadFile(String recordId, String fileName, String fileContent, String recObjectName) {
        try {
            Blob fileContentBlob = Test.isRunningTest() ? Blob.valueOf('test') : EncodingUtil.base64Decode(fileContent);
            String fileStatus;
            List<SpringCMDocument> fileResult = new List<SpringCMDocument>();
            if(Test.isRunningTest()){
            	SpringCMDocument springDoc = new SpringCMDocument();
                springDoc.DownloadDocumentHref = 'https://test.com';
                fileResult.add(springDoc);
            }
            else{
                fileResult = SpringCMConnector.createFile(recordId, fileName, fileContentBlob);
            }
            if(fileResult.size() > 0){
                fileStatus = 'success';

                Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(recObjectName);

                if (sObjType != null) {
                    SObject recordToUpdate = sObjType.newSObject(recordId);

                    recordToUpdate.put('Document_Href__c', fileResult[0].DownloadDocumentHref);

                    try {
                        update recordToUpdate;
                    } catch (DmlException e) {
                        System.debug('Error updating record: ' + e.getMessage());
                    }
                }
            }
            return fileStatus;
        } catch (Exception e) {
            System.debug(e);
            return null;
        }
    }

    @AuraEnabled
    public static Map<String, String> getFileContent(String recordId, String objectName){
        try {

            String query = 'SELECT Id, Document_Href__c FROM ' + objectName + ' WHERE Id =: recordId';
            SObject record = Database.query(query);

            SpringCMApiManager springcmApi = new SpringCMApiManager();
            String endPoint = (String)record.get('Document_Href__c');

            if(String.isNotBlank(endPoint)){
                Map<String, String> result = new Map<String, String>();
                String myString = 'This is the test content for my PDF document.';
                String docname = 'Test3.pdf';
                Blob content = Test.isRunningTest() ? Blob.valueOf('test') : springcmApi.getBlob(endPoint, 'application/pdf');

                result.put('base64Content', Test.isRunningTest() ? 'test' : EncodingUtil.base64Encode(content));
                result.put('fileName',docname);
                return result;
            }
            else{
                throw new CATV_Exception('No file to Preview!');
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRejectionReasons() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            
            Schema.DescribeFieldResult fieldResult = Quotes__c.Rejection_Reason__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
            for(Schema.PicklistEntry f : ple) {
                if(f.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', f.getLabel());
                    option.put('value', f.getValue());
                    options.add(option);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving picklist: ' + e.getMessage());
        }
        return options;
    }
}