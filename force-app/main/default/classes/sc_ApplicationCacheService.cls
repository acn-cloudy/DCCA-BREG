/***
 * Description: Used to be the staring point for the business logics for Application Cache(Draft Application)
 * Created By: Alvin Zhou
 * Date: 25/09/2018
*****/
public without sharing class sc_ApplicationCacheService {
    private static Set<String> draftWithOwnerUpdated = new Set<String>();
    private static Set<String> submittedDraftIds = new Set<String>();
    public class CacheException extends Exception {}
    /****
     * Used by ApplicationService - getApplicationMetaData
     * @Param: appId @Type: String
     * Description: if no results, throw an expcetion.
    *****/
    public static List<Application_Cache__c> getApplicationCacheByName(String appName) {
        List<Application_Cache__c> applicationCaches 
            = sc_ApplicationCacheSelector.getApplicationCacheByName(appName);
            
        if(applicationCaches.isEmpty()) {
            throw new CacheException(sc_GlobalConstants.ERROR_APP_CACHE_NOT_FIND + appName);
        }
        return applicationCaches;
    }
   
    /****
        Used to return card name => list of field meta data records
    ***/
    public static List<sc_CardFeed> getCardFeeds (String draftAppId) {
        List<Application_Cache__c> draftApps = sc_ApplicationCacheSelector.getApplicationCacheById(draftAppId);
        if(draftApps.isEmpty()) {
            return new List<sc_CardFeed>();
        }
        Application_Cache__c record = draftApps.get(0);
        List<String> appMetaDataIds = (List<String>) (new sc_ApplicationCacheDomain(draftApps)).getFieldValues('Application_Meta_Data__c');
        return sc_CardMetaDataService.getCardToFields(appMetaDataIds.get(0));
    }
    /******
        Used to return the card name and list of Field Meta Data records
    *****/
    public static Map<String, List<Field_Meta_Data__c>> getCardToFields (String draftAppId) {
        List<Application_Cache__c> draftApps = sc_ApplicationCacheSelector.getApplicationCacheById(draftAppId);
        if(draftApps.isEmpty()) {
            return new Map<String, List<Field_Meta_Data__c>> ();
        }
        Application_Cache__c record = draftApps.get(0);
        List<String> appMetaDataIds = (List<String>) (new sc_ApplicationCacheDomain(draftApps)).getFieldValues('Application_Meta_Data__c');
        Map<String, Map<String, List<Field_Meta_Data__c>>> appMetaToFieldMeta = sc_FieldMetaDataService.getFields(appMetaDataIds);
        return appMetaToFieldMeta.get(record.Application_Meta_Data__c);
    }

}