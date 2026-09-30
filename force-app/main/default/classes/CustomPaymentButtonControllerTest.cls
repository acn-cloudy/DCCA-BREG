/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for CustomPaymentButtonController
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
private class CustomPaymentButtonControllerTest 
{	
	@IsTest
    public static void testMethod1() 
    {
        // Data Setup
        Account account = new Account();
        account.Name = 'testNameAccount';
        account.SEBSEC__c = true;
        insert account;

        Filing__c newFiling = new Filing__c();
        newFiling.FiscalYearEnd__c = Date.today();
        newFiling.Account__c = account.Id;
        insert newFiling;
        
        Transaction__c trans = new Transaction__c();
        trans.Account__c = account.Id;
        trans.TotalAmount__c = 0;
        trans.TransactionType__c = 'Group';
        trans.Status__c = 'New';
        trans.Filing__c = newFiling.Id;
        insert trans;

        pymt__PaymentX__c newPayment = new pymt__PaymentX__c();
        newPayment.Name = 'test';
        newPayment.Transaction__c = trans.Id;
        newpayment.pymt__Currency_ISO_Code__c = 'USD';
        insert newPayment;

        // Run Code
        Test.startTest();

            // Test Case : When a good Filing Id is provided
            CustomPaymentButtonController.Response serverResponse = CustomPaymentButtonController.getNecessaryInfoFromServer(newFiling.Id, 'ShowPaymentButton__c');

            // Test Case : When a bad or non-existent filing Id is provided
            CustomPaymentButtonController.Response serverResponse2 = CustomPaymentButtonController.getNecessaryInfoFromServer('BadIdTest', 'ShowPaymentButton__c');

        Test.stopTest();

        // Verify Result
        System.assertEquals(serverResponse.paymentId, newPayment.Id);
    }	
}