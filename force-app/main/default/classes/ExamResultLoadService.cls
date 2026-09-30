/*
 * --------------------------------------------------------
 * Author: Ronald Pascual
 * Company: Pacific Point Corp
 * Description: A handler class for the exam result load trigger
 * Inputs: "Exam Results Load Records" - Exam Result Load object that are being triggered
 * Test Class:
 * History
 * <Date> <Authors Name> <Brief Description of Change>
 * 2019-09-16 Ronald Pascual Created the logic for the exam result load trigger
 * --------------------------------------------------------
 */
public class ExamResultLoadService {
    public static void populateExamResults(List<SObject> examResultsLoads) {
        Set<String> examsRequirePhaseFilter = new Set<String>{
                'A - Application Received',
                'B - Board Review',
                'D - Dependency Review',
                'E - Executive Officer Review',
                'X - Exam Phase',
                'L - License Review'
                };

        List<ExamResultsLoad__c> loads = (List<ExamResultsLoad__c>) examResultsLoads;

        Map<String, Map<String, List<ExamResultsLoad__c>>> ssnExamResultsLoadsByTypeMap =
                new Map<String, Map<String, List<ExamResultsLoad__c>>>();

        Map<String, List<ExamResultsLoad__c>> ssnExamResultsLoadsMap = new Map<String, List<ExamResultsLoad__c>>();
        Set<String> examsRequiredExamTypesFilter = new Set<String>();

        //Group ExamResultsLoad by SSN and ExamType
        for (ExamResultsLoad__c load : loads) {
            //ignore if SSN or ExamType field is blank
            if (load.SSN__c == null || load.ExamType__c == null) continue;

            //Store ExamTypes
            examsRequiredExamTypesFilter.add(load.ExamType__c);

            //Group ExamResultsLoad By SSN and ExamType
            if (!ssnExamResultsLoadsByTypeMap.containsKey(load.SSN__c)) {
                ssnExamResultsLoadsByTypeMap.put(load.SSN__c, new Map<String, List<ExamResultsLoad__c>>());
            }

            if (!ssnExamResultsLoadsByTypeMap.get(load.SSN__c).containsKey(load.ExamType__c)) {
                ssnExamResultsLoadsByTypeMap.get(load.SSN__c).put(load.ExamType__c, new List<ExamResultsLoad__c>());
            }

            ssnExamResultsLoadsByTypeMap.get(load.SSN__c).get(load.ExamType__c).add(load);

            //Group ExamResultsLoad By SSN
            if (!ssnExamResultsLoadsMap.containsKey(load.SSN__c)) {
                ssnExamResultsLoadsMap.put(load.SSN__c, new List<ExamResultsLoad__c>());
            }

            ssnExamResultsLoadsMap.get(load.SSN__c).add(load);
        }

        //find Accounts
        List<Account> accounts = [
                SELECT
                        Id,
                        BPID__c
                FROM Account
                WHERE BPID__c IN :ssnExamResultsLoadsMap.keySet()
        ];

        //Exam Types Record
        List<ExamTypes__c> examTypes = [
                SELECT
                        Id,
                        Name
                FROM ExamTypes__c
                WHERE Name IN :examsRequiredExamTypesFilter
        ];

        Map<String, ExamTypes__c> examTypeNameExamTypeMap = new Map<String, ExamTypes__c>();

        for (ExamTypes__c examType : examTypes) {
            examTypeNameExamTypeMap.put(examType.Name, examType);
        }

        Map<String, Account> bpidAccountMap = new Map<String, Account>();

        for (Account a : accounts) {
            bpidAccountMap.put(a.BPID__c, a);
        }

        for (String bpiId : ssnExamResultsLoadsMap.keySet()) {
            if (!bpidAccountMap.keySet().contains(bpiId)) {
                for (ExamResultsLoad__c exl : ssnExamResultsLoadsMap.get(bpiId)) {
                    exl.Result__c = 'SSN Not found';
                }
            }
        }

        //get exams required
        List<ExamsRequired__c> examsReqs = [
                SELECT
                        Id,
                        PVLBPID__c,
                        ExamType__r.Name,
                        Phase__c,
                        (SELECT
                                 Id,
                                 ExamDate__c,
                                 Status__c
                        FROM Exam_Results__r)
                FROM ExamsRequired__c
                WHERE PVLBPID__c IN :bpidAccountMap.keySet()
                AND Phase__c IN :examsRequirePhaseFilter
        ];

        Map<String, List<ExamsRequired__c>> bpidExamsRequiredMap = new Map<String, List<ExamsRequired__c>>();

        Map<String, Map<String, List<ExamsRequired__c>>> bpidExamsRequiredByPhaseMap =
                new Map<String, Map<String, List<ExamsRequired__c>>>();

        Map<String, Map<String, List<ExamsRequired__c>>> bpidExamsRequiredByTypeMap =
                new Map<String, Map<String, List<ExamsRequired__c>>>();

        //We will us this to filter existing exam results
        Map<Id, Map<Date, Map<String, List<ExamResults__c>>>> examsRequiredExamResultsMap =
                new Map<Id, Map<Date, Map<String, List<ExamResults__c>>>>();

        for (ExamsRequired__c examsRequired : examsReqs) {
            if (!bpidExamsRequiredMap.containsKey(examsRequired.PVLBPID__c)) {
                bpidExamsRequiredMap.put(examsRequired.PVLBPID__c, new List<ExamsRequired__c>());
            }

            bpidExamsRequiredMap.get(examsRequired.PVLBPID__c).add(examsRequired);

            if (!bpidExamsRequiredByPhaseMap.containsKey(examsRequired.PVLBPID__c)) {
                bpidExamsRequiredByPhaseMap.put(examsRequired.PVLBPID__c, new Map<String, List<ExamsRequired__c>>());
            }

            if (!bpidExamsRequiredByPhaseMap.get(examsRequired.PVLBPID__c).containsKey(examsRequired.Phase__c)) {
                bpidExamsRequiredByPhaseMap.get(examsRequired.PVLBPID__c).put(examsRequired.Phase__c,
                        new List<ExamsRequired__c>());
            }

            bpidExamsRequiredByPhaseMap.get(examsRequired.PVLBPID__c).get(examsRequired.Phase__c).add(examsRequired);

            if (!bpidExamsRequiredByTypeMap.containsKey(examsRequired.PVLBPID__c)) {
                bpidExamsRequiredByTypeMap.put(examsRequired.PVLBPID__c, new Map<String, List<ExamsRequired__c>>());
            }

            if (!bpidExamsRequiredByTypeMap.get(examsRequired.PVLBPID__c).containsKey(examsRequired.ExamType__r.Name)) {
                bpidExamsRequiredByTypeMap.get(examsRequired.PVLBPID__c).put(examsRequired.ExamType__r.Name,
                        new List<ExamsRequired__c>());
            }

            bpidExamsRequiredByTypeMap.get(examsRequired.PVLBPID__c).get(examsRequired.ExamType__r.Name).add(
                    examsRequired);

            if (!examsRequiredExamResultsMap.containsKey(examsRequired.Id)) {
                examsRequiredExamResultsMap.put(examsRequired.Id, new Map<Date, Map<String, List<ExamResults__c>>>());
            }

            for (ExamResults__c examRes : examsRequired.Exam_Results__r) {
                if (!examsRequiredExamResultsMap.get(examsRequired.Id).containsKey(examRes.ExamDate__c)) {
                    examsRequiredExamResultsMap.get(examsRequired.Id).put(examRes.ExamDate__c,
                            new Map<String, List<ExamResults__c>>());
                }

                if (!examsRequiredExamResultsMap.get(examsRequired.Id).
                get(examRes.ExamDate__c).
                containsKey(examRes.Status__c)) {
                    examsRequiredExamResultsMap.get(examsRequired.Id)
                            .get(examRes.ExamDate__c)
                            .put(examRes.Status__c, new List<ExamResults__c>());
                }

                examsRequiredExamResultsMap.get(examsRequired.Id)
                        .get(examRes.ExamDate__c)
                        .get(examRes.Status__c)
                        .add(examRes);
            }
        }

        List<ExamResults__c> examResultsToInsert = new List<ExamResults__c>();
        List<ExamResults__c> examResultsToUpdate = new List<ExamResults__c>();
        Map<String, String> passFailMap = new Map<String, String>{
        'Pass' => 'Passed',
        'Fail' => 'Failed'
        };

        for (String accountBpid : bpidAccountMap.keySet()) {
            Map<String, List<ExamsRequired__c>> examsRequiredByPhase = bpidExamsRequiredByPhaseMap.get(accountBpid);
            Map<String, List<ExamsRequired__c>> examsRequiredByType = bpidExamsRequiredByTypeMap.get(accountBpid);

            List<ExamResultsLoad__c> accountsExamResultsLoads = ssnExamResultsLoadsMap.get(accountBpid);

            for (ExamResultsLoad__c load : accountsExamResultsLoads) {
                if (examsRequiredByPhase == null) {
                    load.Result__c = 'No open application found.';
                    continue;
                }

                if (!examsRequiredByType.containsKey(load.ExamType__c)) {
                    load.Result__c = 'Exam Required Type not found.';
                    continue;
                }

                List<ExamsRequired__c> validExamsRequired = examsRequiredByType.get(load.ExamType__c);

                for (ExamsRequired__c exr : validExamsRequired) {
                    if (exr.Exam_Results__r == null || exr.Exam_Results__r.isEmpty()) {
                        ExamResults__c er = new ExamResults__c();
                        er.ExamDate__c = load.DateofExam__c;
                        er.ExamScore__c = load.ExamScore__c;
                        er.ExamsRequired__c = exr.Id;
                        er.Status__c = passFailMap.get(load.PassorFail__c);
                        examResultsToInsert.add(er);

                        load.Result__c = 'Record created.';

                        continue;
                    }

                    //get ExistingExamResults for this ExamRequired grouped by exam date
                    Map<String, List<ExamResults__c>> existingExamResultsWithSameDateGroupByStatusMap =
                            examsRequiredExamResultsMap.get(exr.Id).get(load.DateofExam__c);

                    //check if has existing ExamResults with Same Date
                    if (existingExamResultsWithSameDateGroupByStatusMap != null) {
                        List<ExamResults__c> existingExamsResultsWithSameStatus =
                                existingExamResultsWithSameDateGroupByStatusMap.get(
                                        passFailMap.get(load.PassorFail__c));
                        //check if has existing ExamResults with Same Status
                        if (existingExamsResultsWithSameStatus != null &&
                                !existingExamsResultsWithSameStatus.isEmpty()) {
                            load.Result__c = 'Duplicate Record';
                            continue;
                        } else {
                            String otherStatus = (load.PassorFail__c == 'Pass') ? 'Fail' : 'Pass';
                            List<ExamResults__c> unmatchedStatusExamResults =
                                    existingExamResultsWithSameDateGroupByStatusMap.get(passFailMap.get(otherStatus));
                            if (unmatchedStatusExamResults != null) {
                                for (ExamResults__c exRe : unmatchedStatusExamResults) {
                                    exRe.Status__c = passFailMap.get(load.PassorFail__c);
                                    examResultsToUpdate.add(exRe);

                                    load.Result__c = 'Record updated.';
                                }
                            }
                        }
                    } else {
                        ExamResults__c er = new ExamResults__c();
                        er.ExamDate__c = load.DateofExam__c;
                        er.ExamScore__c = load.ExamScore__c;
                        er.ExamsRequired__c = exr.Id;
                        er.Status__c = passFailMap.get(load.PassorFail__c);
                        examResultsToInsert.add(er);

                        load.Result__c = 'Record created.';
                        continue;
                    }
                }
            }

        }

        List<ExamResults__c> examResultsToProcess = new List<ExamResults__c>();
        if (!examResultsToUpdate.isEmpty()) {
            examResultsToProcess.addAll(examResultsToUpdate);
        }

        if (!examResultsToInsert.isEmpty()) {
            examResultsToProcess.addAll(examResultsToInsert);
        }

        if (!examResultsToProcess.isEmpty()) {
            upsert examResultsToProcess;
        }
    }
}