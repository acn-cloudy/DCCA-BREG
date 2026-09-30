public without sharing class FileDetailSharer {
      public static void shareWithAssistantExaminers(List<FileDetails__c> records) {
        Map<Id,FileDetails__c> recordMap= new Map<Id, FileDetails__c>(records);
        List<FileDetails__c> fileDetails = FileDetailSelector.getFileDetails(new List<Id>(recordMap.keySet()));
        Map<Id, Set<Id>> fileDetailSharedUserIdsMap = new Map<Id, Set<Id>>();
        Set<Id> fileDetailIdsForLocking = new Set<Id>();

        //Find and remove AssistantExaminer sharing
        List<FileDetails__Share> existingShares = [
                SELECT
                        Id
                FROM FileDetails__Share
                WHERE ParentId IN :recordMap.keySet()
                AND RowCause = 'AssistantExaminer__c'
        ];

        delete existingShares;

        List<FileDetails__Share> newShares = new List<FileDetails__Share>();
        for (FileDetails__c fd : fileDetails) {
            if (!fileDetailSharedUserIdsMap.containsKey(fd.Id)) {
                fileDetailSharedUserIdsMap.put(fd.Id, new Set<Id>());
            }

            if (fd.Exam__c != null) {
                if (fd.Exam__r.AssistantExaminer__c != null &&
                        !fileDetailSharedUserIdsMap.get(fd.Id).contains(fd.Exam__r.AssistantExaminer__c) &&
                                fd.Exam__r.AssistantExaminer__c != fd.OwnerId) {
                    //share with parent Exam's AssistantExaminer
                    FileDetails__Share s = new FileDetails__Share();
                    s.ParentId = fd.Id;
                    s.AccessLevel = 'Edit';
                    s.RowCause = 'AssistantExaminer__c';
                    s.UserOrGroupId = fd.Exam__r.AssistantExaminer__c;
                    newShares.add(s);
                    fileDetailSharedUserIdsMap.get(fd.Id).add(fd.Exam__r.AssistantExaminer__c);

                    if (!fd.Locked__c) {
                        fileDetailIdsForLocking.add(fd.Id);
                    }
                }
            }
        }

        insert newShares;

        if (!fileDetailIdsForLocking.isEmpty()) {
            FileDetailDomain.lockFileDetailsFuture(new List<Id>(fileDetailIdsForLocking));
        }
    }
}