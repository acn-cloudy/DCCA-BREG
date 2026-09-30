/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL12062021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 12/06/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
public without sharing class ExamSharer {
    public static void shareWithAssistantExaminer(List<Exam__c> exams) {
        Map<Id, Exam__c> recordMap = new Map<Id, Exam__c>(exams);
        //find all child file details
        List<FileDetails__c> children = [
                SELECT
                        Id
                FROM FileDetails__c
                WHERE Exam__c IN :recordMap.keySet()
        ];

        new FileDetailDomain(children).shareWithAssistantExaminers();

        //Find and remove manual sharing
        List<Exam__Share> existingShares = [
                SELECT
                        Id
                FROM Exam__Share
                WHERE ParentId IN :recordMap.keySet()
                AND RowCause = 'AssistantExaminer__c'
        ];

        delete existingShares;

        List<Exam__Share> newShares = new List<Exam__Share>();
        for (Exam__c e : (List<Exam__c>)recordMap.values()) {
            if (e.AssistantExaminer__c != null && e.AssistantExaminer__c != e.OwnerId) {
                Exam__Share s = new Exam__Share();
                s.ParentId = e.Id;
                s.AccessLevel = 'Edit';
                s.RowCause = 'AssistantExaminer__c';
                s.UserOrGroupId = e.AssistantExaminer__c;
                newShares.add(s);
            }
        }

        insert newShares;
    }
}