@isTest
private class LicenseEmployerAddressUpdateBatchTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }

    @isTest
    static void test_executeBatch() {
        Set<String> assocLiceIds = new Set<String>();
        for(AssociatedLicense__c assocLic: [Select Id from AssociatedLicense__c]){
            assocLiceIds.add(assocLic.Id);
        }
        
        Test.startTest();
        DataBase.executeBatch(new LicenseEmployerAddressUpdateBatch(assocLiceIds));
        Test.stopTest();
    }
}