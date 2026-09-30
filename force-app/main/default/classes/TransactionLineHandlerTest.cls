@isTest
private class TransactionLineHandlerTest 
{	
    static Integer s_num = 1;
    public static String getFakeId(Schema.SObjectType sot)
    {
        String result = String.valueOf(s_num++);
        return sot.getDescribe().getKeyPrefix() + 
            '0'.repeat(12-result.length()) + result;
    }

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

        Transaction__c transactionItem = new Transaction__c();
        transactionItem.Account__c = account.Id;
        transactionItem.TotalAmount__c = 0;
        insert transactionItem;

        TransactionLine__c transactionLine = new TransactionLine__c();
        transactionLine.Account__c = account.Id;
        transactionLine.Transaction__c = transactionItem.Id;
        transactionLine.Amount__c = 10;
        transactionLine.Description__c = 'testDescription';
        transactionLine.CashierCode__c = cashierCode.Id;

        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Payment_Type__c = 'Credit Card';
        insert payment;

        // Run Code
        Test.startTest();   
            
            insert transactionLine;

            transactionLine.Amount__c = 15;
            update transactionLine;
            CollectionsAllocation__c col = new CollectionsAllocation__c();
            col.Payment__c = payment.Id;
            col.TransactionLine__c = transactionLine.Id;
            col.AmountAllocated__c = 15;
            insert col;

            transactionLine.RequestRefund__c = true;
            transactionLine.PaidStatus__c = 'Paid';
            transactionLine.Overpayment__c = true;
            update transactionLine;
            
            
            

            delete transactionLine; 

        Test.stopTest();

        // Verify Results
        List<TransactionLine__c> transactionLineList =
            [
                SELECT Id
                FROm TransactionLine__c
            ];

        System.assertEquals(0, transactionLineList.size());

        Transaction__c updatedTransaction =
            [
                SELECT TotalAmount__c
                FROM Transaction__c
                WHERE Id = :transactionItem.Id
            ];

        System.assertEquals(null, updatedTransaction.TotalAmount__c);
	}

    @isTest static void test_updatePartialStatus(){
        Id id1 = getFakeId(TransactionLine__c.SObjectType);
        TransactionLine__c tl1 = (TransactionLine__c)JSON.deserialize('{"Id":"'+id1+'","PaidStatus__c":"Paid","AmountCollected__c":"0.00"}', TransactionLine__c.class);
        TransactionLine__c to1 = (TransactionLine__c)JSON.deserialize('{"Id":"'+id1+'","PaidStatus__c":"Paid","AmountCollected__c":"100.00"}', TransactionLine__c.class);

        List<TransactionLine__c> tlList = new List<TransactionLine__c>{tl1};
        Map<Id, TransactionLine__c> tlMap = new Map<Id, TransactionLine__c>();
        tlMap.put(id1, to1);
        
        TransactionLineHandler.updatePartialStatus(tlList, tlMap);
    }

    @isTest static void test_checkFranchiseTransactionLines() {
        Date today = Date.today();

        Account dummyAccount = new Account();
        dummyAccount.Name = 'Account Name';
        insert dummyAccount;

        LicenseType__c dummyLT = new LicenseType__c();
        dummyLT.StartofRenewalPeriod__c = today;
        dummyLT.Status__c = 'Active';
        dummyLT.Name = 'DIS';        
        insert dummyLT;

        License__c dummyLicense1 = new License__c();
        dummyLicense1.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        dummyLicense1.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense1.LicenseType__c = dummyLT.Id;
        dummyLicense1.Licensee__c = dummyAccount.Id;

        Application__c dummyApplication = new Application__c();
        dummyApplication.CurrentLicense__c = dummyLicense1.Id;
        dummyApplication.Type__c = 'RNEW - Renewal';
        dummyApplication.Phase__c = 'A - Application Received';
        dummyApplication.FranchiseAgreements__c = 2;
        dummyApplication.LicenseType__c = dummyLT.Id;
        insert dummyApplication;

        Transaction__c dummyTransaction = new Transaction__c();
        dummyTransaction.Application__c = dummyApplication.Id;
        insert dummyTransaction;

        CashierCode__c dummyCashierCode = new CashierCode__c();
        dummyCashierCode.Amount__c = 100.00;
        dummyCashierCode.CashierCode__c = '331';
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c();
        dummyTransactionLine.Transaction__c = dummyTransaction.Id;
        dummyTransactionLine.CashierCode__c = dummyCashierCode.Id;
        insert dummyTransactionLine;
    }
}