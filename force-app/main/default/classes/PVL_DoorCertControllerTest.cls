/*
 * ___________________________________________________________________________________
 * Description Test for PVL_DoorCertController
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
private class PVL_DoorCertControllerTest {
    @TestSetup
    static void setup() {
        Course__c c = new Course__c();
        c.StartTime__c = Time.newInstance(1, 0, 0, 0);
        insert c;
    }

    @IsTest
    static void testGetCourse() {
        Course__c c = [SELECT Id FROM Course__c LIMIT 1];
        PageReference p = Page.PVL_DOOR_CERT;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('id', c.Id);
        PVL_DoorCertController ct = new PVL_DoorCertController();
        ct.getCourse();
    }
}