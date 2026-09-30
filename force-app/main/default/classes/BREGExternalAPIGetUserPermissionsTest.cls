@IsTest
private class BREGExternalAPIGetUserPermissionsTest {
    private static final String DOC_R_PERMISSION_SET = 'BREG_DOC_R_User_permissions';
    private static final String CUSTOM_PERMISSION = 'BREG_Publish_Documents';

    private static User createDocRUser() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String stamp = String.valueOf(DateTime.now().getTime());

        User testUser = new User(
            LastName = 'BREG DOC R Test User',
            Alias = 'bregdoc',
            Email = 'bregdoc.' + stamp + '@example.com',
            Username = 'bregdoc.' + stamp + '@example.com.test',
            CommunityNickname = 'bregdoc' + stamp,
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert testUser;

        PermissionSet docRPermissionSet = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :DOC_R_PERMISSION_SET
            LIMIT 1
        ];

        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = docRPermissionSet.Id
        );

        return testUser;
    }

    @IsTest
    static void testGetUserPermissions_ReturnsAvailablePermissionForDocRUser() {
        User docRUser = createDocRUser();

        System.runAs(docRUser) {
            Test.startTest();
            BREGExternalAPIGetUserPermissions.Response resp =
                BREGExternalAPIGetUserPermissions.getUserPermissions();
            Test.stopTest();

            System.assertNotEquals(null, resp, 'Response should not be null');
            System.assertNotEquals(null, resp.permissions, 'Permissions list should be initialized');
            System.assertEquals(null, resp.errorMessage, 'Error message should be null');

            System.assertEquals(1, resp.permissions.size(), 'DOC R user should have one BREG custom permission');
            System.assertEquals(CUSTOM_PERMISSION, resp.permissions[0].permissionName);
            System.assertEquals(true, resp.permissions[0].isAvailable);
        }
    }

    @IsTest
    static void testGetUserPermissions_ReturnsEmptyForStandardUserWithoutDocR() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String stamp = String.valueOf(DateTime.now().getTime());

        User standardUser = new User(
            LastName = 'BREG Standard Test User',
            Alias = 'bregstd',
            Email = 'bregstd.' + stamp + '@example.com',
            Username = 'bregstd.' + stamp + '@example.com.test',
            CommunityNickname = 'bregstd' + stamp,
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert standardUser;

        System.runAs(standardUser) {
            Test.startTest();
            BREGExternalAPIGetUserPermissions.Response resp =
                BREGExternalAPIGetUserPermissions.getUserPermissions();
            Test.stopTest();

            System.assertNotEquals(null, resp, 'Response should not be null');
            System.assertNotEquals(null, resp.permissions, 'Permissions list should be initialized');
            System.assertEquals(0, resp.permissions.size(), 'Standard user should not have DOC R custom permission');
        }
    }
}