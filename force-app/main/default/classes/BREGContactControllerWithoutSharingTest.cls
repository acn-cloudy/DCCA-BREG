@isTest
private with sharing class BREGContactControllerWithoutSharingTest {
    @testSetup
    static void setupData() {
        insert new List<Contact>{
            new Contact(
                FirstName = 'John',
                LastName = 'State Match',
                Email = 'john.state.match@test.com',
                Phone = '808-111-2222',
                MailingStreet = '123 MAIN ST',
                MailingCity = 'HONOLULU',
                MailingStateCode = 'HI',
                MailingPostalCode = '96813',
                MailingCountryCode = 'US'
            ),
            new Contact(
                FirstName = 'Jane',
                LastName = 'No State Match',
                Email = 'jane.no.state.match@test.com',
                Phone = '808-333-4444',
                MailingStreet = '500 BISHOP ST',
                MailingCity = 'HONOLULU',
                MailingPostalCode = '96813',
                MailingCountryCode = 'US'
            )
        };
    }

    @isTest
    static void testCreateNewContact_withStateCode() {
        Test.startTest();
        Id contactId = BREGContactControllerWithoutSharing.createNewContact(
            'Alex',
            'Created State',
            'alex.created.state@test.com',
            '808-555-0001',
            '410 S KING ST',
            'HONOLULU',
            'HI',
            '96813',
            'US'
        );
        Test.stopTest();

        Contact created = [
            SELECT FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingStateCode, MailingPostalCode, MailingCountryCode
            FROM Contact
            WHERE Id = :contactId
        ];

        System.assertEquals('Alex', created.FirstName);
        System.assertEquals('Created State', created.LastName);
        System.assertEquals('alex.created.state@test.com', created.Email);
        System.assertEquals('808-555-0001', created.Phone);
        System.assertEquals('410 S KING ST', created.MailingStreet);
        System.assertEquals('HONOLULU', created.MailingCity);
        System.assertEquals('HI', created.MailingStateCode);
        System.assertEquals('96813', created.MailingPostalCode);
        System.assertEquals('US', created.MailingCountryCode);
    }

    @isTest
    static void testCreateNewContact_withoutStateCode() {
        Test.startTest();
        Id contactId = BREGContactControllerWithoutSharing.createNewContact(
            'Alex',
            'Created No State',
            'alex.created.nostate@test.com',
            '808-555-0002',
            '415 S KING ST',
            'HONOLULU',
            null,
            '96813',
            'US'
        );
        Test.stopTest();

        Contact created = [SELECT MailingStateCode FROM Contact WHERE Id = :contactId];
        System.assertEquals(null, created.MailingStateCode, 'State code should remain null when not provided.');
    }

    @isTest
    static void testFindExistingContact_withStateCode() {
        Test.startTest();
        Id existingContactId = BREGContactControllerWithoutSharing.findExistingContact(
            'John',
            'State Match',
            'john.state.match@test.com',
            '808-111-2222',
            '123 MAIN ST',
            'HONOLULU',
            'HI',
            '96813',
            'US'
        );
        Test.stopTest();

        System.assertNotEquals(null, existingContactId, 'Expected matching contact when state code is provided.');
    }

    @isTest
    static void testFindExistingContact_withoutStateCode() {
        Test.startTest();
        Id existingContactId = BREGContactControllerWithoutSharing.findExistingContact(
            'Jane',
            'No State Match',
            'jane.no.state.match@test.com',
            '808-333-4444',
            '500 BISHOP ST',
            'HONOLULU',
            null,
            '96813',
            'US'
        );
        Test.stopTest();

        System.assertNotEquals(null, existingContactId, 'Expected matching contact when state code is omitted.');
    }

    @isTest
    static void testFindExistingContact_notFound() {
        Test.startTest();
        Id existingContactId = BREGContactControllerWithoutSharing.findExistingContact(
            'Nobody',
            'Missing',
            'nobody.missing@test.com',
            '808-000-0000',
            '1 UNKNOWN ST',
            'HONOLULU',
            null,
            '99999',
            'US'
        );
        Test.stopTest();

        System.assertEquals(null, existingContactId, 'Should return null when no contact matches criteria.');
    }
}