@IsTest
private class BREGCaseStatusHandlerConversionTest {
    // Factory to create a minimal "old entity" (Account) that a Case points to
    private static Case testCase;
    private static List<breg_Form_Configuration__c> formConfigs;
    private static Account oldEntity;
    private static String OLD_ENTITY_NAME = 'Old Entity Corp.';
    private static String NEW_ENTITY_NAME = 'New Entity Name Corp.';
    @TestSetup
    static void makeData() {
        //BREGTestDataFactory.createFormConfigurations();

        formConfigs = new List<breg_Form_Configuration__c>{
            new breg_Form_Configuration__c(breg_Suffix_Code__c = 'X-10', breg_Form_Code__c = 'X-10', breg_Business_Process__c = 'Change')
        };

        BREGTestDataFactory.createFileNumberSequences();
        insert formConfigs;
        oldEntity = makeOldEntity('111111', 'C5');
        testCase = makeCase(oldEntity, '111111');
    }
    private static Account makeOldEntity(String fileNo, String fileSuffix) {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account a = new Account();
        a.Name = OLD_ENTITY_NAME;
        a.RecordTypeId = bregAccountRecordTypeId;
        a.breg_File__c = fileNo;
        a.breg_File_Suffix__c = fileSuffix;
        a.breg_Entity_Status__c = 'Active (A)';
        insert a;
        return a;
    }

    // Factory to create a minimal Case that references the "old entity"
    private static Case makeCase(Account oldEntity, String fileNo) {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case c = new Case();
        c.Subject = 'Test Case';
        c.Status = 'New';
        c.Origin = 'Phone';
        c.RecordTypeId = bregCaseRecordTypeId;
        c.breg_Entity__c = oldEntity.Id;
        c.breg_Form_Configuration__c = formConfigs[0].Id;
        c.breg_Name_of_the_Entity__c = oldEntity.Name;
        // Fields used by createNewEntities mapping:
        c.breg_new_entity_name__c = NEW_ENTITY_NAME;
        c.breg_File__c = fileNo; // must match the value used for entityFileNumberToIdMap lookup
        c.breg_Company_Address__City__s = 'Honolulu';
        c.breg_Company_Address__StateCode__s = 'HI';
        c.breg_Company_Address_State__c = 'HI';
        c.breg_Company_Address__PostalCode__s = '98613';
        c.breg_Company_Address__CountryCode__s = 'US';
        // c.breg_Entity_Type__c = 'D2';
        c.breg_Formation_State__c = 'HI';
        c.breg_Reg_Agent_Type__c = 'Individual';
        c.breg_Mailing_Address__CountryCode__s = 'US';
        c.breg_Mailing_Address__StateCode__s = 'HI';
        c.breg_Mailing_Address__City__s = 'City';
        c.breg_Mailing_Address__PostalCode__s = '98613';
        c.breg_Mailing_Address__Street__s = '123 Test St';
        c.breg_subscribe_owner_free_email_alerts__c = false;
        c.breg_Effective_Date__c = Date.today().addDays(1);
        c.breg_Number_of_initial_members__c = 1;
        c.breg_Purposes__c = 'Purpose';

        insert c;
        return c;
    }

    @IsTest
    static void createNewEntitiesReturnsMapAndCreatesAccountsTest() {
        Case testCase = [
            SELECT
                Id,
                breg_new_entity_name__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Company_Address__City__s,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_State__c,
                breg_Company_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__Street__s,
                breg_Entity_Type__c,
                breg_Formation_State__c,
                breg_Reg_Agent_Type__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__Street__s,
                breg_subscribe_owner_free_email_alerts__c,
                breg_Number_of_initial_members__c,
                breg_Purposes__c,
                breg_New_Registrant_First_Name__c,
                breg_New_Registrant_Last_Name__c,
                breg_New_Registrant_Name__c,
                breg_New_Entity_Jurisdiction__c,
                breg_New_Entity_Type__c,
                breg_Effective_Date_Time__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                CreatedById
            FROM Case
            LIMIT 1
        ];

        testCase.breg_New_Entity_Type__c = 'C5';
        testCase.breg_New_Entity_Jurisdiction__c = 'HI';
        testCase.breg_Effective_Date_Time__c = DateTime.now();
        update testCase;

        // Act
        Test.startTest();
        Map<Id, Id> caseToNewEntity = BREGCaseStatusHandlerConversion.createNewEntities(new List<Case>{ testCase });
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, caseToNewEntity, 'Map should not be null');
        System.assertEquals(1, caseToNewEntity.size(), 'One case should be mapped');
        System.assert(caseToNewEntity.containsKey(testCase.Id), 'Map should contain our Case');

