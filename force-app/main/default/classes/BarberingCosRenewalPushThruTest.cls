@isTest
private class BarberingCosRenewalPushThruTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'I', 'BEO', 'BAR', 'BSC', 'BSH', 'BAS'});

        List<License__c> licenses = new List<License__c>();
        Set<String> barbeTypes = new Set<String>{'I', 'BEO', 'BAR'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            if(licenseType.Name == 'BEO' || licenseType.Name == 'BSC' ){
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            } else if(barbeTypes.contains(licenseType.Name) ) {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
            lic.ThisLicenseRenewed__c = true;
            
            licenses.add(lic);
        }

        insert licenses;

        for(License__c record: licenses) {
            if(!barbeTypes.contains(record.LicenseType__r.Name)) {
                record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            } else {
                record.Status__c = 'C - Current, Valid & In Good Standing';
            }
        }
        update licenses;

        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        License__c entityLicense = [Select Id from License__c where LicenseType__r.Name = 'I' limit 1];
        License__c entityLicense2 = [Select Id from License__c where LicenseType__r.Name = 'BEO' limit 1];
        for(License__c license: licenses) {
            if(license.LicenseType__r.Name == 'I' || license.LicenseType__r.Name == 'BEO' 
                || license.LicenseType__r.Name == 'BSH') {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'D - Designated';
                assLicenses.add(al);
            }
            if(!license.Name.contains('I')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense2.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)';
                assLicenses.add(al);
            }
        }
        if(assLicenses.size() > 0){
            insert assLicenses;
        }
        
        List<String> appTypes = new List<String>{'RNEW - Renewal', 'RSTR - Restore - No A/I Status'};
        List<Application__c> apps = new List<Application__c>();
        
        for(License__c record: [Select Id, LicenseType__c, LicenseType__r.NextLicensePeriod__c, LicenseType__r.PreviousLicensePeriod__c from License__c ]) {
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
        List<String> licenseSetNames = new List<String>{'BSC','BEO','I','BSH', 'BAR'};
        
        Test.startTest();
        Database.executeBatch(new BarberingCosRenewalPushThru());
        Test.stopTest();
    }

}