public without sharing class LicenseTypeCashierCodeSelector {
    public static List<LicenseTypeCashierCode__c> cashierCodes {
        get {
            if(cashierCodes == null) {
                cashierCodes =  [
                    SELECT Id, Type__c, Status__c, LicenseType__c, CashierCode__c, 
                    CashierCode__r.CashierCode__c, ActiveInactive__c, FeeAmount__c, 
                    MethodofLicensure__c, Island__c, Privilege__c, RenewalFeePeriod__c, 
                    Classification__c, PermitFee__c
                    FROM LicenseTypeCashierCode__c];
            }
            return cashierCodes;

        }
        set {}
    }
    public static List<LicenseTypeCashierCode__c> getLicenseTypeCashierCodes(Set<String> appType, Set<String> appStatus,
            Set<String> appLicenseType) {
        return (new LicenseTypeCashierCodeDomain(cashierCodes)).filterCodes(appType, appStatus, appLicenseType, null);
    }
    public static List<LicenseTypeCashierCode__c> getLicenseTypeCashierCodes(Set<String> appType, Set<String> appStatus,
            Set<String> appLicenseType, Set<String> appCurrentLicenseYear) {
        return (new LicenseTypeCashierCodeDomain(cashierCodes)).filterCodes(appType, appStatus, appLicenseType, appCurrentLicenseYear);
    }

    public static List<LicenseTypeCashierCode__c> getLicenseTypeCashierCodesRenewal(Set<String> appLicenseType) {
        return (new LicenseTypeCashierCodeDomain(cashierCodes)).filterRenewalCodes(appLicenseType);
    }
    
    public static List<LicenseTypeCashierCode__c> getLicenseTypeCashierCodesRenewal(String filter) {
        String query = 'SELECT Id, Type__c, Status__c, LicenseType__c, CashierCode__c, CashierCode__r.CashierCode__c, ActiveInactive__c, ';
        query += 'FeeAmount__c, MethodofLicensure__c, Island__c, Privilege__c, RenewalFeePeriod__c, Classification__c ';
        query += 'FROM LicenseTypeCashierCode__c ';
        query += 'WHERE Type__c = \'RNEW - Renewal\' ';

        if(filter != null){
            query += ' AND ' + filter;
        }

        query += ' ORDER BY FeeAmount__c';

        System.debug('EMEL');
        System.debug(query);
        
        return Database.query(query);
    }
}