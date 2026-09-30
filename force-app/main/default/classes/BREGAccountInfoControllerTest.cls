@isTest
public class BREGAccountInfoControllerTest {

    @testSetup
    static void setupData() {
        // 1) Existing role
        UserRole ur = [SELECT Id FROM UserRole LIMIT 1];

        // 2) Internal user with role
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

        // 3) Create Account + Contact under user who HAS a role
        System.runAs(accountOwner) {
            acc = new Account(Name = 'Test Account');
            insert acc;

            con = new Contact(
                FirstName = 'Initial',
                LastName = 'User',
                Email = 'initial@example.com',
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

        // 4) External profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'DCCA BREG - CustomerCommunityUser'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
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
    static void testGetInfo() {
        User u = [SELECT Id FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            BREGAccountInfoController.AccountInfoWrapper info = BREGAccountInfoController.getInfo();
            Test.stopTest();

            System.assertNotEquals(null, info);
            System.assertEquals('Initial', info.FirstName);
            System.assertEquals('User', info.LastName);
            System.assertEquals('initial@example.com', info.Email);
        }
    }

    @isTest
    static void testSaveInfo() {
        User u = [SELECT Id FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];

        System.runAs(u) {
            BREGAccountInfoController.AccountInfoWrapper newInfo = new BREGAccountInfoController.AccountInfoWrapper();
            newInfo.FirstName = 'Updated';
            newInfo.LastName = 'Contact';
            newInfo.Email = 'updated@example.com';
            newInfo.Phone = '9999999999';
            newInfo.SecondaryPhone = '8888888888';
            newInfo.MobilePhone = '7777777777';
            newInfo.street = '456 New St';
            newInfo.street2 = ' Apt 101';
            newInfo.city = 'Los Angeles';
            newInfo.state = 'CA';
            newInfo.postalCode = '90001';
            newInfo.country = 'US';

            Test.startTest();
            BREGAccountInfoController.saveInfo(JSON.serialize(newInfo));
            Test.stopTest();

            Contact updatedCon = [
                SELECT FirstName, LastName, Email, Phone, OtherPhone, MobilePhone,
                    MailingStreet, MailingCity, MailingStateCode, MailingPostalCode, MailingCountryCode
                FROM Contact
                WHERE Id = :[SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId
            ];

            System.assertEquals('Updated', updatedCon.FirstName);
            System.assertEquals('Contact', updatedCon.LastName);
            System.assertEquals('updated@example.com', updatedCon.Email);
            System.assertEquals('9999999999', updatedCon.Phone);
            System.assertEquals('8888888888', updatedCon.OtherPhone);
            System.assertEquals('7777777777', updatedCon.MobilePhone);
            System.assert(updatedCon.MailingStreet.contains('456 New St'), 'Street should contain updated address');
            System.assertEquals('Los Angeles', updatedCon.MailingCity);
            System.assertEquals('CA', updatedCon.MailingStateCode);
            System.assertEquals('90001', updatedCon.MailingPostalCode);
            System.assertEquals('US', updatedCon.MailingCountryCode);
        }
    }
}