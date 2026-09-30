@isTest
private class CLMFileFixControllerTest {
    @isTest
    private static void testGetFiles() {
        Id adminId = UserInfo.getUserId();
        FileDetails__c fd = new FileDetails__c();

        Exam__c exam = new Exam__c();
        exam.AssistantExaminer__c = adminId;
        insert exam;

        fd.Exam__c = exam.Id;
        fd.Category__c = 'SEB Clerical';
        fd.Type__c = 'Complainant Documents';
        fd.FileUrl__c = 'test';
        insert fd;
        Test.startTest();
        CLMFileFixController.getFiles();
        Test.stopTest();
    }   
    @isTest 
    private static void testUpdateExternalFileURL() {
        Id adminId = UserInfo.getUserId();
        FileDetails__c fd = new FileDetails__c();

        Exam__c exam = new Exam__c();
        exam.AssistantExaminer__c = adminId;
        insert exam;

        fd.Exam__c = exam.Id;
        fd.Category__c = 'SEB Clerical';
        fd.Type__c = 'Complainant Documents';
        insert fd;
        Test.startTest();
        CLMFileFixController.UpdateExternalFileURL(fd.Id, 'test', 'test');
        CLMFileFixController.UpdateExternalFileURL(fd.Id, 'error', 'test');
        Test.stopTest();


    }

}