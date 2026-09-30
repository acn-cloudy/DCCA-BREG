public class sc_ApplicationCacheSelector {
    public static  List<Application_Cache__c> getApplicationCacheById(String accId ) {
        return [select Id, AppDataBeforeSubmit__c, Application_Meta_Data__c, Application_Meta_Data__r.Name, Application_Meta_Data__r.Label__c, FormData__c, Status__c,
            Label__c, Name, Sub_Type_Data__c from Application_Cache__c where id=: accId];
    }
    public static  List<Application_Cache__c> getApplicationCacheByName(String name ){
        return [select Id, AppDataBeforeSubmit__c, Application_Meta_Data__c, Application_Meta_Data__r.Name, Application_Meta_Data__r.Label__c, FormData__c, Status__c,
            Label__c, Name,Application_Type__c, Sub_Type__c, Section__c, Application_Meta_Data__r.Description__c, Sub_Type_Data__c from Application_Cache__c where name =: name];
    }
}