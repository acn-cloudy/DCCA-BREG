public without sharing class sc_CardMetaDataSelector {
    public static List<Card_Meta_Data__c> getCardsByAppId(String appMetaDataId){
        return [SELECT Application_Meta_Data__c, Label__c, APPLICATION_META_DATA__R.APPMETAID__C, Name, CardMetaId__c,
            Footer__c, Header__c, Show_on_Initial_Load__c, Sort_Order__c, Type__c, NextActions__c FROM Card_Meta_Data__c where Application_Meta_Data__c=: appMetaDataId order by Sort_Order__c];
    }
    public static List<Card_Meta_Data__c> getCardsByAppIdAndName(String appMetaDataId, String cardMetaDataName){
        return [SELECT Application_Meta_Data__c, Label__c, APPLICATION_META_DATA__R.APPMETAID__C, Name, CardMetaId__c,
            Footer__c, Header__c, Show_on_Initial_Load__c, Sort_Order__c, Type__c, NextActions__c FROM Card_Meta_Data__c where Application_Meta_Data__c=: appMetaDataId and Name =: cardMetaDataName 
            order by Sort_Order__c];
    }
    public static List<Card_Meta_Data__c> getCardsAndFieldsByAppId(String appName){
        return [select id, Name, Header__c,Footer__c,sort_order__c,Label__c, Show_on_Initial_Load__c, Application_Meta_Data__c, NextActions__c
            from Card_Meta_Data__c where Application_Meta_Data__r.Name =: appName order by sort_order__c asc];
    }
    
    public static List<Card_Meta_Data__c> getCardsAndFieldsByAppName(String appName){
        return [select Id, Name, Header__c,Footer__c,sort_order__c,Label__c, Show_on_Initial_Load__c, Application_Meta_Data__c, Type__c, NextActions__c
            from Card_Meta_Data__c where Application_Meta_Data__r.Name =: appName order by sort_order__c asc];
    }
}