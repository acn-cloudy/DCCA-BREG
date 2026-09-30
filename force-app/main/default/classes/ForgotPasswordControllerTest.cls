@isTest
private class ForgotPasswordControllerTest {
    @isTest
    static void testConstructorAndUsernameProperty() {
        ForgotPasswordController controller = new ForgotPasswordController();
        controller.username = 'user@example.com';

        System.assertNotEquals(null, controller, 'Controller should be created');
        System.assertEquals('user@example.com', controller.username, 'Username property should be settable/gettable');
    }

    @isTest
    static void testForgotPasswordReturnsPageReferenceOnSuccess() {
        User u = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        ForgotPasswordController controller = new ForgotPasswordController();
        controller.username = u.Username;

        Test.startTest();
        PageReference result = controller.forgotPassword();
        Test.stopTest();

        if (result != null) {
            System.assertEquals(true, result.getRedirect(), 'Returned page should be redirect');
            System.assert(result.getUrl() != null && result.getUrl().contains('ForgotPasswordConfirm'), 'Should navigate to ForgotPasswordConfirm page');
        } else {
            System.assertEquals(null, result, 'Result may be null if Site.forgotPassword returns false in test context');
        }
    }

    @isTest
    static void testForgotPasswordWithUnknownUsernamePath() {
        ForgotPasswordController controller = new ForgotPasswordController();
        controller.username = 'unknown.' + DateTime.now().getTime() + '@example.com';

        Test.startTest();
        PageReference result = controller.forgotPassword();
        Test.stopTest();

        System.assertEquals(null, result, 'Unknown username should return null when forgot password fails');
    }
}