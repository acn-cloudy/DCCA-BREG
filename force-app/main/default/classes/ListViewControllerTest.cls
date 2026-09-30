@isTest
public with sharing class ListViewControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
    }
    public static testMethod void testSortRecord() {
        List<License__c> records = [Select Id from License__c];
        List<String> recordIds = (new LicenseDomain(records)).getIds();
        ListViewController.sortRecords('License__c', 'Name', null, recordIds, new List<String>{'Name'});
    }
    public static testMethod void testUpsertRecords() {
        List<License__c> records = [Select Id, Name from License__c];
        List<ListViewController.CustomRecord> customRecs = new List<ListViewController.CustomRecord>();
        for(Integer i = 0;i< records.size(); i ++ ) {
            License__c record = records.get(i);
            ListViewController.CustomRecord rec = new ListViewController.CustomRecord();
            rec.record = record;
            rec.index = i; 
            customRecs.add(rec);
        }
        
        System.assert(ListViewController.upsertRecords(JSON.serialize(customRecs)) != null);
        ListViewController.updateRecords(customRecs, false);
    }
}