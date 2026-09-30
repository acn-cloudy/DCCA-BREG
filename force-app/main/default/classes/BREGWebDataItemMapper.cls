public abstract with sharing class BREGWebDataItemMapper {
    protected Map<String, BREGWebFilingWrapper> wrappersByWorkitemId;
    protected String sourceTableName;

    public BREGWebDataItemMapper(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId, String sourceTableName) {
        this.wrappersByWorkitemId = wrappersByWorkitemId;
        this.sourceTableName = sourceTableName;
    }

    /**
     * Reads all accessible records from the source table for all given work item IDs
     * in a single query. The filter field is resolved dynamically: breg_Case__c is used
     * when present on the object, otherwise Id is used.
     *
     * @param workitemIds - Set of Case Ids (work items) to query for
     * @return Map of workitemId to the list of SObject records for that work item
     */
    @SuppressWarnings('PMD.ApexCRUDViolation,PMD.ApexSOQLInjection')
    public virtual Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sourceTableName);
        if (targetType == null) {
            return new Map<String, List<SObject>>();
        }
        if (workitemIds == null || workitemIds.isEmpty()) {
            return new Map<String, List<SObject>>();
        }

        Schema.DescribeSObjectResult objDescribe = targetType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

        List<String> queryFields = new List<String>();
        for (String fieldApiName : fieldMap.keySet()) {
            if (fieldMap.get(fieldApiName).getDescribe().isAccessible()) {
                queryFields.add(fieldApiName);
            }
        }

        if (queryFields.isEmpty()) {
            return new Map<String, List<SObject>>();
        }

        String filterField = resolveCaseFilterField(fieldMap);
        String soql = 'SELECT ' + String.join(queryFields, ', ') + ' FROM ' + objDescribe.getName() + ' WHERE ' + filterField + ' IN :workitemIds';

        Map<String, List<SObject>> resultMap = new Map<String, List<SObject>>();
        for (SObject record : Database.query(soql)) {
            String key = (String) record.get(filterField);
            if (!resultMap.containsKey(key)) {
                resultMap.put(key, new List<SObject>());
            }
            resultMap.get(key).add(record);
        }
        return resultMap;
    }

    private String resolveCaseFilterField(Map<String, Schema.SObjectField> fieldMap) {
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
            if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
                for (Schema.SObjectType ref : fieldDesc.getReferenceTo()) {
                    if (ref.getDescribe().getName() == 'Case') {
                        return fieldDesc.getName();
                    }
                }
            }
        }
        return 'Id';
    }

    protected String buildStreet2(String line2, String line3) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(line2)) {
            parts.add(line2.trim());
        }
        if (String.isNotBlank(line3)) {
            parts.add(line3.trim());
        }
        return parts.isEmpty() ? null : String.join(parts, '\n');
    }
}