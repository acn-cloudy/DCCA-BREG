public without sharing class sc_FieldMetaDataSelector {
    public static List<Field_Meta_Data__c> getFieldMetaDataByAppId(String appId){
        return [select Id, label__c, Name__c, Validation_Date__c, Name, Type__c, Card_Meta_Data__r.Name,Object__c,  ObjectField__c, Client_Email_Response_Field__c,
            Card_Meta_Data__r.Label__c, Card_Meta_Data__r.Application_Meta_Data__c, Default_value_field__c,Validation_Regression__c,
            Card_Meta_Data__r.Application_Meta_Data__r.Application_Id__c from Field_Meta_Data__c 
            where Card_Meta_Data__r.Application_Meta_Data__c =:appId];
    }
    
    public static List<Field_Meta_Data__c> getFieldMetaDataByAppIdToReview(String appId){
        return [select Id, label__c, Name__c, Validation_Date__c, Name, Type__c, Card_Meta_Data__r.Name,Object__c,  ObjectField__c, Client_Email_Response_Field__c,
            Card_Meta_Data__r.Label__c, Card_Meta_Data__r.Application_Meta_Data__c, Default_value_field__c, Validation_Regression__c,
            Card_Meta_Data__r.Application_Meta_Data__r.Application_Id__c from Field_Meta_Data__c 
            where Card_Meta_Data__r.Application_Meta_Data__c =:appId and Type__c != 'info' and Object__c != 'NA' ];
    }

    public static List<Field_Meta_Data__c> getFieldMetaDataByAppIdToReview(String appId, String cardMetaDataName) {
        return [select Id, label__c, Name__c, Validation_Date__c, Name, Type__c, Card_Meta_Data__r.Name,Object__c,  ObjectField__c, Client_Email_Response_Field__c,
            Card_Meta_Data__r.Label__c, Card_Meta_Data__r.Application_Meta_Data__c, Default_value_field__c, Validation_Regression__c,
            Card_Meta_Data__r.Application_Meta_Data__r.Application_Id__c from Field_Meta_Data__c 
            where Card_Meta_Data__r.Application_Meta_Data__c =:appId and Card_Meta_Data__r.Name =: cardMetaDataName and Type__c != 'info' and Object__c != 'NA' ];
    }

    public static List<Field_Meta_Data__c> getFieldMetaDataByAppIds(List<String> appIds){
        return [select Id, Name__c,Label__c,Validation_Date__c, Type__c,Object__c, Card_Meta_Data__r.Application_Meta_Data__c, Card_Meta_Data__c, Placeholder__c,Required__c,sort_order__c, Name, Values__c, Validation_numeric_only__c,Validation_Length__c, 
           Validation_Special_Chars__c, Validation_Email_Only__c,Validation_Phone_Only__c,Validation_ABN_Number__c,Read_Only__c, Validation_Numeric_greater_than_zero__c, 
           Parent_Object_Field_for_Input_Table__c, Target_Fields_For_Input_Table__c, Target_Object_Record_Type__c, Card_Meta_Data__r.Name, Validation_Regression__c,
           Validation_No_Space__c,Default_Value__c, Card_Dependent_Action__c,Validation_Min_Length__c,Card_Dependend_Value__c,DependendCards__c,Inline_Label__c, Client_Email_Response_Field__c,
           DependAction__c,DependField__c, DependValue__c,Hidden__c,Dependent_Value_to_be_set__c,input_table_cols__c, input_table_Field_types__c,Popover_Help__c, File_Upload_Holder_Object_Input_Table__c, 
           PicklistValues__c,Default_value_field__c, Use_Picklist_Values_From_SF__c, ObjectField__c from Field_Meta_Data__c where Active__c = true 
            and Card_Meta_Data__r.Application_Meta_Data__c in:appIds order by sort_order__c asc
        ];
    }
    
    public static List<Field_Meta_Data__c> getFieldMetaDataByAppName(String appName){
        return [select Id, Name__c,Label__c,Validation_Date__c,Type__c,Object__c,Card_Meta_Data__c, Placeholder__c,Required__c,sort_order__c, Name, Values__c, Validation_numeric_only__c,Validation_Length__c, 
           Validation_Special_Chars__c, Validation_Email_Only__c,Validation_Phone_Only__c,Validation_ABN_Number__c,Read_Only__c, Validation_Numeric_greater_than_zero__c, 
           Parent_Object_Field_for_Input_Table__c, Target_Fields_For_Input_Table__c, Target_Object_Record_Type__c, Validation_Regression__c,
           Validation_No_Space__c,Default_Value__c, Card_Dependent_Action__c,Validation_Min_Length__c,Card_Dependend_Value__c,DependendCards__c,Inline_Label__c, Client_Email_Response_Field__c,
           DependAction__c,DependField__c, DependValue__c,Hidden__c,Dependent_Value_to_be_set__c,input_table_cols__c, input_table_Field_types__c,Popover_Help__c, File_Upload_Holder_Object_Input_Table__c, 
           PicklistValues__c,Default_value_field__c, Use_Picklist_Values_From_SF__c, ObjectField__c from Field_Meta_Data__c where Active__c = true 
            and Card_Meta_Data__r.Application_Meta_Data__r.Name =:appName order by sort_order__c asc
        ];
    }

}