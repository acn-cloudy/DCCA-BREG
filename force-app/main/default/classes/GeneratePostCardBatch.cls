global class GeneratePostCardBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    public string queryString;
    public string extraCondition = '';
    public String extraFileName = '';
    public String recordId;
    public List<String> notificationIds = new List<String>();
    public Integer index = 0;
    public String pageName = 'LicensePostcard';
    public List<String> statusList = new List<String>();
    public Boolean isLicense = false;
    global GeneratePostCardBatch(String licenseId, String pageName, Boolean isLicense) {
        this.recordId = licenseId;
        this.pageName = pageName;
        this.isLicense = true;
        queryString = 'Select Id from License__c where Id = \''+recordId+'\'';
    }
    global GeneratePostCardBatch(String licenseTypeId, String pageName, String extraCondition) {
        this(licenseTypeId, pageName, extraCondition, '');
    }
    global GeneratePostCardBatch(String licenseTypeId, String pageName, String extraCondition, String extraFileName) {
        this(licenseTypeId);
        this.extraCondition = extraCondition;
        this.pageName = pageName;
        this.extraFileName = extraFileName;
        queryString = 'Select Id from License__c where LicenseType__c = \''
            + licenseTypeId + '\' and Status__c in: statusList and FlaggedforAudit__c  != true '
            + extraCondition
            + ' order by RenewalMailToCountry__c desc, RenewalMailToZipCodeBlank__c, RenewalMailToZipCodeHI__c, '
            + ' RenewalMailToZipCodeSpecial__c, RenewalMailToZipCode__c ';
    }
    global GeneratePostCardBatch(String licenseTypeId, String pageName) {
        this(licenseTypeId);
        this.pageName = pageName;
    }
    global GeneratePostCardBatch(String licenseTypeId) {
        
        statusList.add('C - Current, Valid & In Good Standing');
        statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
        statusList.add('CR - Current/Next Renewal Paid');
        statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
        statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
        statusList.add('Z - Current & Valid, But Subject To Disciplinary Requirement');
        statusList.add('ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement');
        statusList.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
        queryString = 'Select Id from License__c where LicenseType__c = \''
            + licenseTypeId + '\' and Status__c in: statusList and FlaggedforAudit__c  != true '
            + extraCondition
            + ' order by RenewalMailToCountry__c, RenewalMailToZipCodeBlank__c, RenewalMailToZipCodeHI__c, '
            + ' RenewalMailToZipCodeSpecial__c, RenewalMailToZipCode__c ';
        
        this.recordId = licenseTypeId;
    }
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(queryString);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        if(notificationIds.size() > 0) {
            generatePostCard();
        }
        

        List<License__c> records = (List<License__c> ) scope;
        List<String> recordIds = (new LicenseDomain(records)).getIds();
        String queryIds = String.join(recordIds, ',');
        
        Notification__c notification = new Notification__c();
        notification.Status__c = 'Completed';
        notification.Content__c = queryIds;
        notification.RecordId__c = recordId;
        insert notification;
        notificationIds.add(notification.Id);
    }
    
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        generatePostCard();
        if (!this.isLicense) {
            LicenseType__c lt = [SELECT Id, Name FROM LicenseType__c WHERE Id = :recordId];
            BatchJobFinishNotification notification = new BatchJobFinishNotification('Generate Post Card', lt.Name);
            notification.sendEmail();
        }
    }

    public void generatePostCard() {
        index ++;
        PageReference pageRef = new PageReference('/apex/'+pageName);
        String notificationIdStr = String.join(notificationIds, ',');
        // pageRef.getParameters().put('queryIds', queryIds);
        System.debug('#####notificationIds size#####' + notificationIds.size());
        pageRef.getParameters().put('notificationIds', notificationIdStr);
        
        Blob content;
        if(Test.isRunningTest()) {
            content = Blob.valueOf('test');
        } else {
            content = pageRef.getContent();
            // String docName = 'License Post Card(' +index + ').pdf';
            String docName = pageName + extraFileName + '('+ index + ').pdf';
            List<SpringCMDocument> result = SpringCMConnector.createFile(recordId, docname, content);
        }
        notificationIds.clear();
    }
    
}