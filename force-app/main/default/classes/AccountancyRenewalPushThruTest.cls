@isTest
private class AccountancyRenewalPushThruTest {
    @testSetup 
    static void setupTestData() {
        
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'FPTP', 'FPTP - Sole Proprietor', 'CPA'});

        List<License__c> licenses = new List<License__c>();
        Set<String> CPATypes = new Set<String>{'CPA'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            if(CPATypes.contains(licenseType.Name) ) {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
            lic.ThisLicenseRenewed__c = true;
            
            licenses.add(lic);
        }

        insert licenses;
        for(License__c record: licenses) {
            if(record.LicenseType__r.Name == 'CPA') {
                record.Status__c = 'C - Current, Valid & In Good Standing';
                record.Privilege__c = 'P - Permit to Practice';
            } else {
                record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
        }
        update licenses;

        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        License__c entityLicense = [Select Id from License__c where LicenseType__r.Name = 'FPTP' limit 1];
        License__c entityLicense2 = [Select Id from License__c where LicenseType__r.Name = 'FPTP - Sole Proprietor' limit 1];
        for(License__c license: licenses) {
            if(license.LicenseType__r.Name == 'CPA') {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'P - PRINCIPAL';
                al.Position__c = 'CPA - CERTIFIED PUBLIC ACCOUNTANT';
                assLicenses.add(al);
            }
            if(!license.Name.contains('FPTP - Sole Proprietor')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense2.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)';
                al.PositionStatus__c = 'P - PRINCIPAL';
                assLicenses.add(al);
            }
        }
        if(assLicenses.size() > 0){
            insert assLicenses;
        }
        
        List<String> appTypes = new List<String>{'RNEW - Renewal'};
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
        List<String> licenseSetNames = new List<String>{'FPTP', 'FPTP - Sole Proprietor'};

        Test.startTest();
        Database.executeBatch(new AccountancyRenewalPushThru());
        Test.stopTest();

        List<Application__c> applications = [Select Id, Status__c from Application__c where CurrentLicense__r.LicenseType__r.Name in: licenseSetNames and Status__c = 'HC - Application Completed'];
        System.assertEquals(applications.size(), licenseSetNames.size());

    }
}