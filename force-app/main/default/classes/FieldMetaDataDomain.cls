public class FieldMetaDataDomain extends SObjectDomain {
    public FieldMetaDataDomain(List<Field_Meta_Data__c> fieldMetaData){
        super(fieldMetaData);
    }
    // Summary the fields to be Object Name => List Field Names
    public Map<String, List<String>> getObj2FieldList() {
        Map<String, List<String>> obj2FieldList = new Map<String, List<String>>();
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c> )records) {
            List<String> fieldList = new List<String>();
            if(obj2FieldList.containsKey(record.Object__c)) {
                fieldList = obj2FieldList.get(record.Object__c);
            }
            fieldList.add(record.ObjectField__c);
            obj2FieldList.put(record.Object__c, fieldList);
        }
        return obj2FieldList;
    }
    // Summary the fields to be Card Meta Data => List Fields
    public Map<String, List<Field_Meta_Data__c>> getCardId2FieldList() {
        Map<String, List<Field_Meta_Data__c>> cardId2FieldList = new Map<String, List<Field_Meta_Data__c>>();
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c> )records) {
            List<Field_Meta_Data__c> fieldList = new List<Field_Meta_Data__c>();
            if(cardId2FieldList.containsKey(record.Card_Meta_Data__c)) {
                fieldList = cardId2FieldList.get(record.Card_Meta_Data__c);
            }
            fieldList.add(record);
            cardId2FieldList.put(record.Card_Meta_Data__c, fieldList);
        }
        return cardId2FieldList;
    }

    public Map<String, SObject> generateRecord(Card_Cache__c cache, Map<String, SObject> objMap) {
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c>) records) {
            if(record.Type__c != 'info' && record.Type__c != 'table') {
                String apiName = record.Name__c;
                String values = cache.Values__c;
                String fieldName = record.ObjectField__c;
                String objName = record.Object__c;
                if(fieldName == 'NA' || fieldName == 'Files') continue;
                Map<String, String> valueMap = (Map<String, String>) JSON.deserialize(values, Map<String, String>.class);
                if(valueMap.containsKey(apiName)) {
                    String value = valueMap.get(apiName);
                    if(value != 'null' && value != null && value != '') {
                        if(!Schema.getGlobalDescribe().containsKey(objName)) continue;
                        SObject obj = Schema.getGlobalDescribe().get(objName).newSObject();
                        if(objMap.containsKey(objName)) {
                            obj = objMap.get(objName);
                        }
                        try{
                            if(record.Type__c == 'date') {
                                obj.put(fieldName, Date.valueOf(value));
                            } else if(record.Type__c == 'checkbox') {
                                obj.put(fieldName, value == 'true');
                            } else {
                                obj.put(fieldName, value);    
                            }
                            objMap.put(objName, obj);
                            
                        } catch(Exception ex) {
                            try{
                                if(record.Type__c == 'picklist') {
                                    if(value == 'Yes') {
                                        obj.put(fieldName, true);
                                    } else {
                                        System.debug('#####Field objName#####' + objName + '#####Field api Name#####' + fieldName + '#####Field Label#####' + record.Label__c + '#####Field Type#####' + record.Type__c + '#####Field value#####' + value);    
                                    }
                                } else {
                                    System.debug('#####Field objName#####' + objName + '#####Field api Name#####' + fieldName + '#####Field Label#####' + record.Label__c + '#####Field Type#####' + record.Type__c + '#####Field value#####' + value);
                                }
                                
                            } catch (Exception ex1) {
                                System.debug('#####Field objName#####' + objName + '#####Field api Name#####' + fieldName + '#####Field Label#####' + record.Label__c + '#####Field Type#####' + record.Type__c + '#####Field value#####' + value);
                            }
                            
                        }
                        
                    }
                }
            }
        }
        return objMap;
    }

    public Map<String, List<SObject>> generateTables(Card_Cache__c cache, Map<String, List<SObject>> recordsMaps) {
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c>) records) {
            if(record.Type__c == 'table') {
                String apiName = record.Name__c;
                String values = cache.Values__c;
                String objName = record.Object__c;
                Map<String, String> valueMap = (Map<String, String>) JSON.deserialize(values, Map<String, String>.class);
                
                if(valueMap.containsKey(apiName)) {
                    String value = valueMap.get(apiName);
                    if(String.isBlank(value)) {
                        continue;
                    }
                    List<SObject> records = (List<SObject>) JSON.deserialize(value, List<SObject>.class);
                    List<SObject> allRecords = new List<SObject>();
                    if(recordsMaps.containsKey(objName)) {
                        allRecords = recordsMaps.get(objName);
                    }
                    allRecords.addAll(records);
                    recordsMaps.put(objName, allRecords);
                }
            }
        }
        return recordsMaps;
    }

    public Map<String, List<String>> generateFiles(Card_Cache__c cache, Map<String, List<String>> fileMaps) {
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c>) records) {
            if(record.Type__c == 'clm-file') {
                String apiName = record.Name__c;
                String values = cache.Values__c;
                String objName = record.Object__c;
                Map<String, String> valueMap = (Map<String, String>) JSON.deserialize(values, Map<String, String>.class);
                
                if(valueMap.containsKey(apiName)) {
                    String value = valueMap.get(apiName);
                    if(String.isBlank(value)) continue;
                    System.debug('####test value###' + value);
                    List<Map<String, String>> fMaps = (List<Map<String, String>>) JSON.deserialize(value,
                         List<Map<String, String>>.class);
                    for(Map<String, String> fMap: fMaps ) {
                        String fileUrl = fMap.get('fileUrl');
                        List<String> fileUrls = new List<String>();
                        if(fileMaps.containsKey(objName)) {
                            fileUrls = fileMaps.get(objName);
                        }
                        fileUrls.add(fileUrl);
                        fileMaps.put(objName, fileUrls);
                    }
                }
            }
        }
        return fileMaps;
    }
}