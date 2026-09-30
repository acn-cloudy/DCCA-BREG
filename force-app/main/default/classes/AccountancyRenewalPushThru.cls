global class AccountancyRenewalPushThru extends ApplicationRenewalPushThru {
    global AccountancyRenewalPushThru() {
        super(new List<String> {'FPTP', 'FPTP - Sole Proprietor'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getCPAEmployeeAssociatedLicenses(licenseIds);
        List<String> entityLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        Set<String> entityLicenseIdsSet = new Set<String>(entityLicenseIds);
        List<Application__c> recordsForUpdate = (new ApplicationDomain(records)).filterApplicationByLicenseIds(entityLicenseIdsSet);
        this.appMap = new Map<Id, Application__c> (recordsForUpdate);
    }
    
}