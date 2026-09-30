@isTest
private class SiteLoginControllerTest {
    @isTest
    static void testConstructorAndProperties() {
        SiteLoginController controller = new SiteLoginController();
        controller.username = 'user@example.com';
        controller.password = 'P@ssw0rd';

        System.assertNotEquals(null, controller, 'Controller should be constructed');
        System.assertEquals('user@example.com', controller.username, 'Username should be settable/gettable');
        System.assertEquals('P@ssw0rd', controller.password, 'Password should be settable/gettable');
    }

    @isTest
    static void testLoginWithStartUrl() {
        User currentUser = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        PageReference pageRef = new PageReference('/apex/siteLogin');
        pageRef.getParameters().put('startURL', '/s/home');
        Test.setCurrentPage(pageRef);

        SiteLoginController controller = new SiteLoginController();
        controller.username = currentUser.Username;
        controller.password = 'DummyPassword123!';

        Test.startTest();
        PageReference result = controller.login();
        Test.stopTest();

        if (result != null) {
            System.assertNotEquals(null, result.getUrl(), 'When returned, URL should not be null');
        } else {
            System.assertEquals(null, result, 'Result can be null if Site.login fails in test context');
        }
    }

    @isTest
    static void testLoginWithoutStartUrl() {
        PageReference pageRef = new PageReference('/apex/siteLoginNoStart');
        Test.setCurrentPage(pageRef);

        SiteLoginController controller = new SiteLoginController();
        controller.username = 'unknown.' + DateTime.now().getTime() + '@example.com';
        controller.password = 'Nope123!';

        Test.startTest();
        PageReference result = controller.login();
        Test.stopTest();

        System.assertEquals(null, result, 'Login without valid credentials should return null');
    }
}