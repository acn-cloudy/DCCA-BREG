@isTest
private class sc_FormBuilderControllerTest {
    @TestSetup
    static void makeData(){
        sc_TestDataFactory.prepareData();
        sc_ApplicationControllerTest.createAppCache();
    }
    @isTest
    static void testGetSummaryRecords() {
        Application_Cache__c draftApp = [Select Id, Name from Application_Cache__c limit 1];
        Test.startTest();
        // Put Id into the current page Parameters
        ApexPages.currentPage().getParameters().put('applicationref',draftApp.Name);
        sc_FormBuilderController con = new sc_FormBuilderController();
        System.assert(con.getSummaryRecords() != null);
        Test.stopTest();
    }

}