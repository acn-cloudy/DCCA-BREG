@isTest
public class PDGRenewalTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'PD - Sole Proprietor', 'PD', 'PDA', 'GD', 'GDA', 'GD - Sole Proprietor'});

    }
    @isTest
    static void testProcessPDSoleRestricted() {
        Set<String> inputLicenses = new Set<String> {'PD - Sole Proprietor'};
        Set<String> licenseTypeNames = new Set<String>{'PD'};
        
        PestControlRenewalTest.prepareData(licenseTypeNames, inputLicenses);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        for(License__c license: licenseTest1) {
            license.LicenseRestriction__c = 'R - Restricted';
        }
        update licenseTest1;
        for(License__c l1: licenseTest2) {
            for(License__c l2: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.PositionStatus__c = 'P - PRINCIPAL';
                record.Position__c = 'PR - PRINCIPAL (MASSAGE, PD&G)';
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }

    @isTest
    static void testProcessPDSoleUnRestricted() {
        Set<String> inputLicenses = new Set<String> {'PD - Sole Proprietor'};
        Set<String> licenseTypeNames = new Set<String>{'PD'};
        
        PestControlRenewalTest.prepareData(licenseTypeNames, inputLicenses);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        
        for(License__c l1: licenseTest2) {
            for(License__c l2: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.PositionStatus__c = 'P - PRINCIPAL';
                record.Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)';
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }

    @isTest
    static void testProcessPD() {
        Set<String> inputLicenses = new Set<String> {'PD'};
        Set<String> licenseTypeNames = new Set<String>{'PDA', 'PD - Sole Proprietor'};

        PestControlRenewalTest.prepareData(licenseTypeNames, inputLicenses);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
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

        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }

    @isTest
    static void testProcessGD() {
        Set<String> inputLicenses = new Set<String> {'GD'};
        Set<String> licenseTypeNames = new Set<String>{'GDA', 'GD - Sole Proprietor'};

        prepareData(licenseTypeNames, inputLicenses, inputLicenses, 'extraName');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, Name,  LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        
        for(License__c l1: licenseTest1) {
            if(l1.Name.contains('extraName')) {
                for(License__c l2: licenseTest2) {
                    AssociatedLicense__c record = new AssociatedLicense__c();
                    record.EmployeeLicense__c = l1.Id;
                    record.EntityLicense__c = l2.Id;
                    record.EndDate__c = null;
                    record.EmploymentStatus__c = 'Employed';
                    record.PositionStatus__c = 'P - PRINCIPAL';
                    record.Position__c = 'PR - PRINCIPAL (MASSAGE, PD&G)';
                    associatedLicenses.add(record);
                }
            } else {
                for(License__c l2: licenseTest2) {
                    AssociatedLicense__c record = new AssociatedLicense__c();
                    record.EmployeeLicense__c = l1.Id;
                    record.EntityLicense__c = l2.Id;
                    record.EndDate__c = null;
                    record.EmploymentStatus__c = 'Employed';
                    associatedLicenses.add(record);
                }
            }
        }

        insert associatedLicenses;

        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c 
            where CurrentLicense__r.LicenseType__r.Name in: inputLicenses and CurrentLicense__r.Name like '%extraName%']) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }
    
    public static void prepareData(Set<String> licenseTypeNames, Set<String> inputLicenses, Set<String> extrLicenseTypes, String extraName) {
        List<License__c> licenses = new List<License__c>();
        List<LicenseType__c> licenseTypes = [Select Id, Name from LicenseType__c where Name in: licenseTypeNames or Name in: inputLicenses];
        Account acc = [Select Id from Account limit 1];
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1' ;
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            if(inputLicenses.contains(licenseType.Name)){
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            } else {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            }
            lic.ThisLicenseRenewed__c = true;
            licenses.add(lic);
        }

        for(LicenseType__c licenseType: licenseTypes) {
            if(extrLicenseTypes.contains(licenseType.Name)){
                License__c lic = new License__c();
                lic.Name = licenseType.Name + '-1' + extraName ;
                lic.Licensee__c = acc.Id;
                lic.LicenseType__c = licenseType.Id;
                lic.ActiveInactive__c  = 'Active';
                lic.LicenseType__r = licenseType;
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
                lic.ThisLicenseRenewed__c = true;
                licenses.add(lic);
            } 
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
                if(inputLicenses.contains(record.LicenseType__r.Name)) {
                    app.Status__c = 'D1 - Awaiting Dependency Review' ;
                } else {
                    app.Status__c = 'HC - Application Completed' ;
                }
                
                app.LicenseType__c = record.LicenseType__c;
                app.ApplicationReceivedDate__c = System.today();
                app.LicensePeriodRNEW__c = record.LicenseType__r.PreviousLicensePeriod__c;

                apps.add(app);
            }
        }
        
        insert apps; 
    }
    @isTest
    static void testProcessPDA() {
        Set<String> inputLicenses = new Set<String> {'PDA'};
        Set<String> licenseTypeNames = new Set<String>{'PD'};

        prepareData(licenseTypeNames, inputLicenses, licenseTypeNames, 'testEx');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        
        for(License__c l1: licenseTest1) {
            License__c l2= licenseTest2.get(0);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            record.PositionStatus__c = 'P - PRINCIPAL';
            record.Position__c = 'PR - PRINCIPAL (MASSAGE, PD&G)';
            associatedLicenses.add(record);
        }
        for(License__c l1: licenseTest1) {
            License__c l2= licenseTest2.get(1);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            
            associatedLicenses.add(record);
        }
        
        // PestControlRenewalTest.prepareData(new Set<String>(),licenseTypeNames, 'test1' );
        // Map<String, License__c> oldData = new Map<String, License__c>(licenseTest2);
        // List<License__c> licenseTest3 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames and Id not in: oldData.keySet()];
        
        insert associatedLicenses;
        Test.startTest();
        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c 
            where CurrentLicense__r.LicenseType__r.Name in: inputLicenses ]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }

    
        PDGRenewal.execute(inputs);
        Test.stopTest();
        
    }

    @isTest
    static void testGDA() {
        Set<String> inputLicenses = new Set<String> {'GDA'};
        Set<String> licenseTypeNames = new Set<String>{'GD'};

        prepareData(licenseTypeNames, inputLicenses, licenseTypeNames, 'testEx');
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        
        for(License__c l1: licenseTest1) {
            License__c l2= licenseTest2.get(0);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            record.PositionStatus__c = 'P - PRINCIPAL';
            record.Position__c = 'PR - PRINCIPAL (MASSAGE, PD&G)';
            associatedLicenses.add(record);
        }
        for(License__c l1: licenseTest1) {
            License__c l2= licenseTest2.get(1);
            AssociatedLicense__c record = new AssociatedLicense__c();
            record.EmployeeLicense__c = l2.Id;
            record.EntityLicense__c = l1.Id;
            record.EndDate__c = null;
            record.EmploymentStatus__c = 'Employed';
            
            associatedLicenses.add(record);
        }
        insert associatedLicenses;
        Test.startTest();
        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c 
            where CurrentLicense__r.LicenseType__r.Name in: inputLicenses ]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }

    
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }

    @isTest
    static void testGDSole() {
        Set<String> inputLicenses = new Set<String> {'GD - Sole Proprietor'};
        Set<String> licenseTypeNames = new Set<String>{'GD'};
        
        PestControlRenewalTest.prepareData(licenseTypeNames, inputLicenses);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, LicenseRestriction__c from License__c where LicenseType__r.Name in: inputLicenses];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        for(License__c license: licenseTest1) {
            license.LicenseRestriction__c = 'R - Restricted';
        }
        update licenseTest1;
        for(License__c l1: licenseTest2) {
            for(License__c l2: licenseTest1) {
                AssociatedLicense__c record = new AssociatedLicense__c();
                record.EmployeeLicense__c = l1.Id;
                record.EntityLicense__c = l2.Id;
                record.EndDate__c = null;
                record.PositionStatus__c = 'P - PRINCIPAL';
                record.Position__c = 'PR - PRINCIPAL (MASSAGE, PD&G)';
                record.EmploymentStatus__c = 'Employed';
                associatedLicenses.add(record);
            }
        }
        insert associatedLicenses;

        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name in: inputLicenses]) {
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        
        Test.startTest();
        PDGRenewal.execute(inputs);
        Test.stopTest();
    }
    
    
}