public class SanctionHandler implements ITrigger {
    static List<Sanction__c> sanctionsForPayments = new List<Sanction__c>();
    public void bulkBefore() {
        // Bulk before logic here
    }
    
    public void bulkAfter() {
        // Bulk after logic here
    }

    public void beforeInsert(SObject so) {
        // Not implemented
    }


    
    public void beforeUpdate(SObject oldSo, SObject newSo) {
        Sanction__c oldSanction = (Sanction__c)oldSo;
        Sanction__c newSanction = (Sanction__c)newSo;
        
        if (newSanction.GeneratePaymentSchedule__c 
            && oldSanction.GeneratePaymentSchedule__c != newSanction.GeneratePaymentSchedule__c) {
            sanctionsForPayments.add(newSanction);
        }
    }
    

    public void beforeDelete(SObject so) {
        // Not implemented
    }

    public void beforeUnDelete(SObject so) {
        // Not implemented
    }

    public void afterInsert(SObject so) {
        // Not implemented
    }

    public void afterUpdate(SObject oldSo, SObject newSo) {
        // Not implemented
    }

    public void afterDelete(SObject so) {
        // Not implemented
    }

    public void afterUnDelete(SObject so) {
        // Not implemented
    }

    public void andFinally() {
        if (!sanctionsForPayments.isEmpty() && Trigger.isAfter && Trigger.isUpdate) {
            SanctionService.generatePayments(sanctionsForPayments);
            sanctionsForPayments.clear();
        }
    }
}