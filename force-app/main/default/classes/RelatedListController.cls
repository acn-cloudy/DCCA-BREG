public class RelatedListController {
    @auraEnabled
    public static String getRelatedRecords(String fields, String sobjectName, String parentField, 
                                           String parentId, String otherConditions, String sortBy) 
    {
        return JSON.serialize(getRecords(fields, sobjectName, parentField, parentId, otherConditions, sortBy));
	}
    @auraEnabled
    public static String getSubChildren(String fields, String sobjectName, 
                                        String parentField, String parentId, String otherConditions, 
                                       String exploreFields, String exploreSobjectName, 
                                        String exploreParentField, String soryBy )
    {
        Map<String, Integer> childrenMap = new Map<String, Integer>();
        if(exploreSobjectName == null || exploreSobjectName == '') {
            return JSON.serialize(childrenMap);
        }
        List<SObject> records = getRecords(fields, sobjectName, parentField, parentId, otherConditions);
        List<String> ids = new List<String>();
        for(SObject record : records) {
            ids.add(record.Id);
        }
        List<SObject> childrenRecords = getRecords(exploreFields, exploreSobjectName, exploreParentField, ids, null, soryBy);
        
        for(Sobject record: childrenRecords) {
            String sParentId = (String) record.get(exploreParentField);
            Integer count = childrenMap.get(sParentId);
            count = (count == null)? 0: count;
            count ++;
            childrenMap.put(sParentId, count);
        }
		return JSON.serialize(childrenMap);
    }
    
    public static List<SObject> getRecords(String fields, String sobjectName, String parentField, String parentId, String otherConditions) {
        return getRecords(fields, sobjectName, parentField, new List<String> {parentId}, otherConditions);
    }
    public static List<SObject> getRecords(String fields, String sobjectName, String parentField, String parentId, String otherConditions, String sortBy) {
        return getRecords(fields, sobjectName, parentField, new List<String> {parentId}, otherConditions, sortBy);
    }
    public static List<SObject> getRecords(String fields, String sobjectName, String parentField, List<String> parentIds, String otherConditions) {
        return getRecords(fields, sobjectName, parentField, parentIds, otherConditions, null);
    }
	public static List<SObject> getRecords(String fields, String sobjectName, String parentField, List<String> parentIds, String otherConditions, String sortBy) {
        Set<String> fieldSet = (Set<String>) JSON.deserialize(fields, Set<String>.class);
        if(!fieldSet.contains('Id') && !fieldSet.contains('id') && !fieldSet.contains('ID') && !fieldSet.contains('iD')) {
            fieldSet.add('Id');
        }
        
        List<String> fieldList = new List<String>();
        fieldList.addAll(fieldSet);
        String fieldStr = String.join(fieldList, ',');
		String query = 'Select ' + fieldStr +',  ' + parentField + ' from '+ sobjectName + ' where '+parentField+' in: parentIds ' ;
        if(otherConditions != null) 
	        query = query + otherConditions;
        if(sortBy != null ) {
            query += ' '+ sortBy;
        }
        System.debug('##query###' +query);
        return Database.query(query);
    }
}