public class sc_CardCacheDomain extends SObjectDomain {
    public sc_CardCacheDomain(List<Card_Cache__c> cardCaches) {
        super(cardCaches);
    }
    public List<sc_SummaryFeeds> getValues(Map<String, sc_CardFeed> allCards){
        List<sc_SummaryFeeds> sections = new List<sc_SummaryFeeds>();
        for(SObject record: records) {
            Card_Cache__c draftCard = (Card_Cache__c) record;
            sc_CardFeed cardFeed = allCards.get(draftCard.Name);
            Map<String,Object> valueMap = (Map<String,Object>)JSON.deserializeUntyped(draftCard.Values__c);
            // Not show card which is marked as hidden.
            if(cardFeed== null || cardFeed.card.Type__c == 'Hidden') {
                continue;
            }
            sc_SummaryFeeds section = new sc_SummaryFeeds();
            section.sectionLabel = cardFeed.card.Label__c;
            List<Field_Meta_Data__c> fields = cardFeed.fields;
            section.Feeds = (new sc_FieldMetaDataDomain(fields)).getFieldValues(valueMap);
            sections.add(section);
        }
        return sections;
    }
    
    public Map<String, Card_Cache__c> getNameToCardCaches(){
        Map<String, Card_Cache__c> cardCaches = new Map<String, Card_Cache__c>();
        for(SObject record: records) {
            Card_Cache__c cardCache = (Card_Cache__c) record;
            cardCaches.put(cardCache.Name, cardCache);
        }
        return cardCaches;
    }
}