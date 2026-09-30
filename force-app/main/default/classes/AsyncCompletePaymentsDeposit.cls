/*
 * ___________________________________________________________________________________
 * Description Use queueable
 * See case 00014406
 * Covered by: CompletePaymentsDepositTest
 * __________________________________________________________________________________
 * PacPoint-CL04262021 - Created for DCCA
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 4/26/2021
 * __________________________________________________________________________________
 * @updated 4/25/2023 chris.loyola@pacificpointcorp.com from queueable to batchable
 * __________________________________________________________________________________
 * @updated 8/10/2026 Alvin Zhou
 * See case 00047537 - eCheck chargeback deposit process
 *
 * A bounced eCheck is reprocessed as a BCF (bank collection failure) chargeback. By
 * then the payment already carries a DepositBatch__c from the original deposit and its
 * status has flipped from 'Completed' to 'BCF', so the payment pass below can never
 * reach it and the negative CollectionsAllocation__c records are left unclaimed.
 *
 * The batch now runs in two passes. The first pass is the original payment pass. Its
 * finish() chains a second run of this class with processChargebacks = true, which
 * claims the orphaned negative allocations directly. The chargeback pass sets only
 * CollectionsAllocation__c.Deposit__c - it must never re-stamp the parent payment's
 * DepositBatch__c, because that payment's original positive amount was already
 * deposited on an earlier run and re-stamping would double-count it.
 */
public class AsyncCompletePaymentsDeposit implements Database.Batchable<SObject>, Database.Stateful{
    private String depositId;
    public Set<String> paymentTypeFilter = new Set<String>{'Credit Card', 'ECheck'};
    public Boolean isPuc;
    public Date endDateToPullPayments;
    private Boolean processChargebacks;
    private Datetime chargebackCutoff;

    public AsyncCompletePaymentsDeposit(String depositId) {
        this(depositId, false);
    }

    public AsyncCompletePaymentsDeposit(String depositId, Boolean processChargebacks) {
        Deposits__c deposit = [
            SELECT
                Id,
                EndDatetoPullPayments__c,
                PUCDeposit__c
            FROM Deposits__c
            WHERE Id =:depositId
        ];

        this.depositId = depositId;
        this.isPuc = deposit.PUCDeposit__c;
        this.endDateToPullPayments = deposit.EndDatetoPullPayments__c;
        this.processChargebacks = processChargebacks;

        // EndDatetoPullPayments__c is a Date but CollectionsAllocation__c.CreatedDate is a
        // DateTime, so they cannot be compared directly. Use the start of the following day
        // as an exclusive bound - that keeps the end date itself in scope with no
        // sub-second edge case, and keeps the comparison on the indexed CreatedDate field.
        if (this.endDateToPullPayments != null) {
            this.chargebackCutoff = Datetime.newInstance(
                this.endDateToPullPayments.addDays(1),
                Time.newInstance(0, 0, 0, 0)
            );
        }
    }

    public void execute(Database.BatchableContext bc, List<SObject> sObjects) {
        if (this.processChargebacks) {
            for (CollectionsAllocation__c alloc : (List<CollectionsAllocation__c>) sObjects) {
                alloc.Deposit__c = this.depositId;
            }

            update sObjects;
            return;
        }

        List<CollectionsAllocation__c> allocToUpdate = new List<CollectionsAllocation__c>();
        for (pymt__PaymentX__c p : (List<pymt__PaymentX__c>) sObjects) {
            p.DepositBatch__c = this.depositId;
            for (CollectionsAllocation__c alloc : p.Collections_Allocations__r) {
                alloc.Deposit__c = this.depositId;
                allocToUpdate.add(alloc);
            }
        }

        update sObjects;
        update allocToUpdate;
    }

    public void finish(Database.BatchableContext bc) {
        // Chain the chargeback pass after the payment pass. Running it second means its
        // Deposit__c = null filter already sees the allocations claimed above, so no
        // allocation can be claimed twice within one deposit run.
        if (!this.processChargebacks) {
            Database.executeBatch(new AsyncCompletePaymentsDeposit(this.depositId, true), 200);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (this.processChargebacks) {
            return Database.getQueryLocator(getChargebackQuery());
        }

        String query = 'SELECT ' +
            'Id, ' +
            'DepositBatch__c, ' +
            '(SELECT ' +
            'Id, ' +
            'Deposit__c ' +
            'FROM Collections_Allocations__r) ' +
            'FROM pymt__PaymentX__c ' +
            'WHERE DepositBatch__c = null ' +
            'AND pymt__Status__c = \'Completed\' ' +
            'AND FeeSchedule__c <> null ' +
            'AND pymt__Date__c <= :endDateToPullPayments ' +
            'AND pymt__Payment_Type__c IN :paymentTypeFilter ';

        if (isPuc) {
            query += 'AND Division__c = \'PUC\' ';
        } else {
            query += 'AND Division__c <> \'PUC\' ';
        }

        return Database.getQueryLocator(query);
    }

    /*
     * Negative allocations that no deposit has claimed yet. PUC and DCCA deliberately
     * differ: PUC covers eCheck and credit card and does not look at the payment status,
     * while DCCA covers eCheck only and requires the parent payment to be in BCF.
     *
     * Both rules require the parent payment to already carry a DepositBatch__c. A
     * chargeback only needs offsetting when the original positive amount actually made it
     * into a deposit; if the payment was never deposited there is nothing to reverse, and
     * claiming it would push a negative amount onto a deposit that never saw the credit.
     */
    private String getChargebackQuery() {
        String query = 'SELECT ' +
            'Id, ' +
            'Deposit__c ' +
            'FROM CollectionsAllocation__c ' +
            'WHERE Deposit__c = null ' +
            'AND AmountAllocated__c < 0 ' +
            'AND Payment__r.DepositBatch__c != null ' +
            'AND CreatedDate < :chargebackCutoff ';

        if (isPuc) {
            query += 'AND PaymentType__c IN :paymentTypeFilter ' +
                'AND Division__c = \'PUC\' ';
        } else {
            query += 'AND PaymentType__c = \'ECheck\' ' +
                'AND Payment__r.pymt__Status__c = \'BCF\' ' +
                'AND Division__c <> \'PUC\' ';
        }

        return query;
    }
}