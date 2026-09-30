@isTest
private class AssociatedLicenseSelectorTest {
    @TestSetup  
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }
    @isTest 
    private static void testQueryAssociatedLicenses() {
        List<AssociatedLicense__c> associatedLicenses = [Select Id, EmployeeLicense__c from AssociatedLicense__c ];
        List<String> licenseIds = new List<String>();
        Set<String> licenseIdSet = new Set<String>();
        List<Id> recordIds = new List<Id>();
        Set<Id> recordIdList = new Set<Id>();
        for(AssociatedLicense__c record: associatedLicenses) {
            recordIds.add(record.Id);
            licenseIdSet.add(record.Id);
            licenseIds.add(record.Id);
            recordIdList.add(record.Id);
    
        }
        AssociatedLicenseSelector.getAssociatedLicenses(recordIds);
        AssociatedLicenseSelector.getEmployedAssociatedLicenses(recordIds);
        AssociatedLicenseSelector.getEntityLicenseCount(licenseIds);
        AssociatedLicenseSelector.getPrincipalAssociatedLicenses(licenseIdSet);
        AssociatedLicenseSelector.getEntityAssociatedLicenses(licenseIdSet);
        AssociatedLicenseSelector.getAssociatedEmployeeLicenses(recordIds);
        AssociatedLicenseSelector.getActiveEmployerLicenses(recordIdList);
        AssociatedLicenseSelector.getTerminatedEmployerLicenses(recordIdList);
        AssociatedLicenseSelector.getAssociatedLicensesForEmployerAddressUpdate(' WHERE Id IN (\'' + String.join(recordIds, '\',\'') + '\')');
    }
    
}