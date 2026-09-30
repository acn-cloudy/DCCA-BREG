@isTest
public with sharing class RelatedListControllerTest {
    public static testMethod void testGetRelatedRecords() {
        TestDataFactory.createLicense();
        License__c record = [Select Id, Application__c, DependentLicense__c from License__c where DependentLicense__c != null limit 1];
        RelatedListController.getRelatedRecords('["Name"]', 'License__c', 'Application__c', record.Application__c, null, null);
        RelatedListController.getSubChildren('["Name"]', 'License__c', 'Application__c', record.Application__c, null, '["Name"]', 'License__c', 'DependentLicense__c', null);

    }
}