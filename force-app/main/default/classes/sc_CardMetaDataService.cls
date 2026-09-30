public class sc_CardMetaDataService {
    
    /****
     * Description: get list of cards and fields by applicaiton name
     * Used by : by sc_onboardingController.getCard
     *           Revenue_ApplicationController.getMyObjects
     *  
    *****/
    public static List<sc_CardFeed> getCardsAndFieldsByAppName(String appName){
        List<Card_Meta_Data__c> cardMetaData 
            = sc_CardMetaDataSelector.getCardsAndFieldsByAppName(appName);
        List<Field_Meta_Data__c> fieldMetaData 
            = sc_FieldMetaDataSelector.getFieldMetaDataByAppName(appName);
        
        Map<String, List<Field_Meta_Data__c>> fieldMeta 
            = (new sc_FieldMetaDataDomain(fieldMetaData)).getCardToFieldsMap();
        List<Card_Meta_Data__c> filterCards = (List<Card_Meta_Data__c>)(new sc_CardMetaDataDomain(cardMetaData)).filterRecords('Type__c', 'Shared by children');
        filterCards = (List<Card_Meta_Data__c>)(new sc_CardMetaDataDomain(filterCards)).filterRecords('Type__c', 'Hidden');
        return (new sc_CardMetaDataDomain(filterCards)).updateCardWithFields(fieldMeta);
    }
    
    /***
        Description: get cards from the application metadata Id
        Used By: sc_ApplicationCacheService.getCardFeeds
    ****/
    public static List<sc_CardFeed> getCardToFields(String appMetaId) {
        List<Card_Meta_Data__c> cards = sc_CardMetaDataSelector.getCardsByAppId(appMetaId);
        return getCardFeeds(appMetaId, cards);
    }
    /***
        Description: get cards from the application metadata Id and Cards
        Used By: CardMetaDataService.getSharedCards
    ****/
    public static List<sc_CardFeed> getCardFeeds(String appMetaId, List<Card_Meta_Data__c> cardMetaData) {
        List<Field_Meta_Data__c> fields = sc_FieldMetaDataSelector.getFieldMetaDataByAppIds((new List<String>{appMetaId}));
        Map<String, List<Field_Meta_Data__c>> fieldMeta 
            = (new sc_FieldMetaDataDomain(fields)).getCardToFieldsMap();
        return (new sc_CardMetaDataDomain(cardMetaData)).updateCardWithFields(fieldMeta);    
    }

    /****
     * Description: get list of cards and fields by applicaiton name
     * Used by : by sc_onboardingController.getCard
     *           Revenue_ApplicationController.getMyObjects
     *  
    *****/
    public static List<sc_CardFeed> getCards(String appName){
        
        List<Card_Meta_Data__c> cardMetaData 
            = sc_CardMetaDataSelector.getCardsAndFieldsByAppName(appName);
        List<Card_Meta_Data__c> cards = new List<Card_Meta_Data__c>();
        for(Card_Meta_Data__c card: cardMetaData ) {
            cards.add(card);
        }

        List<Field_Meta_Data__c> fieldMetaData 
            = sc_FieldMetaDataSelector.getFieldMetaDataByAppName(appName);
            
        // List<Field_Meta_Data__c> extrafieldMetaData 
        //     = FieldMetaDataSelector.getFieldMetaDataByAppName(extraCardMeta.Application_Meta_Data__r.Name);
        // fieldMetaData.addAll(extrafieldMetaData);     
        Map<String, List<Field_Meta_Data__c>> fieldMeta 
            = (new sc_FieldMetaDataDomain(fieldMetaData)).getCardToFieldsMap();
        List<Card_Meta_Data__c> filterCards = (List<Card_Meta_Data__c>)(new sc_CardMetaDataDomain(cards)).filterRecords('Type__c', 'Hidden');
        return (new sc_CardMetaDataDomain(filterCards)).updateCardWithFields(fieldMeta);
    }
    
    public static void getFieldByAppName(String appName) {
                
    }
    
}