        Account newEntity = [
            SELECT
                Id,
                Name,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Entity_Status__c,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountryCode,
                breg_Billing_Address_State_Text__c
            FROM Account
            WHERE Name = :NEW_ENTITY_NAME
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Active (A)', newEntity.breg_Entity_Status__c, 'New entity status should be set');
        System.assertEquals(NEW_ENTITY_NAME, newEntity.Name, 'Name should come from case');
        System.assert(String.isNotBlank(newEntity.breg_File__c), 'File number should be generated');
        System.assert(String.isNotBlank(newEntity.breg_File_Suffix__c), 'File suffix should be generated');
        System.assertEquals('Honolulu', newEntity.BillingCity, 'Billing city copied');
        System.assertEquals('HI', newEntity.breg_Billing_Address_State_Text__c, 'Billing state copied');
        System.assertEquals('98613', newEntity.BillingPostalCode, 'Billing zip copied');
        System.assertEquals('US', newEntity.BillingCountryCode, 'Billing country copied');
    }

    @IsTest
    static void updateTNTMSMRunsWithoutErrorTest() {
        // Arrange: old & new entities, case, and one TN_TM_SM linked to old entity
        String fileNo = 'FN-002';
        Case c = [SELECT id, breg_File__c, breg_File_Suffix__c, breg_New_Entity_Jurisdiction__c, breg_Effective_Date__c, breg_Received_Date_Formula__c FROM Case LIMIT 1];
        oldEntity = [SELECT id, breg_File__c, breg_File_Suffix__c FROM Account LIMIT 1];

        // Create a "new entity" to move to (simulate output of createNewEntities)
        Account newEntity = new Account(Name = 'New Entity For Move', breg_File__c = fileNo, breg_File_Suffix__c = 'B', breg_Entity_Status__c = 'New (Y)');
        insert newEntity;

        // A TN_TM_SM record currently tied to the OLD entity
        breg_TN_TM_SM__c tntmsm = new breg_TN_TM_SM__c(breg_Account__c = oldEntity.Id);
        insert tntmsm;

        Map<Id, Id> caseToEntity = new Map<Id, Id>{ c.Id => oldEntity.Id };
        Map<Id, Id> caseToNewEntity = new Map<Id, Id>{ c.Id => newEntity.Id };
        Map<Id, Case> casesMap = new Map<Id, Case>{ c.Id => c };

        // Act
        Test.startTest();
        new BREGCaseStatusHandlerConversion().updateTNTMSM(caseToEntity, caseToNewEntity, casesMap);
        Test.stopTest();

        // Assert: current implementation doesn't add anything to update list,
        // so we just verify nothing blew up and record still exists.
        breg_TN_TM_SM__c reloaded = [SELECT Id, breg_Account__c FROM breg_TN_TM_SM__c WHERE breg_Account__c = :newEntity.Id LIMIT 1];
        tntmsm = [SELECT Id, breg_Account__c, breg_End_Date__c FROM breg_TN_TM_SM__c WHERE Id = :tntmsm.Id LIMIT 1];
        System.assertEquals(
            newEntity.Id,
            reloaded.breg_Account__c,
            'With current implementation, TN_TM_SM remains on new entity (no DML updates were made).'
        );

        System.assertEquals(
            tntmsm.breg_End_Date__c,
            c.breg_Effective_Date__c,
            'With current implementation, TN_TM_SM remains on old entity (no DML updates were made).'
        );
    }

