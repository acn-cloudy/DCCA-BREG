/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class PVL_RenewalsGetDependentApplicationsTest {
    @TestSetup
    static void makeData(){
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        insert new PVLRenewalSettings__c(
            ReceivedDateGracePeriod__c = 15
        );

        List<LicenseType__c> lts = new List<LicenseType__c>();

        LicenseType__c licenseTypeRecord1 = new LicenseType__c(
            Name = 'LT',
            LicenseTypeEffectiveDate__c = Date.Today(),
            StartofRenewalPeriod__c = Date.Today(),
            DurationofLicenseInMonths__c = 5
        );
        LicenseType__c licenseTypeRecord2 = new LicenseType__c(
            Name = 'LT2',
            LicenseTypeEffectiveDate__c = Date.Today(),
            StartofRenewalPeriod__c = Date.Today(),
            DurationofLicenseInMonths__c = 5
        );
        lts.add(licenseTypeRecord1);
        insert lts;
        LicenseType__c dependentLT = new LicenseType__c(
            Name = 'LTD',
            LicenseTypeEffectiveDate__c = Date.Today(),
            StartofRenewalPeriod__c = Date.Today(),
            DurationofLicenseInMonths__c = 5,
            X2ndDependencyRequired__c = true,
            DependentLicenseType__c = licenseTypeRecord1.Id,
            X2ndDependentLicenseType__c = licenseTypeRecord2.Id,
            TypeofPositionStatus__c = 'P - PRINCIPAL'
        );
        insert dependentLT;

        List<License__c> licenses = new List<License__c>();
        License__c license1 = new License__c(
            LicenseType__c = licenseTypeRecord1.Id,
            Name = 'EmployeeLicense1'
        );
        License__c license2 = new License__c(
            LicenseType__c = licenseTypeRecord2.Id,
            Name = 'EmployeeLicense2'
        );
        License__c license3 = new License__c(
            LicenseType__c = dependentLT.Id,
            Name = 'EntityLicense3'
        );
        licenses.add(license1);
        licenses.add(license2);
        licenses.add(license3);
        insert licenses;

        insert new List<AssociatedLicense__c>{
            new AssociatedLicense__c(
                EntityLicense__c = license3.Id,
                EmployeeLicense__c = license1.Id,
                // EntityPrincipal__c = true,
                EmploymentStatus__c = 'Employed',
                PositionStatus__c = 'P - PRINCIPAL'
            ),
            new AssociatedLicense__c(
                EntityLicense__c = license3.Id,
                EmployeeLicense__c = license2.Id,
                // EntityPrincipal__c = true,
                EmploymentStatus__c = 'Employed',
                PositionStatus__c = 'P - PRINCIPAL'
            )
        };

        insert new Application__c(
            Name = 'Test App',
            Status__c = 'D1 - Awaiting Dependency Review',
            Type__c = 'RNEW - Renewal',
            CurrentLicense__c = license1.Id,
            LicenseType__c = licenseTypeRecord1.Id,
            ApplicationReceivedDate__c = Date.Today()
        );
        
    }
    @isTest
    static void myUnitTest() {
        License__c inputLicense = [SELECT DependentLicense__c FROM License__c WHERE LicenseType__r.Name = 'LTD'];
        Test.startTest();
        List<PVL_RenewalsGetDependentApplications.Input> inputs = new List<PVL_RenewalsGetDependentApplications.Input>();
        PVL_RenewalsGetDependentApplications.Input input = new PVL_RenewalsGetDependentApplications.Input();
        input.ivokingLicense = inputLicense;
        input.associatedLicenseRelationship = 'EmployeeLicense';
        input.requiresEntityPrincipal = false;
        inputs.add(input);
        
        List<PVL_RenewalsGetDependentApplications.Output> outputs = PVL_RenewalsGetDependentApplications.getDependentApplication(inputs);
        Test.stopTest();
        System.assertNotEquals(null, outputs[0]?.dependentApplication, 'An application should have been returned');
        System.assertEquals([SELECT Id FROM Application__c WHERE CurrentLicense__r.LicenseType__r.Name = 'LT' LIMIT 1].Id, outputs[0]?.dependentApplication.Id, 'The wrong dependent application was not located');
    }
}