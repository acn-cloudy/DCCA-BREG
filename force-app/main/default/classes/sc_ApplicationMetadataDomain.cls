public class sc_ApplicationMetadataDomain extends SObjectDomain {
    public sc_ApplicationMetadataDomain(List<Application_Meta_Data__c> appMetadata){
        super(appMetadata);
    }
    public List<Application_Cache__c> initiateApplicationCache(String preValue) {
    
        Map<String, Map<String, String>> valueMap = new Map<String, Map<String, String>>();
        if(preValue != null && preValue != '' ){
            valueMap = (Map<String, Map<String, String>>) JSON.deserialize(
                    preValue, Map<String, Map<String, String>>.class);
        
        }
        List<Application_Cache__c> caches = new List<Application_Cache__c>();
        for(SObject record: records) {
            Application_Meta_Data__c appMeta = (Application_Meta_Data__c)record;
            Application_Cache__c acache = new Application_Cache__c ();
            acache.Application_Meta_Data__c = appMeta.Id;
            acache.Label__c  = appMeta.Label__c;
            acache.Name = appMeta.Name;      
            acache.Status__c = 'Draft';
            acache.Sub_Type_Data__c = preValue;
            acache.Section__c = appMeta.Section__c;
            caches.add(acache);
        }
        return caches;
    }
    

}