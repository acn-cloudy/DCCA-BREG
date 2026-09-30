@isTest
private class AssociatedInsuranceSuspenseBatchTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }

    @isTest
    static void testBatch() {
        
        List<AssociatedLicense__c> records = [
            Select Id, Dual__c, EmployeeLicense__r.LicenseType__r.DualRMELosesEmployerDuetoInsurance__r.Name, 
            EntityLicense__c, EmployeeLicense__c, EmploymentStatus__c, EndDate__c, Position__c, 
            EmployeeLicense__r.LicenseType__r.RMELosesEmployerDuetoInsurance__r.Name 
            from AssociatedLicense__c];
        for(AssociatedLicense__c record: records) {
            record.EmploymentStatus__c = 'Employed';
        }
        update records;
        List<String> entityLicenseIds = (List<String>) (new AssociatedLicenseDomain(records)).getFieldValues('EntityLicense__c');
        Test.startTest();
        (new AssociatedInsuranceSuspenseBatch(entityLicenseIds)).execute(null, records);
        Test.stopTest();
    }
}