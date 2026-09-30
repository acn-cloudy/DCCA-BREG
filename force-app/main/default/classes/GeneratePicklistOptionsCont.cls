public class GeneratePicklistOptionsCont {
    @AuraEnabled
    public static List<String> getApplicationRecordTypes() {
        List<RecordType> recordTypes = [Select Id, Name from RecordType where SObjectType = 'Application__c'];
        List<String> rtTypes = new List<String>();
        for(RecordType record: recordTypes) {
            rtTypes.add(record.Name);
        }
        return rtTypes;
    }

    public static Map<String, List<String>> generatePicklist(String recordTypeName, List<String> values) {
        List<LicenseType__c> records = [Select Id, Name, LicenseType__c, ApplicationRecordType__c 
            from LicenseType__c where ApplicationRecordType__c =: recordTypeName ];
        Map<String, List<String>> reValues = new Map<String, List<String>>();
        if(!records.isEmpty()) {
            for(LicenseType__c record: records) {
                String ltType = record.LicenseType__c;
                reValues.put(ltType, values);
            }
        }
        return reValues;
    }

    @AuraEnabled
    public static void updateInstructions(String appMetaDataName, String affectedFieldName, String dependingFieldName, String secondDependingFieldName){
        Field_Meta_Data__c affectedField = [Select Id, Name__c from Field_Meta_Data__c where Name =: affectedFieldName and Card_Meta_Data__r.Application_Meta_Data__r.Name =: appMetaDataName];
        delete [Select Id from Field_Filter__c where Affected_Field_Meta_Data__c =: affectedField.Id];
        Field_Meta_Data__c dependingField = [Select Id, Name__c from Field_Meta_Data__c where Name =: dependingFieldName and Card_Meta_Data__r.Application_Meta_Data__r.Name =: appMetaDataName];
        String dependingAPIFieldName = dependingField.Name__c;
        List<String> strs = new List<String>{'E - By Exam', 
            'R - By Reciprocity, Endorsement or Credentials', 'T - Temporary Military Spouse License Act 18 SLH 2021'};
        List<LicenseType__c> ltypes = [Select Id, LicenseType__c, InstructionsByExam__c, InstructionsByReciprocity__c from LicenseType__c where InstructionsByReciprocity__c != null or InstructionsByExam__c != null];
        Map<String, Field_Filter__c> fieldFilters = new Map<String, Field_Filter__c>();
        Map<String, Field_Filter__c> fieldChilderenFilters = new Map<String, Field_Filter__c>();
        for(LicenseType__c ltype: ltypes) {
            for(String str: strs) {
                String link;
                if(str == 'E - By Exam') {
                    link = ltype.InstructionsByExam__c;
                } else {
                    link = ltype.InstructionsByReciprocity__c;
                }
                if(link == null) continue;
                String uniqueKey = str + ltype.Id;
                Field_Filter__c record = new Field_Filter__c();
                record.Controlling_Field_Name__c = dependingAPIFieldName;
                record.Controlling_Field_Value__c = str;
                record.Affected_Field_Meta_Data__c = affectedField.Id;
                record.Field_attribute_to_be_updated__c = 'Values';
                record.Values__c = '<h1><p style="font-size:18px"><b>INSTRUCTIONS</b> </p><br>Before proceeding with this application, please read the instructions on what is required to apply for this License Type: '
                + '<a href="' + link + '" target="_blank">VIEW INSTRUCTIONS</a></h1>';

                fieldFilters.put(uniqueKey, record);
                Field_Filter__c record1 = new Field_Filter__c();
                record1.Controlling_Field_Name__c = secondDependingFieldName;
                record1.Controlling_Field_Value__c = ltype.LicenseType__c;
                record1.Affected_Field_Meta_Data__c = affectedField.Id;
                
                fieldChilderenFilters.put(uniqueKey, record1);
            }

            insert fieldFilters.values();
            for(String str: fieldFilters.keySet()) {
                Field_Filter__c parentFilter = fieldFilters.get(str);
                Field_Filter__c filter = fieldChilderenFilters.get(str);
                filter.Parent_Field_Filter__c = parentFilter.Id;
            }
            insert fieldChilderenFilters.values();
        }
        
        
        
    }

    @AuraEnabled
    public static void createFieldOptions(String recordTypeName, List<String> values, String appMetaDataName, String affectedFieldName, String dependingFieldName ){
        Field_Meta_Data__c affectedField = [Select Id, Name__c from Field_Meta_Data__c where Name =: affectedFieldName and Card_Meta_Data__r.Application_Meta_Data__r.Name =: appMetaDataName];
        Field_Meta_Data__c dependingField = [Select Id, Name__c from Field_Meta_Data__c where Name =: dependingFieldName and Card_Meta_Data__r.Application_Meta_Data__r.Name =: appMetaDataName];
        String dependingAPIFieldName = dependingField.Name__c;
        
        // List<Field_Filter__c> filters = [Select Id from Field_Filter__c where Affected_Field_Meta_Data__c =: affectedFieldId];
        // delete filters;
        Map<String, List<String>> ltypes = generatePicklist(recordTypeName, values);
        List<Field_Filter__c> filtersForNew = new List<Field_Filter__c>();
        for(String lType: ltypes.keySet()) {
            Field_Filter__c record = new Field_Filter__c();
            record.Controlling_Field_Name__c = dependingAPIFieldName;
            record.Controlling_Field_Value__c = lType;
            record.Affected_Field_Meta_Data__c = affectedField.Id;
            record.Field_attribute_to_be_updated__c = 'Values';
            List<String> items = ltypes.get(lType);
            items.sort();

            record.Values__c = PVL_SC_GeneratePicklistValues.convertItemsToStr(items);
            filtersForNew.add(record);
        }

        insert filtersForNew;
    }
    
}