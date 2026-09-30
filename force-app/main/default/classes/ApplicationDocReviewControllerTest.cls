@isTest
private class ApplicationDocReviewControllerTest {
    @TestSetup
    static void makeData(){
        PVL_PDFGeneratorTest.makeData();
    }
    @isTest
    static void testGeneratePDF() {
        Application__c record = [Select Id from Application__c limit 1];
        ApplicationDocReviewController.Input i = new ApplicationDocReviewController.Input();
        i.recordId = record.Id;
        i.templateName = 'Generic Letter';
        List<ApplicationDocReviewController.Input> inputs = new List<ApplicationDocReviewController.Input>();
        inputs.add(i);
        ApplicationDocReviewController.generatePDF(inputs);
    }
}