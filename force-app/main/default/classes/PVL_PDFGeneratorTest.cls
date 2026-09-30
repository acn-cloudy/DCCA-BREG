@isTest
public class PVL_PDFGeneratorTest {
    @TestSetup
    public static void makeData(){
        DocGeneratorSettings__c setting = new DocGeneratorSettings__c();
        setting.Name = 'Generic Letter';
        setting.DocumentType__c = 'PDF';
        setting.DocumentTemplateName__c = 'Generic Letter';
        setting.TemplateContent__c = 'test';
        insert setting;

        String jsonStr = '[{"attributes":{"type":"DocGeneratorDataSource__c"},"DataType__c":"Detail",'
        +'"Query__c":"Select Id, Name, ApplicationReceivedDate__c,  LicenseType__c, LicenseTypeCode__c, TypeCodeTemplate__c, PhaseDescriptionTemplate__c, LicenseTypeDescription__c, '
        +'StatusCodeTemplate__c, TypeDescriptionTemplate__c, ApplicantName__c, SocialSecurityTemplate__c, DeficiencyDueDate__c,NotificationMailingStreet__c, NotificationMailingCity__c, NotificationMailingState__c, '
        +'NotificationMailingZipCode__c, NotificationMailingCountry__c, Type__c, Phase__c  from Application__c where Id =: queryId","SourceName__c":"Application__c", "Query_conditions__c":"Select LicenseType__c from Application__c where Id =: queryId", "DocGeneratorSettings__c": "'+setting.Id+'"},'
        +'{"attributes":{"type":"DocGeneratorDataSource__c"},"DataType__c":"Table","Query__c":"Select Id, RequirementLongDescription__c, Remarks__c, RemarksTag__c '
        +' from ApplicationRequirement__c where IsDeficient__c = true and ParentApplicationRequirement__c  = null and Application__c =: queryId order by REQMT__c, '
        +' SUB__c","SourceName__c":"ApplicationRequirement__c","Row_Specs__c":"{!ApplicationRequirement__c.RemarksTag__c}", "DocGeneratorSettings__c": "'+setting.Id+'"},'
        +'{"attributes":{"type":"DocGeneratorDataSource__c"},'
        +'"DataType__c":"Image","Query__c":"Select Name from Application__c where Id =: queryId","SourceName__c":"BCode", "DocGeneratorSettings__c": "'+setting.Id+'"},'
        +'{"attributes":{"type":"DocGeneratorDataSource__c"},'
        +'"DataType__c":"Barcode","Query__c":"Select Name from Application__c where Id =: queryId","SourceName__c":"BCode", "DocGeneratorSettings__c": "'+setting.Id+'"},'
        +'{"attributes":{"type":"DocGeneratorDataSource__c"},"DataType__c":"Table",'
        +'"Query__c":"Select Id, RequirementLongDescription__c, ParentApplicationRequirement__c, RemarksTag__c  from ApplicationRequirement__c '
        +'where IsDeficient__c = true and ParentApplicationRequirement__c  != null and Application__c =: queryId order by REQMT__c, '
        +'SUB__c","ParentSourceName__c":"ApplicationRequirement__c","ParentSourceField__c":"ParentApplicationRequirement__c",'
        +'"SourceName__c":"childrenAppRequirement","Row_Specs__c":"{!childrenAppRequirement.RemarksTag__c}", "DocGeneratorSettings__c": "'+setting.Id+'"},{"attributes":{"type":"DocGeneratorDataSource__c"'
        +'},"DataType__c":"Detail",'
        +'"Query__c":"Select Id, Name from BoardProgram__c where Id in: queryIdList","SourceName__c":"BoardProgram","Query_conditions__c":"Select BoardProgram__c from LicenseType__c where Id = {!Application__c.LicenseType__c}", "DocGeneratorSettings__c": "'+setting.Id+'"}]';
        List<DocGeneratorDataSource__c> sources = (List<DocGeneratorDataSource__c>)JSON.deserialize(jsonStr, List<DocGeneratorDataSource__c>.class);
        
        
        insert sources;
        // Create Account
        Account acc = new Account();
        acc.Name = 'test Acc';
        insert acc;
        
        
        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Type__c = 'Program';
        boardProgram.Name = 'Test';
        insert boardProgram;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.BoardProgram__c = boardProgram.Id;
        insert licenseTypeRecord;

        Application__c app = new Application__c();
        app.LicenseType__c = licenseTypeRecord.Id;
        insert app;
        
        ApplicationRequirement__c requirement = new ApplicationRequirement__c();
        requirement.Application__c = app.Id;
        requirement.IsDeficient__c = true;
        insert requirement;

        Notification__c notificationRec = new Notification__c();
        notificationRec.Application__c = app.Id;
        notificationRec.recordId__c = app.Id;
        notificationRec.DocumentTemplateName__c = setting.Name; 
        insert notificationRec;
        
    }
    public static testMethod void testGetContent() {
        Test.startTest();
        Notification__c notification = [Select Id, Application__c from Notification__c limit 1];
        
        PVL_PDFGenerator.getContent(notification.Application__c, 'Generic Letter', notification.Id);
    }
    public static testMethod void testProducePDFToFile() {
        Test.startTest();
        Notification__c notification = [Select Id, Application__c from Notification__c limit 1];
        
        PVL_PDFGenerator.producePDFToFile(notification.Application__c, 'Generic Letter', notification.Id);
    }
    
    public static testMethod void testUpdateSuccessStatus() {
        Notification__c notification = [Select Id, Status__c, DownloadDocumentHref__c, TimeDelivered__c, 
                                        FailedReason__c, PrintStatus__c from Notification__c limit 1];
        
        SpringCMDocument doc = new SpringCMDocument();
        doc.DownloadDocumentHref = 'https://api.springcm.com/v201411/documents/abc123def456/versions/1';
        List<SpringCMDocument> results = new List<SpringCMDocument>{doc};
        
        PVL_PDFGenerator.checkIfCreateSpringCM = false;
        
        Test.startTest();
        NotificationService.updateSuccessStatus(notification.Id, results);
        Test.stopTest();
        
	}
    
    public static testMethod void testGenerateNotificationForIdContain() {
        Application__c app = [Select Id from Application__c limit 1];
        String queryIds = 'test123,test456,test789';
        String recordId = app.Id;
        
        Test.startTest();
        Notification__c result = NotificationService.generateNotificationForIdContain(queryIds, recordId);
        Test.stopTest();
        
	}
}