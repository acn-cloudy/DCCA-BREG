/*
 * ___________________________________________________________________________________
 * Test class for AppDeficiencyEmailAppReqsController
 * __________________________________________________________________________________
 * PacPoint-CL03032020 - Created for Phase #
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/3/2020
 * __________________________________________________________________________________
 */
@IsTest
private class AppDeficiencyEmailAppReqsControllerTest {
    @TestSetup
    static void setup() {
        Application__c app = new Application__c();
        insert app;

        ApplicationRequirement__c requirement = new ApplicationRequirement__c();
        requirement.Application__c = app.Id;
        requirement.IsDeficient__c = true;
        insert requirement;
    }

    @IsTest
    static void testGetApplicationRequirements() {
        AppDeficiencyEmailAppReqsController controller = new AppDeficiencyEmailAppReqsController();
        controller.applicationId = [SELECT Id FROM Application__c].Id;
        List<ApplicationRequirement__c> apps = controller.getApplicationRequirements();
    }
}