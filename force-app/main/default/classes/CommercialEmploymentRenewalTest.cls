@isTest
public class CommercialEmploymentRenewalTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'EMA', 'EMA - Sole Proprietor', 'EMP'});
        
    }
    @isTest
    static void testProcessEMASoleProprietor() {
        Set<String> inputLicenses = new Set<String> {'EMA - Sole Proprietor'};
        Set<String> licenseTypeNames = new Set<String>{'EMP'};
        Set<String> otherlicenseTypes = new Set<String>{'EMP'};
        
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, otherlicenseTypes, 'extraName');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        for(License__c l1: licenseTest1) {
            License__c l2 = licenseTest2.get(0);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            record.Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)';
            associatedLicenses.add(record);
        }
        for(License__c l1: licenseTest1) {
            License__c l2 = licenseTest2.get(1);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            associatedLicenses.add(record);
        }
        insert associatedLicenses;

        List<CommercialEmploymentRenewal.Input> inputs = new List<CommercialEmploymentRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            CommercialEmploymentRenewal.Input input = new CommercialEmploymentRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        CommercialEmploymentRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }

    }
    @isTest
    static void testProcessEMA() {
        Set<String> inputLicenses = new Set<String> {'EMA'};
        Set<String> licenseTypeNames = new Set<String>{'EMP'};
        
        
        PestControlRenewalTest.prepareData(licenseTypeNames, inputLicenses);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        for(License__c l1: licenseTest1) {
            for(License__c l2: licenseTest2) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l2.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<CommercialEmploymentRenewal.Input> inputs = new List<CommercialEmploymentRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            CommercialEmploymentRenewal.Input input = new CommercialEmploymentRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        CommercialEmploymentRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }

    }
    @isTest
    static void testProcessEMP() {
        Set<String> inputLicenses = new Set<String> {'EMP'};
        Set<String> licenseTypeNames = new Set<String>{'EMA', 'EMA - Sole Proprietor'};
        
        Set<String> otherInputLicenses = new Set<String> {'EMP'};
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, otherInputLicenses, 'testExtraName');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        for(License__c l1: licenseTest1) {
            for(License__c l2: licenseTest2) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<CommercialEmploymentRenewal.Input> inputs = new List<CommercialEmploymentRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses and CurrentLicense__r.Name like '%testExtraName%' ]) {
            CommercialEmploymentRenewal.Input input = new CommercialEmploymentRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        CommercialEmploymentRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }

    }


}