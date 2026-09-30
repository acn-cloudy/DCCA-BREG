@isTest
private class MVRRenewalPushThruBatchTest {
    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'RDS', 'RD', 'MRC', 'MC', 'MR'});

        List<License__c> licenses = new List<License__c>();
        Set<String> mrcTypes = new Set<String>{'MRC', 'MC', 'MR'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            if(licenseType.Name == 'RD' || licenseType.Name == 'RDS' ){
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            } else if(mrcTypes.contains(licenseType.Name) ) {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
            lic.ThisLicenseRenewed__c = true;
            
            licenses.add(lic);
        }

        insert licenses;

        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        License__c entityLicense = [Select Id from License__c where LicenseType__r.Name = 'RDS' limit 1];
        License__c entityLicense2 = [Select Id from License__c where LicenseType__r.Name = 'MRC' limit 1];
        for(License__c license: licenses) {
            if(license.Name.contains('MRC') || license.Name.contains('MC') || license.Name.contains('MR')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'D - Designated';
                assLicenses.add(al);
            }
            if(!license.Name.contains('MRC')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense2.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'D - Designated';
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
    static void testBatch() {
        List<License__c> records = [Select Id, SoleOwner__c, LicenseType__r.Name, ThisLicenseRenewed__c, 
            Status__c from License__c where LicenseType__r.Name = 'RD' or LicenseType__r.Name = 'RDS'];
        
        for(License__c record: records) {
            record.ThisLicenseRenewed__c = true;
            record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        }
        
        update records;
        List<String> recordIds = (new LicenseDomain(records)).getIds();
        List<License__c> otherRecords = [Select Id, Status__c from License__c where Id not in: recordIds];

        for(License__c record: otherRecords) {
            record.Status__c = 'C - Current, Valid & In Good Standing';
        }
        update otherRecords;

        List<Application__c> apps = [Select Id, LicensePeriodRNEW__c, LicenseType__r.PreviousLicensePeriod__c, SameAsLicenseTypeRenewPeriod__c from Application__c where CurrentLicense__c in: recordIds];
        for(Application__c app: apps) {
            app.LicensePeriodRNEW__c = app.LicenseType__r.PreviousLicensePeriod__c;
            System.debug(app.SameAsLicenseTypeRenewPeriod__c);
        }
        update apps;


        
        Test.startTest();
        Database.executeBatch(new MVRRenewalPushThruBatch(), 100);
        Test.stopTest();
    }
}