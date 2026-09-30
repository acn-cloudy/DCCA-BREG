/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for GroupTransaction2
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
public class GroupTransactions2Test {
    
	@isTest 
    public static void Test1() {
        
		// Data setup
        Account acc = new Account();
        acc.Name = 'Test936844';
        acc.FileID__c = '1';
        acc.OAH_Case_Number__c = '1';
        insert acc;
        
        Transaction__c trns1 = new Transaction__c();
        trns1.Account__c = acc.Id;
        trns1.WorkitemID__c = '1';
        trns1.TotalAmount__c = 100.00;

        Transaction__c trns2 = new Transaction__c();
        trns2.Account__c = acc.Id;
        trns2.WorkitemID__c = '2';
        insert new List<Transaction__c> { trns1, trns2 };
        
		// Run the code
        Test.startTest();
        GroupTransactions2.getInitialValues();
        List<Account> accs = GroupTransactions2.searchLines1('Test', '1', '', '1', '', '', 5,1);
        List<Account> accs2 = GroupTransactions2.searchLines1('Test Name', '1', 'Test', '1', 'Test', 'Test', 5, 1);
        String saveResult = GroupTransactions2.saveNewAccount('012t0000000PLy1AAG', 'Test936845', '', '', '', '', '', '', '');
		List<Transaction__c> trans = GroupTransactions2.searchLines('Test', null, null, '2', null, null);
		List<Transaction__c> trans2 = GroupTransactions2.searchLines('Test Name', 'Test', 'Test', '2', 'Test', 'Test');
        GroupTransactions2.saveTransactions(acc.Id, new List<String> { trns1.Id, trns2.Id });
        Test.stopTest();
        
        // Verify Results
        System.assertEquals(1, trans.size());
        trns2 = [SELECT TransactionGroup__c FROM Transaction__c WHERE Id = :trns2.Id];
        System.assert(trns2.TransactionGroup__c != null);
    }
}