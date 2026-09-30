public without sharing class DraftApplicationDetailCont {
    @AuraEnabled
    public static string getDraftApp(String name){
        List<Application_Cache__c> draftApps = sc_ApplicationCacheService.getApplicationCacheByName(name);
        return JSON.serialize(draftApps);
    }

    @AuraEnabled
    public static string getApplicationMetaData(String name) {    
        List<Application_Meta_Data__c> records = sc_ApplicationMetadataSelector.getApplicationMetaDataByName(name);
        if(!records.isEmpty()) {
            return JSON.serialize(records.get(0));
        }
        return '';
    }

    @AuraEnabled
    public static string getUserInfo(String recordId) {    
        List<PVL_Portal_User__c> records = [Select Id, Email__c from PVL_Portal_User__c where Id =: recordId];
        if(!records.isEmpty()) {
            return JSON.serialize(records.get(0));
        }
        return '';
    }

    @AuraEnabled
    public static string decode(String data){
        String info = PVL_EncodingService.decode(data);
        return info;
    }
}