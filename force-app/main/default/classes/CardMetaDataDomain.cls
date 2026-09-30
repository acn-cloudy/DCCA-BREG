public class CardMetaDataDomain extends SObjectDomain {
    public CardMetaDataDomain(List<Card_Meta_Data__c> cardMeta){    
        super(cardMeta);
    }

    public Map<String, SObject> convert2AppData(Map<String, Card_Cache__c> cardMetaId2Cache, 
        Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList, Map<String, SObject> objs) {
        for(Card_Meta_Data__c record: (List<Card_Meta_Data__c>) records) {
            Card_Cache__c cache = cardMetaId2Cache.get(record.Name);
            List<Field_Meta_Data__c> fieldList = cardMetaId2FieldList.get(record.Id);
            if(cache != null) {
                objs = (new FieldMetaDataDomain(fieldList)).generateRecord(cache, objs);
            }
        }
        return objs;
    }

    public Map<String, SObject> convert2AppData(Map<String, Card_Cache__c> cardMetaId2Cache, Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList) {
        Map<String, SObject> objs = new Map<String, SObject>();
        for(Card_Meta_Data__c record: (List<Card_Meta_Data__c>) records) {
            Card_Cache__c cache = cardMetaId2Cache.get(record.Name);
            List<Field_Meta_Data__c> fieldList = cardMetaId2FieldList.get(record.Id);
            if(cache != null) {
                objs = (new FieldMetaDataDomain(fieldList)).generateRecord(cache, objs);
            }
        }
        return objs;
    }
    public Map<String, List<String>> generateFiles(Map<String, Card_Cache__c> cardMetaId2Cache, Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList) {
        Map<String, List<String>> objs = new Map<String, List<String>>();
        for(Card_Meta_Data__c record: (List<Card_Meta_Data__c>) records) {
            Card_Cache__c cache = cardMetaId2Cache.get(record.Name);
            List<Field_Meta_Data__c> fieldList = cardMetaId2FieldList.get(record.Id);
            if(cache != null) {
                objs = (new FieldMetaDataDomain(fieldList)).generateFiles(cache, objs);
            }
        }
        return objs;
    }

    public Map<String, List<SObject>> generateTables(Map<String, Card_Cache__c> cardMetaId2Cache, Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList) {
        
        Map<String, List<SObject>> objs = new Map<String, List<SObject>>();

        for(Card_Meta_Data__c record: (List<Card_Meta_Data__c>) records) {
            Card_Cache__c cache = cardMetaId2Cache.get(record.Name);
            List<Field_Meta_Data__c> fieldList = cardMetaId2FieldList.get(record.Id);
            if(cache != null) {
                objs = (new FieldMetaDataDomain(fieldList)).generateTables(cache, objs);
            }
        }
        return objs;
    }
    
}