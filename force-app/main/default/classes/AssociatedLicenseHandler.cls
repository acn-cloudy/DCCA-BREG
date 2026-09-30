public with sharing class AssociatedLicenseHandler implements iTrigger{
    public AssociatedLicenseHandler() {}
    public void bulkBefore() {}
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {
        // Skip if trigger is disabled (e.g., during batch processing)
        if (TriggerHelper.disableAssociatedLicenseTrigger) {
            return;
        }
        // 00009088
        AssociatedLicenseService.captureEmploymentStatusChange( so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        // Skip if trigger is disabled (e.g., during batch processing)
        if (TriggerHelper.disableAssociatedLicenseTrigger) {
            return;
        }
        AssociatedLicenseService.captureEmploymentStatusChange(oldSo, so);
        // VPVL-13: Handle BIC termination for RB-Entity
        AssociatedLicenseService.captureBicTerminationForRbEntity(oldSo, so);
        AssociatedLicenseService.captureLossOfSupervisor(oldSo, so);
    }
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        // Skip if trigger is disabled (e.g., during batch processing)
        if (TriggerHelper.disableAssociatedLicenseTrigger) {
            return;
        }
        if(Trigger.isAfter != null && Trigger.isAfter) {
            // 00008669
            AssociatedLicenseService.countLicenseRecords(); 
            // End
        }
    }
}