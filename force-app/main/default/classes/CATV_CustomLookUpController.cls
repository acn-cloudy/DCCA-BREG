public with sharing class CATV_CustomLookUpController {
    
    private static String sanitizeString(String text){
        if(text != null && text.contains('%')){
            text = text.replace('%','\\%');
        }
        if(text != null && text.contains('_')){
            text = text.replace('_','\\_');
        }
        return text;
    }
    
    @AuraEnabled
    public static List<ResultWrapper> fetchRecords(SearchWrapper inputWrapper) {
        try {
            if(inputWrapper != null && String.isNotBlank(inputWrapper.searchString)){
                Map<String, Object> bindMap = new Map<String, Object>();
                List<String> orgTypeList = (List<String>) JSON.deserialize(String.escapeSingleQuotes(inputWrapper.selectedOrg), List<String>.class);
                bindMap.put('orgTypeList', orgTypeList);
                String query = 'SELECT Id, Type, Name  FROM Account ';
                
                String filterCriteria = inputWrapper.fieldApiName + ' LIKE ' + '\'' + String.escapeSingleQuotes(sanitizeString(inputWrapper.searchString.trim())) + '%\' LIMIT 10';
                
                if (String.isNotBlank(inputWrapper.selectedRecordId)) {
                    query += ' WHERE Id = \''+ String.escapeSingleQuotes(inputWrapper.selectedRecordId)  + '\'';
                } else if (String.isNotBlank(inputWrapper.selectedOrg)) {
                    query += ' WHERE Type IN : orgTypeList';
                    query += ' AND ' + filterCriteria;
                } else {
                    query += ' WHERE '+ filterCriteria;
                }
                List<ResultWrapper> returnWrapperList = new List<ResultWrapper>();
                
                Blob key = Blob.valueOf(System.Label.CATV_EncryptionKey);
                
                for(SObject s : CATV_WithoutSharingUtility.queryRecords(query, bindMap)) {
                    Blob cipherText = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf((String)s.get('id')));
                    String encodedCipherText = EncodingUtil.base64Encode(cipherText);
                    
                    ResultWrapper wrap = new ResultWrapper();
                    wrap.mainField = (String)s.get(inputWrapper.fieldApiName);
                    wrap.subField = (String)s.get(inputWrapper.otherFieldApiName);
                    wrap.id = encodedCipherText;
                    returnWrapperList.add(wrap);
                }
                return returnWrapperList;
            }
            return null;
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
    }
    
    public class ResultWrapper{
        @AuraEnabled public String mainField{get;set;}
        @AuraEnabled public String subField{get;set;}
        @AuraEnabled public String id{get;set;}
    }
    
    public class SearchWrapper {
        @AuraEnabled public String objectApiName{get;set;}
        @AuraEnabled public String fieldApiName{get;set;}
        @AuraEnabled public String otherFieldApiName{get;set;}
        @AuraEnabled public String searchString{get;set;}
        @AuraEnabled public String selectedRecordId{get;set;}
        @AuraEnabled public String parentRecordId{get;set;}
        @AuraEnabled public String parentFieldApiName{get;set;}
        @AuraEnabled public String selectedOrg{get;set;}
    }
}