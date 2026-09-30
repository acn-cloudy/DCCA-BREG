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
private class ExamHandlerTest {
    @IsTest
    static void testUpdateAssistantExaminerSharing() {
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

        Exam__c exam = new Exam__c();
        System.runAs(tempUser1){
            exam.AssistantExaminer__c = tempUser1.Id;
            insert exam;

            exam.AssistantExaminer__c = tempUser2.Id;
            update exam;
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

        Exam__c exam = new Exam__c();
        System.runAs(tempUser1){
            exam.AssistantExaminer__c = tempUser1.Id;
            insert exam;
        }

        System.runAs(tempUser2){
            try {
                update exam;
            } catch (Exception e) {
                System.assert(e.getMessage().contains('Only the Owner and Assistant Examiner can edit this Exam.'));
            }
        }
    }

    @IsTest
    static void testNoAssistantManager() {
        Exam__c exam = new Exam__c();
        insert exam;

        update exam;
    }
}