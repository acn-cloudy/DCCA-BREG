@isTest
public with sharing class RelatedListTreeViewerControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
    }
    public static testMethod void testGetChild1ObjectNameForNewRecord() {
        License__c record = [Select Id, DependentLicense__c from License__c where DependentLicense__c != null limit 1];
        RelatedListTreeViewerController.getChild1ObjectNameForNewRecord(record.DependentLicense__c, 'DependentLicenses__r');

    }
    public static testMethod void testGetData() {
        License__c record = [Select Id, DependentLicense__c from License__c where DependentLicense__c != null limit 1];
        RelatedListTreeViewerController.getData(record.DependentLicense__c, 'DependentLicenses__r', 'Licenses__r', 'Name', '', '', 10, 'Name', '');

    }
    public static testMethod void testGetChild1Columns(){
        License__c record = [Select Id, DependentLicense__c from License__c where DependentLicense__c != null limit 1];
        RelatedListTreeViewerController.getChild1Columns(record.DependentLicense__c, 'DependentLicenses__r', 'Licenses__r', 'Name', 'DependentLicense__c');
    }

    @IsTest
    static void testGetIdObjectName(){
        License__c record = [Select Id, DependentLicense__c from License__c where DependentLicense__c != null limit 1];
        RelatedListTreeViewerController.getIdObjectName(record.Id);
    }
}