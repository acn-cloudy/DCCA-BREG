@isTest
public with sharing class LicenseCurrentAndValidFinderTest {
    private static testMethod void testExecute() {
        // create transactions
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
     
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.DependencyRequired__c = true;
        insert licenseTypeRecord;

        License__c licenseRecord = new License__c();
		licenseRecord.Name = 'License A';
		licenseRecord.ActiveInactive__c = 'Active';
		licenseRecord.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord.RecordTypeId = CTEntityRecordTypeId;
        insert licenseRecord;

        Application__c dependentApplication = new Application__c();
        dependentApplication.Applicant__c = acc.Id;
        dependentApplication.LicenseType__c = licenseTypeRecord.Id;
        dependentApplication.Type__c = 'LICN - New License';
        dependentApplication.Phase__c = 'A - Application Received';
        insert dependentApplication;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        insert applicationRecord;

        Classification__c classificationRecord = new Classification__c();
		classificationRecord.Status__c = 'Active';
		classificationRecord.Name = 'Classification Record';
		classificationRecord.LicenseType__c = licenseTypeRecord.Id;
		insert classificationRecord;

        LicenseClassification__c licenseClassificationRecord = new LicenseClassification__c();
		licenseClassificationRecord.Status__c = 'C - Current, Valid & In Good Standing';
        licenseClassificationRecord.License__c = licenseRecord.id;
        licenseClassificationRecord.Classification__c = classificationRecord.Id;
        insert licenseClassificationRecord;

        Test.startTest();
        List<License__c> records = [SELECT Id, Status__c FROM License__c ];
        (new LicenseCurrentAndValidFinderScheduler()).execute(null, records);
        Database.executeBatch(new LicenseCurrentAndValidFinderScheduler(), 100);
        Test.stopTest();
    }
   
}