public class sc_FieldFilterService {
    public static Map<String, List<List<Field_Filter__c>>> getFieldFilters(String appName) {
        Map<String, List<List<Field_Filter__c>>> fieldFilters = new Map<String, List<List<Field_Filter__c>>>();
        List<Field_Filter__c> records = sc_FieldFilterSelector.getFieldFiltersByAppName(appName);
        fieldFilters = (new sc_FieldFilterDomain(records)).getFieldFilters();
        return fieldFilters;
    }
}