@IsTest
public with sharing class BREGBouncedCheckSchedulerTest {
    @TestSetup
    static void setupTestData() {
        BREG_Setting__c setting = new BREG_Setting__c();
        setting.Days_In_Bounced_Check__c = 30;
        insert setting;

        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);

        Case testCase = cases[0];
        testCase.Status = 'Bounced Check';
        testCase.breg_Bounced_Check_Reason__c = 'Insufficient Funds';
        update testCase;
    }

    @IsTest
    static void testScheduleExecution() {
        Test.startTest();
        String jobId = System.schedule('Test Bounced Check Scheduler', '0 0 22 * * ? *', new BREGBouncedCheckScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Scheduled job should exist');
    }
}