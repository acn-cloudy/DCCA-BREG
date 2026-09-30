@isTest
private class CommunitiesSelfRegControllerTest {
    @isTest
    static void testConstructorWithAndWithoutExpid() {
        Test.setCurrentPage(new PageReference('/apex/selfRegNoExp'));
        CommunitiesSelfRegController c1 = new CommunitiesSelfRegController();
        System.assertNotEquals(null, c1, 'Controller should be created without expid');

        PageReference withExp = new PageReference('/apex/selfRegWithExp');
        withExp.getParameters().put('expid', 'EXP-TEST');
        Test.setCurrentPage(withExp);

        try {
            CommunitiesSelfRegController c2 = new CommunitiesSelfRegController();
            System.assertNotEquals(null, c2, 'Controller should be created with expid');
        } catch (Exception ex) {
            System.assert(
                ex.getMessage().contains('within a community'),
                'In test context, expid path may fail outside community; expected community-only exception'
            );
        }
    }

    @isTest
    static void testPropertyTrimming() {
        Test.setCurrentPage(new PageReference('/apex/selfRegTrim'));
        CommunitiesSelfRegController controller = new CommunitiesSelfRegController();

        controller.password = '  pass123  ';
        controller.confirmPassword = '  pass123  ';
        controller.communityNickname = '  myNick  ';

        System.assertEquals('pass123', controller.password, 'Password should be trimmed');
        System.assertEquals('pass123', controller.confirmPassword, 'Confirm password should be trimmed');
        System.assertEquals('myNick', controller.communityNickname, 'Nickname should be trimmed');

        controller.password = null;
        controller.confirmPassword = null;
        controller.communityNickname = null;

        System.assertEquals(null, controller.password, 'Password null should be preserved');
        System.assertEquals(null, controller.confirmPassword, 'Confirm password null should be preserved');
        System.assertEquals(null, controller.communityNickname, 'Nickname null should be preserved');
    }

    @isTest
    static void testRegisterUserPasswordMismatchReturnsNullAndAddsMessage() {
        Test.setCurrentPage(new PageReference('/apex/selfRegMismatch'));
        CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
        controller.email = 'mismatch@example.com';
        controller.firstName = 'First';
        controller.lastName = 'Last';
        controller.communityNickname = 'MismatchNick';
        controller.password = 'abc123';
        controller.confirmPassword = 'zzz999';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertEquals(null, result, 'registerUser should return null when passwords do not match');
        System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error message should be added for password mismatch');
    }

    @isTest
    static void testRegisterUserMatchingPasswordReturnsNullWhenUserNotCreated() {
        Test.setCurrentPage(new PageReference('/apex/selfRegMatch'));
        CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
        controller.email = 'nouserfound@example.com';
        controller.firstName = 'First';
        controller.lastName = 'Last';
        controller.communityNickname = 'MatchNick';
        controller.password = 'abc123';
        controller.confirmPassword = 'abc123';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertEquals(null, result, 'Current flow should return null when external user creation does not produce a user id');
    }

    @isTest
    static void testRegisterUserMatchingPasswordHandlesExternalCreateError() {
        Test.setCurrentPage(new PageReference('/apex/selfRegMatchDuplicate'));
        User currentUser = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
        controller.email = currentUser.Username;
        controller.firstName = 'Dup';
        controller.lastName = 'User';
        controller.communityNickname = 'DupNick' + String.valueOf(Math.mod(DateTime.now().getTime(), 100000));
        controller.password = 'abc123';
        controller.confirmPassword = 'abc123';

        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();

        System.assertEquals(null, result, 'When external user creation fails, controller should return null');
    }

    @isTest
    static void testCreatePersonAccountBlankEmailThrows() {
        Id profileId = UserInfo.getProfileId();

        try {
            CommunitiesSelfRegController.createPersonAccount('   ', 'First', 'Last', profileId);
            System.assert(false, 'Expected IllegalArgumentException for blank email');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('Email address cannot be blank'), 'Should throw blank-email message');
        }
    }

    @isTest
    static void testCreatePersonAccountExistingUserThrows() {
        User currentUser = [SELECT Id, Email, ProfileId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        try {
            CommunitiesSelfRegController.createPersonAccount(currentUser.Email, 'First', 'Last', currentUser.ProfileId);
            System.assert(false, 'Expected IllegalArgumentException when user already exists');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('User registration failed'), 'Should throw user registration failure');
        }
    }

    @isTest
    static void testCreatePersonAccountDefaultsWhenNamesMissing() {
        Id profileId = UserInfo.getProfileId();
        String uniqueEmail = 'newuser.' + DateTime.now().getTime() + '@example.com';

        Id createdAccountId = CommunitiesSelfRegController.createPersonAccount(uniqueEmail, null, null, profileId);
        System.assertNotEquals(null, createdAccountId, 'Account should be created');

        Account created = [
            SELECT Id, FirstName, LastName, PersonEmail
            FROM Account
            WHERE Id = :createdAccountId
            LIMIT 1
        ];
        System.assertEquals('Unknown', created.FirstName, 'Default first name should be Unknown');
        System.assertEquals('Portal User', created.LastName, 'Default last name should be Portal User');
        System.assertEquals(uniqueEmail, created.PersonEmail, 'PersonEmail should match provided email');
    }
}