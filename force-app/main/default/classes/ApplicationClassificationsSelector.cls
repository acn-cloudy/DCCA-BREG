/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Application Calssification
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
public class ApplicationClassificationsSelector {
    public static List<ApplicationClassifications__c> getApplicationClassifications(
        List<String> applicationIds) {
        return [Select Id, Application__c, Classification__c, 
        Status__c,
        Comments__c, Classification__r.Name, Classification__r.Id  
        from ApplicationClassifications__c 
        where Application__c in: applicationIds];
    }

    public static List<ApplicationClassifications__c> getApplicationClassifications(
            List<String> applicationIds, List<String> statusList) {
        return [Select Id, Application__c, Classification__c, 
        Status__c, EffectiveStartDate__c,
        Comments__c, Classification__r.Name, Classification__r.Id  
        from ApplicationClassifications__c 
        where Application__c in: applicationIds and Status__c in: statusList];
    }

    public static List<Classification__c> getClassificationsByLicenseTypeIds(
            List<String> licenseTypeIds) {
        return [Select Id, Name, Code__c, Description__c, LicenseType__c, Remarks__c, Status__c
        from Classification__c 
        where LicenseType__c in: licenseTypeIds];
    }
}