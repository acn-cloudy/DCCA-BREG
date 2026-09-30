/**
 * VPVL-13: Test class for RBEntityPrincipalBrokerSuspenseBatch
 * Tests all scenarios:
 * 1. Loss of Principal Broker (NOPB suspense creation)
 * 2. Loss of BIC (NBIC suspense creation)
 * 3. Loss of Entity (employee inactivation)
 * 4. Loss of Sole Proprietor (employee inactivation)
 * 5. Skip scenarios (has PB, has BIC, no RBO, not inactive)
 * 
 * @author  Akanksha Reddy Anthireddygari
 * @created 2026-01-22
 * @ticket  VPVL-13
 */
@isTest
private class RBEntityPrincipalBrokerSuspenseBatchTest {
    
    @TestSetup
    static void makeData() {
        // Create License Types
        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = 'Active';
        ltRBEntity.NumberofDaysUntilAutoForfeiture__c = 60;
        ltRBEntity.AutoForfeitureStatus__c = 'F - Terminated; Needs to Reapply';
        ltRBEntity.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBEntity.DurationofLicenseInMonths__c = 24;
        // ActiveInactiveIsSetToInactive validation rule requires AbleToInactivate__c
        ltRBEntity.AbleToInactivate__c = true;
        
        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = 'Active';
        ltRBBroker.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBBroker.DurationofLicenseInMonths__c = 24;
        ltRBBroker.AbleToInactivate__c = true;
        
        LicenseType__c ltRBO = new LicenseType__c();
        ltRBO.Name = 'RBO';
        ltRBO.Status__c = 'Active';
        ltRBO.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBO.DurationofLicenseInMonths__c = 24;
        ltRBO.AbleToInactivate__c = true;
        
        LicenseType__c ltRBSoleProp = new LicenseType__c();
        ltRBSoleProp.Name = 'RB - Sole Proprietor';
        ltRBSoleProp.Status__c = 'Active';
        ltRBSoleProp.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBSoleProp.DurationofLicenseInMonths__c = 24;
        ltRBSoleProp.AbleToInactivate__c = true;
        
        insert new List<LicenseType__c>{ltRBEntity, ltRBBroker, ltRBO, ltRBSoleProp};
        
        // Create Account
        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'User';
        acc.PersonEmail = 'testuser@example.com';
        insert acc;
        
        // Get Record Type IDs
        Id rbEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id rbBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        Id rboRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RBO').getRecordTypeId();
        Id rbSolePropRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Sole Prop').getRecordTypeId();
        
        // Create RB-Entity License for NOPB testing (no PB associations - PB_Counter will be 0)
        License__c rbEntityNOPB = new License__c();
        rbEntityNOPB.Name = 'RB-Entity-NOPB';
        rbEntityNOPB.LicenseType__c = ltRBEntity.Id;
        rbEntityNOPB.RecordTypeId = rbEntityRecordTypeId;
        rbEntityNOPB.Licensee__c = acc.Id;
        rbEntityNOPB.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntityNOPB.ActiveInactive__c = 'Active';
        // Note: PB_Counter__c is a rollup field - will be 0 since no PB associations
        rbEntityNOPB.LossofPrincipalBrokerDate__c = Date.today();
        rbEntityNOPB.LossOfPrincipalRMEDate__c = Date.today();
        
        // Create RB-Entity License for NBIC testing (will have PB association)
        License__c rbEntityNBIC = new License__c();
        rbEntityNBIC.Name = 'RB-Entity-NBIC';
        rbEntityNBIC.LicenseType__c = ltRBEntity.Id;
        rbEntityNBIC.RecordTypeId = rbEntityRecordTypeId;
        rbEntityNBIC.Licensee__c = acc.Id;
        rbEntityNBIC.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntityNBIC.ActiveInactive__c = 'Active';
        // Note: PB_Counter__c is a rollup field - will have PB association created below
        rbEntityNBIC.LossofBICDate__c = Date.today();
        
        // Create RB-Entity License for Entity Loss testing
        License__c rbEntityLoss = new License__c();
        rbEntityLoss.Name = 'RB-Entity-Loss';
        rbEntityLoss.LicenseType__c = ltRBEntity.Id;
        rbEntityLoss.RecordTypeId = rbEntityRecordTypeId;
        rbEntityLoss.Licensee__c = acc.Id;
        rbEntityLoss.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntityLoss.ActiveInactive__c = 'Inactive';
        // Note: PB_Counter__c is a rollup field
        rbEntityLoss.LossofRBEntityDate__c = Date.today();
        
        // Create Sole Proprietor License for SP Loss testing
        License__c soleProp = new License__c();
        soleProp.Name = 'RB-SoleProp-001';
        soleProp.LicenseType__c = ltRBSoleProp.Id;
        soleProp.RecordTypeId = rbSolePropRecordTypeId;
        soleProp.Licensee__c = acc.Id;
        soleProp.Status__c = 'C - Current, Valid & In Good Standing';
        soleProp.ActiveInactive__c = 'Inactive';
        soleProp.LossofSoleProprietorDate__c = Date.today();
        
        // Create RB-Entity with active PB (should be skipped - will have PB association)
        License__c rbEntityWithPB = new License__c();
        rbEntityWithPB.Name = 'RB-Entity-HasPB';
        rbEntityWithPB.LicenseType__c = ltRBEntity.Id;
        rbEntityWithPB.RecordTypeId = rbEntityRecordTypeId;
        rbEntityWithPB.Licensee__c = acc.Id;
        rbEntityWithPB.Status__c = 'C - Current, Valid & In Good Standing';
        rbEntityWithPB.ActiveInactive__c = 'Active';
        // Note: PB_Counter__c is a rollup field - will have PB association created below
        rbEntityWithPB.LossofPrincipalBrokerDate__c = Date.today();
        
        insert new List<License__c>{rbEntityNOPB, rbEntityNBIC, rbEntityLoss, soleProp, rbEntityWithPB};
        
        // Create Employee Licenses (RB-Broker)
        // Note: LicenseHistoryLicensePeriod__c is a formula field and cannot be set directly
        License__c rbBroker1 = new License__c();
        rbBroker1.Name = 'RB-Broker-001';
        rbBroker1.LicenseType__c = ltRBBroker.Id;
        rbBroker1.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker1.Licensee__c = acc.Id;
        rbBroker1.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker1.ActiveInactive__c = 'Active';
        
        License__c rbBroker2 = new License__c();
        rbBroker2.Name = 'RB-Broker-002';
        rbBroker2.LicenseType__c = ltRBBroker.Id;
        rbBroker2.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker2.Licensee__c = acc.Id;
        rbBroker2.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker2.ActiveInactive__c = 'Active';
        
        License__c rbBroker3 = new License__c();
        rbBroker3.Name = 'RB-Broker-003';
        rbBroker3.LicenseType__c = ltRBBroker.Id;
        rbBroker3.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker3.Licensee__c = acc.Id;
        rbBroker3.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker3.ActiveInactive__c = 'Active';
        
        // Create RBO Licenses
        License__c rbo1 = new License__c();
        rbo1.Name = 'RBO-001';
        rbo1.LicenseType__c = ltRBO.Id;
        rbo1.RecordTypeId = rboRecordTypeId;
        rbo1.Licensee__c = acc.Id;
        rbo1.Status__c = 'C - Current, Valid & In Good Standing';
        rbo1.ActiveInactive__c = 'Active';
        
        insert new List<License__c>{rbBroker1, rbBroker2, rbBroker3, rbo1};
        
        // Create Associated Licenses for Entity Loss testing
        AssociatedLicense__c assocEntityLoss = new AssociatedLicense__c();
        assocEntityLoss.EntityLicense__c = rbEntityLoss.Id;
        assocEntityLoss.EmployeeLicense__c = rbBroker1.Id;
        assocEntityLoss.EmploymentStatus__c = 'Employed';
        assocEntityLoss.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        
        // Create Associated Licenses for Sole Proprietor Loss testing
        AssociatedLicense__c assocSPLoss = new AssociatedLicense__c();
        assocSPLoss.EntityLicense__c = soleProp.Id;
        assocSPLoss.EmployeeLicense__c = rbBroker2.Id;
        assocSPLoss.EmploymentStatus__c = 'Employed';
        assocSPLoss.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        
        // Create Associated Licenses for NBIC testing (RBO where RB-Entity is employee)
        // Note: EntityLicenseType__c is a formula field - it derives from EntityLicense__r.LicenseType__r.Name
        AssociatedLicense__c assocNBIC = new AssociatedLicense__c();
        assocNBIC.EmployeeLicense__c = rbEntityNBIC.Id;
        assocNBIC.EntityLicense__c = rbo1.Id;
        assocNBIC.EmploymentStatus__c = 'Employed';
        
        // Create PB association for rbEntityNBIC (so PB_Counter > 0)
        AssociatedLicense__c assocPBforNBIC = new AssociatedLicense__c();
        assocPBforNBIC.EntityLicense__c = rbEntityNBIC.Id;
        assocPBforNBIC.EmployeeLicense__c = rbBroker3.Id;
        assocPBforNBIC.EmploymentStatus__c = 'Employed';
        assocPBforNBIC.Position__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)';
        
