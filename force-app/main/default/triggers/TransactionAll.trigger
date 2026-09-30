/*
 * ─────────────────────────────────────────────────────────
 * class for the Transaction Trigger
 * ─────────────────────────────────────────────────────────
 * PacPoint-LC250719 - Created for PVL phase 1
 * ───────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author PacificPointCorp
 *
 * @created 2018-10-14
 * ───────────────────────────────────────────────────────────
 * Changes
 * updated by Alvin Zhou - 2019-08-21
 * ───────────────────────────────────────────────────────────
 */
trigger TransactionAll on Transaction__c (after insert,
        after update,
        after delete,
        after undelete,
        before update,
        before delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TransactionHandler.UpdateParentTotalAmount(Trigger.new, new Map<Id, Transaction__c>());
        } else if (Trigger.isUpdate) {
            TransactionHandler.UpdateParentTotalAmount(Trigger.new, Trigger.oldMap);
            TransactionHandler.UpdateRelatedTransactionStatus(Trigger.new);
            TransactionHandler.PermitToPracticePaymentAmountSync(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            TransactionHandler.UpdateParentTotalAmount(Trigger.old, new Map<Id, Transaction__c>());
        }
    }

    if (Trigger.isBefore) {
        if (Trigger.isDelete) {
            TransactionPreventDeletion.validateTransaction(Trigger.old);
        }
    }
    TriggerFactory.createAndExecuteHandler(Transaction__c.SObjectType);
}