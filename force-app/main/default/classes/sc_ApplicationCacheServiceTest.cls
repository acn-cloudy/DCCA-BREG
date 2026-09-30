@isTest
private class sc_ApplicationCacheServiceTest {
    @TestSetup
    static void makeData(){
        sc_TestDataFactory.prepareData();
        sc_ApplicationControllerTest.createAppCache();
    }
    @isTest
    static void testService() {
        Application_Cache__c cache = [Select Id, Name from Application_Cache__c limit 1]; 
        String appName = cache.Name;
        Test.startTest();
        sc_ApplicationCacheService.getApplicationCacheByName(appName);
        sc_ApplicationCacheService.getCardFeeds(cache.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetCardToFields() {
        Application_Cache__c cache = [Select Id, Name from Application_Cache__c limit 1]; 
        Test.startTest();
        sc_ApplicationCacheService.getCardToFields(cache.Id);
        Test.stopTest();
    }
   
}