public class sc_ApplicationMetadataSelector {
    public static List<Application_Meta_Data__c> getApplicationMetaDataByIds(List<String> ids){
        return [SELECT Id,Name,Parent_Object__c,Debug_Email__c,Debug_Mode__c,Client_Response_Email_Template_Name__c,Section__c,Label__c, Description__c, DefaultValue__c FROM Application_Meta_Data__c where id in: ids];
    }
    public static List<Application_Meta_Data__c> getApplicationMetaDataByName(String name){
        return [SELECT Id,Name,Parent_Object__c,Debug_Email__c,Debug_Mode__c,Client_Response_Email_Template_Name__c,Section__c,Label__c, Description__c, DefaultValue__c FROM Application_Meta_Data__c where Name =: name];
    }

}