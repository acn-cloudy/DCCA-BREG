/*
 * ___________________________________________________________________________________
 * Description Test for PVL_PrelicensePassCertController
 * __________________________________________________________________________________
 * PacPoint-CL03282021 - Created for DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/28/2021
 * __________________________________________________________________________________
 */
@IsTest
private class PVL_PrelicensePassCertControllerTest {
    @TestSetup
    static void setup() {
        Course__c c = new Course__c();
        insert c;

        PrelicenseCEEnrollment__c enrollment = new PrelicenseCEEnrollment__c();
        enrollment.Course__c = c.Id;
        enrollment.PassDate__c = Date.today();
        insert enrollment;
    }

    @IsTest
    static void testGetCourse() {
        PrelicenseCEEnrollment__c e = [SELECT Id FROM PrelicenseCEEnrollment__c LIMIT 1];
        PageReference p = Page.PVL_PRELIC_PASS_CERT;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('q', e.Id);
        PVL_PrelicensePassCertController ct = new PVL_PrelicensePassCertController();
        ct.getEnrollments();
    }
}