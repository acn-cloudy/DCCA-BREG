@isTest
private class SiteRegisterControllerTest {
    @isTest
    static void testConstructorAndPropertyTrimming() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = ' user@example.com ';
        controller.email = ' person@example.com ';
        controller.password = '  pass123  ';
        controller.confirmPassword = '  pass123  ';
        controller.communityNickname = '  nick  ';

        System.assertNotEquals(null, controller, 'Controller should be created');
        System.assertEquals(' user@example.com ', controller.username, 'Username uses default setter');
        System.assertEquals(' person@example.com ', controller.email, 'Email uses default setter');
        System.assertEquals('pass123', controller.password, 'Password should be trimmed');
        System.assertEquals('pass123', controller.confirmPassword, 'Confirm password should be trimmed');
        System.assertEquals('nick', controller.communityNickname, 'Community nickname should be trimmed');

        controller.password = null;
        controller.confirmPassword = null;
        controller.communityNickname = null;
        System.assertEquals(null, controller.password, 'Password null should be preserved');
        System.assertEquals(null, controller.confirmPassword, 'Confirm password null should be preserved');
        System.assertEquals(null, controller.communityNickname, 'Nickname null should be preserved');
    }

    @isTest
    static void testRegisterUserPasswordMismatch() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'mismatch@example.com';
        controller.email = 'mismatch@example.com';
        controller.communityNickname = 'mismatchNick';
        controller.password = 'abc123';
        controller.confirmPassword = 'xyz999';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when passwords do not match');
        System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'Should add error message for password mismatch');
    }

    @isTest
    static void testRegisterUserMatchingPasswordExecutionPath() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'unknown.' + DateTime.now().getTime() + '@example.com';
        controller.email = 'unknown.' + DateTime.now().getTime() + '@example.com';
        controller.communityNickname = 'nick' + String.valueOf(Math.mod(DateTime.now().getTime(), 100000));
        controller.password = 'abc123';
        controller.confirmPassword = 'abc123';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertEquals(null, result, 'In test context and without valid portal setup, result should be null');
    }

    @isTest
    static void testRegisterUserReturnsLoginResultWhenUserCreatedAndPasswordPresent() {
        SiteRegisterController.testUserIdOverride = '005000000000001AAA';
        SiteRegisterController.testLoginResultOverride = new PageReference('/apex/mockLogin');

        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'created.user@example.com';
        controller.email = 'created.user@example.com';
        controller.communityNickname = 'createdUserNick';
        controller.password = 'abc123';
        controller.confirmPassword = 'abc123';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return login page reference when user is created and password is present');
        System.assert(result.getUrl().contains('mockLogin'), 'Should return mocked login page');

        SiteRegisterController.testUserIdOverride = null;
        SiteRegisterController.testLoginResultOverride = null;
    }

    @isTest
    static void testRegisterUserReturnsConfirmPageWhenUserCreatedAndNoPassword() {
        SiteRegisterController.testUserIdOverride = '005000000000002AAA';
        SiteRegisterController.testLoginResultOverride = null;

        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'created.nopass@example.com';
        controller.email = 'created.nopass@example.com';
        controller.communityNickname = 'createdNoPassNick';
        controller.password = null;
        controller.confirmPassword = null;

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return confirm page when user is created and password is null');
        System.assertNotEquals(null, result.getUrl(), 'Confirm page URL should be present');
        System.assertEquals(true, result.getRedirect(), 'Confirm page should redirect');

        SiteRegisterController.testUserIdOverride = null;
        SiteRegisterController.testLoginResultOverride = null;
    }
}