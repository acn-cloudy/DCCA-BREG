public without sharing class CATV_WithoutSharingUtility {

    @AuraEnabled(cacheable=true)
    public static Id getParentId(Id feedItemId) {
        String prefix = String.valueOf(feedItemId).substring(0, 3);
        if (prefix == '0D7') {
        FeedComment fc = [SELECT ParentId FROM FeedComment WHERE Id = :feedItemId LIMIT 1];
        return fc.ParentId;
        } else if (prefix == '0D5') {
            FeedItem fi = [SELECT ParentId FROM FeedItem WHERE Id = :feedItemId LIMIT 1];
            return fi.ParentId;
        }else {
            throw new IllegalArgumentException('Invalid FeedItem or FeedComment ID: ' + feedItemId);
        }
        
    }

    public static void doInsert( List<SObject> sobj){
        insert sobj;
    }
    
    public static void doInsert( SObject sobj){
        insert sobj;
    }
    
    public static void doUpsert( List<SObject> sobjs){
        Database.upsert(sobjs);
    }
    
    public static void doUpsert( SObject sobj){
        Database.upsert(sobj);
    }
    
    public static void doDelete( SObject sobj){
        delete sobj;
    }
    
    public static void doDelete( List<SObject> sobjs){
        delete sobjs;
    }
    
    public static void doUpdate( SObject sobj){
        update sobj;
    }
    
    public static void doupdate(List<sObject> sobjs){
        update sobjs;
    }

    public static List<SObject> queryRecords(String query, Map<String, Object> bindMap){
        return Database.queryWithBinds(query, bindMap, AccessLevel.SYSTEM_MODE);
    }

    public static List<User> fetchUserFromContactId(String conId){
        return [SELECT Id, Name FROM User 
                WHERE ContactId = :conId];
    }
    
    public static List<User> fetchUserFromContactSet(Set<Id> allContactSet){
        return [SELECT Id, ContactId FROM User 
                WHERE ContactId IN :allContactSet AND IsActive = true];
    }
    
    public static List<AccountContactRelation> fetchAcrRecords(Set<Id> allAccountIdSet){
        return [SELECT Id, ContactId, AccountId FROM 
                AccountContactRelation 
                WHERE AccountId IN :allAccountIdSet];
    }
}