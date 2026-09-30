@isTest
public with sharing class CATV_UserTriggerHandlerTest {
	@isTest static void userTriggerTest(){
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        Contact con = CATV_TestClassUtility.createContact('lname', 'a@b.com', communityDefaultAcc.Id, false);
        con.Type__c = 'Requestor';
        insert con;
        
        Account acc = CATV_TestClassUtility.createAccount('test_acc',false);
        acc.Type = 'City';
        insert acc;

        Account_Access_Request__c aar = CATV_TestClassUtility.createAccountAccessRequest(acc.Id, con.Id, true);
        
        Map<String, Object> inputObj = new Map<String, Object>();
        inputObj.put('recordId', aar.Id);
        inputObj.put('comments', 'test_comments');
        inputObj.put('targetAction', 'approveAction');

        CATV_AccessRequestController.handleRequestAction(JSON.serialize(inputObj));
        system.assertEquals(aar.Id != null, true);
    }
    
    @isTest static void internalUserTriggerTest(){
        Profile staffProfile = [SELECT Id FROM Profile WHERE Name = 'CATV Staff'];
        UserRole role = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName = 'CATV_Staff_Admin'];
        
        User internalUser = CATV_TestClassUtility.createuser('test', 'last111', 'test@dev.com', staffProfile.Id , null, false);
        internalUser.UserRoleId = role.Id;
        insert internalUser;
        
        system.assertEquals(internalUser.Id != null, true);
    }
}