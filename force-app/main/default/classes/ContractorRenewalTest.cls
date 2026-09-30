@isTest
private class ContractorRenewalTest {
    @testSetup 
    static void setupTestData() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'CT - Entity', 'CT - RME', 'CT - Sole Proprietor'});

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
            if(licenseTypeForTest.contains(licenseType.Name)){
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            } else {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            }
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
                if(licenseTypeForTest.contains(record.LicenseType__r.Name)) {
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
    static void testCTEntity() {
        Set<String> licenseTypeNames = new Set<String>{'CT - RME'};
        Set<String> licenseTypeForTest = new Set<String> {'CT - Entity'};
        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name ='CT - Entity'];
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
        }
        insert associatedLicenses;
        
        List<ContractorRenewal.Input> inputs = new List<ContractorRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name = 'CT - Entity']) {
            ContractorRenewal.Input input = new ContractorRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        ContractorRenewal.execute(inputs);
        Test.stopTest();
    }
    
    @isTest
    static void testCTRME() {
        Set<String> licenseTypeForTest = new Set<String> {'CT - RME'};
        Set<String> licenseTypeNames = new Set<String>{'CT - Entity', 'CT - Sole Proprietor'};

        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeForTest];
        List<License__c> licenseTest2 = [Select Id from License__c where LicenseType__r.Name in: licenseTypeNames];
        List<String> licenseTestIds = (new LicenseDomain(licenseTest1)).getIds();
        Test.startTest();
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
        List<ContractorRenewal.Input> inputs = new List<ContractorRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__c in: licenseTestIds]) {
            ContractorRenewal.Input input = new ContractorRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        
        ContractorRenewal.execute(inputs);
        Test.stopTest();
    }

    @isTest
    static void testCTSoleProprietor() {
        Set<String> licenseTypeNames = new Set<String>{'CT - RME'};
        Set<String> licenseTypeForTest = new Set<String> {'CT - Sole Proprietor'};
        prepareData(licenseTypeNames, licenseTypeForTest);
        List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
        List<License__c> licenseTest1 = [Select Id, DependentLicense__c from License__c where LicenseType__r.Name = 'CT - Sole Proprietor'];
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

        insert associatedLicenses;
        
        List<ContractorRenewal.Input> inputs = new List<ContractorRenewal.Input>();
        for(Application__c app: [Select Id from Application__c where CurrentLicense__r.LicenseType__r.Name = 'CT - Sole Proprietor']) {
            ContractorRenewal.Input input = new ContractorRenewal.Input();
            input.record = app;
            inputs.add(input);
        }
        Test.startTest();
        ContractorRenewal.execute(inputs);
        Test.stopTest();
    }
}