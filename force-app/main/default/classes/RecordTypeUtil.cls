public inherited sharing class RecordTypeUtil {

    public class InvocableParams {
        @InvocableVariable(label='SObject Api Name' required=true)
        public String objectApiName;
        @InvocableVariable(label='Record Type Name' required=true)
        public String recordTypeName;
    }

    // 1 less soql query need to make in flows
    @InvocableMethod(label='Get Record Type Id')
    public static Id[] getRecordTypeId(InvocableParams[] params) {
        Id[] ret = new Id[params.size()];
        for (Integer i = 0; i < params.size(); i++) {
            InvocableParams p = params[i];
            ret[i] = fflib_SObjectDescribe.getDescribe(p.objectApiName).getDescribe().getRecordTypeInfosByName().get(p.recordTypeName).getRecordTypeId();
        }
        return ret;
    }
 
    public static Map<String, Schema.RecordTypeInfo> getRecordTypeInfosByName(Schema.SObjectType token) {
        return fflib_SObjectDescribe.getDescribe(token).getDescribe().getRecordTypeInfosByName();
    }

    public static Map<Id, Schema.RecordTypeInfo> getRecordTypeInfosById(Schema.SObjectType token) {
        return fflib_SObjectDescribe.getDescribe(token).getDescribe().getRecordTypeInfosById();
    }

}