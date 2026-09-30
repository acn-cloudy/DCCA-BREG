public class PVL_SC_GeneratePicklistValues {
    public static Map<String, List<String>> generatePicklistValues() {
        List<LicenseType__c> licenseTypes = [Select Id, Name, BoardProgram__c, BoardProgram__r.Name from LicenseType__c where BoardProgram__c != null];
        List<String> boardPrograms = new List<String>();

        Map<String, List<String>> ltypes = new Map<String, List<String>>();
        for(LicenseType__c licenseType: licenseTypes) {
            if(!ltypes.containsKey(licenseType.BoardProgram__r.Name)) {
                boardPrograms.add(licenseType.BoardProgram__r.Name);
            }
            List<String> items = new List<String>();
            if(ltypes.containsKey(licenseType.BoardProgram__r.Name)) {
                items = ltypes.get(licenseType.BoardProgram__r.Name);
            }
            items.add(licenseType.Name);
            ltypes.put(licenseType.BoardProgram__r.Name, items);
        }
        return ltypes;
    }

    public static void generateFieldFilters() {
        String affectedFieldId = 'a3dHv0000000CDYIA2';
        String dependingFieldId = 'a3dHv0000000CDZIA2';
        generateFieldFilters(affectedFieldId, dependingFieldId);
    }
    
    public class FeedOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
    }
    public static void generateFieldFilters(String affectedFieldId, String dependingFieldId) {
        
        Field_Meta_Data__c dependingField = [Select Id, Name__c from Field_Meta_Data__c where Id =: dependingFieldId];
        String dependingFieldName = dependingField.Name__c;
        
        List<Field_Filter__c> filters = [Select Id from Field_Filter__c where Affected_Field_Meta_Data__c =: affectedFieldId];
        delete filters;
        Map<String, List<String>> ltypes = generatePicklistValues();
        List<Field_Filter__c> filtersForNew = new List<Field_Filter__c>();
        for(String lType: ltypes.keySet()) {
            Field_Filter__c record = new Field_Filter__c();
            record.Controlling_Field_Name__c = dependingFieldName;
            record.Controlling_Field_Value__c = lType;
            record.Affected_Field_Meta_Data__c = affectedFieldId;
            record.Field_attribute_to_be_updated__c = 'Values';
            List<String> items = ltypes.get(lType);
            items.sort();

            record.Values__c = convertItemsToStr(items);
            filtersForNew.add(record);
        }
        List<String> ltSet = new List<String>();
        ltSet.addAll(ltypes.keySet());
        ltSet.sort();
        
        Field_Meta_Data__c med = new Field_Meta_Data__c();
        med.Id = dependingFieldId;
        med.Values__c = convertItemsToStr(ltSet);
        update med;
        
        insert filtersForNew;
    }
    public static String convertItemsToStr(List<String> items) {
        List<FeedOption> options = new List<FeedOption>();
        for(String item: items) {
            FeedOption option = new FeedOption();
            option.label = item;
            option.value = item;
            options.add(option);
        }
        return JSON.serialize(options);
    }
}