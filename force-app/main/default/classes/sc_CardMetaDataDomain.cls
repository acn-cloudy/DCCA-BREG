public with sharing class sc_CardMetaDataDomain extends SObjectDomain {
    public sc_CardMetaDataDomain(List<Card_Meta_Data__c> cardMeta){
        super(cardMeta);
    }
    
    public Map<String, Card_Meta_Data__c> getNameToMetadata(){
        Map<String, Card_Meta_Data__c> cardMetadataMap = new Map<String, Card_Meta_Data__c>();
        for(SObject record: records) {
            Card_Meta_Data__c card = (Card_Meta_Data__c) record;
            cardMetadataMap.put(card.Name, card);
        }
        return cardMetadataMap;
    }
    
    /****
     * Used by sc_CardMetaDataService.getCardsAndFieldsByAppName
    *****/
    public List<Card_Meta_Data__c> filterRecords(String fieldName, Object value) {
      List<Card_Meta_Data__c> filteredRecords = new List<Card_Meta_Data__c>();
        for(SObject record: records) {
            if(record.get(fieldName) != value) {
                Card_Meta_Data__c card = (Card_Meta_Data__c) record;
                filteredRecords.add(card);
            }
        }
        return filteredRecords;
  }
    public List<sc_CardFeed> updateCardWithFields(Map<String, List<Field_Meta_Data__c>> fieldMeta){
        List<sc_CardFeed> cardFeeds = new List<sc_CardFeed>();
        for(SObject record: records) {
            sc_CardFeed feed = new sc_CardFeed();
            Card_Meta_Data__c cardMeta = (Card_Meta_Data__c) record;
            feed.card = cardMeta;
            String cardId = cardMeta.Id;
            List<Field_Meta_Data__c> fieldMetaData = fieldMeta.get(cardId);
            if(fieldMetaData != null) {
                feed.fields = fieldMetaData;
            }
            cardFeeds.add(feed);
        }
        return cardFeeds;
    }
}