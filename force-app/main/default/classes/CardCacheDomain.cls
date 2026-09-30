public class CardCacheDomain extends SObjectDomain {
    public CardCacheDomain(List<Card_Cache__c> cardCaches) {
        super(cardCaches);
    }
    
    public Map<String, Card_Cache__c> getCardMeta2Cache() {
        Map<String, Card_Cache__c> cardMetaId2Cache = new Map<String, Card_Cache__c>();
        for(Card_Cache__c record: (List<Card_Cache__c>) records) {
            cardMetaId2Cache.put(record.Name, record);
        }
        return cardMetaId2Cache;
    }
}