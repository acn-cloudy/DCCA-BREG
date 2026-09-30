public class sc_FieldFilterDomain extends SObjectDomain {
    public sc_FieldFilterDomain(List<Field_Filter__c> fieldFilters) {
        super(fieldFilters);
    }
    public Map<String, List<List<Field_Filter__c>>> getFieldFilters (){
        Map<String, List<List<Field_Filter__c>>> fieldFilters = new Map<String, List<List<Field_Filter__c>>>();
        for(SObject record: records) {
            Field_Filter__c filter = (Field_Filter__c) record;
            
            String affectedFieldName = filter.Affected_Field_Meta_Data__r.Name__c;
            List<List<Field_Filter__c>> filters = fieldFilters.get(affectedFieldName);
            if(filters == null){
                filters = new List<List<Field_Filter__c>>();
            }
            
            List<Field_Filter__c> allFieldFilters = new List<Field_Filter__c>();
            allFieldFilters.add(filter);
            List<Field_Filter__c> childrenFilters = filter.Field_Filters__r;
            if(childrenFilters != null ){
               allFieldFilters.addAll(childrenFilters) ;
            }
            filters.add(allFieldFilters);
            
            fieldFilters.put(affectedFieldName, filters);
        }
        return fieldFilters;
    }
}