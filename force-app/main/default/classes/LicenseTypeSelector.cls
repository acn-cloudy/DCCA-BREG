/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the License Type
* ─────────────────────────────────────────────────────────
* PacPoint-AZ190619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-19
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class LicenseTypeSelector {
    // get list of license types
    public static List<LicenseType__c> getLicenseTypes(List<String> recordTypes) {
        return [Select Id, Name, ApplicationRecordType__c, LicenseType__c, AccountType__c , ApplicationPageLayout__c, AccountPageLayout__c,
                Status__c from LicenseType__c where Status__c = 'Active' and ApplicationRecordType__c in: recordTypes order by Name];
    }
    // get List of license types
    public static List<LicenseType__c> getLicenseTypes(List<String> recordTypes, String accountType) {
        return [Select Id, Name, ApplicationRecordType__c, LicenseType__c, AccountType__c , ApplicationPageLayout__c, AccountPageLayout__c,
                Status__c from LicenseType__c where Status__c = 'Active' 
                and AccountType__c =: accountType
                and ApplicationRecordType__c in: recordTypes order by Name];
    }

    public static List<LicenseType__c> getLicenseTypesByIds(List<String> licenseTypeIds) {
        return [Select Id, BoardProgram__c, LicenseNumberAssignmentCode__c, Apprentice__c, Branch__c, RestrictmorethanonelicenseperAccnt__c, 
                LicensePrefix__c, D2CERequired__c from LicenseType__c where Id in: licenseTypeIds];
    }

    public static List<LicenseType__c> getLicenseTypePeriods(Set<String> licenseTypeIds) {
        return [
            SELECT Id, NextLicensePeriod__c, PreviousLicensePeriod__c
            FROM LicenseType__c
            WHERE Id IN :licenseTypeIds 
        ];
    }
}