    @IsTest
    static void checkEffectiveDateValidationBranchesTest() {
        BREGCaseStatusHandlerConversion handler = new BREGCaseStatusHandlerConversion();
        formConfigs = [SELECT Id, breg_Entity_Type__c, breg_Suffix_Code__c, breg_Form_Code__c FROM breg_Form_Configuration__c LIMIT 1];
        Case caseWithoutDate = new Case(
            Subject = 'No Effective Date',
            Status = 'New',
            Origin = 'Phone',
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Name_of_the_Entity__c = 'Validation Entity One Corporation'
        );
        insert caseWithoutDate;
        try {
            handler.handleStatusChange(new List<Case>{ caseWithoutDate }, 'Completed', true, false);
            System.assert(false, 'Expected missing effective date validation exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('Effective date'), 'Should indicate missing effective date');
        }

        Case caseWithPastDate = new Case(
            Subject = 'Past Effective Date',
            Status = 'New',
            Origin = 'Phone',
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Name_of_the_Entity__c = 'Validation Entity Two Corporation',
            breg_Effective_Date__c = Date.today().addDays(1)
        );
        insert caseWithPastDate;
        try {
            handler.handleStatusChange(new List<Case>{ caseWithPastDate }, 'Completed', true, false);
            System.assert(false, 'Expected past-date validation exception');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('before Effective date'), 'Should indicate effective date timing restriction');
        }

        Case caseWithTodayDate = new Case(
            Subject = 'Today Effective Date',
            Status = 'New',
            Origin = 'Phone',
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Name_of_the_Entity__c = 'Validation Entity Three Corporation',
            breg_Effective_Date__c = Date.today()
        );
        insert caseWithTodayDate;
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ caseWithTodayDate }, 'Completed', true, false);
        Test.stopTest();
    }

    @IsTest
    static void performActionsApprovedPathRunsTest() {
        BREGCaseStatusHandlerConversion handler = new BREGCaseStatusHandlerConversion();
        Case approvedCase = [
            SELECT Id, Subject, OwnerId, breg_Form_Code__c, breg_Entity__c, breg_Bounced_Check_Due_Date__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ approvedCase }, 'Approved', false, true);
        Test.stopTest();

        System.assertNotEquals(null, approvedCase.Id, 'Approved action path should execute without errors for persisted case');
    }

    @IsTest
    static void performActionsCompletedPathRunsTest() {
        BREGCaseStatusHandlerConversion handler = new BREGCaseStatusHandlerConversion();

        Case completedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_File__c,
                breg_New_Entity_Name__c,
                breg_New_Entity_Type__c,
                breg_New_Entity_Jurisdiction__c,
                breg_Effective_Date__c,
                breg_Effective_Date_Time__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            LIMIT 1
        ];
        completedCase.breg_New_Entity_Name__c = 'Completed Action Entity Name';
        completedCase.breg_New_Entity_Type__c = 'C5';
        completedCase.breg_New_Entity_Jurisdiction__c = 'HI';
        completedCase.breg_Effective_Date__c = Date.today();
        completedCase.breg_Effective_Date_Time__c = DateTime.now();
        //completedCase.breg_Name_of_the_Entity__c = 'Completed Action Entity Corporation';
        update completedCase;

        completedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_File__c,
                breg_New_Entity_Name__c,
                breg_New_Entity_Type__c,
                breg_New_Entity_Jurisdiction__c,
                breg_Effective_Date__c,
                breg_Effective_Date_Time__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Id = :completedCase.Id
            LIMIT 1
        ];
        
        Test.startTest();
        handler.handleStatusChange(new List<Case>{ completedCase }, 'Completed', false, true);
        Test.stopTest();

        Account reloadedOriginal = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Id = :completedCase.breg_Entity__c LIMIT 1];
        System.assertEquals('Converted (9)', reloadedOriginal.breg_Entity_Status__c, 'Completed actions should convert original entity status');
    }

    @IsTest
    static void updateCaseWithAssignmentRulesReturnsCasesTest() {
        Case c1 = new Case(Subject = 'Assign 1', Status = 'New', Origin = 'Phone');
        Case c2 = new Case(Subject = 'Assign 2', Status = 'New', Origin = 'Phone');

        List<Case> result = BREGCaseStatusHandlerConversion.updateCaseWithAssignmentRules(new List<Case>{ c1, c2 });

        System.assertEquals(2, result.size(), 'Should return all provided cases');
        System.assertEquals('Assign 1', result[0].Subject, 'First case should be preserved');
        System.assertEquals('Assign 2', result[1].Subject, 'Second case should be preserved');
    }

    @IsTest
    static void updateOriginalEntityStatusForCasesUpdatesEntityStatusTest() {
        Account entity = new Account(Name = 'Original Entity For Status', breg_Entity_Status__c = 'Active (A)');
        insert entity;

        Case c = new Case(Subject = 'Status Update', Status = 'New', Origin = 'Phone', breg_Entity__c = entity.Id);

        Test.startTest();
        BREGCaseStatusHandlerConversion.updateOriginalEntityStatusForCases(new List<Case>{ c }, 'Converted (9)');
        Test.stopTest();

        Account reloaded = [SELECT Id, breg_Entity_Status__c FROM Account WHERE Id = :entity.Id LIMIT 1];
        System.assertEquals('Converted (9)', reloaded.breg_Entity_Status__c, 'Original entity status should be updated');
    }

    @IsTest
    static void performActionsReceivedCreatesCvtoTransactionTest() {
        BREGCaseStatusHandlerConversion handler = new BREGCaseStatusHandlerConversion();
        Case receivedCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_Received_Date_Formula__c, breg_TN_TM_SM__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :receivedCase.Id AND breg_Account__c = :receivedCase.breg_Entity__c AND breg_Transaction_Code__c = 'CVTO'
        ];

        System.assertEquals(1, transactions.size(), 'Received action should create one CVTO transaction for the original entity.');
        System.assertEquals('R', transactions[0].breg_Status__c, 'Received CVTO transaction should be in Received status.');
    }

    @IsTest
    static void performActionsRejectedAndElseNoopTest() {
        BREGCaseStatusHandlerConversion handler = new BREGCaseStatusHandlerConversion();
        Case testCase = [SELECT Id, breg_Entity__c FROM Case LIMIT 1];

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Rejected', false, true);
        handler.handleStatusChange(new List<Case>{ testCase }, 'In Progress', false, true);
        Test.stopTest();

        System.assertNotEquals(null, testCase.Id, 'Rejected and fallback action branches should execute without errors.');
    }
}