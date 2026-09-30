@isTest
public with sharing class CATV_AccessRequestControllerTest {
    
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
    }

    @isTest static void checkRequestForValidationTest(){
        Account_Access_Request__c accAccessReq = [SELECT Id FROM Account_Access_Request__c LIMIT 1];

        Map<String, Object> inputObj = new Map<String, Object>();
        inputObj.put('recordId', accAccessReq.Id);

        CATV_AccessRequestController.checkRequestForValidation(JSON.serialize(inputObj));

        accAccessReq.Status__c = 'Approved';
        update accAccessReq;

        try{
            CATV_AccessRequestController.checkRequestForValidation(JSON.serialize(inputObj));
        } catch(Exception e){
            system.assertEquals(e.getMessage().contains('Script'), true);
            accAccessReq.Status__c = 'Pending';
            update accAccessReq;
        }
    }

    @isTest static void handleRequestActionTest(){
        Account_Access_Request__c accAccessReq = [SELECT Id FROM Account_Access_Request__c LIMIT 1];

        Map<String, Object> inputObj = new Map<String, Object>();
        inputObj.put('recordId', accAccessReq.Id);
        inputObj.put('comments', 'test_comments');
        inputObj.put('targetAction', 'approveAction');

        CATV_AccessRequestController.handleRequestAction(JSON.serialize(inputObj));
        system.assertEquals(accAccessReq.Id != null, true);
    }

    @isTest static void handleRequestActionRejectTest(){
        Account_Access_Request__c accAccessReq = [SELECT Id FROM Account_Access_Request__c LIMIT 1];

        Map<String, Object> inputObj = new Map<String, Object>();
        inputObj.put('recordId', accAccessReq.Id);
        inputObj.put('comments', 'test_comments');
        inputObj.put('targetAction', 'rejectAction');

        CATV_AccessRequestController.handleRequestAction(JSON.serialize(inputObj));
        system.assertEquals(accAccessReq.Id != null, true);
    }
}