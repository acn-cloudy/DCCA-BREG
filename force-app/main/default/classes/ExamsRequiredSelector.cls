/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Application
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class ExamsRequiredSelector {
    DataBase.QueryLocator queryLocator;
    public static List<ExamsRequired__c> getExamRequiredBIds(List<String> erIds) {
        return [
            Select Id, Application__c, Status__c, NewFailedResult__c, NumberofAttempts__c, ExamEligibleStartDate__c,
            ExamType__r.NumberofFailedAttemptAllowed__c, ExamType__r.WaitingPeriodUponFailedExam__c,
            ExamType__r.Classification__r.LicenseType__r.BoardProgram__r.Name, PreviousExamEligibleStartDate__c
            from ExamsRequired__c where Id in: erIds ];

    }
}