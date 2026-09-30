@isTest
public with sharing class BatchLicenseResetAuditTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        List<License__c> licenses =  [Select Id, FlaggedforAudit__c from License__c] ;
        for(License__c license: licenses) {
            license.FlaggedforAudit__c = true;
        }
        update licenses;
        List<Notification__c> notifications = new List<Notification__c>();
        for(License__c license: licenses) {
            Notification__c notification = new Notification__c();
            notification.Status__c = 'Scheduled';
            notification.DocumentTemplateName__c = 'Notice of Audit';
            notification.SendToPrinter__c = true;
            notification.RecordId__c = license.Id;
            notification.License__c = license.Id;

            notifications.add(notification);
        }
        insert notifications;
        
    }
    public static  testMethod void testBatch() {
        LicenseType__c record = [Select Id from LicenseType__c limit 1] ;
        List<Id> resetAuditLTIds = new List<Id>();
        resetAuditLTIds.add(record.Id);
        Database.executeBatch(new BatchLicenseResetAudit(resetAuditLTIds), 50);
        
    }

}