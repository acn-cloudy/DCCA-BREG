/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
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
public with sharing class EligibleCandidateLoadDomain extends SObjectDomain{
    
    private List<String> phaseList = new List<String>{'H - License Generation'};
    
    public EligibleCandidateLoadDomain(List<EligibleCandidateLoad__c> ecls) {
        super(ecls);
    }
    
    // Returns the list of SSNs //Added for case 00005582 
    public List<String> getSSNList(List<EligibleCandidateLoad__c> eclList) {
        List<String> ssnList= new List<String>();
        for(EligibleCandidateLoad__c ecl: eclList) {
            if(ecl.SSN__c != null) {
                ssnList.add(ecl.SSN__c);
            }
        }
        return ssnList;
    }
    
    // 00005582: Method to return if EligibleCandidateLoad list after typecasting
    
    public List<EligibleCandidateLoad__c> getEcls(List<SObject> records) {
        List<EligibleCandidateLoad__c> eclList= new List<EligibleCandidateLoad__c>();
        for(SObject obj: records) {
            EligibleCandidateLoad__c ecl = (EligibleCandidateLoad__c)obj;
            eclList.add(ecl);
        }
        return eclList;
    }
    
    // 00005582: Method to update Error Descitption field on Eligible Candidate Load record 
    // if  SSN not found account or there are no Open applications.
    public void updateEligibleApplicationsForExamOrErrorDescription() {
        List<EligibleCandidateLoad__c> eclList = getEcls(records);
        List<String> ssnList = getSSNList(eclList);
        List<Account> applicantList = EligibleCandidateLoadSelector.getApplicantsForSSNs(ssnList);
        List<Application__c> applicationList= EligibleCandidateLoadSelector.getApplicationsForPhaseAndSSNs(ssnList, phaseList);
        Map<String, List<Application__c>> ssnApplicationListMap = new Map<String, List<Application__c>>();
        Map<String, Account> ssnAccountMap = new Map<String, Account>();
        List<Application__c> applicationsToUpdate = new List <Application__c>();
        
        for(Account acc : applicantList){
            if(acc.BPID__c != null){
                ssnAccountMap.put(acc.BPID__c, acc);
            }
        }
        
        for(Application__c app : applicationList){
            List<Application__c> appList = null;
            
            if (ssnApplicationListMap.containsKey(app.PVLBPID__c)) {
                appList = ssnApplicationListMap.get(app.PVLBPID__c);
                appList.add(app);
            } 
            else {
                appList = new List<Application__c> {app};
            }
            ssnApplicationListMap.put(app.PVLBPID__c, appList);
        }

        for(EligibleCandidateLoad__c ecl: eclList){
            
            if(ssnAccountMap.containsKey(ecl.SSN__c)){
                
                if(ssnApplicationListMap.containsKey(ecl.SSN__c) && ssnApplicationListMap.get(ecl.SSN__c).size() > 0){
                    system.debug('<><><>+');
                    List<Application__c> applications= ssnApplicationListMap.get(ecl.SSN__c);
                    applicationsToUpdate.addAll(applications);
                }
                else{
                    ecl.ErrorDescription__c = 'This doesnt have any open applications';
                }
            }
            else{
                ecl.ErrorDescription__c = 'SSN Not found';
            }
        }
        updateApplicationsExamEligibilityFlag(applicationsToUpdate);
    }

    //00005582: Method to update the EligibiltyFlag on Application if SSN found 
    public void updateApplicationsExamEligibilityFlag(List<Application__c> applicationsToUpdate) {
        
        for(Application__c app: applicationsToUpdate){
            app.ExamEligibilityConfirmed__c = true;
        }
        update applicationsToUpdate;
    }
}