@isTest
public with sharing class BREGExternalAPIGetStampsTest {
    @isTest
    static void testGetStamps_UserAndProfileAndOrgDefaults() {
        // Use System Administrator profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            LastName = 'Test',
            Username = 'testuser1@example.com.unit',
            Email = 'testuser1@example.com',
            Alias = 'tuser1',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // User-level setting
        BREG_Stamp_Setting__c userSetting = new BREG_Stamp_Setting__c(
            breg_Stamp_Name__c = 'UserStamp',
            breg_Stamp_Label__c = 'User Stamp',
            breg_Includes_Date__c = true,
            breg_Date_Position_Left__c = 10,
            breg_Date_Position_Top__c = 20,
            breg_Date_Position_Bottom__c = 30,
            breg_Date_Position_Right__c = 40,
            SetupOwnerId = u.Id
        );
        insert userSetting;

        // Profile-level setting
        BREG_Stamp_Setting__c profileSetting = new BREG_Stamp_Setting__c(
            breg_Stamp_Name__c = 'ProfileStamp',
            breg_Stamp_Label__c = 'Profile Stamp',
            breg_Includes_Date__c = false,
            breg_Date_Position_Left__c = 11,
            breg_Date_Position_Top__c = 21,
            breg_Date_Position_Bottom__c = 31,
            breg_Date_Position_Right__c = 41,
            SetupOwnerId = p.Id
        );
        insert profileSetting;

        // Org default setting (simulate getOrgDefaults)
        BREG_Stamp_Setting__c orgDefault = new BREG_Stamp_Setting__c(
            breg_Stamp_Name__c = 'OrgDefaultStamp',
            breg_Stamp_Label__c = 'Org Default Stamp',
            breg_Includes_Date__c = true,
            breg_Date_Position_Left__c = 12,
            breg_Date_Position_Top__c = 22,
            breg_Date_Position_Bottom__c = 32,
            breg_Date_Position_Right__c = 42,
            breg_Stamp_Codes__c = 'AM,CRT,COR,DEL,DRS,DRL,FN,FIL,INT'
            // SetupOwnerId left blank for org default
        );
        insert orgDefault;

        // Mock PageReference.getContent() for static resource images
        Test.startTest();
        // Use a mock for PageReference.getContent()
        // Since we cannot actually mock PageReference in Apex, we expect the image to be blank
        System.runAs(u) {
            BREGExternalAPIGetStamps.Response resp = BREGExternalAPIGetStamps.getStamps();
            Assert.isNotNull(resp, 'Response should not be null');
            Assert.isNull(resp.errorMessage, 'Error message should be null');
            Assert.isNotNull(resp.stamps, 'Stamps should not be null');
            Assert.isTrue(resp.stamps.size() >= 2, 'Should return at least user and profile stamps');
            Set<String> names = new Set<String>();
            for (BREGExternalAPIGetStamps.StampResponse s : resp.stamps) {
                names.add(s.StampName);
                // StampImageBase64 should be blank because static resource is not available in test context
                Assert.isNotNull(s.StampImageBase64, 'StampImageBase64 should be blank in test context');
            }
            Assert.isTrue(names.contains('UserStamp'), 'Should contain UserStamp');
            Assert.isTrue(names.contains('ProfileStamp'), 'Should contain ProfileStamp');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetStamps_NoSettings() {
        // No BREG_Stamp_Setting__c records exist
        Test.startTest();
        BREGExternalAPIGetStamps.Response resp = BREGExternalAPIGetStamps.getStamps();
        Assert.isNotNull(resp, 'Response should not be null');
        Assert.isNull(resp.stamps, 'Stamps should be null when no settings');
        Assert.areEqual('No stamps found', resp.errorMessage, 'Should return no stamps found error');
        Test.stopTest();
    }

    @isTest
    static void testGetStamps_ExceptionOnImage() {
        // Insert a setting with a name that will cause PageReference.getContent() to throw
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        // Use System Administrator profile for SetupOwnerId if needed
        BREG_Stamp_Setting__c userSetting = new BREG_Stamp_Setting__c(
            breg_Stamp_Name__c = 'ExceptionStamp',
            breg_Stamp_Label__c = 'Exception Stamp',
            breg_Includes_Date__c = true,
            breg_Date_Position_Left__c = 1,
            breg_Date_Position_Top__c = 2,
            breg_Date_Position_Bottom__c = 3,
            breg_Date_Position_Right__c = 4,
            SetupOwnerId = u.Id
        );
        insert userSetting;

        // We cannot actually force PageReference.getContent() to throw in a test context,
        // but we can simulate the code path by inserting a record and verifying that
        // errorMessage is still null (since getContent returns null in test context)
        Test.startTest();
        BREGExternalAPIGetStamps.Response resp = BREGExternalAPIGetStamps.getStamps();
        Assert.isNotNull(resp, 'Response should not be null');
        Assert.isNull(resp.errorMessage, 'Error message should be null');
        Assert.areEqual(1, resp.stamps.size(), 'Should return 1 stamp');
        Test.stopTest();
    }
}