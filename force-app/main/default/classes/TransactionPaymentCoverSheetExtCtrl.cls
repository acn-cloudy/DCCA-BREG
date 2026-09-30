/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for Visualforce page - Payment Cover Sheet
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
public class TransactionPaymentCoverSheetExtCtrl {
	private final Transaction__c transactionRecord;

	public TransactionPaymentCoverSheetExtCtrl(ApexPages.StandardController stdController) {
		this.transactionRecord = (Transaction__c)stdController.getRecord();
	}

	public List<TransactionLine__c> getTransactionLineList() {
		return [
			SELECT Id,
				Account__r.Name,
				CashierCode__c,
				CashierCode__r.Name,
				CashierCodeCode__c, Amount__c, AmountOutstanding__c 
			FROM TransactionLine__c
			WHERE Transaction__c = :this.transactionRecord.Transactions__r
			OR Transaction__c = :this.transactionRecord.Id
		];
	}

	public List<TransactionLine__c> getPartialTransactionLineList() {
		return [
			SELECT Id,
				Account__r.Name,
				CashierCode__c,
				CashierCode__r.Name,
				CashierCodeCode__c, Amount__c, AmountOutstanding__c 
			FROM TransactionLine__c
			WHERE Partial_Payment_Apply__c = true 
			and ((Transaction__r.TransactionType__c = 'Group' and (Transaction__c = :this.transactionRecord.Transactions__r
			OR Transaction__c = :this.transactionRecord.Id)) 
			OR (Transaction__r.TransactionType__c != 'Group' and Transaction__c = :this.transactionRecord.Id)) order by Sort_By__c
		];
	}

	public Decimal getPartialOutStanding() {
		AggregateResult result =  [
			SELECT Sum(AmountOutstanding__c) sum
			FROM TransactionLine__c
			WHERE Partial_Payment_Apply__c = true 
			and ((Transaction__r.TransactionType__c = 'Group' and (Transaction__c = :this.transactionRecord.Transactions__r
			OR Transaction__c = :this.transactionRecord.Id)) 
			OR (Transaction__r.TransactionType__c != 'Group' and Transaction__c = :this.transactionRecord.Id))
		];
		Decimal outStanding = ( Decimal) result.get('sum');
		if(outStanding == null) outStanding = 0.00;
		return outStanding;
	}
}