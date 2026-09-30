/*
 * ___________________________________________________________________________________
 * Description Test class for CEPassCertificateController
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
private class CEPassCertificateControllerTest {
    @TestSetup
    static void setup() {
        Course__c c = new Course__c();
        insert c;
    }

    @IsTest
    static void testGetEnrollmentsWithCid() {
        Course__c c = [SELECT Id FROM Course__c LIMIT 1];
        PageReference p = Page.CEPassCertificate;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('cid', c.Id);
        CEPassCertificateController ct = new CEPassCertificateController();
        ct.getEnrollments();
    }

    @IsTest
    static void testGetEnrollmentsWithQ() {
        PageReference p = Page.CEPassCertificate;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('q', '');
        CEPassCertificateController ct = new CEPassCertificateController();
        ct.getEnrollments();
    }
}