@isTest
private class RealEstateRenewalBatchTest {
    @TestSetup
    static void makeData(){
        //RB - Broker, RS, RBO, RB - Entity and RB - Sole Proprietor
        Id RBBRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        Id RSRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RS').getRecordTypeId();
        Id RBORecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RBO').getRecordTypeId();
        Id RBERecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id RBSPRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Sole Prop').getRecordTypeId();

        //License Type
        LicenseType__c ltRBB = new LicenseType__c();
        ltRBB.Name = 'RB - Broker';
        ltRBB.Status__c = 'Active';
        ltRBB.LicenseTypeEffectiveDate__c = Date.today();

        LicenseType__c ltRS = new LicenseType__c();
        ltRS.Name = 'RS';
        ltRS.Status__c = 'Active';        
        ltRS.LicenseTypeEffectiveDate__c = Date.today();

        LicenseType__c ltRBO = new LicenseType__c();
        ltRBO.Name = 'RBO';
        ltRBO.Status__c = 'Active';        
        ltRBO.LicenseTypeEffectiveDate__c = Date.today();
         
        LicenseType__c ltRBE = new LicenseType__c();
        ltRBE.Name = 'RB - Entity';
        ltRBE.Status__c = 'Active';        
        ltRBE.LicenseTypeEffectiveDate__c = Date.today();

        LicenseType__c ltRBSP = new LicenseType__c();
        ltRBSP.Name = 'RB - Sole Proprietor';
        ltRBSP.Status__c = 'Active';        
        ltRBSP.LicenseTypeEffectiveDate__c = Date.today();
        insert new List<LicenseType__c>{ltRBB, ltRS, ltRBO, ltRBE, ltRBSP};

        //Licenses
        List<License__c> licenseListToCreate = new List<License__c>();

        //Group for Active A
        License__c licRBB = new License__c();
        licRBB.Name = 'License RBB';
        licRBB.ActiveInactive__c = 'Active';
        licRBB.LicenseType__c = ltRBB.Id;
        licRBB.Status__c = 'C - Current, Valid & In Good Standing';
        licRBB.RecordTypeId = RBBRecordTypeId;
        licenseListToCreate.add(licRBB);

        License__c licRS = new License__c();
        licRS.Name = 'License RS';
        licRS.ActiveInactive__c = 'Active';
        licRS.LicenseType__c = ltRS.Id;
        licRS.Status__c = 'C - Current, Valid & In Good Standing';
        licRS.RecordTypeId = RSRecordTypeId;
        licenseListToCreate.add(licRS);

        License__c licRBO = new License__c();
        licRBO.Name = 'License RBO';
        licRBO.ActiveInactive__c = 'Active';
        licRBO.LicenseType__c = ltRBO.Id;
        licRBO.Status__c = 'C - Current, Valid & In Good Standing';
        licRBO.RecordTypeId = RBORecordTypeId;
        licenseListToCreate.add(licRBO);

        License__c licRBE = new License__c();
        licRBE.Name = 'License RBE';
        licRBE.ActiveInactive__c = 'Active';
        licRBE.LicenseType__c = ltRBE.Id;
        licRBE.Status__c = 'C - Current, Valid & In Good Standing';
        licRBE.RecordTypeId = RBERecordTypeId;
        licenseListToCreate.add(licRBE);

        License__c licRBSP = new License__c();
        licRBSP.Name = 'License RBSP';
        licRBSP.ActiveInactive__c = 'Active';
        licRBSP.LicenseType__c = ltRBSP.Id;
        licRBSP.Status__c = 'C - Current, Valid & In Good Standing';
        licRBSP.RecordTypeId = RBSPRecordTypeId;
        licenseListToCreate.add(licRBSP);


        insert licenseListToCreate;

        //Associated Licenses
        List<AssociatedLicense__c> associatedLicenseList = new List<AssociatedLicense__c>();

        // RBB - RBE
        AssociatedLicense__c associatedLicenseA = new AssociatedLicense__c();
        associatedLicenseA.EntityLicense__c = licRBE.Id;
        associatedLicenseA.EmployeeLicense__c = licRBB.Id;
        associatedLicenseA.EmploymentStatus__c = 'Employed';
        associatedLicenseA.PositionStatus__c = 'P - PRINCIPAL';
        associatedLicenseList.add(associatedLicenseA);

        // RS - RBSP
        AssociatedLicense__c associatedLicenseB = new AssociatedLicense__c();
        associatedLicenseB.EntityLicense__c = licRBSP.Id;
        associatedLicenseB.EmployeeLicense__c = licRS.Id;
        associatedLicenseB.EmploymentStatus__c = 'Employed';
        associatedLicenseList.add(associatedLicenseB);

        // RBO - RBE
        AssociatedLicense__c associatedLicenseC = new AssociatedLicense__c();
        associatedLicenseC.EntityLicense__c = licRBE.Id;
        associatedLicenseC.EmployeeLicense__c = licRBO.Id;
        associatedLicenseC.EmploymentStatus__c = 'Employed';
        associatedLicenseC.PositionStatus__c = 'P - PRINCIPAL';
        associatedLicenseList.add(associatedLicenseC);
        insert associatedLicenseList;

        //Accounts
        List<Account> accounts = new List<Account>();
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account acc = new Account();
        acc.Name = 'TEST123';
        acc.FEIN__c = '123';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();  
        insert acc;

        List<Application__c> applications = new List<Application__c>();
        Application__c appRBB = new Application__c();
        appRBB.Applicant__c = acc.Id;
        appRBB.CurrentLicense__c = licRBB.Id;
        appRBB.LicenseType__c = ltRBB.Id;
        appRBB.Type__c = 'RNEW - Renewal';
        appRBB.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(appRBB);

        Application__c appRS = new Application__c();
        appRS.Applicant__c = acc.Id;
        appRS.CurrentLicense__c = licRS.Id;
        appRS.LicenseType__c = ltRS.Id;
        appRS.Type__c = 'RNEW - Renewal';
        appRS.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(appRS);

        Application__c appRBO = new Application__c();
        appRBO.Applicant__c = acc.Id;
        appRBO.CurrentLicense__c = licRBO.Id;
        appRBO.LicenseType__c = ltRBO.Id;
        appRBO.Type__c = 'RNEW - Renewal';
        appRBO.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(appRBO);

        Application__c appRBE = new Application__c();
        appRBE.Applicant__c = acc.Id;
        appRBE.CurrentLicense__c = licRBE.Id;
        appRBE.LicenseType__c = ltRBE.Id;
        appRBE.Type__c = 'RNEW - Renewal';
        appRBE.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(appRBE);

        Application__c appRBSP = new Application__c();
        appRBSP.Applicant__c = acc.Id;
        appRBSP.CurrentLicense__c = licRBSP.Id;
        appRBSP.LicenseType__c = ltRBSP.Id;
        appRBSP.Type__c = 'RNEW - Renewal';
        appRBSP.Status__c = 'D1 - Awaiting Dependency Review';
        applications.add(appRBSP);
        
        insert applications;
    }

    @isTest
    static void test_doRBERenewals() {
        Test.startTest();
        // query license
        License__c license = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'RB - Entity' LIMIT 1];
        Application__c application = [Select Id, Name, CEisConfirmed__c from Application__c WHERE CurrentLicense__c =: license.Id LIMIT 1];

        DataBase.executeBatch(new RealEstateRenewalBatch(new Map<String, License__c>{license.Id => license}, new Map<String, Application__c>{application.Id => application}), 50);
        Test.stopTest();
    }

    @isTest
    static void test_doRBERenewalsAsPaymentGuestUser() {
        Test.startTest();
        // query license
        License__c license = [Select Id, Name from License__c WHERE LicenseTypeName__c = 'RB - Entity' LIMIT 1];
        Application__c application = [Select Id, Name, CEisConfirmed__c from Application__c WHERE CurrentLicense__c =: license.Id LIMIT 1];
        User u = [Select Id, Name FROM User WHERE Name = 'PaymentConnect Site Guest User' LIMIT 1];

        System.runAs(u) {
            DataBase.executeBatch(new RealEstateRenewalBatch(new Map<String, License__c>{license.Id => license}, new Map<String, Application__c>{application.Id => application}), 50);
        }
        Test.stopTest();
    }
}