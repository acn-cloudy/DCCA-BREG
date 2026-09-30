@isTest
public class MotorVehicleIndustryRenewalTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'MVD', 'CS', 'MVB', 'MVD - Sole Proprietor'});
        
    }

    @isTest
    static void testProcessMVD() {
        Set<String> inputLicenses = new Set<String> {'MVD'};
        Set<String> licenseTypeNames = new Set<String>{'CS'};
        Set<String> mVBlicenseType = new Set<String>{'MVB'};
        
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, mVBlicenseType, '');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: mVBlicenseType];
        for(License__c l1: licenseTest1) {
            for(License__c l2: licenseTest2) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l2.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
            for(License__c l3: licenseTest3) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l3.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<MotorVehicleIndustryRenewal.Input> inputs = new List<MotorVehicleIndustryRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            MotorVehicleIndustryRenewal.Input input = new MotorVehicleIndustryRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        MotorVehicleIndustryRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }
    }

    @isTest
    static void testProcessCS() {
        Set<String> inputLicenses = new Set<String> {'CS'};
        Set<String> licenseTypeNames = new Set<String>{'MVD', 'MVD - Sole Proprietor'};
        Set<String> mVBlicenseType = new Set<String>{'MVB'};
        
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, mVBlicenseType, '');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: mVBlicenseType];
        for(License__c l2: licenseTest2) {
            for(License__c l1: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
            for(License__c l3: licenseTest3) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l2.Id;
                record.EntityLicense__c = l3.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<MotorVehicleIndustryRenewal.Input> inputs = new List<MotorVehicleIndustryRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            MotorVehicleIndustryRenewal.Input input = new MotorVehicleIndustryRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        MotorVehicleIndustryRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }
    }

    @isTest
    static void testProcessMVB() {
        Set<String> inputLicenses = new Set<String> {'MVB'};
        Set<String> licenseTypeNames = new Set<String>{'MVD'};
        Set<String> extralicenseType = new Set<String>{'MVD - Sole Proprietor'};
        
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, extralicenseType, '');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: extralicenseType];
        for(License__c l1: licenseTest1) {    
            for(License__c l2: licenseTest2) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l2.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
            for(License__c l3: licenseTest3) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l3.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<MotorVehicleIndustryRenewal.Input> inputs = new List<MotorVehicleIndustryRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            MotorVehicleIndustryRenewal.Input input = new MotorVehicleIndustryRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        MotorVehicleIndustryRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses ] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }
    }

    @isTest
    static void testProcessMVDSoleProprietor() {
        Set<String> inputLicenses = new Set<String> {'MVD - Sole Proprietor'};
        Set<String> licenseTypeNames = new Set<String>{'MVD','CS'};
        Set<String> extralicenseType = new Set<String>{'MVB'};
        
        PDGRenewalTest.prepareData(licenseTypeNames, inputLicenses, extralicenseType, '');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: extralicenseType];
        for(License__c l1: licenseTest1) {    
            for(License__c l2: licenseTest2) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l2.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                record.Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)';
                associatedLicenses.add(record);
            }
            for(License__c l3: licenseTest3) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l3.Id;
                record.EntityLicense__c = l1.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<MotorVehicleIndustryRenewal.Input> inputs = new List<MotorVehicleIndustryRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            MotorVehicleIndustryRenewal.Input input = new MotorVehicleIndustryRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        MotorVehicleIndustryRenewal.execute(inputs);
        Test.stopTest();
        for(Application__c app: [Select Status__c from Application__c ] ){
            Assert.areEqual(app.Status__c, 'HC - Application Completed', 'Assume the license is renewed');
        }
    }

}