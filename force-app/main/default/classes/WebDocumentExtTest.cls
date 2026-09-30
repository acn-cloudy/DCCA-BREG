@isTest
private with sharing class WebDocumentExtTest {
    private static testMethod void  testUpdateContent() {
        // create Template
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
        notificationRec.DocumentTemplateName__c = setting.Name; 
        insert notificationRec;
        // create record
        // create BoardProgram__c

        Test.startTest();
        PageReference pageRef = Page.WebPDF;
        
        
        ApexPages.StandardController stdController = new ApexPages.StandardController(setting);
        pageRef.getParameters().put('id', setting.Id);
        pageRef.getParameters().put('queryId', app.Id);
        pageRef.getParameters().put('queryIds', acc.Id);
        Test.setCurrentPage(pageRef);
        WebDocumentExt cont = new WebDocumentExt(stdController);

        PVL_PDFGenerator.producePDFToFile(app.Id, setting.Name, notificationRec.Id);
        GlobalUtilities.convertDate(System.Today());

    }
}