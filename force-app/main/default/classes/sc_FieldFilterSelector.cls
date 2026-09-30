public class sc_FieldFilterSelector {
    public static List<Field_Filter__c> getFieldFiltersByAppName(String appName) {
        return [Select Id, Controlling_Field_Name__c, Controlling_Field_Value__c, Affected_Field_Meta_Data__c,
            Field_attribute_to_be_updated__c, Hidden__c, Label__c, Placeholder__c, Values__c,
            Popover_Help__c, Read_Only__c, Required__c, Affected_Field_Meta_Data__r.Name__c,
            (select Id,  Controlling_Field_Name__c, Controlling_Field_Value__c from Field_Filters__r) 
            from Field_Filter__c where Application_Name__c =: appName  and Parent_Field_Filter__c = null];
    }
}