@isTest
private class ExamNoticeControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createEligibleCandidateLoad();
        
    }
    @isTest
    static void testGetExamNotice() {
        List<Application__c> apps = [Select Id from Application__c];
        ApplicationRequirement__c requirement = new ApplicationRequirement__c();
        requirement.Application__c = apps.get(0).Id;
        requirement.IsDeficient__c = true;
        insert requirement;
        Test.startTest();
        ExamNoticeController controller = new ExamNoticeController();
        controller.recordId = apps.get(0).Id;
        controller.getApplicationClassifications();
        controller.getApplicationRequirements();
        Test.stopTest();
    }

}