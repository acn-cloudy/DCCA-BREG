@isTest
public class sc_ApplicationControllerTest {
    @TestSetup
    static void makeData(){
        sc_TestDataFactory.prepareData();
    }

    public static List<String> createAppCache() {
        Application_Meta_Data__c data = [Select Id, Name from Application_Meta_Data__c limit 1]; 
        String appName = data.Name;
        String appId = data.Id;
        List<Card_Cache__c> caches = sc_TestDataFactory.prepareCardCaches();
        String value = caches[0].Values__c;
        Map<String, Object> valueData = (Map<String, Object>) JSON.deserializeUntyped(value);
        String listStr = sc_ApplicationController.createApplication (appId, null, caches[0].Name, valueData, null, null);
        List<String> ids = (List<String> ) JSON.deserialize(listStr, List<String>.class);
        return ids;
    }
    @isTest
    static void testService() {
        List<String> ids = createAppCache();
        List<Card_Cache__c> caches = sc_TestDataFactory.prepareCardCaches();
        String value = caches[1].Values__c;
        Map<String, Object> valueData = (Map<String, Object>) JSON.deserializeUntyped(value);

        Application_Meta_Data__c data = [Select Id, Name from Application_Meta_Data__c limit 1]; 
        String appCacheName = ids[0];
        String appName = data.Name;
        String appId = data.Id;

        String resultStr = sc_ApplicationController.loadCardComplete(appCacheName);
        
        sc_ApplicationController.saveDraftApplication (appName, appId, appCacheName, caches[1].Name, null, valueData, null);
        System.assert (resultStr != null);
    }

    @isTest
    static void testGetSummaryrecords() {
        List<String> ids = createAppCache();
        String appId = ids[2];
        String appName = ids[0];

        List<Card_Cache__c> caches = sc_TestDataFactory.prepareCardCaches();
        
        List<Card_Cache__c> cardCaches = new List<Card_Cache__c>();
        for(Integer i =1; i<caches.size(); i++) {
            Card_Cache__c cache = caches[i];
            Card_Cache__c cardC = new Card_Cache__c();
            cardC.Values__c = cache.Values__c;
            cardC.Application_Cache__c = appId;
            cardCaches.add(cardC);
        }
        insert cardCaches;

        Test.startTest();
        sc_ApplicationController.loadSummaryValues(appName);
        Test.stopTest();
    }

    @isTest
    static void testGetCurrentUserInfo() {
        sc_ApplicationController.getCurrentUserInfo();
    }

    @isTest
    static void testGetFieldFilters() {
        Application_Meta_Data__c data = [Select Id, Name from Application_Meta_Data__c limit 1]; 
        sc_ApplicationController.getFieldFilters(data.Name);
        sc_ApplicationController.getApplicationMetaData(data.Name);
        sc_ApplicationController.getCardMetaData(data.Name, 'test');
        sc_ApplicationController.getCardMetaData(data.Name, null);
    }

    @isTest
    static void testLoadPreValues() {
        List<String> ids = createAppCache();
        String appCacheName = ids[0];
        Test.startTest();
        sc_ApplicationController.loadPreValues(appCacheName);
        Test.stopTest();

    }

    @isTest
    static void testLoadCardValues() {
        List<String> ids = createAppCache();
        String appCacheName = ids[0];
        Test.startTest();
        sc_ApplicationController.loadCardValues(appCacheName);
        Test.stopTest();
    }
       
}