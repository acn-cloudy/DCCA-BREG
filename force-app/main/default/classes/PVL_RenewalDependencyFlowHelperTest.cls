@IsTest
public with sharing class PVL_RenewalDependencyFlowHelperTest {
    @TestSetup
    static void makeData(){
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        List<LicenseType__c> lts = new List<LicenseType__c>();

        LicenseType__c licenseTypeRecord1 = new LicenseType__c(
            Name = 'LT',
            LicenseTypeEffectiveDate__c = Date.Today(),
            DurationofLicenseInMonths__c = 5
        );
        LicenseType__c licenseTypeRecord2 = new LicenseType__c(
            Name = 'LT2',
            LicenseTypeEffectiveDate__c = Date.Today(),
            DurationofLicenseInMonths__c = 5
        );
        lts.add(licenseTypeRecord1);
        LicenseType__c dependentLT = new LicenseType__c(
            Name = 'LTD',
            LicenseTypeEffectiveDate__c = Date.Today(),
            DurationofLicenseInMonths__c = 5,
            X2ndDependencyRequired__c = true,
            DependentLicenseType__c = licenseTypeRecord1.Id,
            X2ndDependentLicenseType__c = licenseTypeRecord2.Id
        );
        insert dependentLT;

        List<License__c> licenses = new List<License__c>();
        License__c license1 = new License__c(
            LicenseType__c = licenseTypeRecord1.Id,
            Name = 'License1'
        );
        License__c license2 = new License__c(
            LicenseType__c = licenseTypeRecord2.Id,
            Name = 'License2'
        );
        License__c license3 = new License__c(
            LicenseType__c = dependentLT.Id,
            Name = 'License3'
        );
        licenses.add(license1);
        licenses.add(license2);
        licenses.add(license3);
        insert licenses;

        insert new List<AssociatedLicense__c>{
            new AssociatedLicense__c(
                EntityLicense__c = license3.Id,
                EmployeeLicense__c = license1.Id
            ),
            new AssociatedLicense__c(
                EntityLicense__c = license3.Id,
                EmployeeLicense__c = license2.Id
            )
        };

        insert new Application__c(
            Name = 'Test App',
            Status__c = 'D1 - Awaiting Dependency Review',
            CurrentLicense__c = license3.Id
        );
        
    }

    @IsTest
    public static void testgetRelatedMultidependentApplicationsHappyPath_NoResults(){
        List<License__c> licenses = [SELECT Id, LicenseType__c FROM License__c];

        Test.startTest();
        List<PVL_RenewalDependencyFlowHelper.Result> apps = PVL_RenewalDependencyFlowHelper.getRelatedMultidependentApplications(licenses);
        Test.stopTest();

        System.assertEquals(licenses.size(), apps.size(), 'The same amount of outputs should have been returned as the amount of inputs');
        System.assertEquals(1, apps[0].dependentApplications.size(), '1 application should have been returned');

    }
    @IsTest
    public static void testgetRelatedMultidependentApplicationsUnHappyPath(){
        Application__c app = [SELECT Status__c FROM Application__c LIMIT 1];
        app.Status__c = 'A1 - Application Submitted, Awaiting Review';
        update app;

        List<License__c> licenses = [SELECT Id, LicenseType__c FROM License__c];

        Test.startTest();
            List<PVL_RenewalDependencyFlowHelper.Result> apps = PVL_RenewalDependencyFlowHelper.getRelatedMultidependentApplications(licenses);
        Test.stopTest();

        System.assertEquals(licenses.size(), apps.size(), 'The same amount of outputs should have been returned as the amount of inputs');
        System.assertEquals(0, apps[0].dependentApplications.size(), 'No applications should have been returned');

    }
    @IsTest
    public static void testgetRelatedMultidependentApplicationsHappyPath(){
        LicenseType__c tempLT = new LicenseType__c(
            Name = 'Bob'
        );
        insert tempLT;
        License__c tempLicense = new License__c(
            Name = 'License4',
            LicenseType__c = tempLT.Id
        );
        insert tempLicense;

        Test.startTest();
            List<PVL_RenewalDependencyFlowHelper.Result> apps = PVL_RenewalDependencyFlowHelper.getRelatedMultidependentApplications(new List<License__c>{tempLicense});
        Test.stopTest();

        System.assertEquals(1, apps.size(), 'The same amount of outputs should have been returned as the amount of inputs');
        System.assertEquals(0, apps[0].dependentApplications.size(), 'No applications should have been returned');

    }
}