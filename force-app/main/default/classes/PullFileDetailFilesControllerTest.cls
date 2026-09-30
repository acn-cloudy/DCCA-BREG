@isTest
public class PullFileDetailFilesControllerTest {
    @isTest
    static void testPullDownFiles() {
        Id adminId = UserInfo.getUserId();
        FileDetails__c fd = new FileDetails__c();

        Exam__c exam = new Exam__c();
        exam.AssistantExaminer__c = adminId;
        insert exam;

        fd.Exam__c = exam.Id;
        fd.Category__c = 'SEB Clerical';
        fd.FileUrl__c = 'https://test.salesforce.com';
        fd.Type__c = 'Complainant Documents';
        insert fd;

        Test.startTest();
        PullFileDetailFilesController.pullDownFiles(fd.Id);
        Test.stopTest();
    }

}