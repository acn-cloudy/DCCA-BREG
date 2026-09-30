@isTest
private class AssociatedApplicationRenewTest {
    @TestSetup
    static void makeData(){
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'AMD', 'MD', 'DOS'});
        for(LicenseType__c lt: licenseTypes) {
            lt.AbleToInactivate__c = true;
        }
        update licenseTypes;
        List<License__c> licenses = new List<License__c>();
        Set<String> entityTypes = new Set<String>{'MD', 'DOS'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            if(entityTypes.contains(licenseType.Name) ) {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
            lic.ThisLicenseRenewed__c = true;
            if(!entityTypes.contains(licenseType.Name)) {
                License__c clonedRecord = lic.clone();
                licenses.add(clonedRecord);
            }
            licenses.add(lic);
        }
        
        insert licenses;
        for(License__c record: licenses) {
            if(entityTypes.contains(record.LicenseType__r.Name) ) {
                record.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
        }
        update licenses;

        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        List<License__c> entityLicenses = [Select Id from License__c where LicenseType__r.Name in: entityTypes];
        for(License__c license: licenses) {
            if(license.LicenseType__r.Name =='AMD') {
                for(License__c entityLicense: entityLicenses) {
                    AssociatedLicense__c al = new AssociatedLicense__c();
                    al.EmployeeLicense__c = license.Id;
                    al.EntityLicense__c = entityLicense.Id;
                    al.EmploymentStatus__c = 'Employed';
                    assLicenses.add(al);
                }
                break;
            }
        }
        if(assLicenses.size() > 0){
            insert assLicenses;
        }
        
        List<String> appTypes = new List<String>{'RNEW - Renewal'};
        List<Application__c> apps = new List<Application__c>();
        
        for(License__c record: [Select Id, LicenseType__c, LicenseType__r.NextLicensePeriod__c, LicenseType__r.PreviousLicensePeriod__c from License__c  where LicenseType__r.Name = 'AMD']) {
            for(String appType: appTypes) {
                Application__c app = new Application__c();
                app.CurrentLicense__c = record.Id;
                app.Type__c = appType;
                app.Status__c = 'D1 - Awaiting Dependency Review' ;
                app.LicenseType__c = record.LicenseType__c;
                app.ApplicationReceivedDate__c = System.today();
                app.LicensePeriodRNEW__c = record.LicenseType__r.PreviousLicensePeriod__c;

                apps.add(app);
            }
        }
        
        insert apps; 
    }

    @isTest
    private static void testBatch() {
        List<String> licenseSetNames = new List<String>{'AMD'};
        List<License__c> records = [Select Id from License__c where LicenseType__r.Name not in: licenseSetNames];
        List<AssociatedApplicationRenew.Input> inputs = new List<AssociatedApplicationRenew.Input>();
        for(License__c record: records) {
            AssociatedApplicationRenew.Input i = new AssociatedApplicationRenew.Input();
            i.license = record;
            i.associatedLicenseType = 'AMD';
            inputs.add(i);
        }
        Test.startTest();
        AssociatedApplicationRenew.execute(inputs);
        Test.stopTest();

        List<Application__c> applications = [Select Id, Status__c from Application__c where CurrentLicense__r.LicenseType__r.Name in: licenseSetNames and Status__c = 'HC - Application Completed'];
        System.assert(applications.size() > 0);
    }

}