/*
 * ___________________________________________________________________________________
 * Description Test for CECourseRosterController
 * __________________________________________________________________________________
 * PacPoint-CL03272021 - Created for DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/27/2021
 * __________________________________________________________________________________
 */
@IsTest
private class CECourseRosterControllerTest {
    @TestSetup
    static void setup() {
        Course__c c = new Course__c();
        c.StartTime__c = Time.newInstance(1, 0, 0, 0);
        c.Address__c = 'add';
        c.Address2__c = 'add';
        c.City__c = 'add';
        c.State__c = 'HI';
        c.Island__c = 'Hawaii';
        c.ZipCode__c = '1';
        insert c;
    }

    @IsTest
    static void testGetCourse() {
        Course__c c = [SELECT Id FROM Course__c LIMIT 1];
        PageReference p = Page.CECourseRoster;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('q', c.Id);
        CECourseRosterController ct = new CECourseRosterController();
        ct.getCourse();
    }
}