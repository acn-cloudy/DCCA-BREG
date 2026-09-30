@isTest
public class CATV_InetTriggerHandlerTest {
	@testsetup static void setup(){
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        List<Contact> conList = new List<Contact>();
        List<Account> accList = new List<Account>();
        
        Contact con = CATV_TestClassUtility.createContact('lname', 'a@b.com', communityDefaultAcc.Id, false);
        con.Type__c = 'Requestor';
        conList.add(con);
        
        Account acc = CATV_TestClassUtility.createAccount('test_acc',false);
        acc.Type = 'City';
        accList.add(acc);
        
        Account acc2 = CATV_TestClassUtility.createAccount('test_acc',false);
        acc2.Type = 'Provider';
        accList.add(acc2);
        insert accList;
        
        Contact con2 = CATV_TestClassUtility.createContact('lsname', 'aaa@b.com', acc2.Id, false);
        con2.Type__c = 'Provider';
        conList.add(con2);
        insert conList;

        INET_Request__c request = CATV_TestClassUtility.createINETRequest(acc2, con2, acc, con, true);
        
        Account_Access_Request__c aar = CATV_TestClassUtility.createAccountAccessRequest(acc.Id, con.Id, true);
        Account_Access_Request__c aar2 = CATV_TestClassUtility.createAccountAccessRequest(acc2.Id, con2.Id, true);
        
        Map<String, Object> inputObj = new Map<String, Object>();
        inputObj.put('recordId', aar.Id);
        inputObj.put('comments', 'test_comments');
        inputObj.put('targetAction', 'approveAction');
        
        Map<String, Object> inputObj2 = new Map<String, Object>();
        inputObj2.put('recordId', aar2.Id);
        inputObj2.put('comments', 'test_comments');
        inputObj2.put('targetAction', 'approveAction');

        CATV_AccessRequestController.handleRequestAction(JSON.serialize(inputObj));
        CATV_AccessRequestController.handleRequestAction(JSON.serialize(inputObj2));
    }
    
    @isTest static void inetSharingTest(){
        Account reqAcc = [SELECT Id FROM Account WHERE Type = 'City'];
        Account providerAcc = [SELECT Id FROM Account WHERE Type = 'Provider'];
        
        Contact reqCon = [SELECT Id FROM Contact WHERE Type__c = 'Requestor'];
        Contact providerCon = [SELECT Id FROM Contact WHERE Type__c = 'Provider'];
        
        User u = [SELECT Id FROM User WHERE ContactId = :reqCon.Id];
        
        INET_Request__c request = CATV_TestClassUtility.createINETRequest(providerAcc, providerCon, reqAcc, reqCon,  true);
        
        request.Status__c = 'Submitted';
        update request;
        
        system.assertEquals(request.Id != null, true);
        
    }
}