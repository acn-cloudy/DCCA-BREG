/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Checklist
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class LicenseTypeRequirementsSelector {
    // Case: 00003563
    public static List<LicenseTypeRequirements__c> getRequirementsByLicenseTypes(List<String> licenseTypes) {
        return [Select Id, LicenseType__c, Type__c, Required__c, Phase__c, MethodofLicensure__c, TypeofEntity__c, ActiveInactive__c, Requirement__c, Requirement__r.RequirementLongDescription__c, Requirement__r.RequirementShortDescription__c,
                Classification__c, Classification__r.Name from LicenseTypeRequirements__c where LicenseType__c in: licenseTypes and Status__c = 'Active' ];
    }
    public static List<LicenseTypeRequirements__c> getRequirementsByLicenseTypes(List<String> licenseTypes, List<String> phaseList, List<String> classificationIds, List<String> typeList){
        return [Select Id, LicenseType__c, Type__c, MethodofLicensure__c,
        TypeofEntity__c, ActiveInactive__c,
        // Changes to move License Type Requirement Matching to Requirements
        // Case: 00003563
        Requirement__c, Requirement__r.RequirementLongDescription__c, Requirement__r.RequirementShortDescription__c,

        Classification__c from LicenseTypeRequirements__c where LicenseType__c in: licenseTypes
        and Status__c = 'Active' AND Phase__c IN : phaseList AND Classification__c IN: classificationIds AND Type__c IN: typeList];
    }
}