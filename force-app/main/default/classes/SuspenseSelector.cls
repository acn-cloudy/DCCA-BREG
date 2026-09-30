public with sharing class SuspenseSelector {
    public static List<Suspense__c> getSuspenseByIds(List<String> licenseIds) {
        return [
            Select Id, InsuranceType__c, SuspenseDueDate__c, License__c,License__r.LicenseType__r.Name from Suspense__c where License__c in: licenseIds
            and SuspenseDueDate__c >= Today
        ];
    }

    public static List<Suspense__c> getDueSuspenses(Set<String> licenseIds) {
        return [
            Select Id, InsuranceType__c, SuspenseDueDate__c, License__c,License__r.LicenseType__r.Name from Suspense__c where License__c in: licenseIds
            and SuspenseDueDate__c < Today and Delete__c = false and Historical__c = false
        ];
    }

    public static List<Suspense__c> getSuspenseByLicenseIds(List<String> licenseIds) {
        return [
            Select Id, InsuranceType__c,SuspenseStatus__c, SuspenseDueDate__c, 
            License__r.LicenseType__r.AutoForfeitureStatus__c,
            License__c, Historical__c, MaintenanceType__c,License__r.LicenseType__r.Name from Suspense__c 
            where License__c in: licenseIds and Historical__c = false AND License__r.LicenseType__r.Name NOT IN ('BAP', 'BEP', 'MAP') 
            order by CreatedDate
        ];
    }

    public static List<Suspense__c> getNFRMSuspenseByLicenseIds(List<String> licenseIds) {
        return [
            Select Id, InsuranceType__c,SuspenseStatus__c, SuspenseDueDate__c, License__c, Historical__c from Suspense__c 
            where License__c in: licenseIds and Historical__c = false and MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT' 
            order by CreatedDate];
    }

    public static DataBase.QueryLocator getSuspenseQueryLocator(String objectType, String selectFields, String filterCriteria) {
        return Database.getQueryLocator(String.format('SELECT {0} FROM {1} WHERE {2} ', new List<String>{selectFields, objectType, filterCriteria}));
    }
}