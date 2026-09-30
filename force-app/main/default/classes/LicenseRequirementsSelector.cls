/**** 
* ─────────────────────────────────────────────────────────
* class for selecting Data from the License Requirements
* ─────────────────────────────────────────────────────────
* PacPoint-CZ060819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-09-06
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseRequirementsSelector {
    public static List<LicenseRequirements__c> getLicenseRequirements(List<String> licenseIds) {
        return [Select Id, Name, Requirement__c, ParentLicenseRequirement__c, RequirementShortDescription__c, RequirementLongDescription__c from LicenseRequirements__c where License__c in: licenseIds];
    }
}