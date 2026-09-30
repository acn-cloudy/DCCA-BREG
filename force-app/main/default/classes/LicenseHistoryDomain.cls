public class LicenseHistoryDomain extends SObjectDomain {
    private final static string SELECTEDFORAUDIT = 'Selected for Audit';
    public LicenseHistoryDomain(List<LicenseHistory__c> histories) {
        super(histories);
    }

    public Set<String> checkExistingLicenses(Map<String, String> licenseId2LicensePeriodRNEW) {
        Set<String> licenseIds = new Set<String>();
        for(LicenseHistory__c record: (List<LicenseHistory__c>) records) {
            if(licenseId2LicensePeriodRNEW.containsKey(record.License__c)) {
                if(record.LicensePeriod__c == licenseId2LicensePeriodRNEW.get(record.License__c)) {
                    licenseIds.add(record.License__c);
                }
            }
        }
        return licenseIds;
    }

    public List<LicenseHistory__c> updateMarks() {
        List<LicenseHistory__c> recordsForUpdate = new List<LicenseHistory__c>();
        for(LicenseHistory__c record: (List<LicenseHistory__c>) records) {
            if(record.LicensePeriod__c == record.License__r.LicenseType__r.PreviousLicensePeriod__c) {
                if(record.Remarks__c == null || !record.Remarks__c.contains(SELECTEDFORAUDIT)) {
                    if(record.Remarks__c == null) record.Remarks__c = '';
                    record.Remarks__c = record.Remarks__c + ' ' + SELECTEDFORAUDIT; 
                    recordsForUpdate.add(record);
                } 
            }
        }
        return recordsForUpdate;
    }

    /****
         * 00030945
         * Find all Notifications on those Licenses with a DocumentTemplateName__c = CONTAINS
        (Notice of Audit)AND Status__c = "Scheduled"
        ANDSendToPrinter__c = True Set the Notification records found in Step 3
         and set the Notification.Status__c = "Cancelled"and SendToPrinter__c = false
         *** */

    public List<LicenseHistory__c> clearMarks() {
        List<LicenseHistory__c> recordsForUpdate = new List<LicenseHistory__c>();
        for(LicenseHistory__c record: (List<LicenseHistory__c>) records) {
            if(record.LicensePeriod__c == record.License__r.LicenseType__r.PreviousLicensePeriod__c) {
                if(record.Remarks__c != null && record.Remarks__c.contains(SELECTEDFORAUDIT)) {
                    record.Remarks__c = record.Remarks__c.replace(SELECTEDFORAUDIT, '');
                    recordsForUpdate.add(record);
                } 
            }
        }
        return recordsForUpdate;
    }


}