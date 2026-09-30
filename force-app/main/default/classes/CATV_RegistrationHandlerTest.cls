@isTest
public class CATV_RegistrationHandlerTest {
    
    @testsetup static void setup(){
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        Id DCCA_CATV_RECORDTYPEID = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('DCCA_CATV').getRecordTypeId();
        Contact con = CATV_TestClassUtility.createContact('lname', 'tjones@example.com', communityDefaultAcc.Id, false);
        con.Type__c = 'Requestor';
        con.RecordTypeId = DCCA_CATV_RECORDTYPEID;
        insert con;
        
        Account acc = CATV_TestClassUtility.createAccount('test_acc',false);
        acc.Type = 'City';
        insert acc;
        
        
        Account_Access_Request__c aar = CATV_TestClassUtility.createAccountAccessRequest(acc.Id, con.Id, true);
    }
    
    @isTest
    public static void testCanCreateUser() {
        CATV_RegistrationHandler handler = new CATV_RegistrationHandler();
        Auth.UserData data = createUser('test@example.com','John','Adams');
        
        System.Assert(handler.canCreateUser(data),'Handler should be able to create this user');
    }
    
    @isTest
    public static void testCreateInternalUser() {
        CATV_RegistrationHandler handler = new CATV_RegistrationHandler();
        
        Auth.UserData data = createUser('jones@example.com','Thomas','Jones-Drew');
        Test.startTest();
        String theCommunityId = '00000001';
        data.attributeMap.put('sfdc_networkid',theCommunityId);
        try{
            User theUser = handler.createUser(null, data);
        } catch(Exception e){
            system.assertEquals(e.getMessage().contains('No User Found'), true);
        }
        Test.stopTest();
    }
    
    @isTest
    public static void testUpdateUser() {
        Profile staffProfile = [SELECT Id FROM Profile WHERE Name = 'CATV Staff'];
        UserRole role = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName = 'CATV_Staff_Admin'];
        
        User internalUser = CATV_TestClassUtility.createuser('test', 'last111', 'test@dev.com', staffProfile.Id , null, false);
        internalUser.UserRoleId = role.Id;
        insert internalUser;
        
        CATV_RegistrationHandler handler = new CATV_RegistrationHandler();
        
        Auth.UserData data = createUser('tjones@example.com','Thomas','Jones-Drew');
        User theUser = [SELECT Id, Email FROM User WHERE Email = 'test@dev.com' LIMIT 1];
        Test.startTest();
        
        data.firstName='Tom';
        handler.updateUser(theUser.Id, null, data);
        
        User theUpdatedUser = [SELECT Id,firstName,Email,LastName 
                               from User 
                               Where Id = :theUser.id];
        
        System.AssertEquals(theUpdatedUser.FirstName,data.FirstName,'First name must match');
        System.AssertEquals(theUpdatedUser.LastName,data.LastName,'Last name must match');
        
        Test.stopTest();
        
    }
    
    private static Auth.UserData createUser(String email,String lastName, String firstName) {
        Map<String, String> attributeMap = new Map<String,String>();
        String identifier = lastName+System.currentTimeMillis();
        String locale = 'en_US';
        return new Auth.UserData( identifier,
                                 firstName,
                                 lastName,
                                 '', // fullname
                                 email,
                                 '', // link
                                 '', // userName
                                 locale,
                                 '', // provider
                                 '', // siteLoginUrl
                                 attributeMap);       
    }
}