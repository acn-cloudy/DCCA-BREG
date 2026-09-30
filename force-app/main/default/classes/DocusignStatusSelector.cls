public with sharing class DocusignStatusSelector {
    public static List<dsfs__DocuSign_Status__c> getDocusignStatus(List<String> recordIds) {
        return [Select Id, TravelApproval__c, WorkSheet__c from dsfs__DocuSign_Status__c 
        where Id in: recordIds and (TravelApproval__c != null or WorkSheet__c != null)];
    }
}