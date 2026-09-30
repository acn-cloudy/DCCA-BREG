/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test Class for Controller for Visualforce page - Payment Cover Sheet
* Retrieves the related transaction lines for each Transaction on the Parent Group Transaction
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-IC062019 - Created for DCCA phase 1
* @author       Irene Cahilo - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class TransactionPaymentCoverSheetExtCtrlTest {
	@IsTest
	static void transactionPaymentCoverSheetExtCtrlTest(){
		Account accountDummy = new Account();
		accountDummy.Name = 'testNameAccount';
		insert accountDummy;

		Transaction__c groupTransactionDummy = new Transaction__c();
		groupTransactionDummy.TransactionType__c = 'Group';
		groupTransactionDummy.Status__c = 'Pending';
		groupTransactionDummy.TotalAmount__c = 0;
		groupTransactionDummy.Account__c = accountDummy.Id;
		insert groupTransactionDummy;

		Transaction__c childTransactionDummy = new Transaction__c();
		childTransactionDummy.TransactionGroup__c = groupTransactionDummy.Id;
		childTransactionDummy.TransactionType__c = 'Payment';
		childTransactionDummy.Account__c = accountDummy.Id;
		insert childTransactionDummy;

		CashierCode__c cashierCodeDummy = new CashierCode__c();
		cashierCodeDummy.Amount__c = 100.00;
		cashierCodeDummy.Name = 'CashierCode Dummy';
		insert cashierCodeDummy;

		TransactionLine__c transactionLine = new TransactionLine__c();
		transactionLine.CashierCode__c = cashierCodeDummy.Id;
		transactionLine.Transaction__c = childTransactionDummy.Id;
		transactionLine.Account__c = accountDummy.Id;
		insert transactionLine;

		ApexPages.currentPage().getParameters().put('transactionRecord',groupTransactionDummy.id);
		ApexPages.StandardController stdTransaction = new ApexPages.StandardController(groupTransactionDummy);
		TransactionPaymentCoverSheetExtCtrl trnsPaymentControllerExt  = new TransactionPaymentCoverSheetExtCtrl(stdTransaction);

		trnsPaymentControllerExt.getTransactionLineList();
		trnsPaymentControllerExt.getPartialTransactionLineList();
		trnsPaymentControllerExt.getPartialOutStanding();

	}
}