/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for NewTransaction
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-LC040819 - Created for DCCA phase 1
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/ 
@isTest(seeAllData = false)
public class NewTransactionTest {
	
	@isTest
    public static void Test1(){
        
		// Data setup
        Account acc = new Account();
        acc.Name = 'Test936844';
        acc.LicenseNumbers__c = '1,2,3';
        insert acc;
        
        CashierCode__c cc = new CashierCode__c();
        cc.Name = '000 - Test';
        insert cc;
        
		// Run the code
        Test.startTest();
        NewTransaction.getInitialValues();
        List<String> codes = NewTransaction.getLicenseCodes(acc.Id);
        List<Account> accs = NewTransaction.searchLines('Test', '', '', '', '', '', 5, 1);
        List<Account> accs2 = NewTransaction.searchLines('Test Name', 'Test', 'Test', 'Test', 'Test', 'Test', 5, 1);
        String saveResult = NewTransaction.saveNewAccount('012t0000000PLy1AAG', 'Test936845', '', '', '', '', '', '', '');
        NewTransaction.saveTransaction(acc.Id, '[{ "code" : "' + cc.Id + '", "description" : "", "amount" : 100 }]', '2');
        Test.stopTest();
        
        // Verify Results
        System.assertEquals(3, codes.size());
        System.assertEquals(1, accs.size());
        System.assertEquals(18, saveResult.length());
        System.assertEquals(1, [SELECT COUNT() FROM Transaction__c]);
        System.assertEquals(1, [SELECT COUNT() FROM TransactionLine__c]);
    }
}