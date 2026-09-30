@isTest
private class LicenseDomainTest {
    @isTest
    static void testConvertToLicenseTypeIdToLicenses() { 
        TestDataFactory.createLicense();
        String query = 'Select Id, Status__c, Privilege__c, AuditNumber__c, ActiveInactive__c, GenerateFlaggedForAuditNotification__c, FlaggedforAudit__c, LicenseType__c, ' +
            'LicenseType__r.AuditActiveInactive__c, LicenseType__r.AuditStatuses__c, LicenseType__r.Id, LicenseType__r.NoticeOfAuditNotification__r.Name, ' +
            'LicenseType__r.SpecialPrivilege__c, LicenseType__r.AuditCushionPercent__c ' +
            'from License__c ';
        List<License__c> records = Database.query(query);
        Map<String, Integer> licenseTypeMap = new Map<String, Integer>();
        Map<String, Integer> licenseTypeNum = new Map<String, Integer>();
        for(Integer i=0;i<records.size(); i ++ ) {
            licenseTypeMap.put(records.get(i).LicenseType__c, (i + 1));
            licenseTypeNum.put(records.get(i).LicenseType__c, (i + 1));
        }
        (new LicenseDomain(records)).updateAuditNumberWithDedicateNumber(licenseTypeMap, licenseTypeNum);
        (new LicenseDomain(records)).updateAuditNumber(licenseTypeMap);


    }
}