/*
* ─────────────────────────────────────────────────────────
* Used for the bulkify Document Generator Process batch
* 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ110720 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2020-07-11
* ───────────────────────────────────────────────────────────
*/
global with sharing class DocumentGeneratorProcessBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    public Integer countnum{set;get;}
    public string content{set;get;}
    public String fileEngines = 'Renewal Notification' ;
    public String licenseTypeId;
    public List<String> notificationIds = new List<String>();
    public List<String> statusList = new list<String>();
    public String query = 'Select Id, FileEngines__c from License__c ' ;
    public String notificationId;
    public Boolean isAudit = false;
    global DocumentGeneratorProcessBatch(String licenseTypeId, String notificationId, String fileEngines, Boolean isAudit) {
        this.isAudit = isAudit;
        this.licenseTypeId = licenseTypeId;
        this.countnum = 1;
        this.notificationId = notificationId;
        this.fileEngines = fileEngines;
        query += ' where LicenseType__c =: licenseTypeId and FlaggedforAudit__c = true order by LicenseNumberFormula__c ';
    }
    global DocumentGeneratorProcessBatch() {
        this.countnum = 1;
        

        statusList.add('C - Current, Valid & In Good Standing');
        statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
        statusList.add('CR - Current/Next Renewal Paid');
        statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
        statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
        statusList.add('Z - Current & Valid, But Subject To Disciplinary Requirement');
        statusList.add('ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement');
        statusList.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
        query += ' where LicenseType__c =: licenseTypeId and Status__c in: statusList and FlaggedforAudit__c != true ';
    }
    global DocumentGeneratorProcessBatch(String licenseTypeId) {
        this();
        this.licenseTypeId = licenseTypeId;
        
    }
    global DocumentGeneratorProcessBatch(String licenseTypeId, String notificationId, String fileEngines) {
        this(licenseTypeId);
        this.notificationId = notificationId;
        this.fileEngines = fileEngines;
    }
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        Integer recordSize = 20;
        if(orgSetting.DocumentGeneratorSize__c != null && orgSetting.DocumentGeneratorSize__c > 0  ) recordSize = Integer.valueOf(orgSetting.DocumentGeneratorSize__c);
        if(notificationIds.size() == recordSize) {
            generateFiles();
        }
        String unitContent = '';
        List<License__c> records = (List<License__c>) scope;
        Integer totalSize = records.size();
        Integer index = 0;
        for(License__c record: records) {
            index ++;
            unitContent += Test.isRunningTest()? 'test str':PVL_PDFGenerator.getContent(record.Id, fileEngines, notificationId);
            // if(index != totalSize) {
                unitContent += '<div style="page-break-after:always;"></div>';
            // }
        }
        
        Notification__c record = new Notification__c();
        record.Status__c = 'Completed';
        record.Content__c = unitContent;
        insert record;
        notificationIds.add(record.Id);
        
    }
    global void finish(Database.BatchableContext context) {
        generateFiles();
        if(this.isAudit){
            LicenseType__c lt = [SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId];
            BatchJobFinishNotification notification =
                    new BatchJobFinishNotification('Bulk Document Generation', lt.Name);
            notification.sendEmail();
        }
    }
    public void generateFiles(){
        PageReference pageRef = Page.WebMultiPDF;
        List<Notification__c> notifications = NotificationSelector.getNotifications(notificationId);
        String docNameT = 'File';
        if(!notifications.isEmpty()) {
            docNameT = notifications.get(0).DocumentTemplateName__c;
        }
        Date t = Date.today();
        docNameT += ' ' + t.year();
        String queryIds = String.join(notificationIds,',');
        pageRef.getParameters().put('queryIds', queryIds);
                
        Blob content = Test.isRunningTest()? Blob.valueOf('test') : pageRef.getContent();
        String docName = docNameT + ' ('+countnum+').pdf';
        List<SpringCMDocument> result = SpringCMConnector.createFile(licenseTypeId, docname, content); 
        notificationIds.clear(); 
        countnum ++;      
    }
}