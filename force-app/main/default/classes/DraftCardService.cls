public class DraftCardService {
    public static void updateCardCachies(Card_Cache__c cardCache) {
        String appCacheId = cardCache.Application_Cache__c;
        List<Application_Cache__c> appCaches = sc_ApplicationCacheSelector.getApplicationCacheById(appCacheId);
        Application_Cache__c appCache = appCaches.get(0);
        String appMetaDataId = appCache.Application_Meta_Data__c;
        String cardMetaDataName = cardCache.Name;
        Map<String, Card_Cache__c> cardMetaId2Cache = (new CardCacheDomain(new List<Card_Cache__c>{cardCache})).getCardMeta2Cache();
        List<Field_Meta_Data__c> fieldMetaDatas = sc_FieldMetaDataSelector.getFieldMetaDataByAppIdToReview(appMetaDataId, cardMetaDataName);

        Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList = (new sc_FieldMetaDataDomain(fieldMetaDatas)).getCardId2FieldList();
        
        List<Card_Meta_Data__c> cardMetas = sc_CardMetaDataSelector.getCardsByAppIdAndName(appMetaDataId, cardMetaDataName);

        Map<String, SObject> objs = new Map<String, SObject>();
        if(appCache.AppDataBeforeSubmit__c != null)
            objs = (Map<String, SObject>) JSON.deserialize(appCache.AppDataBeforeSubmit__c, 
                Map<String, SObject>.class);
        objs = (new CardMetaDataDomain(cardMetas)).convert2AppData(cardMetaId2Cache, cardMetaId2FieldList, objs);
        appCache.AppDataBeforeSubmit__c = JSON.serialize(objs);
        update appCache;

    }
    
}