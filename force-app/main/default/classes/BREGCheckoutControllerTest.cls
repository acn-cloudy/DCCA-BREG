@isTest
public class BREGCheckoutControllerTest {

    @testSetup
    static void setupData() {
        UserRole ur = [SELECT Id FROM UserRole LIMIT 1];

        Profile internalProfile = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];

        User accountOwner = new User(
            FirstName = 'Owner',
            LastName = 'Internal',
            Email = 'owner@example.com',
            Username = 'owner' + System.currentTimeMillis() + '@example.com',
            Alias = 'ownr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = internalProfile.Id,
            UserRoleId = ur.Id
        );
        insert accountOwner;

        Account acc;
        Contact con;

        System.runAs(accountOwner) {
            acc = new Account(Name = 'Test Account');
            insert acc;

            con = new Contact(
                FirstName = 'John',
                LastName = 'Doe',
                Email = 'johndoe@example.com',
                Phone = '1111111111',
                OtherPhone = '2222222222',
                MobilePhone = '3333333333',
                breg_Mobile_Service_Provider__c = 'AIRFIRE_MOBILE',
                MailingStreet = '123 Main St',
                MailingCity = 'Springfield',
                MailingStateCode = 'CA',
                MailingPostalCode = '98765',
                MailingCountryCode = 'US',
                AccountId = acc.Id
            );
            insert con;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'DCCA BREG - CustomerCommunityUser' LIMIT 1];
        User u = new User(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@example.com',
            Username = 'johndoe' + System.currentTimeMillis() + '@example.com',
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ContactId = con.Id
        );
        insert u;
    }

    @isTest
    static void testGetContact_AuthenticatedUser() {
        User u = [SELECT Id FROM User WHERE Username LIKE 'johndoe%@example.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Contact con = BREGCheckoutController.getContact();
            Test.stopTest();

            System.assertNotEquals(null, con, 'Contact should not be null for authenticated user');
            System.assertEquals('John', con.FirstName, 'FirstName should match');
            System.assertEquals('Doe', con.LastName, 'LastName should match');
            System.assertEquals('johndoe@example.com', con.Email, 'Email should match');
        }
    }
}