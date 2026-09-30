@isTest
private class ApplicationDocCreateControllerTest {
    @TestSetup
    static void makeData(){
        PVL_PDFGeneratorTest.makeData();
    }

    @isTest
    static void testCreatePDF() {
        ApplicationDocCreateController.Input i = new ApplicationDocCreateController.Input();
        i.recordId = [Select Id, RecordId__c from Notification__c limit 1].RecordId__c;
        i.notificationId = [Select Id, RecordId__c, DocumentTemplateName__c from Notification__c limit 1].Id;
        i.templateName = [Select Id, RecordId__c, DocumentTemplateName__c from Notification__c limit 1].DocumentTemplateName__c;
        List<ApplicationDocCreateController.Input> inputs = new List<ApplicationDocCreateController.Input>();
        inputs.add(i);
        ApplicationDocCreateController.createPDF(inputs);
    }
}