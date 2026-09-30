@isTest
private class CreateTransactionTest 
{  
    @isTest static void test_method_one() 
    {
        // Data Setup
        Account account = new Account();
        account.Name = 'testNameAccount';
        insert account;

        CashierCode__c cashierCode1 = new CashierCode__c();
        cashierCode1.Amount__c = 10;
        cashierCode1.Description__c = 'test Description';
        insert cashierCode1;

        CashierCode__c cashierCode2 = new CashierCode__c();
        cashierCode2.Amount__c = 10;
        cashierCode2.Description__c = 'test Description';
        insert cashierCode2;

        Transaction__c transaction1 = new Transaction__c();
        transaction1.Account__c = account.Id;
        transaction1.TotalAmount__c = 10;
        
        TransactionLine__c tline = new TransactionLine__c(CashierCode__c = cashierCode1.Id, Amount__c = 10);
        List<TransactionLine__c> tlinelist = new List<TransactionLine__c>();
        tlinelist.add(tline);
        String str = JSON.serialize(tlinelist);
        // Run Code
        Test.startTest();
            CreateTransaction.initTransaction(account.Id);
            List<CashierCode__c> CashierCodes = CreateTransaction.getCashierCodes();
            List<CreateTransaction.PicklistVal> picklistValues = CreateTransaction.getSelectOptions('Transaction__c', 'TransactionType__c');
            CreateTransaction.saveTransaction(transaction1, str);
        Test.stopTest();

        // Verify Results
        List<Transaction__c> transactionRecord =
            [
                SELECT Id
                FROM Transaction__c
            ];

        System.assertEquals(1, transactionRecord.size());
        
        List<TransactionLine__c> transactionLineList =
            [
                SELECT Id
                FROM TransactionLine__c WHERE Transaction__c = :transactionRecord[0].Id
            ];

        System.assertEquals(1, transactionLineList.size());
    }
    
    
    @isTest static void test_method_two() 
    {
        // Data Setup
        Account account = new Account();
        account.Name = 'testNameAccount';
        insert account;

        CashierCode__c cashierCode1 = new CashierCode__c();
        cashierCode1.Amount__c = 10;
        cashierCode1.Description__c = 'test Description';
        insert cashierCode1;

        CashierCode__c cashierCode2 = new CashierCode__c();
        cashierCode2.Amount__c = 10;
        cashierCode2.Description__c = 'test Description';
        insert cashierCode2;

        Transaction__c transaction1 = new Transaction__c();
        transaction1.Account__c = account.Id;
        transaction1.TotalAmount__c = 10;
        insert transaction1;
        
        TransactionLine__c tline = new TransactionLine__c(CashierCode__c = cashierCode1.Id, Amount__c = 10);
        List<TransactionLine__c> tlinelist = new List<TransactionLine__c>();
        tlinelist.add(tline);
        String str = JSON.serialize(tlinelist);
        // Run Code
        Test.startTest();
            CreateTransaction.initTransaction(transaction1.Id);
            List<CashierCode__c> CashierCodes = CreateTransaction.getCashierCodes();
            List<CreateTransaction.PicklistVal> picklistValues = CreateTransaction.getSelectOptions('Transaction__c', 'TransactionType__c');
            CreateTransaction.saveTransaction(transaction1, str);
        Test.stopTest();

        // Verify Results
        List<Transaction__c> transactionRecord =
            [
                SELECT Id
                FROM Transaction__c
            ];

        System.assertEquals(1, transactionRecord.size());
        
        List<TransactionLine__c> transactionLineList =
            [
                SELECT Id
                FROM TransactionLine__c WHERE Transaction__c = :transactionRecord[0].Id
            ];

        System.assertEquals(1, transactionLineList.size());
    }
}