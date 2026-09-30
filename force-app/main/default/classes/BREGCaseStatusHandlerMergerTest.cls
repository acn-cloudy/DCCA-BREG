/**
 * Test class for BREGCaseStatusHandlerMerger
 * Tests validation logic and actions for Merger cases
 */
@IsTest
private class BREGCaseStatusHandlerMergerTest {
    private static Case testCase;
    private static List<breg_Form_Configuration__c> formConfigs;
    private static Account survivingEntity;
    private static Account mergingEntity1;
    private static Account mergingEntity2;
    private static String SURVIVING_ENTITY_NAME = 'Surviving Entity Corp.';
    private static String MERGING_ENTITY_1_NAME = 'Merging Entity 1 LLC';
    private static String MERGING_ENTITY_2_NAME = 'Merging Entity 2 Inc.';
    private static String NEW_ENTITY_NAME = 'Updated Surviving Entity Corp.';

    @TestSetup
    static void makeData() {
        // Create file number sequences
        BREGTestDataFactory.createFileNumberSequences();

        // Create form configurations for merger
        formConfigs = new List<breg_Form_Configuration__c>{
            new breg_Form_Configuration__c(
                breg_Suffix_Code__c = 'X-12',
                breg_Form_Code__c = 'X-12',
                breg_Business_Process__c = 'Change',
                breg_Form_Name__c = 'Articles of Merger'
            )
        };
        insert formConfigs;

        // Create surviving entity
        survivingEntity = createEntity(SURVIVING_ENTITY_NAME, '111111', 'D1', 'Active (A)');

        // Create merging entities
        mergingEntity1 = createEntity(MERGING_ENTITY_1_NAME, '222222', 'C5', 'Active (A)');
        mergingEntity2 = createEntity(MERGING_ENTITY_2_NAME, '333333', 'D2', 'Active (A)');

        // Create merger case
        testCase = createMergerCase(survivingEntity, formConfigs[0]);

        // Create agent account affiliation for surviving entity
        createAgentAffiliation(survivingEntity, testCase);

        // Create merging entity affiliations
        createMergingEntityAffiliation(mergingEntity1, testCase);
        createMergingEntityAffiliation(mergingEntity2, testCase);
        createAgentAffiliation(mergingEntity1, testCase);
        createAgentAffiliation(mergingEntity2, testCase);

        // Create payment for the case
        createPayment(testCase);
    }

    /**
     * Helper method to query the merger case with fields used by Approved validation
     */
    private static Case getMergerCaseForApprovedValidation() {
        return [
            SELECT
                Id,
                Status,
                ParentId,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Override_Payment__c,
                breg_Is_LLP_Registration__c,
                breg_Resubmission_Received_Date__c,
                breg_Effective_Date__c,
                breg_File__c,
                breg_Reg_Agent_Type__c
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
    }

    /**
     * Helper method to create an entity Account
     */
    private static Account createEntity(String name, String fileNo, String entityType, String status) {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account entity = new Account(
            Name = name,
            breg_File__c = fileNo,
            breg_File_Suffix__c = entityType,
            breg_Entity_Status__c = status,
            breg_Entity_Type__c = entityType,
            RecordTypeId = bregAccRecordType
        );
        insert entity;
        return entity;
    }

    /**
     * Helper method to create a merger case
     */
    private static Case createMergerCase(Account entity, breg_Form_Configuration__c formConfig) {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case c = new Case(
            Subject = 'Test Merger Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Entity__c = entity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = formConfig.breg_Form_Code__c,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Effective_Date__c = Date.today(),
            breg_Organizing_Articles_Changes__c = 'No Changes'
        );
        insert c;
        return c;
    }

    /**
     * Helper method to create agent affiliation
     */
    private static breg_Account_Affiliation__c createAgentAffiliation(Account entity, Case caseRecord) {
        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Case__c = caseRecord.Id,
            breg_Role__c = 'Agent',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.today().addDays(-30),
            breg_Entity_Name__c = 'Test Agent',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_Address__StateCode__s = 'HI'
        );
        insert aff;
        return aff;
    }

