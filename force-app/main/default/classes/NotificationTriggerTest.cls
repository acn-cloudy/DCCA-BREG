@isTest
private class NotificationTriggerTest {
    private static testmethod void testFireFileGenerator() {
        
        Account acc = new Account();
        acc.Name = 'test Acc';
        insert acc;
        
        
        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Type__c = 'Program';
        boardProgram.Name = 'Test';
        insert boardProgram;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.BoardProgram__c = boardProgram.Id;
        insert licenseTypeRecord;

        Application__c app = new Application__c();
        app.LicenseType__c = licenseTypeRecord.Id;
        insert app;

        Notification__c record = new Notification__c();
        record.Application__c = app.Id;
        insert record;
        record.DocumentTemplateName__c = 'Test';
        record.Fire__c = true;
        update record;

    }
}