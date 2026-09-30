public without sharing class sc_CardCacheSelector {
    public static List<Card_Cache__c> getCardCacheByAppName(String name) {
        return [select id, Application_Cache__c, Name, values__c, files__c, Card_Meta_Data__c from Card_Cache__c where Application_Cache__r.Name =: name order by CreatedDate];
    }
    public static List<Card_Cache__c> getCardCacheByIds(List<String> applicationCacheIds) { 
        return [select id, Application_Cache__c, Name, values__c, files__c, Card_Meta_Data__c from Card_Cache__c where Application_Cache__c in: applicationCacheIds order by CreatedDate]; 
    }
}