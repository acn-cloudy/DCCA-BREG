/*
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Test class for CustomCommunityRegistrationCtrl
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * PacPoint-LC012519 - Created for BREG Phase 1
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author Lucian Ciobanu - PacificPointCorp
 *
 * @created 2019-01-25
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Changes
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
@IsTest
public class CustomCommunityRegistrationCtrlTest
{
    @TestSetup
    static void setup() {
        Account existingAcc = new Account(
                Name = 'test 454654',
                BillingStreet = 'testStreet',
                DBA__c = 'dba',
                CRD__c = 'crd',
                RecordTypeId = Schema.SObjectType.Account
                        .getRecordTypeInfosByName()
                        .get('Business Account')
                        .getRecordTypeId()
        );

        insert existingAcc;

        Contact existingCnt = new Contact(
                FirstName = 'test',
                LastName = '357833',
                AccountId = existingAcc.Id,
                Email = 'test357833@email.com'
        );

        insert existingCnt;
    }

    @IsTest
    static void testGetExistingAccount() {
        String params =
                '{"accountName":"test 454654","street":"testStreet","dba":"dba","crd":"crd","businessAccRecordTypeDeveloperName":"BusinessAccount"}';
        CustomCommunityRegistrationController.getExistingAccount(params);
    }

    @IsTest
    static void testGetExistingContactWithExistingUsers() {
        List<Contact> contacts = [
                SELECT
                        Id,
                        FirstName,
                        MiddleName,
                        LastName,
                        Email
                FROM Contact where Email != null
                LIMIT 1
        ];

        Profile profile = [SELECT Id FROM Profile WHERE Name = 'DCCA BREG - CustomerCommunityLogin' LIMIT 1];
        User u = new User();
        u.ProfileId = profile.Id;
        u.firstName = contacts[0].FirstName;
        u.middleName = contacts[0].MiddleName;
        u.lastName = contacts[0].LastName;
        u.ContactId = contacts[0].Id;
        u.Username = contacts[0].Email;
        u.Email = contacts[0].Email;
        u.Alias = CustomCommunityRegistrationController.buildAlias(contacts[0].FirstName, contacts[0].LastName);
        u.CommunityNickname = u.Alias + DateTime.now().format('yyMMddHHmmss');
        u.TimeZoneSidKey = 'Pacific/Honolulu'; // Required
        u.LocaleSidKey = 'en_US'; // Required
        u.EmailEncodingKey = 'ISO-8859-1'; // Required
        u.LanguageLocaleKey = 'en_US'; // Required
        u.Division__c = 'BREG';
        insert u;

        Map<String, Object> ret = CustomCommunityRegistrationController.getExistingContact(
                '{"firstName": "test", "lastName": "357833", "email": "test357833@email.com", "profileName":"DCCA BREG - CustomerCommunityLogin"}');

        System.assert(contacts[0].Id == (Id) ret.get('Id'));
    }

    @IsTest
    static void testGetExistingContact() {
        CustomCommunityRegistrationController.getExistingContact(
                '{"firstName": "test", "lastName": "357833", "email": "test357833@email.com", "profileName":"DCCA BREG - CustomerCommunityLogin"}');
    }

    @IsTest
    static void testGetContactFields() {
        CustomCommunityRegistrationController.getContactFields();
    }

    @IsTest
    static void testGetAccountFields() {
        CustomCommunityRegistrationController.getAccountFields();
    }

    @isTest
    static void testMethod00() {
        // Data Setup
        Account accNew = new Account(
                Name = 'test 454655',
                BillingStreet = 'testStreet'
        );

        Contact cntNew = new Contact(
                FirstName = 'test',
                LastName = '357834',
                Email = 'test357834@email.com'
        );

        // Run Code
        Test.startTest();

        List<CustomCommunityRegistrationController.FieldWrapper> testFWCList =
                CustomCommunityRegistrationController.getContactFields();

        CustomCommunityRegistrationController.CallResponse testCall =
                CustomCommunityRegistrationController.finalizeRecords(accNew, cntNew,
                        'DCCA BREG - CustomerCommunityLogin', 'true', 'false', 'BusinessAccount', 'PersonAccount');

        CustomCommunityRegistrationController.finalizeRecords(accNew, cntNew, 'DCCA BREG - CustomerCommunityLogin',
                'false', 'false', 'BusinessAccount', 'PersonAccount');

        CustomCommunityRegistrationController.getFieldDependencies('Account', 'BillingCountryCode',
                'BillingStateCode');

        Test.stopTest();

        object aux = testFWCList[0].fieldAPIName;
        aux = testFWCList[0].fieldLabel;
        aux = testFWCList[0].fieldHelpText;
        aux = testFWCList[0].fieldIsCreatable;
        aux = testFWCList[0].fieldIsMandatory;
        aux = testFWCList[0].fieldType;
        aux = testFWCList[0].statesOptions;
        aux = testFWCList[0].piclistOptions;
    }

}