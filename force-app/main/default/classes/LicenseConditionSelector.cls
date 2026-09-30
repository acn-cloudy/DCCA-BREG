/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Application
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-11-21
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseConditionSelector {
    public static List<LicenseConditions__c> getChildrenLicenses(Set<String> parentIds) {
        return [Select Id, Condition__c, License__c 
                from LicenseConditions__c where LicenseCondition__c in: parentIds];
    }
    public static List<LicenseConditions__c> getLicenseConditionsByLicenseIds(List<String> licenseIds) {
        return [Select Id, Status__c, RMEandEntity__c, 
                Overdue__c, LicenseCondition__c, License__c, DependentLicense__c, 
                DateDue__c, Condition__c from LicenseConditions__c where License__c in: licenseIds];

    }
}