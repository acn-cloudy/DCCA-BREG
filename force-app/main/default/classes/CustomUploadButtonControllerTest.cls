/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for CustomUploadButtonController
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
private class CustomUploadButtonControllerTest 
{	
	@isTest 
    public static void test_method_one() 
    {
        Account account = new Account();
        account.Name = 'testNameAccount';
        account.SEBSEC__c = true;
        insert account;
		// Data Setup
        Filing__c newFiling = new Filing__c();
        newFiling.Account__c = account.Id;
        newFiling.FiscalYearEnd__c = Date.today();
        insert newFiling;

        // Run Code
        Test.startTest();

            // Test Case : When a good Filing Id is provided
            CustomUploadButtonController.Response serverResponse = CustomUploadButtonController.getNecessaryInfoFromServer(newFiling.Id, 'ShowPaymentButton__c');

            // Test Case : When a bad or non-existent filing Id is provided
            CustomUploadButtonController.Response serverResponse2 = CustomUploadButtonController.getNecessaryInfoFromServer('BadIdTest', 'ShowPaymentButton__c');

        Test.stopTest();

        // Verify Result
        // serverResponse.showUploadButton. We can't say for sure if it will be true or false, its a formula field that will be created by the client
        System.assertNotEquals(serverResponse.showUploadButton, null);
	}	
}