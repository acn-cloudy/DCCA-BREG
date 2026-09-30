/*
 * ___________________________________________________________________________________
 * A trimmed down version of DepositRollupBatch. This class processes only selected
 * deposit records
 * Covered by: DepositPaymentsRolluperTest
 * __________________________________________________________________________________
 * PacPoint-CL082819 - Created for Phase 2
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 8/28/2019
 * __________________________________________________________________________________
 */
public class DepositPaymentsRolluper {
    public static void rollup(List<Id> depositIds) {
        List<Deposits__c> deposits = [
                SELECT Id,
                        Status__c,
                        CarryForwardBalance__c,
                        NetCollectionsafterFees__c,
                        PPIFeesfromCashCheckMoneyOrders__c,
                        HIGETaxfromCashCheckMoneyOrders__c,
                        TotalAmountfromCashMoneyOrders__c,
                        TotalAmountfromCreditCard__c,
                        TotalCollections__c,
                        TotalRefundsfromCreditCard__c,
                        TotalHIGETax__c,
                        TotalPPIFees__c,
                        TotalTransactionFees__c,
                        DepositAmount__c,
                        Total_Refunds_from_Cash_Money_Orders__c,
                        PPIFeesfromCreditCard__c,
                        HIGETaxfromCreditCard__c
                FROM Deposits__c
                WHERE Id IN :depositIds
                ORDER BY Name DESC
        ];

        List<pymt__PaymentX__c> payments = [
                SELECT
                        Id,
                        RemitToDCCA__c,
                        PPIFeeAmount__c,
                        HIGETaxAmount__c,
                        pymt__Amount__c,
                        DepositBatch__c,
                        pymt__Payment_Type__c,
                        pymt__Transaction_Type__c,
                        pymt__Transaction_Fee__c
                FROM pymt__PaymentX__c
                WHERE DepositBatch__c IN: deposits
        ];

        List<CollectionsAllocation__c> allocations = [
                SELECT
                        Id,
                        NetCollectionsafterFeesAllocated__c,
                        AmountAllocated__c,
                        PaymentType__c,
                        Deposit__c
                FROM CollectionsAllocation__c
                WHERE Deposit__c IN :deposits
        ];

        Deposits__c currentDeposit = new Deposits__c();
        if (deposits[0].Status__c != 'Carry Forward to Next Deposit' && deposits[0].Status__c != 'Carry Forward Resolved')
            currentDeposit = deposits[0];
        System.debug('currentDeposit ====> ' + currentDeposit);

        Map<Id, List<pymt__PaymentX__c>> paymentsMap = new Map<Id, List<pymt__PaymentX__c>>();
        for (pymt__PaymentX__c payment : payments) {
            if (!paymentsMap.containsKey(payment.DepositBatch__c)) {
                List<pymt__PaymentX__c> newPayment = new List<pymt__PaymentX__c>();
                newPayment.add(payment);
                paymentsMap.put(payment.DepositBatch__c, newPayment);
            } else {
                List<pymt__PaymentX__c> existingPayment = paymentsMap.get(payment.DepositBatch__c);
                existingPayment.add(payment);
                paymentsMap.put(payment.DepositBatch__c, existingPayment);
            }
        }

        Map<Id, List<CollectionsAllocation__c>> allocationsMap = new Map<Id, List<CollectionsAllocation__c>>();
        for (CollectionsAllocation__c alloc : allocations) {
            if (!allocationsMap.containsKey(alloc.Deposit__c)) {
                List<CollectionsAllocation__c> newAlloc = new List<CollectionsAllocation__c>();
                newAlloc.add(alloc);
                allocationsMap.put(alloc.Deposit__c, newAlloc);
            } else {
                List<CollectionsAllocation__c> existingAlloc = allocationsMap.get(alloc.Deposit__c);
                existingAlloc.add(alloc);
                allocationsMap.put(alloc.Deposit__c, existingAlloc);
            }
        }

        for (Deposits__c dep : deposits) {
            if (dep.Status__c == 'Carry Forward to Next Deposit' && dep.DepositAmount__c != null) {
                currentDeposit.CarryForwardBalance__c = dep.DepositAmount__c;
                dep.Status__c = 'Carry Forward Resolved';
            }

            if (paymentsMap.containsKey(dep.Id)) {
                dep.NetCollectionsafterFees__c = 0;
                dep.PPIFeesfromCashCheckMoneyOrders__c = 0;
                dep.HIGETaxfromCashCheckMoneyOrders__c = 0;
                dep.TotalAmountfromCashMoneyOrders__c = 0;
                dep.TotalAmountfromCreditCard__c = 0;
                dep.TotalCollections__c = 0;
                dep.TotalRefundsfromCreditCard__c = 0;
                dep.TotalHIGETax__c = 0;
                dep.TotalPPIFees__c = 0;
                dep.TotalTransactionFees__c = 0;
                dep.Total_Refunds_from_Cash_Money_Orders__c = 0;
                dep.PPIFeesfromCreditCard__c = 0;
                dep.HIGETaxfromCreditCard__c = 0;

                List<pymt__PaymentX__c> currentPayments = paymentsMap.get(dep.Id);
                for (pymt__PaymentX__c payment : currentPayments) {

                    if (payment.RemitToDCCA__c != null)
                        dep.NetCollectionsafterFees__c += payment.RemitToDCCA__c;

                    if (payment.PPIFeeAmount__c != null && (payment.pymt__Payment_Type__c == 'Cash' || payment.pymt__Payment_Type__c == 'Check or Money Order'))
                        dep.PPIFeesfromCashCheckMoneyOrders__c += payment.PPIFeeAmount__c;

                    if (payment.HIGETaxAmount__c != null && (payment.pymt__Payment_Type__c == 'Cash' || payment.pymt__Payment_Type__c == 'Check or Money Order'))
                        dep.HIGETaxfromCashCheckMoneyOrders__c += payment.HIGETaxAmount__c;

                    if (payment.pymt__Amount__c != null && (payment.pymt__Payment_Type__c == 'Cash' || payment.pymt__Payment_Type__c == 'Check' || payment.pymt__Payment_Type__c == 'Check or Money Order' || payment.pymt__Payment_Type__c == 'Money Order') && payment.pymt__Transaction_Type__c == 'Payment')
                        dep.TotalAmountfromCashMoneyOrders__c += payment.pymt__Amount__c;

                    if (payment.pymt__Amount__c != null && payment.pymt__Payment_Type__c == 'Credit Card' && payment.pymt__Transaction_Type__c == 'Payment')
                        dep.TotalAmountfromCreditCard__c += payment.pymt__Amount__c;

                    if (payment.pymt__Amount__c != null)
                        dep.TotalCollections__c += payment.pymt__Amount__c;

                    if (payment.pymt__Amount__c != null && payment.pymt__Payment_Type__c == 'Credit Card' && payment.pymt__Transaction_Type__c == 'Refund')
                        dep.TotalRefundsfromCreditCard__c += payment.pymt__Amount__c;

                    if (payment.HIGETaxAmount__c != null)
                        dep.TotalHIGETax__c += payment.HIGETaxAmount__c;

                    if (payment.PPIFeeAmount__c != null)
                        dep.TotalPPIFees__c += payment.PPIFeeAmount__c;

                    if (payment.pymt__Amount__c != null && (payment.pymt__Payment_Type__c == 'Cash' || payment.pymt__Payment_Type__c == 'Check' || payment.pymt__Payment_Type__c == 'Check or Money Order' || payment.pymt__Payment_Type__c == 'Money Order') && payment.pymt__Transaction_Type__c == 'Refund')
                        dep.Total_Refunds_from_Cash_Money_Orders__c += payment.pymt__Amount__c;


                    if (payment.pymt__Transaction_Fee__c != null)
                        dep.TotalTransactionFees__c += payment.pymt__Transaction_Fee__c;

                    if (payment.PPIFeeAmount__c != null && payment.pymt__Payment_Type__c == 'Credit Card')
                        dep.PPIFeesfromCreditCard__c += payment.PPIFeeAmount__c;

                    if (payment.HIGETaxAmount__c != null && payment.pymt__Payment_Type__c == 'Credit Card')
                        dep.HIGETaxfromCreditCard__c += payment.HIGETaxAmount__c;
                }
            }

            if (allocationsMap.containsKey(dep.Id)) {
                dep.CollectionAllocationNetAmount__c = 0;
                dep.CollectionAllocationPaymentAmount__c = 0;
                dep.TotalReturnsfromeCheck__c = 0;

                List<CollectionsAllocation__c> currentAllocs = allocationsMap.get(dep.Id);
                for (CollectionsAllocation__c alloc : currentAllocs) {
                    if (alloc.NetCollectionsafterFeesAllocated__c != null)
                        dep.CollectionAllocationNetAmount__c += alloc.NetCollectionsafterFeesAllocated__c;
                    if (alloc.AmountAllocated__c != null)
                        dep.CollectionAllocationPaymentAmount__c += alloc.AmountAllocated__c;
                    // Case 00047537 - eCheck returns/chargebacks only. Kept negative to match
                    // the sign convention of TotalRefundsfromCreditCard__c.
                    if (alloc.AmountAllocated__c != null && alloc.AmountAllocated__c < 0 && alloc.PaymentType__c == 'ECheck')
                        dep.TotalReturnsfromeCheck__c += alloc.AmountAllocated__c;
                }
            }
        }

        update deposits;
        System.debug('currentDeposit 2 ====> ' + currentDeposit);
        if (currentDeposit != null) {
            System.debug('currentDeposit 3 ====> ' + currentDeposit);
            update currentDeposit;
        }
    }
}