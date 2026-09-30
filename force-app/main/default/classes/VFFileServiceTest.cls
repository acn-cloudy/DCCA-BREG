@isTest
private class VFFileServiceTest {
    @TestSetup
    static void makeData(){
        // create licenses
        TestDataFactory.createLicense();
    }
    @isTest
    static void testCreateFiles() {
        Test.startTest();
        // query license
        List<License__c> licenses = [Select Id from License__c];
        if(!licenses.isEmpty()) {
            Map<String, String> recordMap = new Map<String, String>();
            recordMap.put(licenses.get(0).Id, 'PlumberRenewalRefundNotice');
            List<String> strs = new List<String>();
            strs.add(JSON.serialize(recordMap));
            VFFileService.createFiles(strs);
        }
        Test.stopTest();
    }
    
    
}