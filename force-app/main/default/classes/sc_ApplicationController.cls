public without sharing class sc_ApplicationController {
    public class CustomException extends Exception{}
    public String appid {get; set;}
    public List<List<String>> summaryrecords = new List<List<String>>();
        
    public sc_ApplicationController(){
        try{ 
            appid = (String) ApexPages.currentPage().getParameters().get('applicationref'); 
        } catch (Exception e){
            
        }
    }

    public List<Object> getSummaryrecords(){
        List<Object>  res1 = (List<Object>)JSON.deserializeUntyped(loadSummaryValues(appid));
        return res1;
    }
    
    @AuraEnabled
    public static String getCurrentUserInfo(){
        return JSON.serialize(sc_UserSelector.getCurrentUserInformation());
    }
    @AuraEnabled
    public static String loadPreValues(String appCacheName) {
        List<Application_Cache__c> appCaches = sc_ApplicationCacheSelector.getApplicationCacheByName(appCacheName);
        if(appCaches.isEmpty()){
            return '';
        } else {
            return appCaches.get(0).Sub_Type_Data__c;
        }
    }
    
    @AuraEnabled
    public static String loadCardValues(String appCacheName) {
        List<Card_Cache__c> cardCaches = sc_CardCacheSelector.getCardCacheByAppName(appCacheName);
        Map<String, Card_Cache__c> nameToCardCache = (new sc_CardCacheDomain(cardCaches)).getNameToCardCaches();
        return JSON.serialize(nameToCardCache);
    }
    
    @AuraEnabled
    public static string submit(string appName) {
        Application_Cache__c taccid = [select id, Name from Application_Cache__c where Name=:appName  limit 1]; 
        taccid.Is_Submitted__c = true;
        update taccid;
        return JSON.serialize(taccid);
    }

    @AuraEnabled
    public static String getFieldFilters(String appName){
        return JSON.serialize(sc_FieldFilterService.getFieldFilters(appName));
    }
    
    @AuraEnabled
    public static string getCardMetaData(string appid, String appNo) {
        if(appNo != null) {
            return JSON.serialize(sc_CardMetaDataService.getCards(appid));
        }
        
        return JSON.serialize(sc_CardMetaDataService.getCardsAndFieldsByAppName(appid));
    }

    @AuraEnabled
    public static string createApplication (String appId, String formData,
            String cardName, Map<String, Object> comps, String preValue, String files) {
          // Create Applications;      
          List<Application_Cache__c> aCaches 
            = sc_ApplicationMetadataService.createApplicationCache(appid, preValue);
          
          // Create First Card;
		Card_Cache__c ccard = sc_CardCacheService.createCardCache(cardname, aCaches.get(0).Id, comps);
		ccard.Files__c = files;
        System.debug('##ccard###' +ccard);
		update ccard;
       	String cardId=ccard.id;
        Application_Cache__c tAccache = sc_ApplicationCacheSelector.getApplicationCacheById(aCaches.get(0).Id).get(0);
        String appCacheId = tAccache.Name; 
        tAccache.FormData__c = formData;
        update tAccache;
        return JSON.serialize(new List<String>{appCacheId, cardid, tAccache.Id});
    }

    @AuraEnabled
    public static string getFolderURL(String recordId){
        return SpringCMConnector.getFolderURL(recordId);
    }

    @AuraEnabled
    public static string saveDraftApplication(string appname, String appid, String appcacheid, String cardname, String cardcacheid, Map<String, Object> comps, String files) {
        Application_Cache__c draftApplication = sc_ApplicationCacheSelector.getApplicationCacheByName(appcacheid).get(0);
        if(draftApplication.Status__c != 'Submitted') {
            draftApplication.Status__c = 'In Progress';
            update draftApplication;
        }
        return saveApplication(appname, appid, appcacheid, cardname, cardcacheid, comps, files);
    }

    @AuraEnabled
    public static void cardUpdate(String recordId, String cardId){
        Card_Cache__c ccard = [select id, Files__c, Name, Application_Cache__c, values__c from Card_Cache__c where Id =:  cardId and Application_Cache__c =: recordId];
        DraftCardService.updateCardCachies(ccard);
    }

    
    @AuraEnabled
    public static string saveApplication(string appname, 
        String appid, String appcacheid, 
        String cardname, String cardcacheid, 
        Map<String, Object> comps, String files) {

      List<String> strlist = new List<String>();
      String str;
      String appcid;
      String cardId;
      if(appcacheId == null) {
        return createApplication(appId, '', cardName, comps, '', files );
      } else {
        Application_Cache__c draftApplication = sc_ApplicationCacheSelector.getApplicationCacheByName(appcacheId).get(0);
        Card_Cache__c ccard; 
        try { 
            ccard = [select id, Files__c, Name, Application_Cache__c, values__c from Card_Cache__c where Name=:  cardname and Application_Cache__c =: draftApplication.id];
            ccard.values__c = JSON.serialize(comps);
            ccard.Name = ccard.Name;
            ccard.Files__c = files;
            update ccard;
        }catch (Exception e){
            ccard = new Card_Cache__c();
            ccard.Name = cardname;
            ccard.values__c = JSON.serialize(comps);
            ccard.Files__c = files;
            ccard.Application_Cache__c = draftApplication.id;  
            insert ccard;
        }
        
        
        cardId=ccard.id;
        strlist.add(appcacheId);
        strlist.add(cardId);
        strlist.add(draftApplication.Id);
        return JSON.serialize(strlist);
      } 
    }

    @AuraEnabled
    public static string getApplicationMetaData(String name) {    
        List<Application_Meta_Data__c> records = sc_ApplicationMetadataSelector.getApplicationMetaDataByName(name);
        if(!records.isEmpty()) {
            return JSON.serialize(records.get(0));
        }
        return '';
    }
    
    @AuraEnabled
    public static string loadCardComplete(String appcacheid) {
        String res='';
        Map<String, boolean> vals = new Map<String, boolean>();
        Application_Cache__c accc = [SELECT id, Name, Application_Meta_Data__c FROM Application_Cache__c where Name =: appcacheid limit 1];
        
        for (Card_Cache__c cc:[select id, Application_Cache__c, values__c, Name from Card_Cache__c where Application_Cache__c =: accc.id]){
            vals.put(cc.Name, true);
        }
        
        return JSON.serialize(vals);
    }
    
    @AuraEnabled
    public static string loadSummaryValues(String appCacheName) {
        String res='';
        Map<String, Field_Meta_Data__c> fieldsMeta = new map<String, Field_Meta_Data__c>();
        List<List<String>> reslist = new List<List<String>>();
        Application_Cache__c taccid = [select id, Name, Application_Meta_Data__c from Application_Cache__c where Name =:appCacheName limit 1]; 
        List<Card_Cache__c> cards = [select id, Application_Cache__c, values__c, Name from Card_Cache__c where Application_Cache__c =: taccid.id order by CreatedDate];
        
        for (Field_Meta_Data__c fmd:[select id, Name, Name__c, Card_Meta_Data__r.Name from Field_Meta_Data__c where Card_Meta_Data__r.Application_Meta_Data__c =: taccid.Application_Meta_Data__c]){
            fieldsMeta.put(fmd.Name__c,fmd);
        }
        
        for (Card_Cache__c cc:cards){
            Map<String,Object> comps = (Map<String,Object>)JSON.deserializeUntyped(cc.Values__c);
            List<String> vallist = new List<String>();
            vallist.add(cc.Name);
            for (String key: new List<String>(comps.keySet())){
                String value = comps.get(key)+'';
                String keep = ((String)((Field_Meta_Data__c)fieldsMeta.get(key)).Name) + ': '+value.split(',')[0];
                if (keep.indexOf('null')==-1 && keep.indexOf('#')==-1){
                    vallist.add(keep);
                }
            }
            
            if (vallist.size()>0){
                reslist.add(vallist);
            }   
        }
        return JSON.serialize(reslist);
    }

}