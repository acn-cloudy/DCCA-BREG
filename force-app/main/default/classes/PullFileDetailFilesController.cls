public class PullFileDetailFilesController {
    @AuraEnabled
    public static void pullDownFiles(String recordId) {
        FileDetails__c detail = [Select Id, FileUrl__c from FileDetails__c where Id =: recordId];
        SpringCMConnector.updateFilesAndFolder(new List<String>{detail.FileUrl__c}, recordId);
    }
}