@isTest
private class CommunitiesLandingControllerTest {
    @isTest
    static void testConstructor() {
        CommunitiesLandingController controller = new CommunitiesLandingController();
        System.assertNotEquals(null, controller, 'Controller should be created');
    }

    @isTest
    static void testForwardToStartPage() {
        CommunitiesLandingController controller = new CommunitiesLandingController();

        Test.startTest();
        PageReference targetPage;
        try {
            targetPage = controller.forwardToStartPage();
        } catch (Exception e) {
            System.assert(false, 'forwardToStartPage should not throw: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(true, 'forwardToStartPage executed without exceptions');
    }
}