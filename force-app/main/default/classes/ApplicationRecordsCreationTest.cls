@isTest
public with sharing class ApplicationRecordsCreationTest {
    public static testMethod void testCheckDuplicateLicense() {
        Application__c record = TestDataFactory.createDummyApplication();
        insert record;
        ApplicationRecordsCreation.checkDuplicateLicense(JSON.serialize(record), 'WizardMatchingRecords');
    }
    public static testMethod void testCreateApplicationRecord() {
        Classification__c classification = TestDataFactory.createClasifications();
        Application__c record = TestDataFactory.createDummyApplication();
        ApplicationRecordsCreation.createApplicationRecord(JSON.serialize(record), JSON.serialize(new List<Classification__c>{classification}));
    }
    public static testMethod void testgetRecordTypesBySobjectType() {
        insert TestDataFactory.createBusinessAccount();
        
        Classification__c classification = TestDataFactory.createClasifications();
        ApplicationrecordsCreation.getRecordTypesBySobjectType();
        Account record = [Select Id from Account];
        ApplicationrecordsCreation.getLicenseTypes(record.Id);
        
        
        ApplicationRecordsCreation.getClassifications(classification.LicenseType__c);
    }

    public static testMethod void testGetFieldSetByName() {
        ApplicationRecordsCreation.getFieldSetByName('WizardMatchingRecords');
        ApplicationRecordsCreation.getApplicationRecordTypes('PVL - ACU');
    }
    
}