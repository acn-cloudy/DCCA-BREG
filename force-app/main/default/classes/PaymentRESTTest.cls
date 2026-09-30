/*
    Author: Chris Zhuang
    Company: pacificpoint
*/
@isTest
public class PaymentRESTTest {
    
    @isTest
    private static void test_PaymentREST() {
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
        Test.startTest();
        TransactionLine__c tl21 = new TransactionLine__c();
        tl21.Transaction__c = trans2.Id;
        tl21.CashierCode__c = cc2.Id;
        tl21.Description__c = 'bbb';
        insert tl21;
        
		pymt__Settings__c pSetting = new pymt__Settings__c ();
        pSetting.Name = 'test';
        insert pSetting;
            
        pymt__Processor_Connection__c pConnect = new pymt__Processor_Connection__c();
        pConnect.Name = 'Authorize.Net';
        pConnect.pymt__PaymentConnect_Setup__c = pSetting.Id;
        insert pConnect;
        
        pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
        currentYearPayment1.pymt__Status__c = 'Completed';
        currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment1.CreditCardFee__c = 20;
        currentYearPayment1.pymt__Transaction_Fee__c  = 50;
        currentYearPayment1.pymt__Amount__c = 1000;
        currentYearPayment1.Transaction__c = groupTransaction.Id;

        PaymentREST.JSON2Apex testBody = new PaymentREST.JSON2Apex();
        testBody.PaymentExternalId = '1234';
        testBody.AccountExternalId = '4556'; 
        testBody.TransactionExternalId = '32343'; 
        testBody.PaymentAmount = 100;
        testBody.PaymentDate = String.valueof(system.today()); 
        testBody.PaymentType = '1234'; 
        testBody.Status = '1234'; 
        String appJson = JSON.serialize(testBody);
                
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CreatePayment/'; 
        req.httpMethod = 'POST'; 
        req.requestBody = Blob.valueOf(appJson);
        RestContext.request = req;

        RestContext.response = res;
        PaymentREST.createPayment();
        Test.stopTest();
    }
}