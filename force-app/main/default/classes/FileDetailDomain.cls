public with sharing class FileDetailDomain extends SObjectDomain {
    public FileDetailDomain(List<FileDetails__c> fileDetails) {
        super(fileDetails);
    }

    public void shareWithAssistantExaminers() {
        FileDetailSharer.shareWithAssistantExaminers(records);
    }

    @future
    public static void lockFileDetailsFuture(List<Id> fileDetailIds) {
        List<FileDetails__c> fdsForLocking = new List<FileDetails__c>();
        for (Id fdId : fileDetailIds) {
            fdsForLocking.add(new FileDetails__c(Id = fdId, Locked__c = true));
        }

        update fdsForLocking;
    }

    public void validateEditPermission() {
        List<FileDetails__c> fileDetails = FileDetailSelector.getFileDetails(new List<Id>(recordMap.keySet()));
        for (FileDetails__c fd : fileDetails) {
            if (Trigger.isExecuting && System.isFuture()) {
                FileDetails__c oldFd = (FileDetails__c)Trigger.oldMap.get(fd.Id);
                if (fd.Locked__c && !oldFd.Locked__c) {
                    //skip locking when an assistant examiner is assigned
                    continue;
                }
            }

            if (fd.Filing__c != null && !FilingService.validateEditPermission(fd.Filing__r)) {
                recordMap.get(fd.Id).addError('Only the filing reviewer can edit this File Detail.');
                continue;
            }

            if (fd.Exam__c != null && !ExamService.validateEditPermission(fd.Exam__r)) {
                recordMap.get(fd.Id).addError('Only the Owner and Assistant Examiner can edit this File Detail.');
            }
        }
    }

    public void validateCreatePermission() {
        List<FileDetails__c> fileDetails = FileDetailSelector.getFileDetails(new List<Id>(recordMap.keySet()));
        for (FileDetails__c fd : fileDetails) {
            if (fd.Filing__c != null && !FilingService.validateEditPermission(fd.Filing__r)) {
                recordMap.get(fd.Id).addError('Only the filing reviewer can add file details to this record.');
                continue;
            }
        }
    }

    public Map<String, String> checkForExamValidations() {
        String currentUserId = UserInfo.getUserId();
        Map<String, String> errors = new Map<String, String>();
        for (FileDetails__c record : (List<FileDetails__c>) records) {
            if (record.Exam__c != null &&
                            record.Exam__r.AssistantExaminer__c != null &&
                            currentUserId != record.Exam__r.OwnerId &&
                            currentUserId != record.Exam__r.AssistantExaminer__c) {
                errors.put(record.Id, GlobalConstants.EXAMFILEERROR);
            }
        }
        return errors;
    }

    public Map<String, String> checkForFilingValidations() {
        String currentUserId = UserInfo.getUserId();
        Map<String, String> errors = new Map<String, String>();
        for (FileDetails__c record : (List<FileDetails__c>) records) {
            if (record.Filing__c != null &&
                            record.Filing__r.Reviewer__c != null &&
                            currentUserId != record.Filing__r.Reviewer__c) {
                errors.put(record.Id, GlobalConstants.FILINGFILEERROR);
            }
        }
        return errors;
    }

    //    Can be used as a granular version of shareWithAssistantExaminersAndReviewers
    //    commented for now
    //    public void shareWithExamAssistantExaminers() {
    //        List<FileDetails__c> fileDetails = FileDetailSelector.getFileDetails(new List<Id>(recordMap.keySet()));
    //
    //        Map<Id, FileDetails__c> fileDetailsWithAssistantExaminerToShareMap = new Map<Id, FileDetails__c>();
    //
    //        for (FileDetails__c fd : fileDetails) {
    //            if (fd.Exam__c != null &&
    //                            fd.Exam__r.AssistantExaminer__c != null &&
    //                            fd.OwnerId != fd.Exam__r.AssistantExaminer__c) {
    //                fileDetailsWithAssistantExaminerToShareMap.put(fd.Id, fd);
    //            }
    //        }
    //
    //        //Find and remove manual sharing
    //        List<FileDetails__Share> existingShares = [
    //                SELECT
    //                        Id
    //                FROM FileDetails__Share
    //                WHERE ParentId IN :recordMap.keySet()
    //                AND RowCause = 'Manual'
    //        ];
    //
    //        delete existingShares;
    //
    //        List<FileDetails__Share> newShares = new List<FileDetails__Share>();
    //        for (FileDetails__c fd : fileDetailsWithAssistantExaminerToShareMap.values()) {
    //            FileDetails__Share s = new FileDetails__Share();
    //            s.ParentId = fd.Id;
    //            s.AccessLevel = 'Edit';
    //            s.UserOrGroupId = fd.Exam__r.AssistantExaminer__c;
    //            newShares.add(s);
    //        }
    //
    //        insert newShares;
    //    }
    //
    //    public void shareWithFilingReviewer() {
    //        List<FileDetails__c> fileDetails = FileDetailSelector.getFileDetails(new List<Id>(recordMap.keySet()));
    //
    //        Map<Id, FileDetails__c> fileDetailsWithReviewerToShareMap = new Map<Id, FileDetails__c>();
    //
    //        for (FileDetails__c fd : fileDetails) {
    //            if (fd.Filing__c != null &&
    //                            fd.Filing__r.Reviewer__c != null &&
    //                            fd.OwnerId != fd.Filing__r.Reviewer__c) {
    //                fileDetailsWithReviewerToShareMap.put(fd.Id, fd);
    //            }
    //        }
    //
    //        //Find and remove manual sharing
    //        List<FileDetails__Share> existingShares = [
    //                SELECT
    //                        Id
    //                FROM FileDetails__Share
    //                WHERE ParentId IN :recordMap.keySet()
    //                AND RowCause = 'Manual'
    //        ];
    //
    //        delete existingShares;
    //
    //        List<FileDetails__Share> newShares = new List<FileDetails__Share>();
    //        for (FileDetails__c fd : fileDetailsWithReviewerToShareMap.values()) {
    //            FileDetails__Share s = new FileDetails__Share();
    //            s.ParentId = fd.Id;
    //            s.AccessLevel = 'Edit';
    //            s.UserOrGroupId = fd.Exam__r.AssistantExaminer__c;
    //            newShares.add(s);
    //        }
    //
    //        insert newShares;
    //    }

}