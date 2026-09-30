@isTest
private class BarberingCosmetologyRenewalTest {

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
    public static void testLicenseTypes(String licenseType) {
        BarberingCosmetologyRenewal.Input input = new BarberingCosmetologyRenewal.Input();
        Application__c app = [Select Id, SoleOwner__c, LicenseTypeCode__c, RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
        CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
        CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, CurrentLicense__r.SoleOwner__c,
        LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c,
        Status__c, Phase__c from Application__c where LicenseType__r.Name =: licenseType limit 1];
        input.record = app;
        input.license = app.CurrentLicense__r;
        // Set the properties of the input
        // NOTE: You may need to create multiple inputs to cover various scenarios

        List<BarberingCosmetologyRenewal.Input> inputs = new List<BarberingCosmetologyRenewal.Input>{input};

        // Call the execute method
        List<BarberingCosmetologyRenewal.Results> results = BarberingCosmetologyRenewal.execute(inputs);
    }

    @isTest 
    static void testBSC() {
        Test.startTest();
        testLicenseTypes('BSC');
        Test.stopTest();
    }

    @isTest 
    static void testBEO() {
        Test.startTest();
        testLicenseTypes('BEO');
        Test.stopTest();
    }

    @isTest 
    static void testI() {
        Test.startTest();
        testLicenseTypes('I');
        Test.stopTest();
    }
    @isTest 
    static void testBSH() {
        Test.startTest();
        testLicenseTypes('BSH');
        Test.stopTest();
    }
    @isTest 
    static void testBAR() {
        Test.startTest();
        testLicenseTypes('BAR');
        Test.stopTest();
    }

    @isTest 
    static void testBAS() {
        Test.startTest();
        testLicenseTypes('BAS');
        Test.stopTest();
    }
    @isTest
    static void testInactiveFlow() {

        Test.startTest();
        BarberingCosmetologyRenewal.Input input = new BarberingCosmetologyRenewal.Input();
        Application__c record = [Select Id, ActiveInactive__c, SoleOwner__c, LicenseTypeCode__c, RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
        CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
        CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, CurrentLicense__r.SoleOwner__c,
        LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__r.ActiveInactive__c, 
        Status__c, Phase__c from Application__c where LicenseType__r.Name = 'BAS' limit 1];

        record.ActiveInactive__c = 'Inactive';
        License__c license = record.CurrentLicense__r;
        license.ActiveInactive__c = 'Active';
        update license;
        update record;
        
        Application__c app = [Select Id, ActiveInactive__c, SoleOwner__c, LicenseTypeCode__c, RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
        CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
        CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, CurrentLicense__r.SoleOwner__c,
        LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__r.ActiveInactive__c, 
        Status__c, Phase__c from Application__c where LicenseType__r.Name = 'BAS' limit 1];

        input.record = app;
        input.license = app.CurrentLicense__r;
        // Set the properties of the input
        // NOTE: You may need to create multiple inputs to cover various scenarios

        List<BarberingCosmetologyRenewal.Input> inputs = new List<BarberingCosmetologyRenewal.Input>{input};

        // Call the execute method
        try{
            List<BarberingCosmetologyRenewal.Results> results = BarberingCosmetologyRenewal.execute(inputs);
        } catch(Exception ex) {
            
        }
        
        Test.stopTest();
    }
}