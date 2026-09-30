/*
* ─────────────────────────────────────────────────────────
* class for the License Service used to handle 
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ100419 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-11-20
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseConditionService {
    private static Set<String> licenseConditionIdsForClone = new Set<String>();
    private static Set<String> licenseConditionParentIdsForDelete = new Set<String>();
    // 00006348
    // Capture for create
    public static void captureLicenseConditionForCreate(SObject so) {
        LicenseConditions__c condition = (LicenseConditions__c) so;
        if(condition.RMEandEntity__c && condition.DependentLicense__c != null ) {
            licenseConditionIdsForClone.add(condition.Id);
        }
    }
    // 00006348
    // Capture for create
    public static void captureLicenseConditionForCreate(SObject oldSo, SObject so) {
        LicenseConditions__c condition = (LicenseConditions__c) so;
        LicenseConditions__c oldCondition = (LicenseConditions__c) oldSo;
        if(condition.RMEandEntity__c && oldCondition.RMEandEntity__c != condition.RMEandEntity__c  ) {
            captureLicenseConditionForCreate(so);
        }
    }
    // 00006348
    // Capture for delete 
    public static void captureLicenseConditionForDelete(SObject so) {
        licenseConditionParentIdsForDelete.add(so.Id);
    }
    public static void captureLicenseConditionForDelete(SObject oldSo, SObject so) {
        LicenseConditions__c condition = (LicenseConditions__c) so;
        LicenseConditions__c oldCondition = (LicenseConditions__c) oldSo;
        if(!condition.RMEandEntity__c && oldCondition.RMEandEntity__c != condition.RMEandEntity__c  ) {
            captureLicenseConditionForDelete(so);
        }
    }
    
    // clone records.
    public static void cloneLicenseConditions(List<LicenseConditions__c> conditions) {
        if(licenseConditionIdsForClone.isEmpty()) {
            return;
        }
        List<LicenseConditions__c> filteredConditions 
                = (new LicenseConditionDomain(conditions)).filterRecords(licenseConditionIdsForClone);
        licenseConditionIdsForClone.clear();
        createLicenseConditions(filteredConditions);
    }
    public static void createLicenseConditions(List<LicenseConditions__c> records) {
        List<LicenseConditions__c> licenseConditions 
            = (new LicenseConditionDomain(records)).cloneLicenseConditions();
        TriggerHelper.disableLicenseConditionsTrigger = true;
        insert licenseConditions;
        TriggerHelper.disableLicenseConditionsTrigger = false;
    }
    // delete children records.
    public static void deleteLicenseCondtions() {
        if(licenseConditionParentIdsForDelete.isEmpty()) {
            return;
        }
        List<LicenseConditions__c> childLicenseConditions 
            = LicenseConditionSelector.getChildrenLicenses(licenseConditionParentIdsForDelete);
        licenseConditionParentIdsForDelete.clear();
        delete childLicenseConditions;
        
    }
    public static void runFinally(List<LicenseConditions__c> conditions) {
        if(Trigger.isAfter != null && Trigger.isAfter) {
            cloneLicenseConditions(conditions);
            deleteLicenseCondtions();
        }
        if(Trigger.isBefore != null && Trigger.isBefore) {
            if(Trigger.isDelete) {
                deleteLicenseCondtions();
            }
        }
    }

}