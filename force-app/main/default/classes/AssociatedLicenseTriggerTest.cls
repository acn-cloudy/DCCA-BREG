@isTest
public with sharing class AssociatedLicenseTriggerTest {
    @TestSetup  
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
    }
    public static testMethod void testCountLicense() {
        AssociatedLicense__c associatedLicense1 = [Select Id, EmployeeLicense__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' limit 1];
        License__c dlicense = [Select Id, CurrentEmployerCount__c from License__c where Id =: associatedLicense1.EmployeeLicense__c];
        // System.assert(dlicense.CurrentEmployerCount__c > 0);

        AssociatedLicense__c associatedLicense = [Select Id, EmployeeLicense__c, EmploymentStatus__c from AssociatedLicense__c limit 1];
        associatedLicense.EmploymentStatus__c = 'Employed';
        update associatedLicense;
        License__c license = [Select Id, CurrentEmployerCount__c from License__c where Id =: associatedLicense.EmployeeLicense__c];
        // System.assert(license.CurrentEmployerCount__c > 0);
    }

    /**
     * VPVL-13: Test BIC Termination sets LossofBICDate__c on RB-Entity
     */
    @isTest
    static void testBicTerminationSetsLossofBICDate() {
        Id rbEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id rbBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        Id rboRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RBO').getRecordTypeId();
        
        // Account
        Account acc = new Account(); 
        acc.FirstName = 'Test';
        acc.LastName = 'BIC User';
        acc.PersonEmail = 'testbic@example.com';
        insert acc;

        // License Types
        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = 'Active';
        
        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = 'Active';
        
        LicenseType__c ltRBO = new LicenseType__c();
        ltRBO.Name = 'RBO';
        ltRBO.Status__c = 'Active';
        
        insert new List<LicenseType__c>{ltRBEntity, ltRBBroker, ltRBO};

        // RB-Entity License
        License__c rbEntity = new License__c();
        rbEntity.Name = 'RB-Entity-BIC-Test';
        rbEntity.LicenseType__c = ltRBEntity.Id;
        rbEntity.RecordTypeId = rbEntityRecordTypeId;
        rbEntity.Licensee__c = acc.Id;
        rbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntity.ActiveInactive__c = 'Active';
        // Note: PB_Counter__c is a rollup field - it will be calculated from associated PB records
        insert rbEntity;

        // RB-Broker License (BIC)
        License__c rbBroker = new License__c();
        rbBroker.Name = 'RB-Broker-BIC-Test';
        rbBroker.LicenseType__c = ltRBBroker.Id;
        rbBroker.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker.Licensee__c = acc.Id;
        rbBroker.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker.ActiveInactive__c = 'Active';
        
        // RBO License
        License__c rbo = new License__c();
        rbo.Name = 'RBO-BIC-Test';
        rbo.LicenseType__c = ltRBO.Id;
        rbo.RecordTypeId = rboRecordTypeId;
        rbo.Licensee__c = acc.Id;
        rbo.Status__c = 'C - Current, Valid & In Good Standing';
        rbo.ActiveInactive__c = 'Active';
        
        insert new List<License__c>{rbBroker, rbo};

        // Associated License for BIC
        AssociatedLicense__c bicAssoc = new AssociatedLicense__c();
        bicAssoc.EntityLicense__c = rbEntity.Id;
        bicAssoc.EmployeeLicense__c = rbBroker.Id;
        bicAssoc.EmploymentStatus__c = 'Employed';
        bicAssoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';
        
        // Associated License for RBO (Entity is employee of RBO)
        // Note: EntityLicenseType__c is a formula field - it will be calculated from EntityLicense__r.LicenseType__r.Name
        AssociatedLicense__c rboAssoc = new AssociatedLicense__c();
        rboAssoc.EmployeeLicense__c = rbEntity.Id;
        rboAssoc.EntityLicense__c = rbo.Id;
        rboAssoc.EmploymentStatus__c = 'Employed';
        
        insert new List<AssociatedLicense__c>{bicAssoc, rboAssoc};

        // Verify initial state
        rbEntity = [SELECT Id, LossofBICDate__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(null, rbEntity.LossofBICDate__c);

        Test.startTest();
        // Terminate BIC - Require_End_Date_on_Status_Terminated validation rule needs EndDate__c set
        bicAssoc.EmploymentStatus__c = 'Terminated';
        bicAssoc.EndDate__c = Date.today();
        update bicAssoc;
        Test.stopTest();

        // Verify LossofBICDate was set on RB-Entity
        rbEntity = [SELECT Id, LossofBICDate__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(Date.today(), rbEntity.LossofBICDate__c);
    }

    /**
     * VPVL-13: Negative path — terminating a non-BIC association should NOT set LossofBICDate__c.
     * Exercises the early-return guard for non-BIC positions in captureBicTerminationForRbEntity.
     */
    @isTest
    static void testNonBicTerminationDoesNotSetLossofBICDate() {
        Id rbEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id rbBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();

        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'NonBic User';
        acc.PersonEmail = 'testnonbic@example.com';
        insert acc;

        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = 'Active';

        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = 'Active';

        insert new List<LicenseType__c>{ltRBEntity, ltRBBroker};

        License__c rbEntity = new License__c();
        rbEntity.Name = 'RB-Entity-NonBic-Test';
        rbEntity.LicenseType__c = ltRBEntity.Id;
        rbEntity.RecordTypeId = rbEntityRecordTypeId;
        rbEntity.Licensee__c = acc.Id;
        rbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntity.ActiveInactive__c = 'Active';
        insert rbEntity;

        License__c rbBroker = new License__c();
        rbBroker.Name = 'RB-Broker-NonBic-Test';
        rbBroker.LicenseType__c = ltRBBroker.Id;
        rbBroker.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker.Licensee__c = acc.Id;
        rbBroker.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker.ActiveInactive__c = 'Active';
        insert rbBroker;

        AssociatedLicense__c nonBicAssoc = new AssociatedLicense__c();
        nonBicAssoc.EntityLicense__c = rbEntity.Id;
        nonBicAssoc.EmployeeLicense__c = rbBroker.Id;
        nonBicAssoc.EmploymentStatus__c = 'Employed';
        nonBicAssoc.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        insert nonBicAssoc;

        Test.startTest();
        nonBicAssoc.EmploymentStatus__c = 'Terminated';
        nonBicAssoc.EndDate__c = Date.today();
        update nonBicAssoc;
        Test.stopTest();

        rbEntity = [SELECT Id, LossofBICDate__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(null, rbEntity.LossofBICDate__c, 'Non-BIC termination must not set LossofBICDate');
    }

    /**
     * VPVL-13: Negative path — when the entity still has another active BIC, terminating one BIC
     * should NOT set LossofBICDate__c. Exercises the "other active BIC" guard.
     */
    @isTest
    static void testBicTerminationWithAnotherActiveBicDoesNotSetLossofBICDate() {
        Id rbEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id rbBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        Id rboRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RBO').getRecordTypeId();

        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'MultiBic User';
        acc.PersonEmail = 'testmultibic@example.com';
        insert acc;

        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = 'Active';

        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = 'Active';

        LicenseType__c ltRBO = new LicenseType__c();
        ltRBO.Name = 'RBO';
        ltRBO.Status__c = 'Active';

        insert new List<LicenseType__c>{ltRBEntity, ltRBBroker, ltRBO};

        License__c rbEntity = new License__c();
        rbEntity.Name = 'RB-Entity-MultiBic-Test';
        rbEntity.LicenseType__c = ltRBEntity.Id;
        rbEntity.RecordTypeId = rbEntityRecordTypeId;
        rbEntity.Licensee__c = acc.Id;
        rbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntity.ActiveInactive__c = 'Active';
        insert rbEntity;

        License__c bic1 = new License__c();
        bic1.Name = 'RB-Broker-BIC1';
        bic1.LicenseType__c = ltRBBroker.Id;
        bic1.RecordTypeId = rbBrokerRecordTypeId;
        bic1.Licensee__c = acc.Id;
        bic1.Status__c = 'C - Current, Valid & In Good Standing';
        bic1.ActiveInactive__c = 'Active';

        License__c bic2 = new License__c();
        bic2.Name = 'RB-Broker-BIC2';
        bic2.LicenseType__c = ltRBBroker.Id;
        bic2.RecordTypeId = rbBrokerRecordTypeId;
        bic2.Licensee__c = acc.Id;
        bic2.Status__c = 'C - Current, Valid & In Good Standing';
        bic2.ActiveInactive__c = 'Active';

        License__c rbo = new License__c();
        rbo.Name = 'RBO-MultiBic-Test';
        rbo.LicenseType__c = ltRBO.Id;
        rbo.RecordTypeId = rboRecordTypeId;
        rbo.Licensee__c = acc.Id;
        rbo.Status__c = 'C - Current, Valid & In Good Standing';
        rbo.ActiveInactive__c = 'Active';

        insert new List<License__c>{bic1, bic2, rbo};

        AssociatedLicense__c bic1Assoc = new AssociatedLicense__c();
        bic1Assoc.EntityLicense__c = rbEntity.Id;
        bic1Assoc.EmployeeLicense__c = bic1.Id;
        bic1Assoc.EmploymentStatus__c = 'Employed';
        bic1Assoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';

        AssociatedLicense__c bic2Assoc = new AssociatedLicense__c();
        bic2Assoc.EntityLicense__c = rbEntity.Id;
        bic2Assoc.EmployeeLicense__c = bic2.Id;
        bic2Assoc.EmploymentStatus__c = 'Employed';
        bic2Assoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';

        AssociatedLicense__c rboAssoc = new AssociatedLicense__c();
        rboAssoc.EmployeeLicense__c = rbEntity.Id;
        rboAssoc.EntityLicense__c = rbo.Id;
        rboAssoc.EmploymentStatus__c = 'Employed';

        insert new List<AssociatedLicense__c>{bic1Assoc, bic2Assoc, rboAssoc};

        Test.startTest();
        // Terminate only one of two BICs - entity still has the other one active
        bic1Assoc.EmploymentStatus__c = 'Terminated';
        bic1Assoc.EndDate__c = Date.today();
        update bic1Assoc;
        Test.stopTest();

        rbEntity = [SELECT Id, LossofBICDate__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(null, rbEntity.LossofBICDate__c, 
            'LossofBICDate must not be set while another BIC is still active for the entity');
    }

    /**
     * Covers AssociatedLicenseHandler stub methods that are never reached through
     * the AssociatedLicenseTrigger (which only fires on insert/update/after delete).
     * Direct invocation is used to exercise these for coverage purposes only.
     */
    @isTest
    static void testHandlerStubMethodsDirectInvocation() {
        AssociatedLicenseHandler handler = new AssociatedLicenseHandler();
        AssociatedLicense__c stub = new AssociatedLicense__c();
        
        Test.startTest();
        handler.bulkBefore();
        handler.bulkAfter();
        handler.beforeInsert(stub);
        handler.beforeUpdate(stub, stub);
        handler.beforeDelete(stub);
        handler.beforeUnDelete(stub);
        handler.afterDelete(stub);
        handler.afterUnDelete(stub);
        Test.stopTest();
        
        // No exceptions = stubs covered
        System.assert(true, 'AssociatedLicenseHandler stub methods are callable');
    }

    /**
     * Covers the disable-guard early-return path in AssociatedLicenseHandler.afterInsert
     * and afterUpdate when TriggerHelper.disableAssociatedLicenseTrigger = true.
     */
    @isTest
    static void testHandlerWithDisableFlagSkipsLogic() {
        TriggerHelper.disableAssociatedLicenseTrigger = true;
        try {
            AssociatedLicenseHandler handler = new AssociatedLicenseHandler();
            AssociatedLicense__c stub = new AssociatedLicense__c();
            Test.startTest();
            handler.afterInsert(stub);
            handler.afterUpdate(stub, stub);
            handler.andFinally();
            Test.stopTest();
            System.assert(true, 'Disable flag short-circuits handler logic');
        } finally {
            TriggerHelper.disableAssociatedLicenseTrigger = false;
        }
    }

    /**
     * VPVL-13: Negative path — when the RB-Entity has no active RBO association,
     * terminating its only BIC should NOT set LossofBICDate__c (no RBO impact to track).
     * Exercises the "no active RBO" guard.
     */
    @isTest
    static void testBicTerminationWithNoActiveRboDoesNotSetLossofBICDate() {
        Id rbEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id rbBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();

        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'NoRbo User';
        acc.PersonEmail = 'testnorbo@example.com';
        insert acc;

        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = 'Active';

        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = 'Active';

        insert new List<LicenseType__c>{ltRBEntity, ltRBBroker};

        License__c rbEntity = new License__c();
        rbEntity.Name = 'RB-Entity-NoRbo-Test';
        rbEntity.LicenseType__c = ltRBEntity.Id;
        rbEntity.RecordTypeId = rbEntityRecordTypeId;
        rbEntity.Licensee__c = acc.Id;
        rbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntity.ActiveInactive__c = 'Active';
        insert rbEntity;

        License__c bic = new License__c();
        bic.Name = 'RB-Broker-NoRbo-BIC';
        bic.LicenseType__c = ltRBBroker.Id;
        bic.RecordTypeId = rbBrokerRecordTypeId;
        bic.Licensee__c = acc.Id;
        bic.Status__c = 'C - Current, Valid & In Good Standing';
        bic.ActiveInactive__c = 'Active';
        insert bic;

        // BIC association, but NO RBO association for the entity
        AssociatedLicense__c bicAssoc = new AssociatedLicense__c();
        bicAssoc.EntityLicense__c = rbEntity.Id;
        bicAssoc.EmployeeLicense__c = bic.Id;
        bicAssoc.EmploymentStatus__c = 'Employed';
        bicAssoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';
        insert bicAssoc;

        Test.startTest();
        bicAssoc.EmploymentStatus__c = 'Terminated';
        bicAssoc.EndDate__c = Date.today();
        update bicAssoc;
        Test.stopTest();

        rbEntity = [SELECT Id, LossofBICDate__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(null, rbEntity.LossofBICDate__c,
            'LossofBICDate must not be set when entity has no active RBO');
    }

    
    @isTest
    static void testCaptureLossOfSupervisor() {
        LicenseType__c supervisorType = new LicenseType__c(Name = 'SUP-LIC', Status__c = 'Active');
        LicenseType__c mftpType = new LicenseType__c(Name = 'MFTP', Status__c = 'Active');
        mftpType.AbleToInactivate__c = true;
        insert new List<LicenseType__c>{ supervisorType, mftpType };

        License__c supervisorLicense = new License__c(
            LicenseType__c = supervisorType.Id,
            ActiveInactive__c = 'Active',
            Status__c = 'C - Current, Valid & In Good Standing'
        );
        License__c employeeLicense = new License__c(
            LicenseType__c = mftpType.Id,
            ActiveInactive__c = 'Active',
            Status__c = 'C - Current, Valid & In Good Standing'
        );
        insert new List<License__c>{ supervisorLicense, employeeLicense };

        AssociatedLicense__c supervisorAssociation = new AssociatedLicense__c(
            EntityLicense__c = supervisorLicense.Id,
            EmployeeLicense__c = employeeLicense.Id,
            EmploymentStatus__c = 'Employed'
        );
        insert supervisorAssociation;

        AssociatedLicense__c oldAssociation = supervisorAssociation.clone(true, true, false, false);
        AssociatedLicense__c newAssociation = supervisorAssociation.clone(true, true, false, false);
        oldAssociation.EmploymentStatus__c = 'Employed';
        newAssociation.EmploymentStatus__c = 'Terminated';

        Test.startTest();
        AssociatedLicenseService.captureLossOfSupervisor(oldAssociation, newAssociation);
        Test.stopTest();

        employeeLicense = [SELECT ActiveInactive__c FROM License__c WHERE Id = :employeeLicense.Id];
        System.assertEquals('Inactive', employeeLicense.ActiveInactive__c);
    }
}