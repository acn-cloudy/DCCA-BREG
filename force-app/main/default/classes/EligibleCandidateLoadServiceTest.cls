@isTest
public with sharing class EligibleCandidateLoadServiceTest {
    public static testMethod void testEligibleCandidates() {
        List<EligibleCandidateLoad__c> records = TestDataFactory.createEligibleCandidateLoad();
        EligibleCandidateLoadService.updateEligibleApplicationsForExam(records);
    }

    
}