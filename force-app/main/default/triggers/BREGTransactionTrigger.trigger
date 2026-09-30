trigger BREGTransactionTrigger on breg_Transaction__c(before insert, before update) {
    new BREGTransactionTriggerHandler().run();
}