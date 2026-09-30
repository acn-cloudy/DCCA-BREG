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
private class PestControlRenewalPushThruTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'PCFR', 'PCO - Entity', 'PCO - RME', 'PCO - Sole Proprietor'});

        for(LicenseType__c licenseType : licenseTypes){
            licenseType.AbleToInactivate__c  = true;
        }
        
        update licenseTypes;
    }

    public static void prepareData(Set<String> licenseTypeNames, Set<String> licenseTypeForTest) {
        prepareData(licenseTypeNames, licenseTypeForTest, '');
    }

    public static void prepareData(Set<String> licenseTypeNames, Set<String> licenseTypeForTest, String extraName) {
        List<License__c> licenses = new List<License__c>();
        List<LicenseType__c> licenseTypes = [Select Id, Name from LicenseType__c where Name in: licenseTypeNames or Name in: licenseTypeForTest];
        Account acc = [Select Id from Account limit 1];
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1' + extraName;
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            lic.ThisLicenseRenewed__c = true;
            licenses.add(lic);
        }
        insert licenses;
        List<String> licenseIds = (new LicenseDomain(licenses)).getIds();
        List<Application__c> apps = new List<Application__c>();
        List<String> appTypes = new List<String>{'RNEW - Renewal'};
        for(License__c record: [Select Id, LicenseType__c, LicenseType__r.Name, 
            LicenseType__r.NextLicensePeriod__c, LicenseType__r.PreviousLicensePeriod__c 
                from License__c where Id in: licenseIds ]) {
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
    static void testPCFR() {
        // create PCO - Entity and PCO - Sole Proprietor
        Set<String> licenseTypeNames = new Set<String>{'PCO - Entity', 'PCO - Sole Proprietor'};
        Set<String> licenseTypeForTest = new Set<String> {'PCFR'};
        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeForTest];
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
        
        Test.startTest();
        DataBase.executeBatch(new PestControlRenewalPushThru(), 200);
        Test.stopTest();
    }

    @isTest
    static void testPCOEntity() {
        Set<String> licenseTypeNames = new Set<String>{'PCO - RME'};
        Set<String> licenseTypeForTest = new Set<String> {'PCO - Entity', 'PCFR'};
        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name ='PCO - Entity'];
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name ='PCFR'];
        for(License__c l2: licenseTest2) {
            for(License__c l1: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                record.PositionStatus__c = 'P - PRINCIPAL';
                associatedLicenses.add(record);
            }
            for(License__c l3: licenseTest3) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l3.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;
        
        Test.startTest();        
        DataBase.executeBatch(new PestControlRenewalPushThru(), 200);
        Test.stopTest();
    }
    
    @isTest
    static void testPCORME() {
        Set<String> licenseTypeForTest = new Set<String> {'PCO - RME'};
        Set<String> licenseTypeNames = new Set<String>{'PCO - Entity', 'PCO - Sole Proprietor'};

        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeForTest];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<String> licenseTestIds = (new LicenseDomain(licenseTest1)).getIds();
        
        prepareData(new Set<String>(), licenseTypeForTest, System.now().getTime() + 'test1');
        List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeForTest and Id not in: licenseTestIds];
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
                record.EmployeeLicense__c = l3.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }

        }
        insert associatedLicenses;

        Test.startTest();        
        DataBase.executeBatch(new PestControlRenewalPushThru(), 200);
        Test.stopTest();
    }

    @isTest
    static void testPCOSoleProprietor() {
        Set<String> licenseTypeNames = new Set<String>{'PCO - RME'};
        Set<String> licenseTypeForTest = new Set<String> {'PCO - Sole Proprietor', 'PCFR'};
        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, DependentLicense__c from License__c where LicenseType__r.Name = 'PCO - Sole Proprietor'];
        List<License__c> licenseTest2 = [Select Id, DependentLicense__c from License__c where LicenseType__r.Name in: licenseTypeNames ];
        
        for(License__c l2: licenseTest2) {
            for(License__c l1: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }   
        }
        for(License__c l1: [Select Id from License__c where LicenseType__r.Name = 'PCFR']) {
            for(License__c l2: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            } 
        }
        insert associatedLicenses;
        
        Test.startTest();
        DataBase.executeBatch(new PestControlRenewalPushThru(), 200);
        Test.stopTest();
    }    
}