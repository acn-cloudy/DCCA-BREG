/*
* ─────────────────────────────────────────────────────────
* Controller Test for the EligibleCandidateLoadTrigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ250919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* 
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
@isTest
private class EligibleCandidateLoadTriggerTest {
    public static testmethod void testUpdateEligibleApplicationsForExam() {
        Integer testSize = 10;
        // Data setup
        List<Account> accounts = new List<Account>();
        for(Integer i = 0 ; i< testSize; i++ ) {
            Account acc = new Account();
            acc.Name = 'Test 398624';
            acc.BPID__c = '2323442'+ i;
            accounts.add(acc);
        }
		
        insert accounts;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;
        List<Application__c> applications = new List<Application__c>();
        for(Integer i=0;i< testSize; i++ ) {
            Application__c applicationRecord = new Application__c();
            applicationRecord.Applicant__c = accounts.get(i).Id;
            applicationRecord.LicenseType__c = licenseTypeRecord.Id;
            applicationRecord.Type__c = 'LICN - New License';
            applicationRecord.Phase__c = 'A - Application Received';
            applications.add(applicationRecord);
        }
        
        insert applications;

        Test.startTest();
        List<EligibleCandidateLoad__c> eligibleCandiates = new List<EligibleCandidateLoad__c>();
        for(Integer i = 0; i< testSize; i++) {
            EligibleCandidateLoad__c candidateLoad = new EligibleCandidateLoad__c();
            candidateLoad.SSN__c = accounts.get(i).BPID__c;
            eligibleCandiates.add(candidateLoad);
        }
        insert eligibleCandiates;
        List<Application__c> apps = [Select Id from Application__c where ExamEligibilityConfirmed__c = true];
        // System.assert(apps.size() > 0);

        update eligibleCandiates;
        Test.stopTest();
    }
    
}