public class LicenseHistorySelector {
    public static List<LicenseHistory__c> getHistories(List<String> transactionTypes, List<String> licenseIds) {
        return [SELECT Id, Remarks__c, LicensePeriod__c, License__r.LicenseType__r.PreviousLicensePeriod__c, License__r.AuditNumber__c FROM LicenseHistory__c  WHERE TransactionType__c in: transactionTypes 
            AND License__c in: licenseIds];
    }

    public static List<LicenseHistory__c> getPostAuditLicenseHistories(List<String> transactionTypes, List<String> licenseIds) {
        return [SELECT Id, Remarks__c, LicensePeriod__c, License__r.LicenseType__r.PreviousLicensePeriod__c, License__r.AuditNumber__c FROM LicenseHistory__c  WHERE TransactionType__c in: transactionTypes 
            AND License__r.LicenseType__r.AuditType__c = 'Post-Audit' AND License__c in: licenseIds];
    }
    
}