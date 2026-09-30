/*
* ─────────────────────────────────────────────────────────
* class for the License Handller used to handle 
* License trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ310819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-08-31
* ───────────────────────────────────────────────────────────
* Changes
*
* PacPoint EA02022024: Case 00033728
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseHandler implements ITrigger{
    public LicenseHandler() {}
    public void bulkBefore() {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        List<License__c> licenses = Trigger.new ;
        // Collect the license type values 
        if(Trigger.isInsert != null && Trigger.isInsert) {
            LicenseService.cacheRecordsForLicenseInitiation(licenses);
        }
        if (Trigger.isUpdate) {
            Map<Id, License__c> oldRecords = (Map<Id, License__c>)Trigger.oldMap;
            // 00026663
            Set<Id> ids = new Set<Id>();
            for(License__c record: licenses) {
                License__c oldRecord = oldRecords.get(record.Id);
                if(record.NumberofActiveEmployers__c != oldRecord.NumberofActiveEmployers__c 
                && record.NumberofActiveEmployers__c == 0
                && record.ActiveInactive__c != 'Inactive'
                && record.LicenseTypeName__c != 'MVD'
                && record.LicenseTypeDependencyRequired__c) {
                    ids.add(record.Id);
                }
            }
            if(!ids.isEmpty()) {
                licenseService.captureRecentTerminatedEmployers(ids);
            }
            
            LicenseActiveClassesValidation.runNumberOfActiveClassesValidation(licenses, oldRecords);
            licenseService.sendNoticeOfLicensure(Trigger.new, oldRecords);

            //Case 00021265
            List<String> licenseIdsForSendRenewalEmail = new List<String>();
            for (License__c l : licenses) {
                if (l.SendRenewalEmail__c) {
                    l.SendRenewalEmail__c = false;
                    if (l.PVL_Portal_User__c != null) {
                        licenseIdsForSendRenewalEmail.add(l.Id);
                    }
                }
            }

            if (!licenseIdsForSendRenewalEmail.isEmpty()) {
                licenseService.sendRenewalEmails(licenseIdsForSendRenewalEmail);
            }
        }
    }

    public void bulkAfter() {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        //licenseService.prepareDataForLicenseNumber(Trigger.new);
        if(Trigger.isUpdate && Trigger.isAfter) {
            List<License__c> licenses = Trigger.new;
            LicenseService.captureLicenseTypeRecords(licenses);
        }
    }
    public void beforeInsert(SObject so) {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        //system.debug('before insert logic >>>>');
        licenseService.populateLicenceName(so);
    }
    public void afterInsert(SObject so) {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        // 00004719
        licenseService.captureLicenseForClassification(so);
        // 00005902
        LicenseService.captureIdForFileGeneration(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {
        //was causing issue during deployment
        //look likes was added for troubleshooting. commenting this out for now
        //-chris l
        //        License__c rec = (License__c) so;
        //        if(rec.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due') {
        //            rec.addError('Test');
        //        }
        // Capture the license previous status
        //00007676
        licenseService.capturePreviousStatus(oldSo, so);
        licenseService.captureZTStatusChagne(oldSo, so);
        // 00011992
        LicenseService.captureUpdate(oldSo, so);

        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        //  Dymatic Create PDF 
        // 00005902
        licenseService.captureIdForFileGeneration(oldSo, so);
        //  Capture license conditions need for deletion.
        // 00006348
        licenseService.captureIdForLicenseConditionsRemove(oldSo, so);
        
        // 00012549
        LicenseService.generatePostCard(oldSo, so);

        // 00014637
        LicenseService.generateRenewalNotification(oldSo, so);
        
        //00033728        
        LicenseService.captureAMDInactivation(oldSo, so);
        
        // VPVL-13: Handle Sole Proprietor inactivation (must be in beforeUpdate to modify record)
        licenseService.captureSoleProprietorInactivation(oldSo, so);
        
        // VPVL-13: Handle RB-Entity closed business (must be in beforeUpdate to modify record)
        licenseService.captureRbEntityInactivationForAssociatedLicenses(oldSo, so);
        
    }
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        // Capture license conditions need for creation.
        // 00006348
        licenseService.captureIdForLicenseConditionsCreate(oldSo, so);

        // Trigger to perform a "Classification Check" and ensure Entities have the required RME Classifications
        // 00007697
        licenseService.performLicenseClassificationCheck(oldSo, so);

        //Create License History record when Business Address OR Mailing Address is changed
        //00008996
        licenseService.captureAddressesUpdate(oldSo, so);

        // Check Loss of Principal Suspense Process
        // 00010823
        LicenseService.capturePrincipalSuspenseProcess(oldSo, so);
        // Check Loss of Entity Suspense Process
        // 00010823
        LicenseService.captureEntitySuspenseProcess(oldSo, so);
        //00008669
        LicenseService.captureForActiveEmployersCal(oldSo, so);
        
    }
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        if(TriggerHelper.disableLicenseTrigger) {
            return;
        }
        licenseService.runInFinally(Trigger.new);
    } 
}