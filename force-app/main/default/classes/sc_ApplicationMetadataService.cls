public class sc_ApplicationMetadataService {

    public static List<Application_Cache__c> createApplicationCache(String appId, String preValue) {
        Map<String, Map<String, String>> valueMap = new Map<String, Map<String, String>>();
        if(preValue != null && preValue != '' ){
         valueMap = (Map<String, Map<String, String>>) JSON.deserialize(
                    preValue, Map<String, Map<String, String>>.class);
        
        }
        String infoName = null;
        if(valueMap.get('settingName') != null && valueMap.get('settingName').get('value') != null){
            infoName  = valueMap.get('settingName').get('value');
        }
        
        List<Application_Meta_Data__c> appMetaDatas 
            = sc_ApplicationMetadataSelector.getApplicationMetaDataByIds(new List<String> {appId});
        
        List<Application_Cache__c> aCaches 
            = (new sc_ApplicationMetadataDomain(appMetaDatas)).initiateApplicationCache(preValue);
        insert aCaches;
        return aCaches;
    }
}