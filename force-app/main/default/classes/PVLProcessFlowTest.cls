@isTest
private class PVLProcessFlowTest {
    @isTest
    static void testDependencyFlow() {
        TestDataFactory.createLicense();
        Account acc = [Select Id from Account limit 1];
        Set<Id> recordIds = new Set<Id>();
        List<Application__c> apps = new List<Application__c>();
        for(License__c record: [Select Id, LicenseType__c from License__c]) {
            recordIds.add(record.Id);
            Application__c app = new Application__c();
            app.Name = 'app';
            app.Status__c = 'D1 - Awaiting Dependency Review';
            app.LicenseType__c = record.LicenseType__c;
            app.Applicant__c = acc.Id;
            app.CurrentLicense__c = record.Id;
            app.Type__c = 'RNEW - Renewal';
            apps.add(app);
        }

        Test.startTest();
        insert apps;

        
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'DependencyFlow';
        process.Payload__c = JSON.serialize(recordIds);
        EventBus.publish(process);
        Test.stopTest();
    }
    @isTest
    static void testMultiDependencyFlow() {
        TestDataFactory.prepareAssociatedLicenses();
        List<LicenseType__c> licenseTypes = [Select Id, X2ndDependencyRequired__c from LicenseType__c ];
        for(LicenseType__c record: licenseTypes) {
            record.X2ndDependencyRequired__c = true;
        }
        update licenseTypes;
        List<License__c> records = [Select Id, LicenseType__c from License__c ];
        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'MultiDependencyFlow';
        process.Payload__c = JSON.serialize(records);
        EventBus.publish(process);
        Test.stopTest();
        
    }
}