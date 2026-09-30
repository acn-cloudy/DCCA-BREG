@isTest
private class CATV_UserTriggerIsolationTest {

    @isTest
    static void testCATVProfileExecution() {
        // 1. Setup: Get a User Role (any role will work)
        UserRole portalRole = [SELECT Id FROM UserRole WHERE ParentRoleId != null LIMIT 1];
        
        // 2. Setup: Create a "Running User" with a role to own the Account
        User runningUser = CATV_TestClassUtility.createuser(
            'Admin', 'User', 'admin@test.com', 
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id, 
            null, false
        );
        runningUser.UserRoleId = portalRole.Id;
        insert runningUser;

        System.runAs(runningUser) {
            // 3. Data Sequence: Account & Contact now have an owner with a role
            String targetProfileName = 'CATV Community Profile';
            Profile catvProfile = [SELECT Id FROM Profile WHERE Name = :targetProfileName LIMIT 1];
            
            Account portalAcc = CATV_TestClassUtility.createAccount('Test Portal Account', true);
            Contact portalCon = CATV_TestClassUtility.createContact('PortalContact', 'test@catv.com', portalAcc.Id, true);
            
            // 4. Execution
            Test.startTest();
            User catvUser = CATV_TestClassUtility.createuser(
                'CATV', 
                'TestUser', 
                'catv_test@example.com', 
                catvProfile.Id, 
                portalCon.Id, 
                true
            );
            Test.stopTest();

            // Verification
            User checkUser = [SELECT Id, Profile.Name FROM User WHERE Id = :catvUser.Id];
            System.assertEquals(targetProfileName, checkUser.Profile.Name);
        }
    }

    @isTest
    static void testNonCATVProfileBypass() {
        // Standard users don't have the "Role" requirement, so this stays simple
        String bypassProfileName = 'Standard User';
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = :bypassProfileName LIMIT 1];
        
        Test.startTest();
        User nonCatvUser = CATV_TestClassUtility.createuser(
            'NonCATV', 
            'BypassTest', 
            'standard_test@example.com', 
            standardProfile.Id, 
            null, 
            true
        );
        Test.stopTest();

        User checkUser = [SELECT Id, Profile.Name FROM User WHERE Id = :nonCatvUser.Id];
        System.assertNotEquals('CATV Community Profile', checkUser.Profile.Name);
    }
}