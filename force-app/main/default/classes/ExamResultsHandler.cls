/*
* ─────────────────────────────────────────────────────────
* class for the Exam Results Handller used to handle 
* Exam Results trigger
* ─────────────────────────────────────────────────────────
* PacPoint-EA05102024: Created for Case 00035511
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Emel ly Agarao - PacificPointCorp 
* @created      2024-05-10
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class ExamResultsHandler implements ITrigger{
    public ExamResultsHandler() {}
    public void bulkBefore() {
        List<ExamResults__c> newExamResults = (List<ExamResults__c>) Trigger.new;
        Map<Id, ExamResults__c> oldExamResults = (Map<Id, ExamResults__c>) Trigger.oldMap;

        if(Trigger.isInsert){
            List<ExamResults__c> forNewFailedResultUpdate = new List<ExamResults__c>(); 
            for(ExamResults__c newExamResult : newExamResults){
                if(newExamResult.Status__c == 'Failed') forNewFailedResultUpdate.add(newExamResult);
            }

            if(!forNewFailedResultUpdate.isEmpty()) ExamResultsService.setNewFailedExamResult(forNewFailedResultUpdate);

        } else if(Trigger.isUpdate){            
            List<ExamResults__c> forNewFailedResultUpdate = new List<ExamResults__c>(); 
            for(ExamResults__c newExamResult : newExamResults){
                if(newExamResult.Status__c != oldExamResults.get(newExamResult.Id).Status__c && newExamResult.Status__c == 'Failed') forNewFailedResultUpdate.add(newExamResult);
            }

            if(!forNewFailedResultUpdate.isEmpty()) ExamResultsService.setNewFailedExamResult(forNewFailedResultUpdate);
        }
    }
    public void bulkAfter() {
        
        List<ExamResults__c> newExamResults = (List<ExamResults__c>) Trigger.new;
        Map<Id, ExamResults__c> oldExamResults = (Map<Id, ExamResults__c>) Trigger.oldMap;
        
        if(Trigger.isInsert){
            List<ExamResults__c> failedResults = new List<ExamResults__c>();
            for(ExamResults__c newExamResult : newExamResults){
                if(newExamResult.Status__c == 'Failed') failedResults.add(newExamResult);
            }
            ExamResultsService.processNewFailedExamResults(failedResults);
        } else if(Trigger.isUpdate){            
            List<ExamResults__c> failedResults = new List<ExamResults__c>();            
            List<ExamResults__c> passedResults = new List<ExamResults__c>();
            for(ExamResults__c newExamResult : newExamResults){
                if(newExamResult.Status__c == 'Failed') failedResults.add(newExamResult);
                if(newExamResult.Status__c == 'Passed') passedResults.add(newExamResult);
            }
            ExamResultsService.processUpdatedFailedOrDeletedExamResults(failedResults, false);
            ExamResultsService.processUpdatedPassedExamResults(passedResults);
        } else if(Trigger.isDelete){
            ExamResultsService.processUpdatedFailedOrDeletedExamResults(new List<ExamResults__c>(oldExamResults.values()), true);
        }
    }

    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so){}
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so) {}
    public void afterDelete(SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {}
}