@isTest
public with sharing class WebDocumentMutiExtTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
    }
    public static testMethod void testFunc() {
        License__c record = [Select Id from License__c limit 1];
        ApexPages.StandardController stdController = new ApexPages.StandardController(record);
        WebDocumentMutiExt ext = new WebDocumentMutiExt(stdController);
    }
}