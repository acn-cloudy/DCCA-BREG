@isTest
private class ApplicationDocEmailControllerTest {
    @TestSetup
    static void makeData(){
        PVL_PDFGeneratorTest.makeData();
    }

    @isTest 
    static void testSendEmail() {
        Notification__c record = [Select Id, RecipientEmail__c from Notification__c limit 1];
        record.RecipientEmail__c = 'testEmail.test@pacificpointcorp.com';
        FileListControllerTest.createContentDocument('testFile', record.Id);
        update record;
        
        Test.startTest();
        ApplicationDocEmailController.Input i = new ApplicationDocEmailController.Input();
        i.recordId = record.Id;
        ApplicationDocEmailController.sendEmail(new List<ApplicationDocEmailController.Input>{i});

        Test.stopTest();
    }

}