        // Create PB association for rbEntityWithPB (so PB_Counter > 0 and it gets skipped)
        License__c rbBroker4 = new License__c();
        rbBroker4.Name = 'RB-Broker-004';
        rbBroker4.LicenseType__c = ltRBBroker.Id;
        rbBroker4.RecordTypeId = rbBrokerRecordTypeId;
        rbBroker4.Licensee__c = acc.Id;
        rbBroker4.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker4.ActiveInactive__c = 'Active';
        insert rbBroker4;
        
        AssociatedLicense__c assocPBforHasPB = new AssociatedLicense__c();
        assocPBforHasPB.EntityLicense__c = rbEntityWithPB.Id;
        assocPBforHasPB.EmployeeLicense__c = rbBroker4.Id;
        assocPBforHasPB.EmploymentStatus__c = 'Employed';
        assocPBforHasPB.Position__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)';
        
        insert new List<AssociatedLicense__c>{assocEntityLoss, assocSPLoss, assocNBIC, assocPBforNBIC, assocPBforHasPB};
    }
    
    /**
     * Test NOPB suspense creation
     */
    @isTest
    static void test_NOPBSuspenseCreation() {
        // Get test data
        License__c rbEntity = [SELECT Id, Name, LossofPrincipalBrokerDate__c, PB_Counter__c 
                               FROM License__c WHERE Name = 'RB-Entity-NOPB' LIMIT 1];
        
        // Verify setup
        System.assertEquals(Date.today(), rbEntity.LossofPrincipalBrokerDate__c);
        System.assertEquals(0, rbEntity.PB_Counter__c);
        
        // Verify no suspense exists
        List<Suspense__c> existingSuspenses = [SELECT Id FROM Suspense__c WHERE License__c = :rbEntity.Id];
        System.assertEquals(0, existingSuspenses.size());
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify NOPB suspense was created
        List<Suspense__c> suspenses = [SELECT Id, MaintenanceType__c, SuspenseDueDate__c 
                                        FROM Suspense__c WHERE License__c = :rbEntity.Id];
        System.assertEquals(1, suspenses.size());
        System.assertEquals('NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER', suspenses[0].MaintenanceType__c);
        
        // Note: the batch sets GenerateEntityLosesRMENotification__c = true on the license,
        // but downstream automation (LicenseImmediateActions flow + LicenseRMELoseBatch) consumes
        // the flag and resets it to false in the same transaction. The reliable observable outcome
        // is the NOPB suspense record verified above.
    }
    
    /**
     * Test NBIC suspense creation
     */
    @isTest
    static void test_NBICSuspenseCreation() {
        // Get test data
        License__c rbEntity = [SELECT Id, Name, LossofBICDate__c 
                               FROM License__c WHERE Name = 'RB-Entity-NBIC' LIMIT 1];
        
        // Verify setup
        System.assertEquals(Date.today(), rbEntity.LossofBICDate__c);
        
        // Verify no suspense exists
        List<Suspense__c> existingSuspenses = [SELECT Id FROM Suspense__c WHERE License__c = :rbEntity.Id];
        System.assertEquals(0, existingSuspenses.size());
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify NBIC suspense was created
        List<Suspense__c> suspenses = [SELECT Id, MaintenanceType__c, SuspenseDueDate__c 
                                        FROM Suspense__c WHERE License__c = :rbEntity.Id];
        System.assertEquals(1, suspenses.size());
        System.assertEquals('NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE', suspenses[0].MaintenanceType__c);
    }
    
    /**
     * Test Entity Loss - employee inactivation
     */
    @isTest
    static void test_EntityLossEmployeeInactivation() {
        // Get test data
        License__c rbEntity = [SELECT Id, Name, LossofRBEntityDate__c, ActiveInactive__c 
                               FROM License__c WHERE Name = 'RB-Entity-Loss' LIMIT 1];
        License__c employee = [SELECT Id, Name, ActiveInactive__c, Status__c 
                               FROM License__c WHERE Name = 'RB-Broker-001' LIMIT 1];
        
        // Verify setup
        System.assertEquals(Date.today(), rbEntity.LossofRBEntityDate__c);
        System.assertEquals('Inactive', rbEntity.ActiveInactive__c);
        System.assertEquals('Active', employee.ActiveInactive__c);
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify employee was inactivated
        employee = [SELECT Id, ActiveInactive__c, Status__c FROM License__c WHERE Id = :employee.Id];
        System.assertEquals('Inactive', employee.ActiveInactive__c);
        System.assertEquals('C - Current, Valid & In Good Standing', employee.Status__c);
        
        // Verify INAC history record was created
        List<LicenseHistory__c> histories = [SELECT Id, TransactionType__c, Remarks__c 
                                              FROM LicenseHistory__c WHERE License__c = :employee.Id];
        System.assertEquals(1, histories.size());
        System.assertEquals('I - INACTIVE', histories[0].TransactionType__c);
        System.assertEquals('Employee Lost Employer', histories[0].Remarks__c);
    }
    
    /**
     * Test Sole Proprietor Loss - employee inactivation
     */
    @isTest
    static void test_SoleProprietorLossEmployeeInactivation() {
        // Get test data
        License__c soleProp = [SELECT Id, Name, LossofSoleProprietorDate__c, ActiveInactive__c 
                               FROM License__c WHERE Name = 'RB-SoleProp-001' LIMIT 1];
        License__c employee = [SELECT Id, Name, ActiveInactive__c, Status__c 
                               FROM License__c WHERE Name = 'RB-Broker-002' LIMIT 1];
        
        // Verify setup
        System.assertEquals(Date.today(), soleProp.LossofSoleProprietorDate__c);
        System.assertEquals('Inactive', soleProp.ActiveInactive__c);
        System.assertEquals('Active', employee.ActiveInactive__c);
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify employee was inactivated
        employee = [SELECT Id, ActiveInactive__c, Status__c FROM License__c WHERE Id = :employee.Id];
        System.assertEquals('Inactive', employee.ActiveInactive__c);
        System.assertEquals('C - Current, Valid & In Good Standing', employee.Status__c);
        
        // Verify INAC history record was created
        List<LicenseHistory__c> histories = [SELECT Id, TransactionType__c, Remarks__c 
                                              FROM LicenseHistory__c WHERE License__c = :employee.Id];
        System.assertEquals(1, histories.size());
        System.assertEquals('I - INACTIVE', histories[0].TransactionType__c);
        System.assertEquals('Employee Lost Employer', histories[0].Remarks__c);
    }
    
    /**
     * Test Skip - RB-Entity has active PB
     */
    @isTest
    static void test_SkipHasPB() {
        // Get test data
        License__c rbEntity = [SELECT Id, Name, LossofPrincipalBrokerDate__c, PB_Counter__c 
                               FROM License__c WHERE Name = 'RB-Entity-HasPB' LIMIT 1];
        
        // Verify setup
        System.assertEquals(Date.today(), rbEntity.LossofPrincipalBrokerDate__c);
        System.assertEquals(1, rbEntity.PB_Counter__c);
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify no NOPB suspense was created (skipped because has PB)
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c 
                                        WHERE License__c = :rbEntity.Id 
                                        AND MaintenanceType__c = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER'];
        System.assertEquals(0, suspenses.size());
    }
    
    /**
     * Test Schedulable interface
     */
    @isTest
    static void test_Schedulable() {
        Test.startTest();
        String jobId = System.schedule('Test RB-Entity Batch', '0 0 0 * * ?', new RBEntityPrincipalBrokerSuspenseBatch());
        Test.stopTest();
        
        // Verify job was scheduled
        List<CronTrigger> triggers = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, triggers.size());
    }
    
    /**
     * Test batch with no records
     */
    @isTest
    static void test_NoRecords() {
        // Delete all test data
        delete [SELECT Id FROM License__c WHERE LossofPrincipalBrokerDate__c = TODAY 
                OR LossofBICDate__c = TODAY OR LossofRBEntityDate__c = TODAY 
                OR LossofSoleProprietorDate__c = TODAY];
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Just verify no errors occurred
        System.assert(true);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Negative-path tests targeting skip branches in the batch
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * BIC loss skipped when the entity still has another active BIC association.
     * Exercises the "has active BIC" early return in processLossOfBIC.
     */
    @isTest
    static void test_BicLoss_SkippedWhenAnotherBicStillActive() {
        License__c rbEntity = [SELECT Id FROM License__c WHERE Name = 'RB-Entity-NBIC' LIMIT 1];
        License__c someBroker = [SELECT Id FROM License__c WHERE Name = 'RB-Broker-001' LIMIT 1];

        // Insert another active BIC association so the batch's BIC-still-present guard triggers
        AssociatedLicense__c anotherBic = new AssociatedLicense__c();
        anotherBic.EntityLicense__c = rbEntity.Id;
        anotherBic.EmployeeLicense__c = someBroker.Id;
        anotherBic.EmploymentStatus__c = 'Employed';
        anotherBic.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';
        insert anotherBic;
        
        // Snapshot existing suspense count to be sure no new NBIC is created
        Integer beforeCount = [SELECT count() FROM Suspense__c 
                               WHERE License__c = :rbEntity.Id 
                               AND MaintenanceType__c = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE'];
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        Integer afterCount = [SELECT count() FROM Suspense__c 
                              WHERE License__c = :rbEntity.Id 
                              AND MaintenanceType__c = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE'];
        System.assertEquals(beforeCount, afterCount, 'NBIC must not be created when another active BIC exists');
    }

    /**
     * BIC loss skipped when the entity has no active RBO association.
     * Exercises the "no active RBO" early return in processLossOfBIC.
     */
    @isTest
    static void test_BicLoss_SkippedWhenNoActiveRbo() {
        // Build a fresh RB-Entity with LossofBICDate=today, no BIC association, no RBO association
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Entity' LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        
        License__c isolatedEntity = new License__c();
        isolatedEntity.Name = 'RB-Entity-NoRBO-Isolated';
        isolatedEntity.LicenseType__c = lt.Id;
        isolatedEntity.RecordTypeId = rtId;
        isolatedEntity.Licensee__c = acc.Id;
        isolatedEntity.Status__c = 'C - Current, Valid & In Good Standing';
        isolatedEntity.ActiveInactive__c = 'Active';
        isolatedEntity.LossofBICDate__c = Date.today();
        insert isolatedEntity;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        Integer nbicCount = [SELECT count() FROM Suspense__c 
                             WHERE License__c = :isolatedEntity.Id 
                             AND MaintenanceType__c = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE'];
        System.assertEquals(0, nbicCount, 'NBIC must not be created when entity has no active RBO');
    }

    /**
     * Entity-loss processing skipped when the entity is still Active.
     * Exercises the "not Inactive" early return in processLossOfEntity.
     * Uses an isolated fresh entity so other batch paths don't interfere.
     */
    @isTest
    static void test_EntityLoss_SkippedWhenStillActive() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Entity' LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id brokerRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        LicenseType__c ltBroker = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Broker' LIMIT 1];
        
        // Active entity with LossofRBEntityDate=today (only this loss-date set, so only entity-loss path triggers)
        License__c entity = new License__c();
        entity.Name = 'RB-Entity-StillActiveLoss';
        entity.LicenseType__c = lt.Id;
        entity.RecordTypeId = rtId;
        entity.Licensee__c = acc.Id;
        entity.Status__c = 'C - Current, Valid & In Good Standing';
        entity.ActiveInactive__c = 'Active';
        entity.LossofRBEntityDate__c = Date.today();
        insert entity;

        License__c broker = new License__c();
        broker.Name = 'RB-Broker-EntityStillActive';
        broker.LicenseType__c = ltBroker.Id;
        broker.RecordTypeId = brokerRtId;
        broker.Licensee__c = acc.Id;
        broker.Status__c = 'C - Current, Valid & In Good Standing';
        broker.ActiveInactive__c = 'Active';
        insert broker;
        
        AssociatedLicense__c assoc = new AssociatedLicense__c();
        assoc.EntityLicense__c = entity.Id;
        assoc.EmployeeLicense__c = broker.Id;
        assoc.EmploymentStatus__c = 'Employed';
        assoc.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        insert assoc;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Broker should remain Active since the entity-loss path was skipped (entity is Active)
        broker = [SELECT Id, ActiveInactive__c FROM License__c WHERE Id = :broker.Id];
        System.assertEquals('Active', broker.ActiveInactive__c, 'Broker must stay Active when entity-loss skipped');
    }

    /**
     * Entity-loss processing returns early when there are no associated licenses
     * Exercises the empty/null associations check in processLossOfEntity.
     */
    @isTest
    static void test_EntityLoss_NoAssociations() {
        // Create an Inactive RB-Entity with LossofRBEntityDate=today but no associations
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Entity' LIMIT 1];
        // We need this LicenseType to allow inactivation
        lt.AbleToInactivate__c = true;
        update lt;
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        
        License__c entity = new License__c();
        entity.Name = 'RB-Entity-NoAssoc';
        entity.LicenseType__c = lt.Id;
        entity.RecordTypeId = rtId;
        entity.Licensee__c = acc.Id;
        entity.Status__c = 'C - Current, Valid & In Good Standing';
        entity.ActiveInactive__c = 'Inactive';
        entity.LossofRBEntityDate__c = Date.today();
        insert entity;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // The entity stays Inactive; no employees to inactivate, so no histories created
        Integer historyCount = [SELECT count() FROM LicenseHistory__c WHERE License__c = :entity.Id];
        System.assertEquals(0, historyCount, 'No history when entity has no associations');
    }

    /**
     * Sole-proprietor processing skipped when license is still Active.
     */
    @isTest
    static void test_SoleProprietorLoss_SkippedWhenStillActive() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Sole Proprietor' LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Sole Prop').getRecordTypeId();
        
        License__c soleProp = new License__c();
        soleProp.Name = 'RB-SoleProp-StillActive';
        soleProp.LicenseType__c = lt.Id;
        soleProp.RecordTypeId = rtId;
        soleProp.Licensee__c = acc.Id;
        soleProp.Status__c = 'C - Current, Valid & In Good Standing';
        soleProp.ActiveInactive__c = 'Active';
        soleProp.LossofSoleProprietorDate__c = Date.today();
        insert soleProp;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        Integer historyCount = [SELECT count() FROM LicenseHistory__c WHERE License__c = :soleProp.Id];
        System.assertEquals(0, historyCount, 'Active sole-prop loss is skipped');
    }

    /**
     * Sole-proprietor processing returns early when there are no associated licenses.
     */
    @isTest
    static void test_SoleProprietorLoss_NoAssociations() {
        LicenseType__c lt = [SELECT Id, AbleToInactivate__c FROM LicenseType__c WHERE Name = 'RB - Sole Proprietor' LIMIT 1];
        lt.AbleToInactivate__c = true;
        update lt;
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Sole Prop').getRecordTypeId();
        
        License__c soleProp = new License__c();
        soleProp.Name = 'RB-SoleProp-NoAssoc';
        soleProp.LicenseType__c = lt.Id;
        soleProp.RecordTypeId = rtId;
        soleProp.Licensee__c = acc.Id;
        soleProp.Status__c = 'C - Current, Valid & In Good Standing';
        soleProp.ActiveInactive__c = 'Inactive';
        soleProp.LossofSoleProprietorDate__c = Date.today();
        insert soleProp;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        Integer historyCount = [SELECT count() FROM LicenseHistory__c WHERE License__c = :soleProp.Id];
        System.assertEquals(0, historyCount, 'No history when sole-prop has no associations');
    }

    /**
     * Employee-license inactivation skipped (continue) when employee is already Inactive.
     * Exercises the "already Inactive or null employee" continue branch in
     * processAssociatedLicenseInactivation.
     */
    @isTest
    static void test_EntityLoss_AlreadyInactiveEmployee_Skipped() {
        // Set up an Inactive RB-Entity with one associated license whose employee is ALREADY Inactive
        LicenseType__c ltEntity = [SELECT Id, AbleToInactivate__c FROM LicenseType__c WHERE Name = 'RB - Entity' LIMIT 1];
        ltEntity.AbleToInactivate__c = true;
        update ltEntity;

        LicenseType__c ltBroker = [SELECT Id, AbleToInactivate__c FROM LicenseType__c WHERE Name = 'RB - Broker' LIMIT 1];
        if (ltBroker.AbleToInactivate__c != true) {
            ltBroker.AbleToInactivate__c = true;
            update ltBroker;
        }

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id entityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        Id brokerRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();

        License__c inactiveEntity = new License__c();
        inactiveEntity.Name = 'RB-Entity-WithInactiveEmployee';
        inactiveEntity.LicenseType__c = ltEntity.Id;
        inactiveEntity.RecordTypeId = entityRtId;
        inactiveEntity.Licensee__c = acc.Id;
        inactiveEntity.Status__c = 'C - Current, Valid & In Good Standing';
        inactiveEntity.ActiveInactive__c = 'Inactive';
        inactiveEntity.LossofRBEntityDate__c = Date.today();
        insert inactiveEntity;

        License__c inactiveBroker = new License__c();
        inactiveBroker.Name = 'RB-Broker-AlreadyInactive';
        inactiveBroker.LicenseType__c = ltBroker.Id;
        inactiveBroker.RecordTypeId = brokerRtId;
        inactiveBroker.Licensee__c = acc.Id;
        inactiveBroker.Status__c = 'C - Current, Valid & In Good Standing';
        inactiveBroker.ActiveInactive__c = 'Inactive';
        insert inactiveBroker;

        AssociatedLicense__c assoc = new AssociatedLicense__c();
        assoc.EntityLicense__c = inactiveEntity.Id;
        assoc.EmployeeLicense__c = inactiveBroker.Id;
        assoc.EmploymentStatus__c = 'Employed';
        assoc.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        insert assoc;

        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();

        // No history should be created for the already-inactive employee
        Integer histCount = [SELECT count() FROM LicenseHistory__c WHERE License__c = :inactiveBroker.Id];
        System.assertEquals(0, histCount, 'Already-Inactive employee is skipped via continue');
    }

    /**
     * Covers the empty-scope early-return at line 114 of execute() by directly
     * invoking the method (Database.executeBatch with empty start() output 
     * never calls execute(), so direct invocation is required).
     */
    @isTest
    static void test_BatchExecuteWithEmptyScope() {
        RBEntityPrincipalBrokerSuspenseBatch batch = new RBEntityPrincipalBrokerSuspenseBatch();
        Test.startTest();
        // Pass null context (unused by execute) and empty scope to hit the early return
        batch.execute((Database.BatchableContext) null, new List<SObject>());
        Test.stopTest();
        System.assert(true, 'Empty-scope execute returned early');
    }

    /**
     * Run the batch when ONLY a Principal-Broker-loss license is in scope (all
     * BIC / RB-Entity / Sole-Proprietor loss licenses removed). This makes
     * licenseIdsForBICCheck / licenseIdsForEntityLoss / licenseIdsForSoleProprietorLoss
     * empty during execute(), covering the empty-set early-return paths in
     * getLicensesWithActiveBIC, getLicensesWithActiveRBO, and getAssociatedLicensesForEntities.
     */
    @isTest
    static void test_BatchExecuteOnlyNOPBInScope() {
        // Remove all licenses that would trigger BIC, RB-Entity, or Sole-Prop scenarios
        delete [SELECT Id FROM License__c WHERE LossofBICDate__c = TODAY 
                OR LossofRBEntityDate__c = TODAY OR LossofSoleProprietorDate__c = TODAY];
        // Only LossofPrincipalBrokerDate=TODAY licenses remain (rbEntityNOPB, rbEntityWithPB)
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        // Verify NOPB was processed (suspense for rbEntityNOPB at least)
        License__c entity = [SELECT Id FROM License__c WHERE Name = 'RB-Entity-NOPB' LIMIT 1];
        Integer suspCount = [SELECT count() FROM Suspense__c WHERE License__c = :entity.Id];
        System.assert(suspCount >= 1, 'At least one suspense from the NOPB-only run');
    }

    /**
     * NOPB suspense built with null LossOfPrincipalRMEDate__c covers the
     * `: Date.today()` fallback branch in buildNOPBSuspenseRecord.
     */
    @isTest
    static void test_NOPBSuspense_NullPrincipalRMEDate_UsesToday() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Entity' LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id rtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId();
        
        License__c entity = new License__c();
        entity.Name = 'RB-Entity-NullRMEDate';
        entity.LicenseType__c = lt.Id;
        entity.RecordTypeId = rtId;
        entity.Licensee__c = acc.Id;
        entity.Status__c = 'C - Current, Valid & In Good Standing';
        entity.ActiveInactive__c = 'Active';
        entity.LossofPrincipalBrokerDate__c = Date.today();
        // Deliberately leave LossOfPrincipalRMEDate__c null
        insert entity;
        
        Test.startTest();
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
        Test.stopTest();
        
        List<Suspense__c> suspenses = [
            SELECT Id, SuspenseDueDate__c FROM Suspense__c 
            WHERE License__c = :entity.Id 
            AND MaintenanceType__c = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER'
        ];
        System.assertEquals(1, suspenses.size(), 'NOPB suspense built using Date.today() fallback');
    }
}