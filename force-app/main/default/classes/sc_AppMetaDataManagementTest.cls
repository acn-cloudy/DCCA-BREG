@isTest
private class sc_AppMetaDataManagementTest {
    @TestSetup
    static void makeData(){
        sc_TestDataFactory.prepareData();
    }
    @isTest
    static void testBackupApp() {
        Application_Meta_Data__c record = [Select Id, Name from Application_Meta_Data__c limit 1];
        Test.startTest();
        sc_AppMetaDataManagement.backupApp(record.Id);
        Test.stopTest();
    }

}