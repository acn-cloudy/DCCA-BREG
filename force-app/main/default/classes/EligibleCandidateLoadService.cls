/*
* ─────────────────────────────────────────────────────────
* Used for the Business logic around
* EligibleCandidateLoad records
* ─────────────────────────────────────────────────────────
* PacPoint-SS005582 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Surbhi Sharma - PacificPointCorp
* @created      2019-09-14
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class EligibleCandidateLoadService {

    // 00005582: Method to update Error Descitption field on Eligible Candidate Load record 
    // if  SSN not found account or there are no Open applications.
    public static void updateEligibleApplicationsForExam(List<Sobject> eclList) {
        (new EligibleCandidateLoadDomain(eclList)).updateEligibleApplicationsForExamOrErrorDescription();
    }
}