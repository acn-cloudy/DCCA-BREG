/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11192021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/19/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class FilingDomainTest {
    @IsTest
    static void testValidateEditPermissionValid() {
        Filing__c filing = new Filing__c();
        filing.Reviewer__c = UserInfo.getUserId();
        filing.FilingDate__c = Date.today();
        insert filing;

        new FilingDomain(new List<Filing__c>{filing}).validateEditPermission();
    }

    @IsTest
    static void testValidateEditPermissionInvalid() {
        Profile p = [SELECT Id FROM Profile WHERE Name ='DCCA Sec Clerical'];
        UserRole secManager = [SELECT Id FROM UserRole WHERE DeveloperName = 'BREG_SEC_MANAGER'];
        UserRole secStaff = [SELECT Id FROM UserRole WHERE DeveloperName = 'BREG_SEC_Staff'];

        User tempUser1 = new User(FirstName = 'in',
                LastName = 'valid',
                email = 'temp1@testtest.org',
                Username = 'temp1@testtest.org',
                EmailEncodingKey = 'ISO-8859-1',
                Alias = 'temp1',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                UserRoleId = secStaff.Id);

        User tempUser2 = new User(FirstName = 'in',
                LastName = 'valid2',
                email = 'temp2@testtest.org',
                Username = 'temp2@testtest.org',
                EmailEncodingKey = 'ISO-8859-1',
                Alias = 'temp2',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                UserRoleId = secManager.Id);

        insert new List<User>{tempUser1, tempUser2};

        Filing__c filing = new Filing__c();
        System.runAs(tempUser1){
            filing.Reviewer__c = tempUser1.Id;
            filing.FilingDate__c = Date.today();
            insert filing;
        }

        System.runAs(tempUser2){
            new FilingDomain(new List<Filing__c>{filing}).validateEditPermission();
            System.assert(filing.hasErrors());
            System.assert(filing.getErrors()[0]
                    .getMessage()
                    .contains('Only the reviewer can edit this Filing.'));
        }
    }
}