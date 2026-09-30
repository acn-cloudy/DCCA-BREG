public without sharing class sc_FieldMetaDataService {
    /****
     * Used to get field meta data needs to be captured
     * Used by: 
     * 
    ***/
    public static Map<String, Map<String, List<Field_Meta_Data__c>>> getFields(List<String> appIds) {
        // query all the field meta data records.
        List<Field_Meta_Data__c> fields = sc_FieldMetadataSelector.getFieldMetaDataByAppIds(appIds);
        Map<String, Map<String, List<Field_Meta_Data__c>>> appToFieldMeta = (new sc_FieldMetaDataDomain(fields)).getAppToFields();
        return appToFieldMeta;
    }

}