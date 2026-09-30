/*
* ─────────────────────────────────────────────────────────
* Used for the Trigger for CollectionAllocations
* ─────────────────────────────────────────────────────────
* PacPoint-AZ09082020 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2020-08-09
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
trigger CollectionsAllocationTrigger on CollectionsAllocation__c (before insert) {
    List<CollectionsAllocation__c> records = trigger.new;
    String profileId = GlobalUtilities.getIntegrationProfileId();
    if(Trigger.isInsert && Trigger.isBefore) {
        // 00006806
        List<String> paymentIds = new List<String>();
        for(CollectionsAllocation__c allocation: records) {
            paymentIds.add(allocation.Payment__c);
        }
        List<pymt__PaymentX__c> payments = [Select Id, PPIFeeAmount__c,
        HIGETaxAmount__c, pymt__Transaction_Fee__c from pymt__PaymentX__c where Id in: paymentIds AND CreatedBy.ProfileId != :profileId];
        
        Map<String, List<CollectionsAllocation__c>> paymentIdToCA = new Map<String, List<CollectionsAllocation__c>>();
        for(CollectionsAllocation__c record: records) {
            String paymentId = record.Payment__c;
            List<CollectionsAllocation__c> caList = new List<CollectionsAllocation__c>();
            if(paymentIdToCA.containsKey(paymentId)) {
                caList = paymentIdToCA.get(paymentId);
            }
            caList.add(record);
            paymentIdToCA.put(paymentId, caList);
        }
        System.debug('payments' + payments);
        for(pymt__PaymentX__c payment: payments) {
            if(payment.PPIFeeAmount__c == null ) {
                payment.PPIFeeAmount__c = 0;
            }
            if(payment.HIGETaxAmount__c == null ) {
                payment.HIGETaxAmount__c = 0;
            }
            if(payment.pymt__Transaction_Fee__c == null ) {
                payment.pymt__Transaction_Fee__c = 0;
            }

            Decimal fees = payment.PPIFeeAmount__c  + payment.HIGETaxAmount__c + payment.pymt__Transaction_Fee__c ;
            List<CollectionsAllocation__c> caList = paymentIdToCA.get(payment.Id);
            Double totalFees = 0;
            for(Integer index = 0; index< (caList.size()-1); index ++) {
                totalFees += caList.get(index).TotalFeesAllocated__c;
            }
            CollectionsAllocation__c lastCa = caList.get(caList.size()-1);
            Decimal amount = lastCa.TotalFeesAllocated__c;
            if(amount == null) amount = 0;
            totalFees += amount;
            System.debug('totalFees' + totalFees);
            
            System.debug(lastCa.Id);
            Decimal roundedFees = fees.setScale(2);
            System.debug('roundedFees' + roundedFees);
            if(roundedFees != totalFees) {
                lastCa.AdjustedAllocationFees__c = roundedFees - totalFees ;
            }
            System.debug(lastCa.AdjustedAllocationFees__c);
        }
    }
    


}