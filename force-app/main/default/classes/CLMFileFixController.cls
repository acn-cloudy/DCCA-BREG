public class CLMFileFixController {
    @AuraEnabled
    public static string getFiles(){
        List<FileDetails__c> fileDetails = [Select Id, FileUrl__c, CreatedDate, ExternalFileURL__c from FileDetails__c where FileUrl__c != null and ExternalFileURL__c = null];
        return JSON.serialize(fileDetails.get(0));
    }

    @AuraEnabled
    public static void updateExternalFileURL(String recordId, String fileUrl, String des) {
        if(fileUrl != 'error') {
            FileDetails__c detail = [Select FileUrl__c, CreatedDate, ExternalFileURL__c from FileDetails__c where id =: recordId];
            if(!test.isRunningTest()) {
                SpringCMConnector.updateFileDesAndFolder(fileUrl, des, detail.Id);
            }
            
            detail.ExternalFileURL__c = detail.FileUrl__c;
            detail.FileUrl__c = fileUrl;
            update detail;
        } else {
            FileDetails__c detail = [Select FileUrl__c, CreatedDate, ExternalFileURL__c from FileDetails__c where id =: recordId];
            detail.ExternalFileURL__c = fileUrl;
            update detail;
        }
    }
    
    
}