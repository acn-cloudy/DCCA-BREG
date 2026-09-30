@isTest
private class TransactionHandlerTest 
{	
	@isTest static void test_method_one() 
    {
        // Data Setup
        Account account = new Account();
        account.Name = 'testNameAccount';
        insert account;

        CashierCode__c cashierCode = new CashierCode__c();
        cashierCode.Amount__c = 10;
        cashierCode.Description__c = 'test Description';
        insert cashierCode;

        Transaction__c transactionGroupParent = new Transaction__c();
        transactionGroupParent.Account__c = account.Id;
        transactionGroupParent.TotalAmount__c = 0;
        transactionGroupParent.TransactionType__c = 'Group';
        transactionGroupParent.Status__c = 'New';
        insert transactionGroupParent;

        // Run Code
        Test.startTest();

            Transaction__c transactionChild = new Transaction__c();
            transactionChild.Account__c = account.Id;
            transactionChild.TotalAmount__c = 10;
            transactionChild.TransactionGroup__c = transactionGroupParent.Id;
            insert transactionChild;

            transactionChild.TotalAmount__c = 20;
            update transactionChild;

            delete transactionChild;

            transactionGroupParent.Status__c = 'Completed';
            update transactionGroupParent;

        Test.stopTest();

        // Verify Results
        List<Transaction__c> transactionList =
            [
                SELECT Id
                FROM Transaction__c
            ];

        System.assertEquals(1, transactionList.size());
    }
}