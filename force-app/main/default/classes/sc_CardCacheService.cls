public without sharing class sc_CardCacheService {
    
    public static Card_Cache__c createCardCache(String cardname, String aCacheid,
                    Map<String, Object> comps){
                        
        Card_Cache__c ccard = new Card_Cache__c();
        ccard.Name = cardname;
        ccard.values__c = JSON.serialize(comps);
        ccard.Application_Cache__c = aCacheid;
        insert cCard;
        return cCard;
    }
    /*****
        Used to get card name => draft values map.
    ****/
    public static List<sc_SummaryFeeds>  getCardCaches(String appNo, 
                        Map<String, sc_CardFeed> allCards) {
        List<Card_Cache__c> dratValues = sc_CardCacheSelector.getCardCacheByAppName(appNo);
        return (new sc_CardCacheDomain(dratValues)).getValues(allCards);   
    }
}