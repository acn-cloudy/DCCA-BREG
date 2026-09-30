@isTest
private class AssociatedLicenseDomainTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }
    @isTest
    static void testGetEntityLicenseIds() {
        List<AssociatedLicense__c> records = [Select Id, EntityLicense__r.Status__c ,EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c];
        (new AssociatedLicenseDomain(records)).getEntityLicenseIds();
        (new AssociatedLicenseDomain(records)).getMostRecentExpiredLicense();
        (new AssociatedLicenseDomain(records)).filterAssociatedLicensesByEntityId(new Map<String, String>());
    }
}