/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the EligibleCandidateLoad Object
* ─────────────────────────────────────────────────────────
* PacPoint- - Created for PVL phase 1
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
public class EligibleCandidateLoadSelector {
    //retuns the list of Applications filtered by phase and SSN's //Added for case 00005582 
    public static List<Application__c> getApplicationsForPhaseAndSSNs(List<String> ssnList, List<String> phaseList) {
        return [SELECT Id, PVLBPID__c, Applicant__c from Application__c WHERE  phase__c NOT IN: phaseList AND PVLBPID__c IN: ssnList];
    }
    
    //retuns the list of Applicants/Accounts filtered by on basis SSN's //Added for case 00005582 
    public static List<Account> getApplicantsForSSNs(List<String> ssnList) {
        return [SELECT Id, BPID__c FROM Account WHERE BPID__c IN: ssnList];
    }

}