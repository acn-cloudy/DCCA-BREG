/*
* ─────────────────────────────────────────────────────────
* Description: 
* ─────────────────────────────────────────────────────────
* PacPoint-EA05102024: Created for Case 00035511
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Emel ly Agarao - PacificPointCorp 
* @created      2024-05-10
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class ExamResultsService {
    public static void setNewFailedExamResult(List<ExamResults__c> examResults){
        Map<String, ExamResults__c> exReqExResMap = new Map<String, ExamResults__c>();
        for(ExamResults__c examResult:examResults){
            exReqExResMap.put(examResult.ExamsRequired__c, examResult);
        }

        if(exReqExResMap.isEmpty()) return;

        List<ExamsRequired__c> examsRequired = ExamsRequiredSelector.getExamRequiredBIds(new List<String>(exReqExResMap.keySet()));
        if(!examsRequired.isEmpty()){
            for(ExamsRequired__c examRequired:examsRequired){
                examRequired.NewFailedResult__c = true;
            }

            update examsRequired;
        }
    }

    public static void processNewFailedExamResults(List<ExamResults__c> examResults){
        Map<String, ExamResults__c> exReqExResMap = new Map<String, ExamResults__c>();
        for(ExamResults__c examResult:examResults){
            exReqExResMap.put(examResult.ExamsRequired__c, examResult);
        }

        if(exReqExResMap.isEmpty()) return;

        List<ExamsRequired__c> examsRequired = ExamsRequiredSelector.getExamRequiredBIds(new List<String>(exReqExResMap.keySet()));
        if(!examsRequired.isEmpty()){
            Map<String, ExamsRequired__c> appExamRequiredMap = new Map<String, ExamsRequired__c>();
            for(ExamsRequired__c examRequired:examsRequired){
                examRequired.NewFailedResult__c = false;
                if(
                    examRequired.Application__c != null
                    && (
                        examRequired.ExamType__r.NumberofFailedAttemptAllowed__c == null
                        ||examRequired.ExamType__r.NumberofFailedAttemptAllowed__c <= 1
                        || (math.mod(Integer.valueOf(examRequired.NumberofAttempts__c + 1), Integer.valueOf(examRequired.ExamType__r.NumberofFailedAttemptAllowed__c)) == 0 && examRequired.NumberofAttempts__c > 0)
                    ) && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c > 0
                ){
                    ExamResults__c exResult = exReqExResMap.get(examRequired.Id);
                    Date startDate = null;
                    if(exResult.ExamDate__c != null){
                        startDate = Date.valueOf(exResult.ExamDate__c);
                        if(examRequired.ExamType__r != null && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null) startDate = startDate.addDays(Integer.valueOf(examRequired.ExamType__r.WaitingPeriodUponFailedExam__c));
                    }

                    examRequired.PreviousExamEligibleStartDate__c = examRequired.ExamEligibleStartDate__c != null ? Date.valueOf(examRequired.ExamEligibleStartDate__c) : null;
                    examRequired.ExamEligibleStartDate__c = startDate;
                    appExamRequiredMap.put(examRequired.Application__c, examRequired);
                } 
            }

            update examsRequired;

            // if(!appExamRequiredMap.isEmpty()){
            //     List<Application__c> apps = ApplicationSelector.getApplications(appExamRequiredMap.keySet());
            //     for(Application__c app:apps){
            //         if(
            //             app.BoardProgramName__c != 'CONTRACTORS LICENSE BOARD' 
            //             && app.BoardProgramName__c != 'BOARD OF PRIVATE DETECTIVES AND GUARDS'
            //             && app.ApplicationReceivedDate__c <= Date.newInstance(2024, 4, 1)
            //         ){
            //             ExamsRequired__c exRequired = appExamRequiredMap.get(app.Id);
            //             ExamResults__c exResult = exReqExResMap.get(exRequired.Id);

            //             // Date completeBy = null;
            //             // if(exResult.ExamDate__c != null){
            //             //     completeBy = Date.valueOf(exResult.ExamDate__c);
            //             //     if(app.LicenseType__r != null && app.LicenseType__r.DurationofTestEligibilityMonths__c != null) completeBy = completeBy.addMonths(Integer.valueOf(app.LicenseType__r.DurationofTestEligibilityMonths__c));
            //             //     if(exRequired.ExamType__r != null && exRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null) completeBy = completeBy.addDays(Integer.valueOf(exRequired.ExamType__r.WaitingPeriodUponFailedExam__c));
            //             // }

            //             // app.CompleteApplicationBy__c = completeBy;
            //         }
            //     }

            //     if(!apps.isEmpty()){
            //         update apps;
            //     }
            // }
        }
    }
    
    public static void processUpdatedFailedOrDeletedExamResults(List<ExamResults__c> examResults, Boolean isDelete){
        Map<String, ExamResults__c> exReqExResMap = new Map<String, ExamResults__c>();
        for(ExamResults__c examResult:examResults){
            exReqExResMap.put(examResult.ExamsRequired__c, examResult);
        }

        if(exReqExResMap.isEmpty()) return;

        List<ExamsRequired__c> examsRequired = ExamsRequiredSelector.getExamRequiredBIds(new List<String>(exReqExResMap.keySet()));
        if(!examsRequired.isEmpty()){
            Map<String, Date> exReqStartDateMap = New Map<String, Date>();
            for(AggregateResult aggRes:[Select MAX(ExamDate__c) latestResultDate, ExamsRequired__c FROM ExamResults__c WHERE ExamsRequired__c IN :exReqExResMap.keySet() GROUP BY ExamsRequired__c ]){
                exReqStartDateMap.put(String.valueOf(aggRes.get('ExamsRequired__c')), Date.valueOf(aggRes.get('latestResultDate')));
            }
            
            Map<String, Integer> exReqAttemmptCountMap = New Map<String, Integer>();
            for(AggregateResult aggRes:[Select COUNT(Id) attemptCount, ExamsRequired__c FROM ExamResults__c WHERE ExamsRequired__c IN :exReqExResMap.keySet() AND Status__c = 'Failed' AND TakenRemedialCourse__c = false GROUP BY ExamsRequired__c ]){
                exReqAttemmptCountMap.put(String.valueOf(aggRes.get('ExamsRequired__c')), Integer.valueOf(aggRes.get('attemptCount')));
            }
            
            Map<String, Integer> exReqPassedAttemmptCountMap = New Map<String, Integer>();
            for(AggregateResult aggRes:[Select COUNT(Id) attemptCount, ExamsRequired__c FROM ExamResults__c WHERE ExamsRequired__c IN :exReqExResMap.keySet() AND Status__c = 'Passed' AND TakenRemedialCourse__c = false GROUP BY ExamsRequired__c ]){
                exReqPassedAttemmptCountMap.put(String.valueOf(aggRes.get('ExamsRequired__c')), Integer.valueOf(aggRes.get('attemptCount')));
            }

            Map<String, ExamsRequired__c> appExamRequiredMap0 = new Map<String, ExamsRequired__c>();            
            Map<String, ExamsRequired__c> appExamRequiredMap1 = new Map<String, ExamsRequired__c>();
 
            for(ExamsRequired__c examRequired:examsRequired){
                Integer numberOfAttempts = Integer.valueOf(exReqAttemmptCountMap.get(examRequired.Id));
                if(numberOfAttempts == null || numberOfAttempts == 0){
                    if(examRequired?.ExamType__r?.Classification__r?.LicenseType__r?.BoardProgram__r?.Name == 'CONTRACTORS LICENSE BOARD'){
                        examRequired.ExamEligibleStartDate__c = null;
                        examRequired.Status__c = 'Awaiting Results';
                        examRequired.Date__c = null;
                    } else {                        
                        appExamRequiredMap0.put(examRequired.Application__c, examRequired);
                    }
                } else if(numberOfAttempts > 0){
                    if(
                        examRequired.Application__c != null
                        && (
                            examRequired.ExamType__r.NumberofFailedAttemptAllowed__c == null
                            || examRequired.ExamType__r.NumberofFailedAttemptAllowed__c <= 1
                            || (math.mod(numberOfAttempts, Integer.valueOf(examRequired.ExamType__r.NumberofFailedAttemptAllowed__c)) == 0 && numberOfAttempts > 0)
                        )
                    ){
                        if(examRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null  && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c > 0){
                            Integer numberOfPassedAttempts = Integer.valueOf(exReqPassedAttemmptCountMap.get(examRequired.Id));
                            if(numberOfPassedAttempts >= 1){
                                examRequired.Status__c = 'Passed';
                            } else {                                
                                ExamResults__c exResult = exReqExResMap.get(examRequired.Id);
                                Date startDate = exReqStartDateMap.get(examRequired.Id);
                                if(startDate != null){
                                    if(examRequired.ExamType__r != null && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null) startDate = startDate.addDays(Integer.valueOf(examRequired.ExamType__r.WaitingPeriodUponFailedExam__c));examRequired.Status__c = 'Failed';
                                }

                                examRequired.ExamEligibleStartDate__c = startDate;
                            }
                            appExamRequiredMap1.put(examRequired.Application__c, examRequired);
                        }
                    } else if(numberOfAttempts != examRequired.ExamType__r.NumberofFailedAttemptAllowed__c && examRequired.ExamType__r.NumberofFailedAttemptAllowed__c > 1){
                        examRequired.ExamEligibleStartDate__c = examRequired.PreviousExamEligibleStartDate__c;
                    }
                }
            }

            update examsRequired;

            if(!appExamRequiredMap0.isEmpty()){
                List<Application__c> apps = ApplicationSelector.getApplications(appExamRequiredMap0.keySet());
                for(Application__c app:apps){
                    ExamsRequired__c exRequired = appExamRequiredMap0.get(app.Id);
                    exRequired.ExamEligibleStartDate__c = app.PhaseXStartDate__c != null ? app.PhaseXStartDate__c.date() : null;
                    exRequired.Status__c = 'Awaiting Results';
                    exRequired.Date__c = null;
                    app.CompleteApplicationBy__c = app.ApplicationReceivedDate__c;
                    if(app.CompleteApplicationBy__c != null && app.LicenseType__r.CompletebyDuration__c != null){
                        app.CompleteApplicationBy__c = Date.valueOf(app.CompleteApplicationBy__c).addMonths(Integer.valueOf(app.LicenseType__r.CompletebyDuration__c));
                     }
                }

                 if(!apps.isEmpty()) update apps;

                update appExamRequiredMap0.values();
            }

            // if(!appExamRequiredMap1.isEmpty()){
            //     List<Application__c> apps = ApplicationSelector.getApplications(appExamRequiredMap1.keySet());
            //     for(Application__c app:apps){
            //         if(
            //             app.BoardProgramName__c != 'CONTRACTORS LICENSE BOARD' 
            //             && app.BoardProgramName__c != 'BOARD OF PRIVATE DETECTIVES AND GUARDS'
            //             && app.ApplicationReceivedDate__c <= Date.newInstance(2024, 4, 1)
            //         ){                        
            //             ExamsRequired__c exRequired = appExamRequiredMap1.get(app.Id);
            //             ExamResults__c exResult = exReqExResMap.get(exRequired.Id);
                        
            //             // Date completeBy = exReqStartDateMap.get(exRequired.Id);
            //             // if(completeBy != null){
            //             //     if(app?.LicenseType__r?.DurationofTestEligibilityMonths__c != null) completeBy = completeBy.addMonths(Integer.valueOf(app.LicenseType__r.DurationofTestEligibilityMonths__c));
            //             //     if(exRequired?.ExamType__r?.WaitingPeriodUponFailedExam__c != null) completeBy = completeBy.addDays(Integer.valueOf(exRequired.ExamType__r.WaitingPeriodUponFailedExam__c));
            //             // }
                        
            //             // app.CompleteApplicationBy__c = completeBy;
            //         }
            //     }

            //     if(!apps.isEmpty()){
            //         update apps;
            //     }
            // }
        }
    }

    public static void processUpdatedPassedExamResults(List<ExamResults__c> examResults){
        Map<String, ExamResults__c> exReqExResMap = new Map<String, ExamResults__c>();
        for(ExamResults__c examResult:examResults){
            exReqExResMap.put(examResult.ExamsRequired__c, examResult);
        }

        if(exReqExResMap.isEmpty()) return;

        List<ExamsRequired__c> examsRequired = ExamsRequiredSelector.getExamRequiredBIds(new List<String>(exReqExResMap.keySet()));
        if(!examsRequired.isEmpty()){
            Map<String, Integer> exReqAttemmptCountMap = New Map<String, Integer>();
            for(AggregateResult aggRes:[Select COUNT(Id) attemptCount, ExamsRequired__c FROM ExamResults__c WHERE ExamsRequired__c IN :exReqExResMap.keySet() AND Status__c = 'Failed' AND TakenRemedialCourse__c = false GROUP BY ExamsRequired__c ]){
                exReqAttemmptCountMap.put(String.valueOf(aggRes.get('ExamsRequired__c')), Integer.valueOf(aggRes.get('attemptCount')));
            }

            Map<String, ExamsRequired__c> appExamRequiredMap = new Map<String, ExamsRequired__c>();
            for(ExamsRequired__c examRequired:examsRequired){
                Integer numberOfAttempts = Integer.valueOf(exReqAttemmptCountMap.get(examRequired.Id));
                if(examRequired.Status__c != 'Failed'){
                    examRequired.ExamEligibleStartDate__c = null;
                } else if(
                    examRequired.Application__c != null
                    && (
                        examRequired.ExamType__r.NumberofFailedAttemptAllowed__c == null
                        || examRequired.ExamType__r.NumberofFailedAttemptAllowed__c <= 1
                        || (math.mod(numberOfAttempts, Integer.valueOf(examRequired.ExamType__r.NumberofFailedAttemptAllowed__c)) == 0 && numberOfAttempts > 0)
                    ) && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null
                    && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c > 0
                ){
                    ExamResults__c exResult = exReqExResMap.get(examRequired.Id);
                    Date startDate = null;
                    if(exResult.ExamDate__c != null){
                        startDate = Date.valueOf(exResult.ExamDate__c);
                        if(examRequired.ExamType__r != null && examRequired.ExamType__r.WaitingPeriodUponFailedExam__c != null) startDate = startDate.addDays(Integer.valueOf(examRequired.ExamType__r.WaitingPeriodUponFailedExam__c));
                    }

                    examRequired.ExamEligibleStartDate__c = startDate;
                    appExamRequiredMap.put(examRequired.Application__c, examRequired);
                } else if(examRequired.ExamType__r.NumberofFailedAttemptAllowed__c > 1){
                    examRequired.ExamEligibleStartDate__c = examRequired.PreviousExamEligibleStartDate__c;
                }
            }

            update examsRequired;

            // if(!appExamRequiredMap.isEmpty()){
            //     List<Application__c> apps = ApplicationSelector.getApplications(appExamRequiredMap.keySet());
            //     for(Application__c app:apps){
            //         if(
            //             app.BoardProgramName__c != 'CONTRACTORS LICENSE BOARD' 
            //             && app.BoardProgramName__c != 'BOARD OF PRIVATE DETECTIVES AND GUARDS'
            //             && app.ApplicationReceivedDate__c <= Date.newInstance(2024, 4, 1)
            //         ){
            //             ExamsRequired__c exRequired = appExamRequiredMap.get(app.Id);
            //             ExamResults__c exResult = exReqExResMap.get(exRequired.Id);
                        
            //             // Date completeBy = null;
            //             // if(exResult.ExamDate__c != null){
            //             //     completeBy = Date.valueOf(exResult.ExamDate__c);
            //             //     if(app?.LicenseType__r?.DurationofTestEligibilityMonths__c != null) completeBy = completeBy.addMonths(Integer.valueOf(app.LicenseType__r.DurationofTestEligibilityMonths__c));
            //             //     if(exRequired?.ExamType__r?.WaitingPeriodUponFailedExam__c != null) completeBy = completeBy.addDays(Integer.valueOf(exRequired.ExamType__r.WaitingPeriodUponFailedExam__c));
            //             // }
                        
            //             // app.CompleteApplicationBy__c = completeBy;
            //         }
            //     }

            //     if(!apps.isEmpty()){
            //         update apps;
            //     }
            // }
        }
    }
}