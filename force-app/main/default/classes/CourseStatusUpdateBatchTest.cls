/*
 * -----------------------------------------------------------------------------------
 * Description
 * Test for CourseStatusUpdateBatch
 * -----------------------------------------------------------------------------------
 * PacPoint-CL08182022 - Created for case 00022621
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 08/18/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class CourseStatusUpdateBatchTest {
    @TestSetup
    static void setup() {
        Subject__c subj = new Subject__c();
        subj.Name = 'subj';
        subj.Medium__c = 'Classroom';
        subj.CreditsForCESubjects__c = 1;
        insert subj;

        Course__c c = new Course__c();
        c.Subject__c = subj.Id;
        insert c;
    }

    @IsTest
    static void statusOpenTest() {
        Course__c c = [SELECT Id FROM Course__c LIMIT 1];
        c.StartDate__c = Date.today().addDays(1);
        c.Status__c = 'Closed';
        update c;
        Test.startTest();
        (new CourseStatusUpdateBatch()).execute(null);
        Test.stopTest();
    }

    @IsTest
    static void statusClosedTest() {
        Course__c c = [SELECT Id FROM Course__c LIMIT 1];
        c.StartDate__c = Date.today().addDays(-1);
        c.EndDate__c = Date.today().addDays(1);
        c.Status__c = 'Open';
        update c;

        Test.startTest();
        (new CourseStatusUpdateBatch()).execute(null);
        Test.stopTest();
    }
}