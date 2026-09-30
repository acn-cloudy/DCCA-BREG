public without sharing class sc_FormBuilderController {
    public string appName {set; get;}
    public List<List<String>> summaryrecords = new List<List<String>>();
    public Application_Cache__c application{set;get;}
    public String description {set;get;}
    public sc_FormBuilderController() {
        appName = (String) ApexPages.currentPage().getParameters().get('applicationref');
        application = sc_ApplicationCacheSelector.getApplicationCacheByName(appName).get(0);
        description = application.Sub_Type__c != null ? application.Sub_Type__c: application.Application_Meta_Data__r.Description__c ;
    }
    
    public List<sc_SummaryFeeds> getSummaryRecords() {
        return loadSummaryValues(appName);
    }
    @AuraEnabled
    public static List<sc_SummaryFeeds> loadSummaryValues(String appCacheName) {
        Application_Cache__c draftApp = sc_ApplicationCacheSelector.getApplicationCacheByName(appCacheName).get(0);
        
        List<sc_CardFeed> cardFeeds = sc_ApplicationCacheService.getCardFeeds(draftApp.Id);        
        
        Map<String, sc_CardFeed> allCards = new Map<String, sc_CardFeed>();
        for(sc_CardFeed feed: cardFeeds) {
            allCards.put(feed.card.Name, feed);
        }
        

        
        System.debug('cardFeeds--' + cardFeeds);
        List<sc_SummaryFeeds> initialSumaryFeeds = new List<sc_SummaryFeeds>();
        String appType = draftApp.Application_Type__c;
           
        sc_SummaryFeeds section = new sc_SummaryFeeds();
        section.sectionLabel = 'Application Info';
        section.feeds = new List<sc_SummaryFeeds.Feed>();
        
        String subTypeDataStr = draftApp.Sub_Type_Data__c;
        if(subTypeDataStr == null ) {
            subTypeDataStr = '{}';
        }
        Map<String, Map<String, String>> dataValues= (Map<String, Map<String, String>>)JSON.deserialize(subTypeDataStr, 
                        Map<String, Map<String, String>>.class);
        for(String fieldLabel: dataValues.keySet()) {
            if(fieldLabel != 'settingName' && fieldLabel != 'reassessmentAppId') {
                String value = dataValues.get(fieldLabel).get('value');
                section.feeds.add(new sc_SummaryFeeds.Feed(fieldLabel, 
                        value ));
            }
        }
        
        if(!section.feeds.isEmpty()) {
            initialSumaryFeeds.add(section);
        }
        initialSumaryFeeds.addAll(sc_CardCacheService.getCardCaches(appCacheName, allCards));
        return initialSumaryFeeds;
    }
    
    
    
}