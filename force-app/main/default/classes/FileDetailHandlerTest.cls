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
private class FileDetailHandlerTest {
    private class MockSpringCMConnector implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }
    @IsTest
    static void testValidateEditPermissionExam() {
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
        Id adminId = UserInfo.getUserId();
        FileDetails__c fd = new FileDetails__c();

        System.runAs(tempUser1){
            Exam__c exam = new Exam__c();
            exam.AssistantExaminer__c = adminId;
            insert exam;

            fd.Exam__c = exam.Id;
            fd.Category__c = 'SEB Clerical';
            fd.Type__c = 'Complainant Documents';
            insert fd;
        }

        System.runAs(tempUser2){
            try {
                update fd;
            } catch (Exception e) {
                System.assert(e.getMessage()
                        .contains('Only the Owner and Assistant Examiner can edit this File Detail.'));
            }
        }
    }

    @IsTest
    static void testValidateEditPermissionFiling() {
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
        FileDetails__c fd = new FileDetails__c();

        System.runAs(tempUser1){
            Filing__c filing = new Filing__c();
            filing.Reviewer__c = tempUser1.Id;
            filing.FilingDate__c = Date.today();
            insert filing;


            fd.Filing__c = filing.Id;
            fd.Category__c = 'SEB Clerical';
            fd.Type__c = 'Complainant Documents';
            insert fd;
        }

        System.runAs(tempUser2){
            try {
                update fd;
            } catch (Exception e) {
                System.assert(e.getMessage().contains('Only the filing reviewer can edit this File Detail.'));
            }
        }

    }
    @isTest    
    static void testFileDeletion() {
        // Set up test data
        FileDetails__c testRecord = new FileDetails__c(Category__c = 'SEB Clerical',Type__c = 'Complainant Documents',FileUrl__c = 'http://example.com/testfile');
        insert testRecord;

        // Start the test, remember to include callouts
        Test.startTest();

        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new MockSpringCMConnector());

        // Perform the deletion
        delete testRecord;

        // Stop the test
        Test.stopTest();

    }
}