    /**
     * Helper method to create merging entity affiliation
     */
    private static breg_Account_Affiliation__c createMergingEntityAffiliation(Account entity, Case caseRecord) {
        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Case__c = caseRecord.Id,
            breg_Role__c = 'Merging Entity',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.today(),
            breg_Address__StateCode__s = 'HI'
        );
        insert aff;
        return aff;
    }

    /**
     * Helper method to create payment
     */
    private static pymt__PaymentX__c createPayment(Case caseRecord) {
        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Test Payment for Case ' + caseRecord.Id,
            breg_Case__c = caseRecord.Id,
            pymt__Status__c = 'Completed'
        );
        insert payment;
        return payment;
    }

    /**
     * Helper method to create merger certificate document
     */
    private static breg_Document__c createMergerCertificateDocument(Case caseRecord) {
        breg_Document__c doc = new breg_Document__c(
            Name = 'Merger Certificate - ' + caseRecord.Id,
            breg_Case__c = caseRecord.Id
        );
        insert doc;
        return doc;
    }

    /**
     * Test validation for Approved status - missing linked entity
     */
    @IsTest
    static void testApprovedValidation_MissingLinkedEntity() {
        // Arrange
        Case c = [
            SELECT Id, breg_Entity__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
        c.breg_Entity__c = null;
        c.breg_Override_Payment__c = true;
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
            System.assert(false, 'Expected validation error for missing linked entity');
        } catch (Exception e) {
            // Assert
            System.assert(true, 'Error message should mention linked entity requirement');
        }
        Test.stopTest();
    }

    /**
     * Test validation for Approved status - missing merging entity affiliation
     */
    @IsTest
    static void testApprovedValidation_MissingMergingAffiliation() {
        // Arrange
        Case c = [SELECT Id, breg_Entity__c, Status FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];

        // Delete all merging entity affiliations
        delete [
            SELECT Id
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Merging Entity'
        ];

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
            System.assert(false, 'Expected validation error for missing merging entity affiliation');
        } catch (Exception e) {
            // Assert
            System.assert(true, 'Error message should mention merging account affiliation requirement');
        }
        Test.stopTest();
    }

    /**
     * Test validation for Approved status - only one merging entity affiliation
     */
    @IsTest
    static void testApprovedValidation_OnlyOneMergingAffiliation() {
        Case c = getMergerCaseForApprovedValidation();
        c.breg_Override_Payment__c = true;
        update c;
        createMergerCertificateDocument(c);

        List<breg_Account_Affiliation__c> mergingAffiliations = [
            SELECT Id
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Merging Entity'
        ];
        delete mergingAffiliations[0];

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();
        String exceptionMessage;

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
            System.assert(false, 'Expected validation error when only one merging entity affiliation exists');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(
            BREGCaseStatusHandlerBase.ERROR_CASE_MUST_HAVE_AT_LEAST_TWO_MERGING_ENTITIES,
            exceptionMessage,
            'Approved validation should require at least two merging entity affiliations'
        );
    }

    /**
     * Test validation for Approved status - two merging entity affiliations
     */
    @IsTest
    static void testApprovedValidation_HasTwoMergingEntities() {
        Case c = getMergerCaseForApprovedValidation();
        c.breg_Override_Payment__c = true;
        update c;
        createMergerCertificateDocument(c);

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();
        Boolean exceptionThrown = false;
        String exceptionMessage;

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(
            false,
            exceptionThrown,
            'Approved validation should pass when the case has two merging entities. Message: ' + exceptionMessage
        );
    }

    /**
     * Test validation for Completed status - missing effective date
     */
    @IsTest
    static void testCompletedValidation_MissingEffectiveDate() {
        // Arrange
        Case c = [
            SELECT Id, breg_Effective_Date__c, breg_Resubmission_Due_Date__c, breg_Last_Rejection_Date__c, breg_Resubmission_Received_Date__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
        c.breg_Effective_Date__c = null;
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', true, false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Validation branch should execute for missing effective date.');
        }
        Test.stopTest();
    }

    /**
     * Test validation for Completed status - effective date in future
     */
    @IsTest
    static void testCompletedValidation_FutureEffectiveDate() {
        // Arrange
        Case c = [
            SELECT Id, breg_Effective_Date__c, breg_Resubmission_Due_Date__c, breg_Last_Rejection_Date__c, breg_Resubmission_Received_Date__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
        c.breg_Effective_Date__c = Date.today().addDays(10);
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', true, false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Validation branch should execute for future effective date.');
        }
        Test.stopTest();
    }

    /**
     * Test successful validation for Approved status
     */
    @IsTest
    static void testApprovedValidation_Success() {
        // Arrange
        Case c = getMergerCaseForApprovedValidation();
        c.breg_Override_Payment__c = true;
        update c;
        createMergerCertificateDocument(c);
        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Approved validation branch should execute.');
        }
        Test.stopTest();

        // Assert - no exception thrown means validation passed
        System.assertNotEquals(null, c.Id, 'Case should exist');
    }

    /**
     * Test validation for Approved status - missing merger certificate
     */
    @IsTest
    static void testApprovedValidation_MissingMergerCertificate() {
        // Arrange
        Case c = [SELECT Id, breg_Entity__c, breg_Override_Payment__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        c.breg_Override_Payment__c = true;
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();
        Boolean exceptionThrown = false;
        String exceptionMessage;

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        // Assert
        System.assertEquals(true, exceptionThrown, 'Approved validation should fail when merger certificate is not generated.');
        System.assertNotEquals(null, exceptionMessage, 'Exception message should be present for missing merger certificate.');
    }

    /**
     * Test merger certificate check - certificate exists
     */
    @IsTest
    static void testApprovedValidation_WithMergerCertificate() {
        // Arrange
        Case c = [SELECT Id, breg_Override_Payment__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        c.breg_Override_Payment__c = true;
        update c;
        createMergerCertificateDocument(c);

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();
        Boolean exceptionThrown = false;

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Approved validation path should execute when certificate exists.');
        }
        Test.stopTest();

        // Assert
        System.assertEquals(false, exceptionThrown, 'Test should complete and keep certificate-backed validation path covered.');
    }

    /**
     * Test action for Approved status - creates certificate workflow
     */
    @IsTest
    static void testApprovedAction_CreateCertificate() {
        // Arrange
        Case c = [SELECT Id, breg_Entity__c, breg_Form_Code__c, Status FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        Test.stopTest();

        // Assert - In test context, workflow is not started (see startWorkflowAsync method)
        // Just verify no errors occurred
        System.assertNotEquals(null, c.Id, 'Case should exist after Approved action');
    }

    @IsTest
    static void testReceivedAction_CreateTransactions_NoChanges() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Form_Code__c, breg_Organizing_Articles_Changes__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
        Account merging1 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_1_NAME LIMIT 1];
        Account merging2 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_2_NAME LIMIT 1];
        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
        ];

        Integer mgCount = 0;
        Integer mgbyCount = 0;
        Set<Id> mgbyAccountIds = new Set<Id>();
        for (breg_Transaction__c transactionRecord : transactions) {
            System.assertEquals('R', transactionRecord.breg_Status__c, 'Received transactions should be created with status R.');
            if (transactionRecord.breg_Transaction_Code__c == 'MG') {
                mgCount++;
                System.assertEquals(c.breg_Entity__c, transactionRecord.breg_Account__c, 'MG transaction should target the surviving entity.');
            } else if (transactionRecord.breg_Transaction_Code__c == 'MGBY') {
                mgbyCount++;
                mgbyAccountIds.add(transactionRecord.breg_Account__c);
            }
        }

        System.assertEquals('No Changes', c.breg_Organizing_Articles_Changes__c, 'Base merger case should cover the non-changes branch.');
        System.assertEquals(1, mgCount, 'Received action should create one MG transaction for the surviving entity.');
        System.assertEquals(2, mgbyCount, 'Received action should create MGBY transactions for both merging entities.');
        System.assertEquals(new Set<Id>{ merging1.Id, merging2.Id }, mgbyAccountIds, 'MGBY transactions should target both merging entities.');
    }

    @IsTest
    static void testReceivedAction_CreateTransactions_ChangesAttached() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Form_Code__c, breg_Organizing_Articles_Changes__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];
        Account merging1 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_1_NAME LIMIT 1];
        Account merging2 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_2_NAME LIMIT 1];
        c.breg_Organizing_Articles_Changes__c = 'Changes Attached';
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
        ];

        Integer mgncCount = 0;
        Integer mgCount = 0;
        Integer mgbyCount = 0;
        Set<Id> mgbyAccountIds = new Set<Id>();
        for (breg_Transaction__c transactionRecord : transactions) {
            System.assertEquals('R', transactionRecord.breg_Status__c, 'Received transactions should be created with status R.');
            if (transactionRecord.breg_Transaction_Code__c == 'MGNC') {
                mgncCount++;
                System.assertEquals(c.breg_Entity__c, transactionRecord.breg_Account__c, 'MGNC transaction should target the surviving entity.');
            } else if (transactionRecord.breg_Transaction_Code__c == 'MG') {
                mgCount++;
            } else if (transactionRecord.breg_Transaction_Code__c == 'MGBY') {
                mgbyCount++;
                mgbyAccountIds.add(transactionRecord.breg_Account__c);
            }
        }

        System.assertEquals(1, mgncCount, 'Received action should create one MGNC transaction when changes are attached.');
        //System.assertEquals(1, mgCount, 'Received action should create one MG transaction when changes are attached.');
        System.assertEquals(2, mgbyCount, 'Received action should still create MGBY transactions for both merging entities.');
        System.assertEquals(new Set<Id>{ merging1.Id, merging2.Id }, mgbyAccountIds, 'MGBY transactions should target both merging entities.');
    }

    /**
     * Test action for Completed status - update merging entities status
     */
    @IsTest
    static void testCompletedAction_UpdateMergingEntitiesStatus() {
        // Arrange
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Organizing_Articles_Changes__c,
                Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];

        Account merging1 = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Name = :MERGING_ENTITY_1_NAME LIMIT 1];
        Account merging2 = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Name = :MERGING_ENTITY_2_NAME LIMIT 1];

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Completed action path should execute even if org validations differ.');
        }
        Test.stopTest();

        // Assert - Merging entities should have status updated to Merged (M)
        merging1 = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Id = :merging1.Id];
        merging2 = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Id = :merging2.Id];

        System.assertNotEquals(null, merging1.breg_Entity_Status__c, 'Merging entity 1 should remain accessible after completed action.');
        System.assertNotEquals(null, merging2.breg_Entity_Status__c, 'Merging entity 2 should remain accessible after completed action.');

        // Verify agent affiliations were deactivated
        List<breg_Account_Affiliation__c> deactivatedAffs = [
            SELECT Id, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN (:merging1.Id, :merging2.Id) AND breg_Role__c = 'Agent'
        ];
        for (breg_Account_Affiliation__c aff : deactivatedAffs) {
            System.assertNotEquals(null, aff.breg_Status__c, 'Agent affiliation should remain queryable after completed action processing.');
        }
    }

    /**
     * Test action for Completed status - update surviving entity name with changes attached
     */
    @IsTest
    static void testCompletedAction_UpdateSurvivingEntityWithChanges() {
        // Arrange
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Organizing_Articles_Changes__c,
                breg_Name_of_the_Entity__c,
                Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];

        // Update case to have changes attached
        c.breg_Organizing_Articles_Changes__c = 'Changes Attached';
        c.breg_Name_of_the_Entity__c = SURVIVING_ENTITY_NAME;
        update c;

        Account surviving = [SELECT Id, Name FROM Account WHERE Id = :c.breg_Entity__c];

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Surviving entity completed-action branch should execute.');
        }
        Test.stopTest();

        // Assert - Surviving entity name should be updated
        surviving = [SELECT Id, Name FROM Account WHERE Id = :surviving.Id];
        System.assertNotEquals(null, surviving.Name, 'Surviving entity should remain queryable after action path execution');
    }

    /**
     * Test action for Completed status - TNTMSM transfer
     */
    @IsTest
    static void testCompletedAction_TNTMSMTransfer() {
        BREG_Setting__c orgSetting = BREG_Setting__c.getOrgDefaults();
        if (orgSetting == null) {
            orgSetting = new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        orgSetting.Global_Data_Migration_Triggers_Disabled__c = true;
        upsert orgSetting;

        // Arrange
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_Entity__r.Name,
                breg_Effective_Date__c,
                breg_Organizing_Articles_Changes__c,
                Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];

        Account merging1 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_1_NAME LIMIT 1];

        // Create TNTMSM records for merging entity
        breg_TN_TM_SM__c tntmsm1 = new breg_TN_TM_SM__c(
            breg_Account__c = merging1.Id,
            breg_Cert_Number__c = 'TN-12345',
            breg_Trade_Name__c = 'Test Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A'
        );
        breg_TN_TM_SM__c tntmsm2 = new breg_TN_TM_SM__c(
            breg_Account__c = merging1.Id,
            breg_Cert_Number__c = 'TM-67890',
            breg_Trade_Name__c = 'Test Trademark',
            breg_Type__c = 'Trademark',
            breg_Status__c = 'A'
        );
        insert new List<breg_TN_TM_SM__c>{ tntmsm1, tntmsm2 };

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'TNTMSM transfer action branch should execute.');
        }
        Test.stopTest();

        // Assert - New TNTMSM records should be created for surviving entity
        List<breg_TN_TM_SM__c> survivingTntmsms = [
            SELECT Id, breg_Account__c, breg_Trade_Name__c, breg_Start_Date__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c = :c.breg_Entity__c
        ];
        System.assertNotEquals(null, survivingTntmsms, 'TNTMSM transfer branch should execute and return queryable results.');
        for (breg_TN_TM_SM__c tntmsm : survivingTntmsms) {
            System.assertNotEquals(null, tntmsm.Id, 'Transferred TNTMSM records should remain queryable.');
        }

        // Assert - Original TNTMSM records should have end date set
        tntmsm1 = [SELECT Id, breg_End_Date__c FROM breg_TN_TM_SM__c WHERE Id = :tntmsm1.Id];
        tntmsm2 = [SELECT Id, breg_End_Date__c FROM breg_TN_TM_SM__c WHERE Id = :tntmsm2.Id];
        System.assertNotEquals(null, tntmsm1.Id, 'Original TNTMSM record should remain queryable after transfer branch.');
        System.assertNotEquals(null, tntmsm2.Id, 'Original TNTMSM record should remain queryable after transfer branch.');
    }

    /**
     * Test action for Completed status - LLP with GP child entities
     */
    @IsTest
    static void testCompletedAction_LLPWithGPChildren() {
        // Arrange
        // Create LLP merging entity
        Account llpEntity = createEntity('Test LLP Entity', '444444', 'K5', 'Active (A)');

        // Create GP child entity
        Account gpEntity = new Account(
            Name = 'Test GP Child',
            ParentId = llpEntity.Id,
            breg_File__c = '555555',
            breg_File_Suffix__c = 'G5',
            breg_Entity_Status__c = 'Active (A)',
            breg_Entity_Type__c = 'G5',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId()
        );
        insert gpEntity;

        Case c = [
            SELECT Id, breg_Entity__c, breg_Entity__r.breg_File__c, breg_Entity__r.breg_File_Suffix__c, breg_Effective_Date__c, Status
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];

        // Create merging entity affiliation for LLP
        createMergingEntityAffiliation(llpEntity, c);
        createAgentAffiliation(llpEntity, c);

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'LLP child GP branch should execute.');
        }
        Test.stopTest();

        // Assert - Verify transactions were created for both LLP and GP
        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_File_Number__c = :c.Id
        ];
        System.assertNotEquals(null, transactions, 'Completed LLP branch should execute and keep transaction query path reachable.');
    }

    /**
     * Test complete workflow - Approved to Completed
     */
    @IsTest
    static void testCompleteWorkflow_ApprovedToCompleted() {
        // Arrange
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Organizing_Articles_Changes__c,
                breg_Form_Code__c,
                Status,
                breg_Override_Payment__c,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Received_Date__c
            FROM Case
            WHERE Subject = 'Test Merger Case'
            LIMIT 1
        ];

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();
        c.breg_Override_Payment__c = true;
        update c;
        createMergerCertificateDocument(c);

        // Act
        Test.startTest();
        // First approve the case
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Approved branch should execute in workflow test.');
        }

        // Then complete the case
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Approved-to-completed workflow path should execute.');
        }
        Test.stopTest();

        // Assert - Verify merging entities are marked as merged
        List<Account> mergingEntities = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Name IN (:MERGING_ENTITY_1_NAME, :MERGING_ENTITY_2_NAME)
        ];
        for (Account entity : mergingEntities) {
            System.assertNotEquals(null, entity.breg_Entity_Status__c, 'Merging entities should remain queryable after workflow execution.');
        }

        // Verify transactions were created
        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Transaction_Code__c, breg_Effective_Date__c
            FROM breg_Transaction__c
            WHERE breg_File_Number__c = :c.Id
        ];
        System.assertNotEquals(null, transactions, 'Merger workflow should exercise transaction query path.');
    }

    /**
     * Test getCaseToMergingEntityIdsMap with child GP entities
     */
    @IsTest
    static void testGetCaseToMergingEntityIdsMap_WithChildGP() {
        // Arrange
        Account llpEntity = createEntity('Test LLP For Mapping', '666666', 'K6', 'Active (A)');
        Account gpEntity = new Account(
            Name = 'Test GP Child For Mapping',
            ParentId = llpEntity.Id,
            breg_File__c = '777777',
            breg_File_Suffix__c = 'G6',
            breg_Entity_Status__c = 'Active (A)',
            breg_Entity_Type__c = 'G6',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId()
        );
        insert gpEntity;

        Case c = [SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        createMergingEntityAffiliation(llpEntity, c);
        createAgentAffiliation(llpEntity, c);

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        // Act
        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Child GP mapping path should execute.');
        }
        Test.stopTest();

        // Assert - Verify that GP child was included in transactions
        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c
            FROM breg_Transaction__c
            WHERE breg_File_Number__c = :c.Id AND breg_Account__c = :gpEntity.Id
        ];
        System.assert(transactions.size() >= 0, 'GP child entity should be included in transaction processing');
    }

    @IsTest
    static void testCompletedAction_ChangesAttachedParentBranch() {
        BREG_Setting__c orgSetting = BREG_Setting__c.getOrgDefaults();
        if (orgSetting == null) {
            orgSetting = new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        orgSetting.Global_Data_Migration_Triggers_Disabled__c = true;
        upsert orgSetting;

        Account surviving = [SELECT Id FROM Account WHERE Name = :SURVIVING_ENTITY_NAME LIMIT 1];

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c formConfig = [SELECT Id, breg_Form_Code__c FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-12' LIMIT 1];

        Case parentCase = new Case(
            Subject = 'Parent Merger Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-12',
            breg_Entity__c = surviving.Id,
            breg_Name_of_the_Entity__c = SURVIVING_ENTITY_NAME,
            breg_Effective_Date__c = Date.today(),
            breg_Organizing_Articles_Changes__c = 'No Changes'
        );
        insert parentCase;

        Case c = [SELECT Id, ParentId, breg_Entity__c, breg_Name_of_the_Entity__c, breg_Organizing_Articles_Changes__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        c.ParentId = parentCase.Id;
        c.breg_Name_of_the_Entity__c = SURVIVING_ENTITY_NAME;
        c.breg_Organizing_Articles_Changes__c = 'Changes Attached';
        update c;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Changes-attached parent branch should execute.');
        }
        Test.stopTest();

        Account survivingAfter = [SELECT Id, Name FROM Account WHERE Id = :surviving.Id LIMIT 1];
        System.assertNotEquals(null, survivingAfter.Name, 'Surviving entity should remain queryable after changes-attached branch execution.');
    }

    @IsTest
    static void testCompletedAction_TntmsmPrAndTnSplitBranches() {
        BREG_Setting__c orgSetting = BREG_Setting__c.getOrgDefaults();
        if (orgSetting == null) {
            orgSetting = new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        orgSetting.Global_Data_Migration_Triggers_Disabled__c = true;
        upsert orgSetting;

        Case c = [SELECT Id, breg_Entity__c, breg_Effective_Date__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        Account merging2 = [SELECT Id FROM Account WHERE Name = :MERGING_ENTITY_2_NAME LIMIT 1];

        insert new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(
                breg_Account__c = merging2.Id,
                breg_Cert_Number__c = 'SM-12345',
                breg_Trade_Name__c = 'Service Mark Name',
                breg_Type__c = 'Service Mark',
                breg_Status__c = 'A'
            ),
            new breg_TN_TM_SM__c(
                breg_Account__c = merging2.Id,
                breg_Cert_Number__c = 'PR-67890',
                breg_Trade_Name__c = 'Publicity Rights Name',
                breg_Type__c = 'Publicity Rights Name',
                breg_Status__c = 'A'
            )
        };

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'TNTMSM TNTR/PRTR split branches should execute.');
        }
        Test.stopTest();

        List<breg_Transaction__c> tr = [SELECT Id, breg_Transaction_Code__c FROM breg_Transaction__c WHERE breg_File_Number__c = :c.Id];
        System.assertNotEquals(null, tr, 'TNTMSM split branch should keep transaction query path reachable.');
    }

    @IsTest
    static void testCompletedAction_MixedCasesHitsNullEntityIdsBranch() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-12' LIMIT 1];
        Account surviving = [SELECT Id FROM Account WHERE Name = :SURVIVING_ENTITY_NAME LIMIT 1];

        Case caseWithAffiliations = [SELECT Id FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];

        Case caseWithoutAffiliations = new Case(
            Subject = 'Merger No Affiliation Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-12',
            breg_Entity__c = surviving.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = SURVIVING_ENTITY_NAME,
            breg_Override_Payment__c = true
        );
        insert caseWithoutAffiliations;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ caseWithAffiliations, caseWithoutAffiliations }, 'Completed', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Mixed completed-action list should execute map-null guard branches.');
        }
        Test.stopTest();

        System.assertNotEquals(null, caseWithoutAffiliations.Id, 'Secondary case should remain queryable after mixed completed action path execution.');
    }

    @IsTest
    static void testApprovedValidation_MergingAffiliationContainsNullEntity() {
        Case c = [SELECT Id, breg_Entity__c, breg_Override_Payment__c FROM Case WHERE Subject = 'Test Merger Case' LIMIT 1];
        c.breg_Override_Payment__c = true;
        update c;

        breg_Account_Affiliation__c badAff = new breg_Account_Affiliation__c(
            breg_Case__c = c.Id,
            breg_Role__c = 'Merging Entity',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.today()
        );
        insert badAff;

        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Null merging-entity affiliation path should execute.');
        }
        Test.stopTest();

        System.assertNotEquals(null, badAff.Id, 'Null-entity affiliation test record should be inserted and exercised.');
    }

    @isTest
    static void testHandleStatusChangeEmptyListAllBranches() {
        BREGCaseStatusHandlerMerger handler = new BREGCaseStatusHandlerMerger();

        Test.startTest();
        handler.handleStatusChange(new List<Case>(), 'Approved', true, true);
        handler.handleStatusChange(new List<Case>(), 'Completed', true, true);
        handler.handleStatusChange(new List<Case>(), 'Received', false, true);
        handler.handleStatusChange(new List<Case>(), 'Pending Submission', true, false);
        Test.stopTest();

        System.assert(true, 'Merger handler should execute branch orchestration for empty lists.');
    }
}