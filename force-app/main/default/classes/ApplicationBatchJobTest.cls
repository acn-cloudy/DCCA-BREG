/*
* ─────────────────────────────────────────────────────────
* Used for testing Application Batch Job
* Application records
* ─────────────────────────────────────────────────────────
* PacPoint-CZ050919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp
* @created      2019-09-05
* ───────────────────────────────────────────────────────────
* Changes
* 5003 - Creation of a batch job that will Set Application to AW when Complete By Date is reached during A Phase
*
* ───────────────────────────────────────────────────────────
*/
@isTest
public with sharing class ApplicationBatchJobTest {
    public static testMethod void test_ApplicationBatchJob() {
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        applicationRecord.Status__c = 'A1 - Application Submitted, Awaiting Review';
        applicationRecord.IsApplicationTerminated__c = false;
        insert applicationRecord;

        applicationRecord.CompleteApplicationBy__c = System.today() - 1;
        update applicationRecord;

		Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 100.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = applicationRecord.Id;

        insert trn;

        Test.StartTest();
        /* run ApplicationBatchJob class */
        ApplicationBatchJob abj = new ApplicationBatchJob();
        Database.executeBatch(abj, 100);
        Test.StopTest();
    }
}