trigger PaymentTrigger on pymt__PaymentX__c(before insert,
        after insert,
        before update,
        after update,
        before delete,
        after delete) {
    OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
    if(orgSetting.DisableTriggers__c || UserInfo.getProfileId() == GlobalUtilities.getIntegrationProfileId()) {
        return;
    }
    if(PaymentDeduplicator.disableTrigger){
        return;
    }
    Map<Id, pymt__PaymentX__c> paymentsForDedupeMap = new Map<Id, pymt__PaymentX__c>();
    if (Trigger.isAfter) {
        List<Id> transactionIdsToUpdatePaymentAmount = new List<Id>();

        if (Trigger.isInsert) {
            for (pymt__PaymentX__c payment : Trigger.new) {
                if (payment.Transaction__c != null) {
                    transactionIdsToUpdatePaymentAmount.add(payment.Transaction__c);
                }
                if (payment.pymt__Payment_Type__c != 'Credit Card' 
                // &&(payment.Transaction__c != Trigger.oldMap.get(payment.Id).Transaction__c &&
                //                         payment.Transaction__c != null
                //                         )
                ) {
                    paymentsForDedupeMap.put(payment.Id, payment);
                }
            }
        }

        if (Trigger.isUpdate) {
            

            for (pymt__PaymentX__c payment : Trigger.new) {
                if (payment.Transaction__c != null) {
                    if ((payment.pymt__Status__c != Trigger.oldMap.get(payment.Id).pymt__Status__c) ||
                            (payment.Transaction__c != Trigger.oldMap.get(payment.Id).Transaction__c) ||
                                    payment.pymt__Amount__c != Trigger.oldMap.get(payment.Id).pymt__Amount__c) {
                        transactionIdsToUpdatePaymentAmount.add(payment.Transaction__c);
                    }
                }

                if (payment.pymt__Payment_Type__c != 'Credit Card' && payment.Deleted__c != true
                // &&(payment.Transaction__c != Trigger.oldMap.get(payment.Id).Transaction__c &&
                //                         payment.Transaction__c != null
                //                         )
                ) {
                    paymentsForDedupeMap.put(payment.Id, payment);
                }
            }

            
        }
        
        if (!paymentsForDedupeMap.isEmpty()) {
            PaymentDeduplicator.deduplicate(paymentsForDedupeMap);
            paymentsForDedupeMap.clear();
        }

        if (Trigger.isDelete) {
            for (pymt__PaymentX__c payment : Trigger.old) {
                if (payment.Transaction__c != null) {
                    transactionIdsToUpdatePaymentAmount.add(payment.Transaction__c);
                }
            }
        }

        if (!transactionIdsToUpdatePaymentAmount.isEmpty()) {
            TransactionPaymentAmtCalculator.calculate(transactionIdsToUpdatePaymentAmount);
        }
    }
}