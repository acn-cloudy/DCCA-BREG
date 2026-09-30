public class FileDetailSelector {
    public static List<FileDetails__c> getFileDetails(List<String> recordIds) {
        return [
                SELECT
                        Id,
                        OwnerId,
                        Locked__c,
                        Exam__c,
                        Exam__r.OwnerId,
                        Exam__r.AssistantExaminer__c,
                        Exam__r.SkipCustomEditValidation__c,
                        Filing__r.AllowUserToPerformReviewer__c,
                        Filing__r.OwnerId,
                        Filing__r.Reviewer__c,
                        Filing__r.SkipReviewerEditValidation__c,
                        Filing__c
                FROM FileDetails__c
                WHERE Id IN: recordIds
        ];
    }
}