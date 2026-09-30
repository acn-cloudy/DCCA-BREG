@isTest
private class CommunitiesLoginControllerTest {
    @isTest
    static void testConstructor() {
        CommunitiesLoginController controller = new CommunitiesLoginController();
        System.assertNotEquals(null, controller, 'Controller should be created');
    }

    @isTest
    static void testForwardToAuthPageWithParams() {
        PageReference current = new PageReference('/apex/testLogin');
        current.getParameters().put('startURL', '/s/home');
        current.getParameters().put('display', 'popup');
        Test.setCurrentPage(current);

        CommunitiesLoginController controller = new CommunitiesLoginController();

        Test.startTest();
        PageReference authPage;
        try {
            authPage = controller.forwardToAuthPage();
        } catch (Exception e) {
            System.assert(false, 'forwardToAuthPage should not throw with params: ' + e.getMessage());
            return;
        }
        Test.stopTest();

        if (authPage != null) {
            System.assertNotEquals(null, authPage.getUrl(), 'Returned page reference should be valid when present');
        }
    }

    @isTest
    static void testForwardToAuthPageWithoutParams() {
        PageReference current = new PageReference('/apex/testLoginNoParams');
        Test.setCurrentPage(current);

        CommunitiesLoginController controller = new CommunitiesLoginController();

        Test.startTest();
        PageReference authPage;
        try {
            authPage = controller.forwardToAuthPage();
        } catch (Exception e) {
            System.assert(false, 'forwardToAuthPage should not throw without params: ' + e.getMessage());
            return;
        }
        Test.stopTest();

        if (authPage != null) {
            System.assertNotEquals(null, authPage.getUrl(), 'Returned page reference should be valid when present');
        }
    }
}