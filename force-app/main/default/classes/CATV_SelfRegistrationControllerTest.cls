@isTest
public class CATV_SelfRegistrationControllerTest {
	@testsetup static void setup(){
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        Contact con = CATV_TestClassUtility.createContact('lname', 'a@b.com', communityDefaultAcc.Id, false);
        con.Type__c = 'Requestor';
        //insert con;
        
        Account acc = CATV_TestClassUtility.createAccount('test_acc',false);
        acc.Type = 'City';
        insert acc;

        //Account_Access_Request__c aar = CATV_TestClassUtility.createAccountAccessRequest(acc.Id, con.Id, true);
    }
    
    @isTest
    static void createContactAndAccountRequestTest(){
        Account acc = [SELECT Id,Name from Account WHERE Type = 'Community' LIMIT 1];
        Account acc2 = [SELECT Id,Name from Account WHERE Type = 'City' LIMIT 1];
        
        Blob key = Blob.valueOf('4234557899123446');
        Blob cipherText = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf(acc.Id));
        String encodedCipherText = EncodingUtil.base64Encode(cipherText);
        
        Blob cipherText2 = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf(acc2.Id));
        String encodedCipherText2 = EncodingUtil.base64Encode(cipherText2);
        
        Test.startTest();
        
        CATV_SelfRegistrationController.RegistrationWrapper inputWrap = new CATV_SelfRegistrationController.RegistrationWrapper();
        inputWrap.firstName = 'Test First';
        inputWrap.middleName = 'Test Middle';
        inputWrap.lastName = 'Test Last';
        inputWrap.suffix = 'Test';
        inputWrap.email = 'Test@xyz.com';
        inputWrap.phoneNo = '1234567890';
        inputWrap.accountId = encodedCipherText;
        inputWrap.provideOrRequestor = 'Requestor';
        
        String retValue = CATV_SelfRegistrationController.createContactAndAccountRequest(JSON.serialize(inputWrap));
        
        inputWrap.accountId = encodedCipherText2;
        String retValue2 = CATV_SelfRegistrationController.createContactAndAccountRequest(JSON.serialize(inputWrap));
        
        Test.stopTest();
        
        Assert.AreNotEqual(retValue,'Error');
    }
    
    @isTest
    static void existingContactAndAccountAccessRequestTest(){
        Account acc = [SELECT Id,Name from Account WHERE Type = 'Community' LIMIT 1];
        Blob key = Blob.valueOf('4234557899123446');
        Blob cipherText = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf(acc.Id));
        String encodedCipherText = EncodingUtil.base64Encode(cipherText);
        
        String retValue;
        Test.startTest();
        
        CATV_SelfRegistrationController.RegistrationWrapper inputWrap = new CATV_SelfRegistrationController.RegistrationWrapper();
        inputWrap.firstName = 'Test First';
        inputWrap.middleName = 'Test Middle';
        inputWrap.lastName = 'Test Last';
        inputWrap.suffix = 'Test';
        inputWrap.email = 'Test@xyz.com';
        inputWrap.phoneNo = '1234567890';
        inputWrap.accountId = encodedCipherText;
        inputWrap.provideOrRequestor = 'Requestor';
        
       	retValue = CATV_SelfRegistrationController.createContactAndAccountRequest(JSON.serialize(inputWrap));
        
        Account_Access_Request__c accAccessReq = [SELECT Id FROM Account_Access_Request__c LIMIT 1];
        accAccessReq.Status__c = 'Approved';
        update accAccessReq;
        
       	retValue = CATV_SelfRegistrationController.createContactAndAccountRequest(JSON.serialize(inputWrap));
        
        accAccessReq.Status__c = 'Rejected';
        update accAccessReq;
        
       	retValue = CATV_SelfRegistrationController.createContactAndAccountRequest(JSON.serialize(inputWrap));
        
        Test.stopTest();
        Assert.AreNotEqual(retValue,'Error');
    }
}