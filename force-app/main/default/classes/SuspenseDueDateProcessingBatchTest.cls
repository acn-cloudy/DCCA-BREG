/*
 * -----------------------------------------------------------------------------------
 * Description
 * Test class for SuspenseDueDateProcessingBatch
 * - NOPB suspense processing (entity + employee inactivation)
 * - NBIC suspense processing (RBO inactivation only)
 * - Edge cases and Schedulable interface
 * -----------------------------------------------------------------------------------
 * VPVL-13 - Created for processing NOPB and NBIC suspense due dates
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author akanksha.reddy@anthireddygari.com
 *
 * @created 2026-01-22
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@isTest
private class SuspenseDueDateProcessingBatchTest {
    
    // Constants for maintenance types
    private static final String MAINTENANCE_TYPE_NOPB = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER';
    private static final String MAINTENANCE_TYPE_NBIC = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE';
    
    // Constants for status values
    private static final String STATUS_CURRENT = 'C - Current, Valid & In Good Standing';
    private static final String STATUS_CM = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
    private static final String ACTIVE = 'Active';
    private static final String INACTIVE = 'Inactive';
    private static final String EMPLOYED = 'Employed';
    private static final String TERMINATED = 'Terminated';
    
    // Constants for history and termination
    private static final String HISTORY_INACTIVE = 'I - INACTIVE';
    private static final String REMARKS_NOPB = 'Employer Lost Principal Broker';
    private static final String REMARKS_NBIC = 'Employer Lost Broker-In-Charge';
    private static final String TERM_REASON_NOPB = 'PLOS - TERMINATION DUE TO PRINCIPAL';
    private static final String TERM_REASON_NBIC = 'NBIC - TERMINATION DUE TO BROKER-IN-CHARGE';
    
    // Constants for license names
    private static final String ENTITY_NOPB = 'RB-Entity-NOPB';
    private static final String ENTITY_NBIC = 'RB-Entity-NBIC';
    private static final String ENTITY_REGAINED_PB = 'RB-Entity-RegainedPB';
    
    // Batch size
    private static final Integer BATCH_SIZE = 50;
    
    @TestSetup
    static void setup() {
        // Create License Types
        List<LicenseType__c> licenseTypes = createLicenseTypes();
        insert licenseTypes;
        
        Map<String, LicenseType__c> ltMap = new Map<String, LicenseType__c>();
        for (LicenseType__c lt : licenseTypes) {
            ltMap.put(lt.Name, lt);
        }
        
        // Create Account
        Account acc = createTestAccount();
        insert acc;
        
        // Get Record Type IDs
        Map<String, Id> recordTypeIds = getRecordTypeIds();
        
        // Create RB-Entity Licenses
        List<License__c> entityLicenses = createEntityLicenses(ltMap.get('RB - Entity').Id, recordTypeIds.get('RB-Entity'), acc.Id);
        insert entityLicenses;
        
        // Create Employee and RBO Licenses
        List<License__c> otherLicenses = createEmployeeAndRBOLicenses(ltMap, recordTypeIds, acc.Id);
        insert otherLicenses;
        
        // Create Associated Licenses
        Map<String, License__c> licenseMap = getLicenseMap();
        List<AssociatedLicense__c> associations = createAssociations(licenseMap);
        insert associations;
        
        // Create Suspense Records
        List<Suspense__c> suspenses = createSuspenses(licenseMap);
        insert suspenses;
    }
    
    // ==================== Helper Methods for Test Data Creation ====================
    
    private static List<LicenseType__c> createLicenseTypes() {
        List<LicenseType__c> types = new List<LicenseType__c>();
        
        LicenseType__c ltRBEntity = new LicenseType__c();
        ltRBEntity.Name = 'RB - Entity';
        ltRBEntity.Status__c = ACTIVE;
        ltRBEntity.NumberofDaysUntilAutoForfeiture__c = 60;
        ltRBEntity.AutoForfeitureStatus__c = 'F - Terminated; Needs to Reapply';
        ltRBEntity.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBEntity.DurationofLicenseInMonths__c = 24;
        // ActiveInactiveIsSetToInactive validation rule requires AbleToInactivate__c
        ltRBEntity.AbleToInactivate__c = true;
        types.add(ltRBEntity);
        
        LicenseType__c ltRBBroker = new LicenseType__c();
        ltRBBroker.Name = 'RB - Broker';
        ltRBBroker.Status__c = ACTIVE;
        ltRBBroker.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBBroker.DurationofLicenseInMonths__c = 24;
        ltRBBroker.AbleToInactivate__c = true;
        types.add(ltRBBroker);
        
        LicenseType__c ltRBO = new LicenseType__c();
        ltRBO.Name = 'RBO';
        ltRBO.Status__c = ACTIVE;
        ltRBO.LicenseTypeEffectiveDate__c = Date.today().addYears(-1);
        ltRBO.DurationofLicenseInMonths__c = 24;
        ltRBO.AbleToInactivate__c = true;
        types.add(ltRBO);
        
        return types;
    }
    
    private static Account createTestAccount() {
        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'User';
        acc.PersonEmail = 'testuser@example.com';
        return acc;
    }
    
    private static Map<String, Id> getRecordTypeIds() {
        Map<String, Id> rtIds = new Map<String, Id>();
        rtIds.put('RB-Entity', Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Entity').getRecordTypeId());
        rtIds.put('RB-Broker', Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId());
        rtIds.put('RBO', Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RBO').getRecordTypeId());
        return rtIds;
    }
    
    private static List<License__c> createEntityLicenses(Id licenseTypeId, Id recordTypeId, Id accountId) {
        List<License__c> entities = new List<License__c>();
        
        // Entity for NOPB testing (no PB)
        // Note: PB_Counter__c is a formula/rollup field - will be 0 when no PB associations exist
        License__c rbEntityNOPB = new License__c();
        rbEntityNOPB.Name = ENTITY_NOPB;
        rbEntityNOPB.LicenseType__c = licenseTypeId;
        rbEntityNOPB.RecordTypeId = recordTypeId;
        rbEntityNOPB.Licensee__c = accountId;
        rbEntityNOPB.Status__c = STATUS_CURRENT;
        rbEntityNOPB.ActiveInactive__c = ACTIVE;
        entities.add(rbEntityNOPB);
        
        // Entity for NBIC testing (has PB)
        // Note: PB_Counter__c is a formula/rollup field - will be populated when PB associations are created
        License__c rbEntityNBIC = new License__c();
        rbEntityNBIC.Name = ENTITY_NBIC;
        rbEntityNBIC.LicenseType__c = licenseTypeId;
        rbEntityNBIC.RecordTypeId = recordTypeId;
        rbEntityNBIC.Licensee__c = accountId;
        rbEntityNBIC.Status__c = STATUS_CURRENT;
        rbEntityNBIC.ActiveInactive__c = ACTIVE;
        entities.add(rbEntityNBIC);
        
        // Entity that regained PB (should skip NOPB processing)
        // Note: PB_Counter__c is a formula/rollup field - will be populated when PB associations are created
        License__c rbEntityRegainedPB = new License__c();
        rbEntityRegainedPB.Name = ENTITY_REGAINED_PB;
        rbEntityRegainedPB.LicenseType__c = licenseTypeId;
        rbEntityRegainedPB.RecordTypeId = recordTypeId;
        rbEntityRegainedPB.Licensee__c = accountId;
        rbEntityRegainedPB.Status__c = STATUS_CURRENT;
        rbEntityRegainedPB.ActiveInactive__c = ACTIVE;
        entities.add(rbEntityRegainedPB);
        
        return entities;
    }
    
    private static List<License__c> createEmployeeAndRBOLicenses(Map<String, LicenseType__c> ltMap, Map<String, Id> rtIds, Id accountId) {
        List<License__c> licenses = new List<License__c>();
        
        // Employee Licenses (RB-Broker) under the NOPB entity - 2 brokers used in NOPB assertions
        // Note: LicenseHistoryLicensePeriod__c is a formula field and cannot be set directly
        for (Integer i = 1; i <= 2; i++) {
            License__c broker = new License__c();
            broker.Name = 'RB-Broker-00' + i;
            broker.LicenseType__c = ltMap.get('RB - Broker').Id;
            broker.RecordTypeId = rtIds.get('RB-Broker');
            broker.Licensee__c = accountId;
            broker.Status__c = STATUS_CURRENT;
            broker.ActiveInactive__c = ACTIVE;
            licenses.add(broker);
        }
        
        // PB broker for the "Regained PB" entity - named differently so it doesn't match
        // the 'RB-Broker%' LIKE filter used in the NOPB assertions
        License__c regainedPbBroker = new License__c();
        regainedPbBroker.Name = 'RegPB-Broker-001';
        regainedPbBroker.LicenseType__c = ltMap.get('RB - Broker').Id;
        regainedPbBroker.RecordTypeId = rtIds.get('RB-Broker');
        regainedPbBroker.Licensee__c = accountId;
        regainedPbBroker.Status__c = STATUS_CURRENT;
        regainedPbBroker.ActiveInactive__c = ACTIVE;
        licenses.add(regainedPbBroker);
        
        // RBO Licenses
        // Note: LicenseHistoryLicensePeriod__c is a formula field and cannot be set directly
        for (Integer i = 1; i <= 2; i++) {
            License__c rbo = new License__c();
            rbo.Name = 'RBO-00' + i;
            rbo.LicenseType__c = ltMap.get('RBO').Id;
            rbo.RecordTypeId = rtIds.get('RBO');
            rbo.Licensee__c = accountId;
            rbo.Status__c = STATUS_CM;
            rbo.ActiveInactive__c = ACTIVE;
            licenses.add(rbo);
        }
        
        return licenses;
    }
    
    private static Map<String, License__c> getLicenseMap() {
        Map<String, License__c> licenseMap = new Map<String, License__c>();
        for (License__c lic : [SELECT Id, Name FROM License__c]) {
            licenseMap.put(lic.Name, lic);
        }
        return licenseMap;
    }
    
    private static List<AssociatedLicense__c> createAssociations(Map<String, License__c> licenseMap) {
        List<AssociatedLicense__c> associations = new List<AssociatedLicense__c>();
        
        // NOPB associations (employees under NOPB entity)
        AssociatedLicense__c assoc1 = new AssociatedLicense__c();
        assoc1.EntityLicense__c = licenseMap.get(ENTITY_NOPB).Id;
        assoc1.EmployeeLicense__c = licenseMap.get('RB-Broker-001').Id;
        assoc1.EmploymentStatus__c = EMPLOYED;
        assoc1.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        associations.add(assoc1);
        
        AssociatedLicense__c assoc2 = new AssociatedLicense__c();
        assoc2.EntityLicense__c = licenseMap.get(ENTITY_NOPB).Id;
        assoc2.EmployeeLicense__c = licenseMap.get('RB-Broker-002').Id;
        assoc2.EmploymentStatus__c = EMPLOYED;
        assoc2.Position__c = 'RS - REAL ESTATE SALESPERSON (REAL ESTATE COMMISSION)';
        associations.add(assoc2);
        
        // NBIC associations (RBO where RB-Entity is employee)
        // Note: EntityLicenseType__c is a formula field derived from EntityLicense__c
        AssociatedLicense__c assoc3 = new AssociatedLicense__c();
        assoc3.EmployeeLicense__c = licenseMap.get(ENTITY_NBIC).Id;
        assoc3.EntityLicense__c = licenseMap.get('RBO-001').Id;
        assoc3.EmploymentStatus__c = EMPLOYED;
        associations.add(assoc3);
        
        AssociatedLicense__c assoc4 = new AssociatedLicense__c();
        assoc4.EmployeeLicense__c = licenseMap.get(ENTITY_NBIC).Id;
        assoc4.EntityLicense__c = licenseMap.get('RBO-002').Id;
        assoc4.EmploymentStatus__c = EMPLOYED;
        associations.add(assoc4);
        
        // PB association for the "regained PB" entity so PB_Counter__c rolls up to 1
        // testSkipEntityRegainedPB expects this entity to be skipped because it has an active PB
        AssociatedLicense__c assocPB = new AssociatedLicense__c();
        assocPB.EntityLicense__c = licenseMap.get(ENTITY_REGAINED_PB).Id;
        assocPB.EmployeeLicense__c = licenseMap.get('RegPB-Broker-001').Id;
        assocPB.EmploymentStatus__c = EMPLOYED;
        assocPB.Position__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)';
        associations.add(assocPB);
        
        return associations;
    }
    
    private static List<Suspense__c> createSuspenses(Map<String, License__c> licenseMap) {
        List<Suspense__c> suspenses = new List<Suspense__c>();
        Date yesterdayDate = Date.today().addDays(-1);
        
        // NOPB Suspense (due date passed)
        Suspense__c nopbSuspense = new Suspense__c();
        nopbSuspense.License__c = licenseMap.get(ENTITY_NOPB).Id;
        nopbSuspense.MaintenanceType__c = MAINTENANCE_TYPE_NOPB;
        nopbSuspense.SuspenseDueDate__c = yesterdayDate;
        nopbSuspense.SuspenseStatus__c = 'F - Terminated; Needs to Reapply';
        nopbSuspense.Historical__c = false;
        nopbSuspense.Delete__c = false;
        suspenses.add(nopbSuspense);
        
        // NBIC Suspense (due date passed)
        Suspense__c nbicSuspense = new Suspense__c();
        nbicSuspense.License__c = licenseMap.get(ENTITY_NBIC).Id;
        nbicSuspense.MaintenanceType__c = MAINTENANCE_TYPE_NBIC;
        nbicSuspense.SuspenseDueDate__c = yesterdayDate;
        nbicSuspense.SuspenseStatus__c = 'F - Terminated; Needs to Reapply';
        nbicSuspense.Historical__c = false;
        nbicSuspense.Delete__c = false;
        suspenses.add(nbicSuspense);
        
        // NOPB Suspense for entity that regained PB (should be skipped)
        Suspense__c skipSuspense = new Suspense__c();
        skipSuspense.License__c = licenseMap.get(ENTITY_REGAINED_PB).Id;
        skipSuspense.MaintenanceType__c = MAINTENANCE_TYPE_NOPB;
        skipSuspense.SuspenseDueDate__c = yesterdayDate;
        skipSuspense.SuspenseStatus__c = 'F - Terminated; Needs to Reapply';
        skipSuspense.Historical__c = false;
        skipSuspense.Delete__c = false;
        suspenses.add(skipSuspense);
        
        return suspenses;
    }
    
    // ==================== Helper Methods for Assertions ====================
    
    private static Set<Id> getIdsFromRecords(List<SObject> records) {
        Set<Id> ids = new Set<Id>();
        for (SObject record : records) {
            ids.add(record.Id);
        }
        return ids;
    }
    
    // ==================== NOPB Suspense Processing Tests ====================
    
    /**
     * Test NOPB suspense processing
     * Verifies: entity inactivation, employee inactivation, history records,
     * notifications, and suspense deletion
     */
    @IsTest
    static void testNOPBSuspenseProcessing() {
        // Arrange
        License__c rbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NOPB LIMIT 1];
        List<License__c> employees = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RB-Broker%'];
        List<AssociatedLicense__c> associations = [SELECT Id, EmploymentStatus__c FROM AssociatedLicense__c WHERE EntityLicense__c = :rbEntity.Id];
        
        // Verify initial state
        System.assertEquals(ACTIVE, rbEntity.ActiveInactive__c);
        System.assertEquals(2, employees.size());
        System.assertEquals(2, associations.size());
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - Entity inactivation
        rbEntity = [SELECT Id, ActiveInactive__c, Status__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(INACTIVE, rbEntity.ActiveInactive__c);
        System.assertEquals(STATUS_CURRENT, rbEntity.Status__c);
        
        // Assert - Employee inactivation
        Set<Id> employeeIds = getIdsFromRecords(employees);
        employees = [SELECT Id, ActiveInactive__c, Status__c FROM License__c WHERE Id IN :employeeIds];
        for (License__c emp : employees) {
            System.assertEquals(INACTIVE, emp.ActiveInactive__c);
            System.assertEquals(STATUS_CURRENT, emp.Status__c);
        }
        
        // Assert - Association termination
        Set<Id> assocIds = getIdsFromRecords(associations);
        associations = [SELECT Id, EmploymentStatus__c, EndDate__c, TerminationReason__c FROM AssociatedLicense__c WHERE Id IN :assocIds];
        for (AssociatedLicense__c al : associations) {
            System.assertEquals(TERMINATED, al.EmploymentStatus__c);
            System.assertNotEquals(null, al.EndDate__c);
            System.assertEquals(TERM_REASON_NOPB, al.TerminationReason__c);
        }
        
        // Assert - History records
        List<LicenseHistory__c> histories = [SELECT Id, TransactionType__c, Remarks__c FROM LicenseHistory__c WHERE License__c IN :employeeIds];
        System.assertEquals(2, histories.size());
        for (LicenseHistory__c hist : histories) {
            System.assertEquals(HISTORY_INACTIVE, hist.TransactionType__c);
            System.assertEquals(REMARKS_NOPB, hist.Remarks__c);
        }
        
        // Assert - Notifications
        List<Notification__c> notifications = [SELECT Id FROM Notification__c WHERE License__c IN :employeeIds];
        System.assertEquals(2, notifications.size());
        
        // Assert - Suspense deletion
        List<Suspense__c> remainingSuspenses = [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NOPB AND License__c = :rbEntity.Id];
        System.assertEquals(0, remainingSuspenses.size());
    }
    
    /**
     * Test NOPB processing when entity has no active employee associations
     * Entity should still be inactivated but no employee changes
     */
    @IsTest
    static void testNOPBNoActiveEmployeeAssociations() {
        // Arrange - Terminate all employee associations
        delete [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NBIC];
        delete [SELECT Id FROM Suspense__c WHERE License__r.Name = :ENTITY_REGAINED_PB];
        
        License__c nopbEntity = [SELECT Id FROM License__c WHERE Name = :ENTITY_NOPB LIMIT 1];
        List<AssociatedLicense__c> empAssocs = [SELECT Id FROM AssociatedLicense__c WHERE EntityLicense__c = :nopbEntity.Id];
        for (AssociatedLicense__c al : empAssocs) {
            al.EmploymentStatus__c = TERMINATED;
            al.EndDate__c = Date.today().addDays(-5);
        }
        update empAssocs;
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - Entity inactivated
        nopbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Id = :nopbEntity.Id];
        System.assertEquals(INACTIVE, nopbEntity.ActiveInactive__c);
        
        // Assert - Employees remain active
        List<License__c> employees = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RB-Broker%'];
        for (License__c emp : employees) {
            System.assertEquals(ACTIVE, emp.ActiveInactive__c);
        }
        
        // Assert - Suspense deleted
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c WHERE License__c = :nopbEntity.Id];
        System.assertEquals(0, suspenses.size());
    }
    
    // ==================== NBIC Suspense Processing Tests ====================
    
    /**
     * Test NBIC suspense processing
     * Verifies: RBO inactivation, history records, suspense deletion,
     * and that the RB-Entity remains active
     */
    @IsTest
    static void testNBICSuspenseProcessing() {
        // Arrange
        License__c rbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NBIC LIMIT 1];
        List<License__c> rboLicenses = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RBO%'];
        List<AssociatedLicense__c> associations = [SELECT Id FROM AssociatedLicense__c WHERE EmployeeLicense__c = :rbEntity.Id AND EntityLicenseType__c = 'RBO'];
        
        // Verify initial state
        System.assertEquals(ACTIVE, rbEntity.ActiveInactive__c);
        System.assertEquals(2, rboLicenses.size());
        System.assertEquals(2, associations.size());
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - RBO licenses inactivated
        Set<Id> rboIds = getIdsFromRecords(rboLicenses);
        rboLicenses = [SELECT Id, ActiveInactive__c, Status__c FROM License__c WHERE Id IN :rboIds];
        for (License__c rbo : rboLicenses) {
            System.assertEquals(INACTIVE, rbo.ActiveInactive__c);
            System.assertEquals(STATUS_CURRENT, rbo.Status__c);
        }
        
        // Assert - Association termination
        Set<Id> assocIds = getIdsFromRecords(associations);
        associations = [SELECT Id, EmploymentStatus__c, EndDate__c, TerminationReason__c FROM AssociatedLicense__c WHERE Id IN :assocIds];
        for (AssociatedLicense__c al : associations) {
            System.assertEquals(TERMINATED, al.EmploymentStatus__c);
            System.assertNotEquals(null, al.EndDate__c);
            System.assertEquals(TERM_REASON_NBIC, al.TerminationReason__c);
        }
        
        // Assert - History records for RBOs
        List<LicenseHistory__c> histories = [SELECT Id, TransactionType__c, Remarks__c FROM LicenseHistory__c WHERE License__c IN :rboIds];
        System.assertEquals(2, histories.size());
        for (LicenseHistory__c hist : histories) {
            System.assertEquals(HISTORY_INACTIVE, hist.TransactionType__c);
            System.assertEquals(REMARKS_NBIC, hist.Remarks__c);
        }
        
        // Assert - Suspense deleted
        List<Suspense__c> remainingSuspenses = [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NBIC];
        System.assertEquals(0, remainingSuspenses.size());
        
        // Assert - RB-Entity NOT inactivated (only RBOs affected)
        rbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(ACTIVE, rbEntity.ActiveInactive__c);
    }
    
    /**
     * Test NBIC processing when no active RBO associations exist
     * RBOs should remain unchanged
     */
    @IsTest
    static void testNBICNoActiveRBOAssociations() {
        // Arrange - Delete NOPB suspenses and terminate RBO associations
        delete [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NOPB];
        
        List<AssociatedLicense__c> rboAssocs = [SELECT Id FROM AssociatedLicense__c WHERE EntityLicenseType__c = 'RBO'];
        for (AssociatedLicense__c al : rboAssocs) {
            al.EmploymentStatus__c = TERMINATED;
            al.EndDate__c = Date.today().addDays(-5);
        }
        update rboAssocs;
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - RBOs remain active
        List<License__c> rboLicenses = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RBO%'];
        for (License__c rbo : rboLicenses) {
            System.assertEquals(ACTIVE, rbo.ActiveInactive__c);
        }
    }
    
    // ==================== Skip Processing Tests ====================
    
    /**
     * Test that NOPB processing is skipped when entity has regained Principal Broker
     */
    @IsTest
    static void testSkipEntityRegainedPB() {
        // Arrange
        License__c rbEntity = [SELECT Id, PB_Counter__c FROM License__c WHERE Name = :ENTITY_REGAINED_PB LIMIT 1];
        System.assertEquals(1, rbEntity.PB_Counter__c);
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - Entity NOT inactivated
        rbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Id = :rbEntity.Id];
        System.assertEquals(ACTIVE, rbEntity.ActiveInactive__c);
        
        // Assert - Suspense NOT deleted
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c WHERE License__c = :rbEntity.Id AND MaintenanceType__c = :MAINTENANCE_TYPE_NOPB];
        System.assertEquals(1, suspenses.size());
    }
    
    // ==================== Edge Case Tests ====================
    
    /**
     * Test batch execution with no expired suspenses
     */
    @IsTest
    static void testNoExpiredSuspenses() {
        // Arrange
        delete [SELECT Id FROM Suspense__c];
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - No licenses inactivated
        List<License__c> inactiveLicenses = [SELECT Id FROM License__c WHERE ActiveInactive__c = :INACTIVE];
        System.assertEquals(0, inactiveLicenses.size());
        
        // Assert - No history records
        List<LicenseHistory__c> histories = [SELECT Id FROM LicenseHistory__c];
        System.assertEquals(0, histories.size());
    }
    
    /**
     * Test that future-dated suspenses are not processed
     */
    @IsTest
    static void testFutureDatedSuspenses() {
        // Arrange
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c];
        for (Suspense__c susp : suspenses) {
            susp.SuspenseDueDate__c = Date.today().addDays(10);
        }
        update suspenses;
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - No licenses inactivated
        List<License__c> inactiveLicenses = [SELECT Id FROM License__c WHERE ActiveInactive__c = :INACTIVE];
        System.assertEquals(0, inactiveLicenses.size());
        
        // Assert - Suspenses still exist
        suspenses = [SELECT Id FROM Suspense__c];
        System.assertEquals(3, suspenses.size());
    }
    
    /**
     * Test that historical suspenses are not processed
     */
    @IsTest
    static void testHistoricalSuspenses() {
        // Arrange
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c];
        for (Suspense__c susp : suspenses) {
            susp.Historical__c = true;
        }
        update suspenses;
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert
        List<License__c> inactiveLicenses = [SELECT Id FROM License__c WHERE ActiveInactive__c = :INACTIVE];
        System.assertEquals(0, inactiveLicenses.size());
    }
    
    /**
     * Test that suspenses marked for deletion are not processed
     */
    @IsTest
    static void testDeletedSuspenses() {
        // Arrange
        List<Suspense__c> suspenses = [SELECT Id FROM Suspense__c];
        for (Suspense__c susp : suspenses) {
            susp.Delete__c = true;
        }
        update suspenses;
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert
        List<License__c> inactiveLicenses = [SELECT Id FROM License__c WHERE ActiveInactive__c = :INACTIVE];
        System.assertEquals(0, inactiveLicenses.size());
    }
    
    // ==================== Mixed Processing Tests ====================
    
    /**
     * Test processing of both NOPB and NBIC suspenses in a single batch
     */
    @IsTest
    static void testMixedSuspenseTypes() {
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - NOPB entity inactivated
        License__c nopbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NOPB];
        System.assertEquals(INACTIVE, nopbEntity.ActiveInactive__c);
        
        // Assert - NBIC entity remains active
        License__c nbicEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NBIC];
        System.assertEquals(ACTIVE, nbicEntity.ActiveInactive__c);
        
        // Assert - Regained PB entity remains active
        License__c regainedPBEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_REGAINED_PB];
        System.assertEquals(ACTIVE, regainedPBEntity.ActiveInactive__c);
        
        // Assert - Total history records (2 NOPB employees + 2 RBOs = 4)
        List<LicenseHistory__c> histories = [SELECT Id FROM LicenseHistory__c];
        System.assertEquals(4, histories.size());
        
        // Assert - Processed suspenses deleted, skip suspense remains
        List<Suspense__c> remainingSuspenses = [SELECT Id FROM Suspense__c];
        System.assertEquals(1, remainingSuspenses.size());
    }
    
    /**
     * Test processing only NOPB suspenses
     */
    @IsTest
    static void testOnlyNOPBSuspenses() {
        // Arrange
        delete [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NBIC];
        delete [SELECT Id FROM Suspense__c WHERE License__r.Name = :ENTITY_REGAINED_PB];
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - NOPB entity inactivated
        License__c nopbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NOPB];
        System.assertEquals(INACTIVE, nopbEntity.ActiveInactive__c);
        
        // Assert - RBOs remain active (no NBIC processing)
        List<License__c> rboLicenses = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RBO%'];
        for (License__c rbo : rboLicenses) {
            System.assertEquals(ACTIVE, rbo.ActiveInactive__c);
        }
    }
    
    /**
     * Test processing only NBIC suspenses
     */
    @IsTest
    static void testOnlyNBICSuspenses() {
        // Arrange
        delete [SELECT Id FROM Suspense__c WHERE MaintenanceType__c = :MAINTENANCE_TYPE_NOPB];
        
        // Act
        Test.startTest();
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), BATCH_SIZE);
        Test.stopTest();
        
        // Assert - NOPB entity remains active
        License__c nopbEntity = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name = :ENTITY_NOPB];
        System.assertEquals(ACTIVE, nopbEntity.ActiveInactive__c);
        
        // Assert - RBOs inactivated
        List<License__c> rboLicenses = [SELECT Id, ActiveInactive__c FROM License__c WHERE Name LIKE 'RBO%'];
        for (License__c rbo : rboLicenses) {
            System.assertEquals(INACTIVE, rbo.ActiveInactive__c);
        }
    }
    
    // ==================== Schedulable Interface Tests ====================
    
    /**
     * Test Schedulable interface implementation
     */
    @IsTest
    static void testSchedulable() {
        // Arrange
        String cronExp = '0 30 0 * * ?';
        
        // Act
        Test.startTest();
        String jobId = System.schedule('Test Suspense Due Date Batch', cronExp, new SuspenseDueDateProcessingBatch());
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, jobId);
        
        CronTrigger ct = [SELECT Id, CronExpression, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
    }
}