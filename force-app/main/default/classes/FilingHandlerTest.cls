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
private class FilingHandlerTest {
    @IsTest
    static void testUpdateReviewerSharing() {
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
                ProfileId = UserInfo.getProfileId(),
                UserRoleId = secManager.Id);

        insert new List<User>{tempUser1, tempUser2};

        Filing__c filing = new Filing__c();
        System.runAs(tempUser2){
            insert filing;

            FileDetails__c fd = new FileDetails__c();
            fd.Filing__c = filing.Id;
            fd.Category__c = 'SEB Clerical';
            fd.Type__c = 'Complainant Documents';
            insert fd;

            filing.Reviewer__c = tempUser1.Id;
            filing.FilingDate__c = Date.today();
            filing.OwnerId = tempUser1.Id;
            update filing;
        }

        System.runAs(tempUser1){
            filing.Reviewer__c = null;
            update filing;
        }
    }

    @IsTest
    static void testValidateEditPermissionInvalidTrigger() {
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
            try {
                update filing;
            } catch (Exception e) {
                System.assert(e.getMessage().contains('Only the reviewer can edit this Filing.'));
            }
        }
    }
}