trigger TransactionLineAll on TransactionLine__c (after insert, after update, after delete, after undelete, before insert, before delete, before update)
{
    if(Trigger.isAfter)
    {
        if(Trigger.isInsert)
        {
            TransactionLineHandler.UpdateParentTotalAmount(Trigger.new);
        }
        else if(Trigger.isUpdate)
        {
            TransactionLineHandler.UpdateParentTotalAmount(Trigger.new);
        }
        else if(Trigger.isDelete)
        {
            TransactionLineHandler.UpdateParentTotalAmount(Trigger.old);
        }
    }
    if(Trigger.isBefore)
    {
        if(Trigger.isDelete)
        {
            TransactionLinePreventDeletion.validateTransactionLine(Trigger.old);
        } else if (Trigger.isUpdate) {
            TransactionLineHandler.updatePartialStatus(Trigger.new, Trigger.oldMap);
        } else if(Trigger.isInsert)
        {
            TransactionLineHandler.checkFranchiseTransactionLines(Trigger.new);
        }
    }
}