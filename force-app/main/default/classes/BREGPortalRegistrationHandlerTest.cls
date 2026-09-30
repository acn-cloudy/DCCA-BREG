@IsTest
public class BREGPortalRegistrationHandlerTest {
    private static Auth.UserData buildUserData(String email, String firstName, String lastName, Map<String, String> attributes) {
        return new Auth.UserData(
            'testId',
            firstName,
            lastName,
            firstName + ' ' + lastName,
            email,
            null,
            email.substringBefore('@'),
            'en_US',
            'facebook',
            null,
            attributes
        );
    }

    @IsTest
    static void testCreateAndUpdateUser() {
        BREGPortalRegistrationHandler handler = new BREGPortalRegistrationHandler();
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            null,
            'testuserlong',
            'en_US',
            'facebook',
            null,
            new Map<String, String>{ 'language' => 'en_US' }
        );
        User u = handler.createUser(null, sampleData);

        Assert.areEqual('testuser@example.org' + handler.usernamePostfix, u.username);
        Assert.areEqual('testuser@example.org', u.email);
        Assert.areEqual('testLast', u.lastName);
        Assert.areEqual('testFirst', u.firstName);
        Assert.areEqual('testuser', u.alias);
        insert u;
        String uid = u.id;

        sampleData = new Auth.UserData(
            'testNewId',
            'testNewFirst',
            'testNewLast',
            'testNewFirst testNewLast',
            'testnewuser@example.org',
            null,
            'testnewuserlong',
            'en_US',
            'facebook',
            null,
            new Map<String, String>{ 'language' => 'en_US', 'sfdc_networkid' => 'dummyNetworkId' }
        );
        handler.updateUser(uid, null, sampleData);

        User updatedUser = [SELECT Email, FirstName, LastName FROM User WHERE Id = :uid];

        Assert.areEqual('testnewuser@example.org', updatedUser.email);
        Assert.areEqual('testNewLast', updatedUser.lastName);
        Assert.areEqual('testNewFirst', updatedUser.firstName);
    }

    @IsTest
    static void testCreateUserReturnsNullWhenRequiredFieldsMissing() {
        BREGPortalRegistrationHandler handler = new BREGPortalRegistrationHandler();
        Auth.UserData invalidData = buildUserData('', 'First', '', new Map<String, String>());

        User createdUser = handler.createUser(null, invalidData);

        Assert.areEqual(null, createdUser, 'Handler should return null when email or last name is blank');
        Assert.isFalse(handler.canCreateUser(invalidData), 'canCreateUser should reject blank required fields');
    }

    @IsTest
    static void testCreateCommunityUserCreatesPersonAccountWhenMissing() {
        BREGPortalRegistrationHandler handler = new BREGPortalRegistrationHandler();
        String uniqueEmail = 'community.new.' + DateTime.now().getTime() + '@example.org';
        Auth.UserData communityData = buildUserData(
            uniqueEmail,
            'Community',
            'User',
            new Map<String, String>{ 'language' => 'en_US', 'sfdc_networkid' => 'dummyNetworkId' }
        );

        Test.startTest();
        User createdUser = handler.createUser(null, communityData);
        Test.stopTest();

        Account createdAccount = [
            SELECT Id, PersonEmail, PersonContactId
            FROM Account
            WHERE PersonEmail = :uniqueEmail
            LIMIT 1
        ];

        Assert.areEqual(uniqueEmail, createdUser.email, 'Community user email should match source data');
        Assert.areEqual(createdAccount.PersonContactId, createdUser.ContactId, 'Community user should be linked to created person account contact');
    }

    @IsTest
    static void testCreateCommunityUserReusesExistingPersonAccount() {
        RecordType personRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = TRUE
            LIMIT 1
        ];

        String uniqueEmail = 'community.existing.' + DateTime.now().getTime() + '@example.org';
        Account existingPersonAccount = new Account(
            RecordTypeId = personRt.Id,
            FirstName = 'Existing',
            LastName = 'Person',
            PersonEmail = uniqueEmail
        );
        insert existingPersonAccount;

        existingPersonAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :existingPersonAccount.Id
        ];

        BREGPortalRegistrationHandler handler = new BREGPortalRegistrationHandler();
        Auth.UserData communityData = buildUserData(
            uniqueEmail,
            'Existing',
            'Person',
            new Map<String, String>{ 'language' => 'en_US', 'sfdc_networkid' => 'dummyNetworkId' }
        );

        Test.startTest();
        User createdUser = handler.createUser(null, communityData);
        Test.stopTest();

        Integer personAccountCount = [SELECT COUNT() FROM Account WHERE PersonEmail = :uniqueEmail];

        Assert.areEqual(1, personAccountCount, 'Existing person account should be reused instead of creating a duplicate');
        Assert.areEqual(existingPersonAccount.PersonContactId, createdUser.ContactId, 'Community user should reuse existing person contact');
    }
}