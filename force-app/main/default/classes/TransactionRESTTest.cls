/*
    Author: Chris Zhuang
    Company: pacificpoint
*/
@isTest
public class TransactionRESTTest {
    /* Creating Test data class */
    @TestSetup
    static void createTestData() {
        Account acc = new Account(Name = 'Test Account', External_Id__c = '4556');
        insert acc;
        
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        
        date sd = Date.Today();
        
        Transaction__c groupTransaction = new Transaction__c();
        groupTransaction.Account__c = acc.Id;
        groupTransaction.Contact__c = cnt.Id;
        groupTransaction.Date__c = sd.addDays(-2);
        groupTransaction.Status__c = 'New';
        groupTransaction.TransactionType__c = 'Group';
        insert groupTransaction;
        
        Transaction__c trans1 = new Transaction__c();
        trans1.Account__c = acc.Id;
        trans1.Contact__c = cnt.Id;
        trans1.Date__c = sd.addDays(-2);
        trans1.TransactionId__c = '32343'; 
        trans1.Status__c = 'New';
        trans1.TransactionGroup__c = groupTransaction.Id;
        trans1.TransactionType__c = 'Payment';
        insert trans1;
        
        CashierCode__c cc1 = new CashierCode__c();
        cc1.Name = 'Cashier Code 1';
        cc1.Amount__c = 30;
        cc1.CashierCode__c = '000011';
        cc1.Category__c = 'Categ1';
        cc1.Division__c = 'BREG';
        insert cc1;
        
        TransactionLine__c tl1 = new TransactionLine__c();
        tl1.Transaction__c = trans1.Id;
        tl1.Amount__c = 30;
        tl1.CashierCode__c = cc1.Id;
        tl1.Description__c = 'aaa';
        insert tl1;
        
        TransactionLine__c tl11 = new TransactionLine__c();
        tl11.Transaction__c = trans1.Id;
        tl11.Amount__c = 30;
        tl11.CashierCode__c = cc1.Id;
        tl11.Description__c = 'aaa';
        tl11.PaidStatus__c = 'Paid';
        insert tl11;
        
        Transaction__c trans2 = new Transaction__c();
        trans2.Account__c = acc.Id;
        trans2.Contact__c = cnt.Id;
        trans2.Date__c = sd.addDays(-2);
        trans2.Status__c = 'New';
        trans2.TransactionGroup__c = groupTransaction.Id;
        trans2.TransactionType__c = 'Payment';
        insert trans2;
        
        CashierCode__c cc2 = new CashierCode__c();
        cc2.Name = 'Cashier Code 1';
        cc2.Amount__c = 70;
        cc2.CashierCode__c = '000011';
        cc2.Category__c = 'Categ1';
        cc2.Division__c = 'BREG';
        insert cc2;
        
        TransactionLine__c tl2 = new TransactionLine__c();
        tl2.Transaction__c = trans2.Id;
        tl2.CashierCode__c = cc2.Id;
        tl2.Description__c = 'bbb';
        insert tl2;
        
        
    }
  
    @isTest
    private static void test_TransactionREST1() {
        TransactionREST.JSON2Apex testBody = new TransactionREST.JSON2Apex();
        testBody.AccountFirstName = 'test firstname';
        testBody.AccountLastName = 'test lastname'; 
        testBody.AccountType = 'test'; 
        testBody.AccountExternalId = '4556';
        testBody.TransactionExternalId = '32343';
        testBody.TransactionDate = system.today(); 
        testBody.Division = 'test'; 
        testBody.Description = 'test'; 
        String appJson = JSON.serialize(testBody);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CreateTransaction/'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        TransactionREST.createTransaction();
        Test.stopTest();
    }
    
 
    @isTest
    private static void test_TransactionREST2() {
        TransactionREST.JSON2Apex testBody = new TransactionREST.JSON2Apex();
        testBody.AccountFirstName = 'test firstname';
        testBody.AccountLastName = 'test lastname'; 
        testBody.AccountType = 'test'; 
        testBody.AccountExternalId = '4556';
        testBody.TransactionExternalId = '111111';
        testBody.TransactionDate = system.today(); 
        testBody.Division = 'test'; 
        testBody.Description = 'test'; 
        String appJson = JSON.serialize(testBody);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CreateTransaction/'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        TransactionREST.createTransaction();
        Test.stopTest();
    }
    
    @isTest
    private static void test_TransactionREST3() {
        TransactionREST.JSON2Apex testBody = new TransactionREST.JSON2Apex();
        testBody.AccountFirstName = 'test firstname';
        testBody.AccountLastName = 'test lastname'; 
        testBody.AccountType = 'Business Account'; 
        testBody.BusinessName = 'test Account 1'; 
        testBody.AccountExternalId = '23442';
        testBody.TransactionExternalId = '222222';
        testBody.TransactionDate = system.today(); 
        testBody.Division = 'DFI'; 
        testBody.Description = 'test';
        
        TransactionREST.TransactionLineWrap tlw = new TransactionREST.TransactionLineWrap();
        tlw.CashierCodeName = '020';
        tlw.PaidStatus = 'Paid';
        tlw.Amount = 150;
        tlw.Description = 'dadsad';
        testBody.TransactionLineItems = new List<TransactionREST.TransactionLineWrap>();
        testBody.TransactionLineItems.add(tlw);
        String appJson = JSON.serialize(testBody);
        system.debug('xxx:' + appJson);
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CreateTransaction/'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        TransactionREST.createTransaction();
        Test.stopTest();
    }
    
    @isTest
    private static void test_TransactionREST4() {
        TransactionREST.JSON2Apex testBody = new TransactionREST.JSON2Apex();
        testBody.AccountFirstName = 'test firstname';
        testBody.AccountLastName = 'test lastname'; 
        testBody.AccountType = 'Person Account'; 
        testBody.BusinessName = 'test Account 1'; 
        testBody.AccountExternalId = '232412';
        testBody.TransactionExternalId = '233423';
        testBody.TransactionDate = system.today(); 
        testBody.Division = 'DFI'; 
        testBody.Description = 'test';
        
        TransactionREST.TransactionLineWrap tlw = new TransactionREST.TransactionLineWrap();
        tlw.CashierCodeName = '025';
        tlw.PaidStatus = 'Pendding';
        tlw.Amount = 200;
        tlw.Description = 'aaa';
        testBody.TransactionLineItems = new List<TransactionREST.TransactionLineWrap>();
        testBody.TransactionLineItems.add(tlw);
        String appJson = JSON.serialize(testBody);
                
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CreateTransaction/'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        TransactionREST.createTransaction();
        Test.stopTest();
    }
}