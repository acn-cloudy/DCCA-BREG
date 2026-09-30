/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for GenericCreatePayment component
* Wizard to create a filing, transaction and payment
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* PacPoint-RdG240220 - Updated for Case 6778
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class GenericCreatePaymentCtrl 
{
    public static Map<String, Schema.SObjectField> fMap { get; set; }
    
    @AuraEnabled
    public static Response getNecessaryInfoFromServer(String filingId)
    {
        Response serverResponse = new Response();
        
        List<Filing__c> filingList =
            [
                SELECT Id, ApplicationType__c, ShowPaymentButton__c, ShowUploadButton__c, RecordType.Name,
                (
                    SELECT Id
                    FROM Payments__r
                    ORDER BY CreatedDate
                )
                FROM Filing__c
                WHERE Id = :filingId
                LIMIT 1
            ]; 
        
        if(filingList.size() == 0)
        {
            serverResponse.errorMessage = 'No Filing records were found for the given record Id!'; 
            return serverResponse;           
        }
        else
        {
            serverResponse.filingRecordType = filingList[0].RecordType.Name;
            serverResponse.filingId = filingId;
            serverResponse.applicationType = filingList[0].ApplicationType__c;
            
            // if this filing has a payment linked to it
            if(filingList[0].Payments__r.size() > 0)
            {
                serverResponse.paymentId = filingList[0].Payments__r[0].Id;
            }
        }
        
        List<FlowperRecordType__mdt> flowPerRecordTypeList =
            [
                SELECT Id, Account__c, ApplicationType__c, AccountNameLabel__c, ButtonNameLabel__c,  CreateAccount__c, DisplayFilesScreen__c, DisplayPayment__c, FilingRecordType__c, PersonAccount__c
                FROM FlowperRecordType__mdt
                WHERE ApplicationType__c = :serverResponse.applicationType
                AND FilingRecordType__c = :serverResponse.filingRecordType
            ];
        
        if(flowPerRecordTypeList.size() == 0)
        {
            serverResponse.errorMessage = 'No \'FlowperRecordType\' records were found for the given application and record type!';  
            return serverResponse;          
        }
        else
        {            
            serverResponse.displayPayment = flowPerRecordTypeList[0].DisplayPayment__c;
            serverResponse.accountNameLabel = flowPerRecordTypeList.get(0).AccountNameLabel__c;
            serverResponse.buttonNameLabel = flowPerRecordTypeList.get(0).ButtonNameLabel__c;
        }
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static Response getInitialDataFromServer(String filingRecordType)
    {
        Response serverResponse = new Response();
        
        List<FlowperRecordType__mdt> flowPerRecordTypeList =
            [
                SELECT Id, ApplicationType__c, AccountNameLabel__c, ButtonNameLabel__c
                FROM FlowperRecordType__mdt
                WHERE FilingRecordType__c = :filingRecordType
            ];
        
        if(flowPerRecordTypeList.size() == 0)
        {
            serverResponse.errorMessage = 'No \'FlowperRecordType\' records were found for the given record type!';            
        }
        else
        {
            for(FlowperRecordType__mdt flowperRecordType : flowPerRecordTypeList)
            {
                serverResponse.availableApplicationTypeList.add(flowperRecordType.ApplicationType__c);
            }
            serverResponse.accountNameLabel = flowPerRecordTypeList.get(0).AccountNameLabel__c;
            serverResponse.buttonNameLabel = flowPerRecordTypeList.get(0).ButtonNameLabel__c;
        }
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static Response getUploadedFilesperRecordTypeFromServer(String applicationType, String filingRecordType)
    {
        Response serverResponse = new Response();
        
        List<UploadedFilesperRecordType__mdt> allUploadedFilesperRecordTypeList =
            [
                SELECT Id, FilingRecordType__c, New__c, Amendment__c, Renewal__c, DocumentUpload__c, Required__c, FileDetailsType__c, Category__c, Group__c, Order__c
                FROM UploadedFilesperRecordType__mdt
                WHERE FilingRecordType__c = :filingRecordType
                ORDER BY Order__c ASC
            ];
        
        List<FileUploadWrapper> uploadedFilesWrapperList = new List<FileUploadWrapper>();
        
        for(UploadedFilesperRecordType__mdt uploadedFilesperRecordType : allUploadedFilesperRecordTypeList)
        {
            Boolean foundApplicationType = false;
            
            if(applicationType == 'New' && uploadedFilesperRecordType.New__c == true)
            {
                foundApplicationType = true;
            }
            else if(applicationType == 'Amendment' && uploadedFilesperRecordType.Amendment__c == true)
            {
                foundApplicationType = true;
            }
            else if(applicationType == 'Renewal' && uploadedFilesperRecordType.Renewal__c == true)
            {
                foundApplicationType = true;
            }
            else if(applicationType == 'Document Upload' && uploadedFilesperRecordType.DocumentUpload__c == true)
            {
                foundApplicationType = true;
            }
            
            if(foundApplicationType == true)
            {
                FileUploadWrapper fileUploadWrapper = new FileUploadWrapper();
                fileUploadWrapper.fileDetails = uploadedFilesperRecordType.FileDetailsType__c;
                fileUploadWrapper.isRequired = uploadedFilesperRecordType.Required__c;
                fileUploadWrapper.fileCategory = uploadedFilesperRecordType.Category__c;
                fileUploadWrapper.uploadGroup = uploadedFilesperRecordType.Group__c;
                
                uploadedFilesWrapperList.add(fileUploadWrapper);
            }
        }        
        
        if(uploadedFilesWrapperList.size() == 0)
        {
            serverResponse.errorMessage = 'No \'UploadedFilesperRecordType\' records were found for the given application and record type!';            
        }
        else
        {
            serverResponse.uploadedFilesWrapperList = uploadedFilesWrapperList;
        }
        
        return serverResponse;
    }

    @future(CallOut= true)
    public static void moveFileFolderAndUpdateDescription(List<String> fileDetailIds) {
        List<FileDetails__c> files = [Select Id, Description__c, Filing__c, FileUrl__c, Response__c from FileDetails__c where Id =: fileDetailIds];
        for(FileDetails__c record: files) {
            record.Response__c = SpringCMConnector.updateFileDesAndFolder(record.FileUrl__c, record.Description__c, record.Id);
        }
        update files;
    }
    
    @AuraEnabled
    public static Response saveAfterUploadOnServer(String serverResponseString)
    {
        Response serverResponse = new Response();
        
        Response clientRequest = (Response)JSON.deserialize(serverResponseString, Response.class);
        
        try
        { 
            List<FileDetails__c> fileDetailList = new List<FileDetails__c>();
            Map<String, String> contentDocumentIdToFileDetailId = new Map<String, String>();
            Set<String> contentDocumentIdSet = new Set<String>();
            
            for(FileUploadWrapper uploadedFileWrapper : clientRequest.uploadedFilesWrapperList)
            {
                
                // to remove it from the file content document but connect with File links.
                // only insert records that have an uploaded file linked to them
                if(String.isNotEmpty(uploadedFileWrapper.contentDocumentId) 
                    || String.isNotEmpty(uploadedFileWrapper.fileUrl) )
                { 
                    FileDetails__c newFileDetail = new FileDetails__c();
                    newFileDetail.FileUrl__c =  uploadedFileWrapper.fileUrl;
                    newFileDetail.ContentDocumentId__c = uploadedFileWrapper.contentDocumentId;
                    newFileDetail.ContentDocumentTitle__c = uploadedFileWrapper.uploadedFileName;
                    newFileDetail.Filing__c = clientRequest.filingId;
                    if(!String.isBlank(uploadedFileWrapper.fileDescription)) {
                        uploadedFileWrapper.fileDescription 
                            = uploadedFileWrapper.fileDetails + 
                                '-' + uploadedFileWrapper.fileDescription;
                    } else {
                        uploadedFileWrapper.fileDescription = uploadedFileWrapper.fileDetails;
                    }
                    newFileDetail.Description__c = uploadedFileWrapper.fileDescription;
                    newFileDetail.Category__c = uploadedFileWrapper.fileCategory;
                    newFileDetail.Type__c = uploadedFileWrapper.fileDetails;
                    newFileDetail.DateReceived__c = Date.today();
                    fileDetailList.add(newFileDetail);
                    if(uploadedFileWrapper.contentDocumentId != null) 
                        contentDocumentIdSet.add(uploadedFileWrapper.contentDocumentId);
                }
            }
            
            if(fileDetailList.size() > 0)
            {
                insert fileDetailList;
                List<String> fileDetailIds = new List<String>();
                // create the fileDetails map
                for(FileDetails__c fileDetail : fileDetailList)
                {
                    if(fileDetail.ContentDocumentId__c != null) {
                        contentDocumentIdToFileDetailId.put(fileDetail.ContentDocumentId__c, fileDetail.Id);
                    }
                    if(fileDetail.FileUrl__c != null) {
                        fileDetailIds.add(fileDetail.Id);
                        moveFileFolderAndUpdateDescription(new List<String>{fileDetail.Id});
                    }
                } 
                
                // get all the files uploaded to the current filing record
                List<ContentDocumentLink> contentDocumentLinkList =
                    [
                        SELECT Id, LinkedEntityId, ContentDocumentId
                        FROM ContentDocumentLink
                        WHERE ContentDocumentId IN :contentDocumentIdSet
                    ];   
                
                List<ContentDocumentLink> contentDocumentLinkListToCreate = new List<ContentDocumentLink>();
                
                // this set is used to replicate the links only ONCE
                Set<String> usedContentDocumentIds = new Set<String>();
                
                // link the file to the fileDetail and not to the current filing record
                for(ContentDocumentLink contentDocumentLink : contentDocumentLinkList)
                {
                    if(contentDocumentIdToFileDetailId.get(contentDocumentLink.ContentDocumentId) != null && !usedContentDocumentIds.contains(contentDocumentLink.ContentDocumentId))
                    {
                        ContentDocumentLink newContentDocumentLink = new ContentDocumentLink();
                        newContentDocumentLink.LinkedEntityId = contentDocumentIdToFileDetailId.get(contentDocumentLink.ContentDocumentId);
                        newContentDocumentLink.ContentDocumentId = contentDocumentLink.ContentDocumentId; 
                        newContentDocumentLink.ShareType = 'I'; 
                        
                        contentDocumentLinkListToCreate.add(newContentDocumentLink);
                        usedContentDocumentIds.add(contentDocumentLink.ContentDocumentId);
                    }
                }  
                
                //delete contentDocumentLinkList;  
                if(!contentDocumentLinkListToCreate.isEmpty()) {
                    insert contentDocumentLinkListToCreate;
                }
            }
            
            List<Filing__c> currentFilingList =
                [
                    SELECT Id, AllDocumentsUploaded__c
                    FROM Filing__c
                    WHERE Id = :clientRequest.filingId
                    LIMIT 1
                ];
            
            // if the current filing was found
            if(currentFilingList.size() > 0)
            {
                currentFilingList[0].AllDocumentsUploaded__c = true;
                
                update currentFilingList[0];
            }
        }
        catch(Exception e)
        {
            serverResponse.errorMessage = e.getMessage();
        }
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static Response saveRecordsOnServer(String serverResponseString, String filingRecordType, String applicationType)
    {
        Response serverResponse = new Response();
        
        Response clientRequest = (Response)JSON.deserialize(serverResponseString, Response.class);
        
        User currentUser = 
            [
                SELECT Id, ContactId, Contact.AccountId, Division__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            Profile currentUserProfile =
            [
                SELECT Name from Profile where Id =: UserInfo.getProfileId() LIMIT 1
            ];
            String currentUserProfileName = currentUserProfile.Name;

        try
        { 
            Account filingAccount = new Account(); 
            
            // if the user created a new Account, insert it
            if(clientRequest.newAccountCreated == true)
            {
                String businessAccountId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
                String personAccountId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
                
                filingAccount = clientRequest.createdAccount;
                // because Salesforce don't allow community user to create accounts, we must hardCode the owner Id to a system user.
                filingAccount.OwnerId = Label.UserIdForGenericCreatePayment;
                filingAccount.SEBSEC__c = true;
                if(clientRequest.isPersonAccount == true)
                {
                    filingAccount.RecordTypeId = personAccountId;
                }
                else
                {
                    filingAccount.RecordTypeId = businessAccountId;
                }
                
                insert filingAccount;
            }
            // if the user searched and found an existing account, use that account
            else
            {
                filingAccount = clientRequest.searchedAccount;
            }
            
            serverResponse.filingAccountId = filingAccount.Id;
            
            String recordTypeId = Schema.SObjectType.Filing__c.getRecordTypeInfosByName().get(filingRecordType).getRecordTypeId();
            
            // get the filing with the user inserted values
            Filing__c newFiling = clientRequest.newFiling;
            newFiling.RecordTypeId = recordTypeId;
            newFiling.Account__c = filingAccount.Id;
            newFiling.FilerAccount__c = currentUser.Contact.AccountId;
            newFiling.FilerContact__c = currentUser.ContactId; 
            newFiling.ApplicationType__c = applicationType;
            System.debug('###newFiling####' + newFiling);
            insert newFiling;
            
            serverResponse.filingId = newFiling.Id;
            
            if (clientRequest.displayPayment) {
                // create a transaction record
                Transaction__c newTransaction = new Transaction__c();
                newTransaction.Account__c = currentUser.Contact.AccountId;
                newTransaction.Contact__c = currentUser.ContactId;
                
                // the user's divison__c field is a multiselect field while the transaction one is a simple picklist
                // thus to avoid errors, we take just the first selected divison from the user
                if(currentUser.Division__c != null && currentUser.Division__c != '')
                {
                    if((currentUser.Division__c).split(';').size() == 1)
                    {
                        newTransaction.Division__c = currentUser.Division__c;
                    }
                    else
                    {
                        newTransaction.Division__c = (currentUser.Division__c).split(';')[0];
                    }
                }
                
                newTransaction.Status__c = 'New';
                newTransaction.Date__c = Date.today();
                newTransaction.TransactionType__c = 'Payment';
                newTransaction.Filing__c = newFiling.Id;
             	//added for case 26254
                 if(currentUserProfileName =='Customer Community Login User' || currentUserProfileName == 'DCCA BREG - CustomerCommunityLogin'){
                    newTransaction.Account__c = filingAccount.Id;
                    insert newTransaction;
                }
                // create a transaction line record
                List<Filing__c> createdFiling = 
                    [
                        SELECT Id, CashierCode__r.Amount__c, Amount__c
                        FROM Filing__c 
                        WHERE Id = :newFiling.Id
                        LIMIT 1
                    ];
                
                TransactionLine__c newTransactionLine = new TransactionLine__c();
                newTransactionLine.CashierCode__c = newFiling.CashierCode__c;
                
                if(createdFiling.size() > 0 && createdFiling[0].Amount__c != null)
                {
                    newTransactionLine.Amount__c = createdFiling[0].Amount__c;
                }
                
                newTransactionLine.Transaction__c = newTransaction.Id;
                insert newTransactionLine;
                
                // create a payment record
                pymt__PaymentX__c newPayment = new pymt__PaymentX__c();
                newPayment.Name = filingRecordType;
                newPayment.Transaction__c = newTransaction.Id;
                
                if(createdFiling.size() > 0 && createdFiling[0].Amount__c != null)
                {
                    newPayment.pymt__Amount__c = createdFiling[0].Amount__c;
                }
                
                newPayment.pymt__Contact__c = currentUser.ContactId;
                newPayment.pymt__Account__c = currentUser.Contact.AccountId;
                newPayment.pymt__Currency_ISO_Code__c = 'USD';
                insert newPayment; 
                
                serverResponse.paymentId = newPayment.Id;
            }
        }
        catch(Exception e)
        {
            serverResponse.errorMessage = e.getMessage();
        }
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static Response getFilingMetadataInfoFromServer(String flowperRecordTypeId)
    {
        Response serverResponse = new Response();
        
        List<FieldsperRecordType__mdt> fieldsPerRecordTypeList =
            [
                SELECT Id, FieldAPIName__c, DefaulValue__c, Editable__c, FieldLabel__c, Required__c
                FROM FieldsperRecordType__mdt
                WHERE RecordType__c = :flowperRecordTypeId
                AND FieldAPIName__c <> null
                AND FieldLabel__c <> null
                ORDER BY Order__c ASC
            ];
        
        /*if(fieldsPerRecordTypeList.size() == 0)
{
serverResponse.errorMessage = 'No \'FieldsperRecordType\' records were found!';
}
else
{ */
        List<CustomFieldWrapper> filingFieldsWrapperList = new List<CustomFieldWrapper>();
        
        for(FieldsperRecordType__mdt fieldsPerRecordType : fieldsPerRecordTypeList)
        {
            CustomFieldWrapper filingFieldWrapper = new CustomFieldWrapper(fieldsPerRecordType.FieldAPIName__c, 'Filing__c', fieldsPerRecordType.DefaulValue__c, fieldsPerRecordType.Editable__c, fieldsPerRecordType.FieldLabel__c, fieldsPerRecordType.Required__c);
            
            filingFieldsWrapperList.add(filingFieldWrapper);
        }
        
        serverResponse.filingFieldsWrapperList = filingFieldsWrapperList;
        //}
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static Response getAccountLayoutInfoFromServer(Boolean isPersonAccount, Boolean isBusinessAccount)
    {
        Response serverResponse = new Response();
        String layoutName = '';
        String sObjLayoutName = '';
        String sObjName = 'Account';
        
        // if it's person Account
        if(isPersonAccount == true && isBusinessAccount == false)
        {
            layoutName = 'Person Account Layout - Community Create';
            sObjLayoutName = 'PersonAccount';
        }
        // if it's business Account
        else if(isPersonAccount == false && isBusinessAccount == true)
        {
            layoutName = 'Account Layout - Community Create';
            sObjLayoutName = 'Account';
        }
        
        serverResponse.layoutWrapper = GetLayout(sObjName, layoutName, sObjLayoutName);
        
        return serverResponse;
    }
    
    @AuraEnabled
    public static LayoutWrapper GetLayout(String sObjName, String layoutName, String sObjLayoutName) 
    {       
        fMap = Schema.getGlobalDescribe().get(sObjName.toLowerCase()).getDescribe().Fields.getMap();
        
        List<String> componentNameList = new List<String>{ sObjLayoutName + '-' + layoutName };
            List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, componentNameList);
        
        LayoutWrapper layoutWrapper = new LayoutWrapper((Metadata.Layout)components.get(0));
        
        return layoutWrapper;
    }
    
    @AuraEnabled
    public static Response searchPersonAccountsFromServer(String firstName, String lastName, String email)
    {       
        Response serverResponse = new Response();
        
        List<Account> accountList = [
            SELECT Id, FirstName, LastName, PersonEmail
            FROM Account
            WHERE FirstName = :firstName
            AND LastName = :lastName
            AND PersonEmail = :email
            AND IsPersonAccount = true
            AND SEBSEC__c= true
        ];
        
        if(accountList.size() > 0)
        {
            serverResponse.foundAccount = true;
            serverResponse.searchedAccount = accountList[0];
        }
        else
        {
            serverResponse.foundAccount = false;
        }
        
        return serverResponse;
    }
    public static String getQuery(Boolean isSeparete, String accountName, String accountCRD, String accountDBA, String streetName) {
        List<String> queries = new List<String>();
        String streetNameSearch = '%' + streetName + '%';
        String query = 'SELECT Id, Name, BillingStreet,DBA__c FROM Account WHERE ';
        if(isSeparete) {
            string accountNameWhere = '';
            for(String nameValue : accountName.split(' ')){
                accountNameWhere += (accountNameWhere == '' ? '' : ' OR ') + 'Name LIKE \'%'+nameValue+'%\' ';
            }
            query +=' ('+accountNameWhere+') ';
        } else {
            
            query +=' Name LIKE \'%'+accountName+'%\' ';
        }
        if (accountCRD != null && accountCRD.trim() != ''){
            queries.add('CRD__c = :accountCRD');
        }
        
        if (accountDBA != null && accountDBA.trim() != ''){
            string dbaClause = '';
            for(String dbaVal : accountDBA.split(' ')){
                dbaClause += (dbaClause == '' ? '' : ' OR ') + 'DBA__c LIKE \'%'+dbaVal+'%\' ';
            }
            queries.add('('+dbaClause+')');
            //queries.add('DBA__c = :accountDBA');
    	}
            
        
        if (streetName != null && streetName.trim() != ''){
            queries.add('BillingStreet LIKE \'%'+streetName+'%\' ');
        }
        
        if(queries.size() > 0){ //PacPoint-RdG240220 - Updated for Case 6778
            query += 'AND (' +String.join(queries, ' OR ') +')';
        }
        query+=  ' AND IsPersonAccount = false AND SEBSEC__c= true';
        
        return query;
    }
    @AuraEnabled
    public static Response searchBusinessAccountsFromServer(String accountName, String accountCRD, String accountDBA, String streetName)
    {
        Response serverResponse = new Response();
        
        // Remove leading digits
        while (streetName != null && streetName.length() > 0 && streetName.substring(0, 1).isNumeric())
            streetName = streetName.substring(1);
        if (streetName != null)
            streetName = streetName.trim();
        
        String query = getQuery(false, accountName, accountCRD, accountDBA, streetName);
        
        List<Account> accountList = Database.query(query);
        if(accountList.isEmpty()) {
            query = getQuery(true, accountName, accountCRD, accountDBA, streetName);
            accountList = Database.query(query);
        }
        if(accountList.size() > 0)
        {
            serverResponse.foundAccount = true;
            serverResponse.searchedAccount = accountList[0];
            serverResponse.searchedAccounts = accountList;//Updated PacPoint
        }
        else
        {
            serverResponse.foundAccount = false;
        }
        
        return serverResponse;
    }
    
    //PacPoint-RdG240220 - Updated for Case 6778
    @AuraEnabled
    public static Account getAccountRecord(String accountId)
    {
        Account acc = [SELECT Id, Name, BillingStreet, DBA__c FROM Account WHERE Id =: accountId];
        return acc;
    }
    
    @AuraEnabled
    public static Response getMetadataInfoFromServer(String applicationType, String filingRecordType)
    {
        Response serverResponse = new Response();
        
        List<FlowperRecordType__mdt> flowPerRecordTypeList =
            [
                SELECT Id, Account__c, ApplicationType__c, AccountNameLabel__c,FirstNameLabel__c, LastNameLabel__c, ButtonNameLabel__c, CreateAccount__c, DisplayFilesScreen__c, DisplayPayment__c, FilingRecordType__c, PersonAccount__c
                FROM FlowperRecordType__mdt
                WHERE ApplicationType__c = :applicationType
                AND FilingRecordType__c = :filingRecordType
            ];
        
        if(flowPerRecordTypeList.size() == 0)
        {
            serverResponse.errorMessage = 'No \'FlowperRecordType\' records were found for the given application and record type!';            
        }
        else
        {
            serverResponse.isPersonAccount = flowPerRecordTypeList[0].PersonAccount__c;
            serverResponse.isBusinessAccount = flowPerRecordTypeList[0].Account__c;
            serverResponse.createAccount = flowPerRecordTypeList[0].CreateAccount__c;
            serverResponse.flowperRecordTypeId = flowPerRecordTypeList[0].Id;
            serverResponse.displayFiles = flowPerRecordTypeList[0].DisplayFilesScreen__c;
            serverResponse.displayPayment = flowPerRecordTypeList[0].DisplayPayment__c;
            serverResponse.accountNameLabel = flowPerRecordTypeList.get(0).AccountNameLabel__c;
            serverResponse.firstNameLabel = flowPerRecordTypeList.get(0).FirstNameLabel__c;
            serverResponse.lastNameLabel = flowPerRecordTypeList.get(0).LastNameLabel__c;
            serverResponse.buttonNameLabel = flowPerRecordTypeList.get(0).ButtonNameLabel__c;
        }
        
        return serverResponse;
    }
    
    public class Response
    {
        @AuraEnabled
        public String filingRecordType {get; set;}
        
        @AuraEnabled
        public String applicationType {get; set;}
        
        @AuraEnabled
        public List<String> availableApplicationTypeList {get; set;}
        
        @AuraEnabled
        public String paymentId {get; set;}
        
        @AuraEnabled
        public String filingAccountId {get; set;}
        
        @AuraEnabled
        public String filingId {get; set;}
        
        @AuraEnabled
        public Boolean displayPayment {get; set;}
        
        @AuraEnabled
        public Boolean displayFiles {get; set;}
        
        @AuraEnabled
        public Filing__c newFiling {get; set;}
        
        @AuraEnabled
        public List<CustomFieldWrapper> filingFieldsWrapperList {get; set;}
        
        @AuraEnabled
        public String accountNameLabel {get;set;}
        
        @AuraEnabled
        public String lastNameLabel {get;set;}
        
        @AuraEnabled
        public String firstNameLabel {get;set;}
        
        @AuraEnabled
        public String buttonNameLabel {get;set;}
        
        @AuraEnabled
        public LayoutWrapper layoutWrapper {get; set;}
        
        @AuraEnabled
        public String flowperRecordTypeId {get; set;}
        
        @AuraEnabled
        public String errorMessage {get; set;}
        
        @AuraEnabled
        public Boolean isPersonAccount {get; set;}
        
        @AuraEnabled
        public Boolean isBusinessAccount {get; set;}
        
        @AuraEnabled
        public Boolean createAccount {get; set;}
        
        @AuraEnabled
        public Account searchedAccount {get; set;}
        
        @AuraEnabled
        public Account createdAccount {get; set;}
        
        @AuraEnabled
        public Boolean foundAccount {get; set;}
        
        @AuraEnabled
        public Boolean newAccountCreated {get; set;}
        
        @AuraEnabled
        public List<FileUploadWrapper> uploadedFilesWrapperList {get; set;}
        
        @AuraEnabled
        public List<Account> searchedAccounts {get; set;} //PacPoint-RdG240220 - New Var Added for Case 6778
        
        public Response()
        {
            filingRecordType = '';
            applicationType = '';
            availableApplicationTypeList = new List<String>();
            paymentId = '';
            filingAccountId = '';
            accountNameLabel = '';
            firstNameLabel = '';
            lastNameLabel = '';
            buttonNameLabel = '';
            filingId = '';
            uploadedFilesWrapperList = new List<FileUploadWrapper>();
            displayPayment = false;
            displayFiles = false;
            newFiling = new Filing__c();
            filingFieldsWrapperList = new List<CustomFieldWrapper>();
            flowperRecordTypeId = '';
            errorMessage = '';
            isPersonAccount  = false;
            isBusinessAccount  = false;
            createAccount = false;
            searchedAccount = new Account();
            createdAccount = new Account();
            foundAccount = false;
            newAccountCreated = false;
            searchedAccounts = new List<Account>();
        }
    }
    
    public class FileUploadWrapper
    {
        @AuraEnabled
        public String uploadedFileName {get; set;}
        
        @AuraEnabled
        public String contentDocumentId {get; set;}
        
        @AuraEnabled
        public String fileDetails {get; set;}
        
        @AuraEnabled
        public String fileCategory {get; set;}

        @AuraEnabled
        public String fileUrl {get; set;}
        
        @AuraEnabled
        public String fileDescription {get; set;}
        
        @AuraEnabled
        public Boolean isRequired {get; set;}
        
        @AuraEnabled
        public String uploadGroup {get; set;}
        
        public FileUploadWrapper()
        {
            uploadGroup = '';
            fileCategory = '';
            uploadedFileName = '';
            contentDocumentId = '';
            fileDescription = '';
            fileDetails = '';
            isRequired = false;
        }
    }
    
    public class CustomFieldWrapper
    {   
        @AuraEnabled
        public String metadataDefaultValue {get; set;}
        
        @AuraEnabled
        public Boolean metadataEditable {get; set;}
        
        @AuraEnabled
        public String metadataLabel {get; set;}
        
        @AuraEnabled
        public Boolean metadataRequired {get; set;}
        
        @AuraEnabled
        public String fieldAPIName {get; set;}
        
        @AuraEnabled
        public Boolean fieldIsCreatable {get; set;}
        
        @AuraEnabled
        public String fieldType {get; set;}
        
        @AuraEnabled
        public Object defaultValue {get; set;}
        
        @AuraEnabled
        public Boolean fieldIsMandatory {get; set;}
        
        @AuraEnabled
        public String fieldHelpText {get; set;}
        
        @AuraEnabled
        public String fieldLabel {get; set;}
        
        @AuraEnabled
        public Boolean isAccessible {get; set;}    
        
        @AuraEnabled
        public Boolean isUpdateable {get; set;}     
        
        @AuraEnabled
        public List<PicklistOption> piclistOptions {get; set;}
        
        @AuraEnabled
        public List<String> fieldReferenceTo {get; set;}
        
        public CustomFieldWrapper(String initialFieldApiName, String sObjectName, String metadataDefaultValue, Boolean metadataEditable, String metadataLabel, Boolean metadataRequired)
        {
            piclistOptions = new List<PicklistOption>();
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().Fields.getMap();
            
            // when initialFieldApiName = 'hsecD_Dept__c.Name' we need to get the relationship lookup apiName 'fd_state_dept__c'
            if(initialFieldApiName.split('\\.').size() == 2)
            { 
                List<String> stringParts = initialFieldApiName.split('\\.');
                
                for(String key : fieldMap.keySet())
                {
                    String type2 = fieldMap.get(key).getDescribe().getType().name();
                    
                    List<String> fieldReferenceToList2 = new List<String>();
                    
                    if(type2.toLowerCase() == 'reference')
                    { 
                        Schema.DescribeFieldResult descField = fieldMap.get(key).getDescribe();
                        
                        for(Schema.sObjectType reference : descField.getReferenceTo())
                        {
                            fieldReferenceToList2.add(reference.getDescribe().getName());
                        }   
                        
                        if(fieldReferenceToList2.size() > 0 && stringParts[0] == fieldReferenceToList2[0])
                        {
                            initialFieldApiName = fieldMap.get(key).getDescribe().getName();
                        }
                    }
                }
            }
            else
            {
                // change it from 'NAME' to 'Name' (it matters in javascript)
                initialFieldApiName = fieldMap.get(initialFieldApiName).getDescribe().getName();
            }
            
            this.fieldIsCreatable = fieldMap.get(initialFieldApiName).getDescribe().isCreateable();
            this.isAccessible = fieldMap.get(initialFieldAPIName).getDescribe().isAccessible();
            this.isUpdateable = fieldMap.get(initialFieldAPIName).getDescribe().isUpdateable();
            this.fieldType = fieldMap.get(initialFieldApiName).getDescribe().getType().name();
            this.defaultValue = fieldMap.get(initialFieldApiName).getDescribe().getDefaultValue();
            
            //specific values from the metadata
            this.metadataDefaultValue = metadataDefaultValue;
            this.metadataEditable = metadataEditable;
            this.metadataLabel = metadataLabel;
            this.metadataRequired = metadataRequired;
            
            List<String> fieldReferenceToList = new List<String>();
            
            if(this.fieldType == 'reference')
            { 
                Schema.DescribeFieldResult descField = fieldMap.get(initialFieldApiName).getDescribe();
                
                for(Schema.sObjectType reference : descField.getReferenceTo())
                {
                    fieldReferenceToList.add(reference.getDescribe().getName());
                }   
            } 
            
            this.fieldReferenceTo = fieldReferenceToList;
            
            if(fieldMap.get(initialFieldApiName).getDescribe().isNillable() == true)
            {
                this.fieldIsMandatory = false; 
            }
            else
            {
                this.fieldIsMandatory = true; 
            }
            
            this.fieldHelpText = fieldMap.get(initialFieldApiName).getDescribe().getInlineHelpText();
            this.fieldLabel = fieldMap.get(initialFieldApiName).getDescribe().getLabel();
            this.fieldAPIName = initialFieldApiName;
            
            for (Schema.PicklistEntry plE : fieldMap.get(initialFieldApiName).getDescribe().getPicklistValues()) 
            {
                this.piclistOptions.add(new PicklistOption(plE));
            }
        }
    }
    
    public class LayoutWrapper 
    {
        @AuraEnabled
        public Metadata.Layout layout { get; set; }
        
        @AuraEnabled
        public List<SectionWrapper> sections { get; set; }
        
        public LayoutWrapper(Metadata.Layout layout) 
        {
            this.layout = layout;
            sections = new List<SectionWrapper>();
            
            for (Metadata.LayoutSection section : layout.layoutSections) 
            {
                if (section.style != Metadata.LayoutSectionStyle.CustomLinks) 
                {
                    sections.add(new SectionWrapper(section));
                }
            }
        }
    }
    
    public class SectionWrapper 
    {
        @AuraEnabled
        public Metadata.LayoutSection section { get; set; }
        
        @AuraEnabled
        public String label 
        {
            get 
            {
                return section.label;
            }
        }
        
        @AuraEnabled
        public Integer columns 
        {
            get 
            {
                if (section == null || section.style == Metadata.LayoutSectionStyle.TwoColumnsTopToBottom || section.style == Metadata.LayoutSectionStyle.TwoColumnsLeftToRight) 
                {
                    return 2;
                } 
                else 
                {
                    return 1;
                }
            }
        }
        
        @AuraEnabled
        public List<FieldGroupWrapper> fields { get; set; }
        
        public SectionWrapper(Metadata.LayoutSection section) 
        {
            this.section = section;
            fields = new List<FieldGroupWrapper>();
            
            if (section.layoutColumns.size() == 1 && section.layoutColumns[0].layoutItems != null && section.layoutColumns[0].layoutItems.size() > 0) 
            {
                for (Metadata.LayoutItem li : section.layoutColumns[0].layoutItems) 
                {
                    FieldGroupWrapper fgw = new FieldGroupWrapper();
                    fgw.field1 = new FieldWrapper(li);
                    fields.add(fgw);
                }
            }
            
            if (section.layoutColumns.size() == 2 && section.layoutColumns[0].layoutItems != null && section.layoutColumns[0].layoutItems.size() > 0) 
            {
                for (integer i = 0; i < Math.max((section.layoutColumns[0].layoutItems == null ? 0 : section.layoutColumns[0].layoutItems.size()), (section.layoutColumns[1].layoutItems == null ? 0 : section.layoutColumns[1].layoutItems.size())); i++) 
                {
                    FieldGroupWrapper fgw = new FieldGroupWrapper();
                    
                    if (section.layoutColumns[0].layoutItems != null && section.layoutColumns[0].layoutItems.size() > i)
                    {
                        fgw.field1 = new FieldWrapper(section.layoutColumns[0].layoutItems[i]);
                    }
                    
                    if (section.layoutColumns[1].layoutItems != null && section.layoutColumns[1].layoutItems.size() > i)
                    {
                        fgw.field2 = new FieldWrapper(section.layoutColumns[1].layoutItems[i]);
                    }
                    
                    fields.add(fgw);
                }
            }
        }
    }
    
    public class FieldGroupWrapper 
    {
        @AuraEnabled
        public FieldWrapper field1 { get; set; }
        
        @AuraEnabled
        public FieldWrapper field2 { get; set; }
    }
    
    public class FieldWrapper 
    {
        @AuraEnabled
        public Metadata.LayoutItem field { get; set; }
        
        @AuraEnabled
        public String fieldAPIName 
        {
            get 
            {
                return field.field;
            }
        }
        
        @AuraEnabled
        public Boolean isAccessible {
            
            get 
            {
                if (fieldAPIName == null)
                {
                    return false;
                }
                
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().isAccessible();
            }
        }


        @AuraEnabled
        public List<PicklistOption> statesOptions
        {
            get 
            {
                List<PicklistOption> optoReturn = new List<PicklistOption>();
                Schema.sObjectType objType = Account.getSObjectType();
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                list<Schema.PicklistEntry> values = fieldMap.get('ShippingStateCode').getDescribe().getPickListValues();
                
                List<SelectOption> options = new List<SelectOption>();
                for (Schema.PicklistEntry v : values){
                    if (GenericCreatePaymentCtrl.USStates.contains(v.getLabel())) {
                        optoReturn.add(new PicklistOption(v)); 
                    }
                }
                
                return optoReturn;
            }    
        }
        
        @AuraEnabled
        public String fieldLabel {
            
            get 
            {
                if (fieldAPIName == null)
                {
                    return '';
                }
                
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getLabel();
            }
        }
        
        @AuraEnabled
        public List<String> fieldReferenceTo 
        {
            get 
            {
                List<String> fieldReferenceToList = new List<String>();
                
                if (fieldAPIName == null)
                {
                    return fieldReferenceToList;
                }
                else
                { 
                    if(this.fieldType == 'reference')
                    { 
                        Schema.DescribeFieldResult descField = fMap.get(fieldAPIName.toLowerCase()).getDescribe();
                        
                        for(Schema.sObjectType reference : descField.getReferenceTo())
                        {
                            fieldReferenceToList.add(reference.getDescribe().getName());
                        }   
                    }
                    
                    return fieldReferenceToList;
                }
            }
        }
        
        @AuraEnabled
        public String fieldHelpText 
        {
            get 
            {
                if (fieldAPIName == null)
                {
                    return '';
                }
                
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getInlineHelpText();
            }
        }
        
        @AuraEnabled
        public Boolean fieldIsCreatable 
        {
            get 
            {
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().isCreateable();
            }
        }
        
        @AuraEnabled
        public Boolean fieldIsMandatory 
        {
            get 
            {
                return field.behavior == Metadata.UiBehavior.Required;
            }
        }
        
        @AuraEnabled
        public String fieldType 
        {
            get 
            {
                if (fieldAPIName == null)
                {
                    return '';
                }
                
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getType().name();
            }
        }
        
        @AuraEnabled
        public List<PicklistOption> piclistOptions 
        {
            get 
            {
                List<PicklistOption> toReturn = new List<PicklistOption>();
                
                if(fieldAPIName != null) 
                {
                    for (Schema.PicklistEntry plE : fMap.get(fieldAPIName.toLowerCase()).getDescribe().getPicklistValues()) 
                    {
                        toReturn.add(new PicklistOption(plE));
                    }
                }
                
                return toReturn;
            }
        }
        
        @AuraEnabled
        public object defaultValue 
        {
            get 
            {
                if (fieldAPIName != null)
                {
                    return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getDefaultValue();
                }
                
                return null;
            }
        }
        
        public FieldWrapper(Metadata.LayoutItem field) 
        {
            this.field = field;
        }
        
    }


    private static Set<String> usStatesPrivate;
    public static Set<String> USStates {
        get {
            if (usStatesPrivate == null) {
                usStatesPrivate = new Set<String>(getFieldDependencies('Account', 'BillingCountryCode', 'BillingStateCode').get('US'));
            }
            return usStatesPrivate;
        }
    }
    private static Map<String, List<String>> getFieldDependencies(String objectName, String controllingField, String dependentField)
    {
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        
        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();
        
        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();
        
        for(Schema.PicklistEntry currControllingValue : controllingValues)
        {
            controllingInfo.put(currControllingValue.getValue(), new List<String>());
        }
        
        for(Schema.PicklistEntry currDependentValue : dependentValues)
        {
            String jsonString = JSON.serialize(currDependentValue);
            
            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);
            
            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();
            
            Integer baseCount = 0;
            
            for(Integer curr : hexString.getChars())
            {
                Integer val = 0;
                
                if(curr >= 65)
                {
                    val = curr - 65 + 10;
                }
                else
                {
                    val = curr - 48;
                }
                
                if((val & 8) == 8)
                {
                    controllingInfo.get(controllingValues[baseCount + 0].getValue()).add(currDependentValue.getLabel());
                }
                if((val & 4) == 4)
                {
                    controllingInfo.get(controllingValues[baseCount + 1].getValue()).add(currDependentValue.getLabel());                    
                }
                if((val & 2) == 2)
                {
                    controllingInfo.get(controllingValues[baseCount + 2].getValue()).add(currDependentValue.getLabel());                    
                }
                if((val & 1) == 1)
                {
                    controllingInfo.get(controllingValues[baseCount + 3].getValue()).add(currDependentValue.getLabel());                    
                }
                
                baseCount += 4;
            }            
        } 
        
        System.debug('ControllingInfo: ' + controllingInfo);
        
        return controllingInfo;
    }

    public class MyPickListInfo
    {
        public String validFor;
    }
    
    public class PicklistOption 
    {
        @AuraEnabled
        public string label { get; set; }
        
        @AuraEnabled
        public string value { get; set; }
        
        public PicklistOption(Schema.PicklistEntry plE) 
        {
            label = plE.getLabel();
            value = plE.getValue();
        }
    }
}