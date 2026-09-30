/*
 * ___________________________________________________________________________________
 * 1) Find all payments where:
 * a) Payment's CutOffBatchDate__c is not null
 * b) Payment's Created by user's "Exclude from Auto-Close" flag is not checked (User.ExcludefromAutoClose__c = FALSE)
 * 2) For all payments found, set the CutOffBatchDate__c = today's date at 4:30pm Hawaii Standard Time.
 * 3) For all the Collection Allocation records tied to the payments, do the same thing: CutOffBatchDate__c = today's date at 6:00pm Hawaii Standard Time.
 * 4) This Apex job should be scheduled to run every day at 4:30pm Hawaiian Standard time. (note: you may not have to hardcode the 4:30pm time in steps 2) and 3) if you just schedule it to run and 6pm and set the fields to the current date and time.
 * 5) Can you add a button called "Close Day for All". When pressed it opens up a Progress Page and you can kick-off the job manually too? Exactly like PaymentXBatch. You can put it on the Fee Schedule page layout as well if that works.
 * Covered by: PaymentAutoCloserBatchTest
 * __________________________________________________________________________________
 * PacPoint-CL031319 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/13/2019
 * __________________________________________________________________________________
 */
global class PaymentAutoCloserBatch implements Database.Batchable<sObject>{
    global void execute(Database.BatchableContext bc, List<CollectionsAllocation__c> collectionsAllocations) {
        Map<Id, pymt__PaymentX__c> paymentsToUpdate = new Map<Id, pymt__PaymentX__c>();
        for (CollectionsAllocation__c cc : collectionsAllocations) {
            cc.CutOffBatchDate__c = Datetime.now();
            pymt__PaymentX__c p = cc.Payment__r;
            if (p.CutOffBatchDate__c == null && !paymentsToUpdate.containsKey(p.Id)) {
                p.CutOffBatchDate__c = Datetime.now();
                paymentsToUpdate.put(p.Id, p);
            }
        }

        update paymentsToUpdate.values();
        update collectionsAllocations;
    }

    global void finish(Database.BatchableContext bc) {
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, CutOffBatchDate__c, Payment__c, Payment__r.CutOffBatchDate__c';
        query += ' FROM CollectionsAllocation__c';
        query += ' WHERE CutOffBatchDate__c = null';
        query += ' AND ( (Payment__r.pymt__Status__c IN (\'Completed\', \'Voided\', \'BCF\')';
        query += ' AND Payment__r.CreatedBy.ExcludefromAutoClose__c = false) ';
        query += ' Or (Payment__r.CutOffBatchDate__c != null and Payment__r.pymt__Status__c = \'BCF\') ) ';
        return Database.getQueryLocator(query);
    }
}