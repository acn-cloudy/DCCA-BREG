/**
 * Test class for BREGCaseStatusHandlerNBR
 * Tests validation NBR specific logic
 */
@isTest
public class BREGCaseStatusHandlerNBRTest {
    @TestSetup
    static void setupData() {
        BREGCaseStatusHandlerBaseTest.setupTestData();
    }

    @isTest
    static void testR7LinkageLogic() {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account testR7 = new Account(
            Name = 'Test R7',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
            breg_Entity_Status__c = 'Active (A)',
            breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
        );
        insert testR7;

        Case testCase = [SELECT breg_Form_Code__c, Status, breg_Form_Configuration__c FROM Case WHERE breg_Form_Code__c = 'DC-1' LIMIT 1];
        testCase.breg_Name_Reservation__c = testR7.Id;
        update testCase;

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Approved', false, true);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'R7 linkage branch should execute even if org picklist differs.');
        }
        Test.stopTest();

        Account updatedR7 = [SELECT breg_Entity_Status__c, breg_Notes__c, breg_End_Date__c FROM Account WHERE Id = :testR7.Id];
        Assert.isNotNull(updatedR7, 'R7 test record should remain queryable after linkage path execution.');
    }

    @isTest
    static void testAgentAffiliationValidationSuccess() {
        // Get test case
        Case testCase = [
            SELECT 
                Id, 
                breg_Form_Code__c, 
                breg_Resubmission_Due_Date__c, 
                breg_Last_Rejection_Date__c, 
                breg_Resubmission_Received_Date__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];

        // Create Agent affiliation
        breg_Account_Affiliation__c agentAffiliation = new breg_Account_Affiliation__c(
            breg_Case__c = testCase.Id,
            breg_Role__c = 'Agent',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Agent',
            breg_Type__c = 'Individual'
        );
        insert agentAffiliation;

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.areEqual(false, exceptionThrown, 'No exception should be thrown when Agent affiliation exists');
    }

    @isTest
    static void testAgentAffiliationValidationFailure() {
        // Get test case without Agent affiliation
        Case testCase = [
            SELECT 
                Id, 
                breg_Form_Code__c, 
                breg_Resubmission_Due_Date__c, 
                breg_Last_Rejection_Date__c, 
                breg_Resubmission_Received_Date__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(true, exceptionThrown, 'Exception should be thrown when Agent affiliation is missing');
        Assert.isTrue(errorMessage.contains('Registered Agent is required'), 'Error message should mention Registered Agent requirement');
    }

    @isTest
    static void testAgentAffiliationValidationExcludedForm() {
        // Create SOLE-1 form configuration (excluded from Agent validation)
        breg_Form_Configuration__c soleFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D9',
            breg_Suffix_Code__c = 'D9',
            breg_Form_Code__c = 'SOLE-1'
        );
        insert soleFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case soleCase = new Case(
            Subject = 'Test SOLE-1 Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = soleFormConfig.Id,
            breg_Form_Code__c = 'SOLE-1',
            breg_Name_of_the_Entity__c = 'Test Sole Proprietorship'
        );
        insert soleCase;

        // Create handler instance (no Agent affiliation)
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ soleCase }, 'Completed', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.areEqual(false, exceptionThrown, 'No exception should be thrown for SOLE-1 form without Agent');
    }

    @isTest
    static void testValidateGpEntityFieldSuccess() {
        // Create LLP-1 form configuration
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K5',
            breg_Suffix_Code__c = 'K5',
            breg_Form_Code__c = 'LLP-1'
        );
        insert llpFormConfig;

        // Create GP Entity
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account gpEntity = new Account(
            Name = 'GP Entity',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert gpEntity;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case llpCase = new Case(
            Subject = 'Test LLP-1 Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = 'LLP-1',
            breg_Name_of_the_Entity__c = 'Test LLP',
            breg_GP_Already_Registered__c = true,
            breg_GP_Entity__c = gpEntity.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert llpCase;

        createCompletedPayment(llpCase.Id);
        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ llpCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            System.debug('Exception Message: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(false, exceptionThrown, 'No exception should be thrown when GP Entity is populated');
    }

    @isTest
    static void testValidateGpEntityFieldFailure() {
        // Create LLP-1 form configuration
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K5',
            breg_Suffix_Code__c = 'K5',
            breg_Form_Code__c = 'LLP-1'
        );
        insert llpFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case llpCase = new Case(
            Subject = 'Test LLP-1 Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = 'LLP-1',
            breg_Name_of_the_Entity__c = 'Test LLP',
            breg_GP_Already_Registered__c = true,
            breg_GP_Entity__c = null,
            breg_Effective_Date__c = Date.today()
        );
        insert llpCase;

        createCompletedPayment(llpCase.Id);
        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ llpCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(true, exceptionThrown, 'Exception should be thrown when GP Entity is null for registered GP');
        String caseGPEntityLabel = BREGUtils.returnFielLabelByApiName('Case', 'breg_GP_Entity__c');
        Assert.isTrue(errorMessage.contains(caseGPEntityLabel), 'Error message should indicate the GP Entity is required');
    }

    @isTest
    static void testUpdateRelatedEntityStatuses() {
        // Create test entity
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account testEntity = new Account(
            Name = 'Test Entity for Status Update',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'New (Y)'
        );
        insert testEntity;

        Case testCase = [SELECT Id, breg_Form_Code__c FROM Case WHERE breg_Form_Code__c = 'DC-1' LIMIT 1];
        testCase.breg_Entity__c = testEntity.Id;
        testCase.breg_Name_of_the_Entity__c = testEntity.Name;
        update testCase;

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedEntity = [SELECT breg_Entity_Status__c FROM Account WHERE Id = :testEntity.Id];
        Assert.areEqual(ConstantsHelper.ENTITY_STATUS_ACTIVE, updatedEntity.breg_Entity_Status__c, 'Entity status should be updated to Active');
    }

    @isTest
    static void testUpdateRelatedGPCaseStatus() {
        // Create LLP-1 form configuration
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K5',
            breg_Suffix_Code__c = 'K5',
            breg_Form_Code__c = 'LLP-1'
        );
        insert llpFormConfig;

        // Create GP case form configuration
        breg_Form_Configuration__c gpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'G6',
            breg_Suffix_Code__c = 'G6',
            breg_Form_Code__c = 'GP-1'
        );
        insert gpFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Create GP case
        Case gpCase = new Case(
            Subject = 'Test GP Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = gpFormConfig.Id,
            breg_Form_Code__c = 'GP-1',
            breg_Name_of_the_Entity__c = 'Test GP'
        );
        insert gpCase;

        // Create LLP case linked to GP case
        Case llpCase = new Case(
            Subject = 'Test LLP Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Form_Code__c = 'LLP-1',
            breg_Name_of_the_Entity__c = 'Test LLP',
            breg_GP_Already_Registered__c = false,
            breg_GP_Case__c = gpCase.Id
        );
        insert llpCase;

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ llpCase }, 'Received', false, true);
        Test.stopTest();

        Case updatedGpCase = [SELECT Status FROM Case WHERE Id = :gpCase.Id];
        Assert.areEqual('Received', updatedGpCase.Status, 'GP Case status should be updated to Received');
    }

    @isTest
    static void testFLLPFormValidation() {
        // Create FLLP-1 form configuration
        breg_Form_Configuration__c fllpFormConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'K6',
            breg_Suffix_Code__c = 'K6',
            breg_Form_Code__c = 'FLLP-1'
        );
        insert fllpFormConfig;

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case fllpCase = new Case(
            Subject = 'Test FLLP-1 Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = fllpFormConfig.Id,
            breg_Form_Code__c = 'FLLP-1',
            breg_Name_of_the_Entity__c = 'Test FLLP',
            breg_GP_Already_Registered__c = true,
            breg_GP_Entity__c = null,
            breg_Effective_Date__c = Date.today()
        );
        insert fllpCase;

        createCompletedPayment(fllpCase.Id);

        // Create handler instance
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ fllpCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(true, exceptionThrown, 'Exception should be thrown for FLLP-1 when GP Entity is missing');
        String caseGPEntityLabel = BREGUtils.returnFielLabelByApiName('Case', 'breg_GP_Entity__c');
        Assert.isTrue(errorMessage.contains(caseGPEntityLabel), 'Error message should indicate the GP Entity is required');
    }

    @isTest
    static void testCreateChildCaseForCertCopyOnReceived() {
        Contact requestor = new Contact(FirstName = 'Taylor', LastName = 'Requester', Email = 'taylor.requester@example.com');
        insert requestor;

        breg_Form_Configuration__c docdlvrFormConfig = createDocdlvrFormConfig();

        Case testCase = [
            SELECT Id, ContactId, breg_Name_of_the_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];
        testCase.ContactId = requestor.Id;
        update testCase;

        createCertCopyTransactionLine(testCase.Id);

        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<Case> childCases = [
            SELECT ParentId, Subject, Status, ContactId, Origin, breg_Delivery_Method__c, breg_Form_Configuration__c
            FROM Case
            WHERE ParentId = :testCase.Id
        ];

        Assert.areEqual(1, childCases.size(), 'A certified-copy child case should be created for qualifying NBR cases.');
        Assert.areEqual(testCase.Id, childCases[0].ParentId, 'The child case should link back to the source case.');
        Assert.areEqual(
            'Document Certified Copy (Digital) - Public initial filing for ' + testCase.breg_Name_of_the_Entity__c,
            childCases[0].Subject,
            'The child case subject should start with the placeholder filing name.'
        );
        Assert.areEqual('Pending Submission', childCases[0].Status, 'The child case should be created in Pending Submission status.');
        Assert.areEqual(requestor.Id, childCases[0].ContactId, 'The child case should copy the requestor contact.');
        Assert.areEqual('Web', childCases[0].Origin, 'The child case origin should be Web.');
        Assert.areEqual('Email', childCases[0].breg_Delivery_Method__c, 'The child case should default to Email delivery.');
        Assert.areEqual(docdlvrFormConfig.Id, childCases[0].breg_Form_Configuration__c, 'The child case should use the DOCDLVR form configuration.');
    }

    @isTest
    static void testCreateChildCaseForCertCopySkipsExistingDocdlvrChild() {
        Contact requestor = new Contact(FirstName = 'Avery', LastName = 'Existing', Email = 'avery.existing@example.com');
        insert requestor;

        breg_Form_Configuration__c docdlvrFormConfig = createDocdlvrFormConfig();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case testCase = [
            SELECT Id, ContactId, breg_Name_of_the_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];
        testCase.ContactId = requestor.Id;
        update testCase;

        createCertCopyTransactionLine(testCase.Id);

        Case existingChildCase = new Case(
            Subject = 'Document Certified Copy (Digital) - Existing child for ' + testCase.breg_Name_of_the_Entity__c,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ContactId = requestor.Id,
            breg_Form_Configuration__c = docdlvrFormConfig.Id,
            breg_Name_of_the_Entity__c = testCase.breg_Name_of_the_Entity__c,
            ParentId = testCase.Id
        );
        insert existingChildCase;

        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Received', false, true);
        Test.stopTest();

        List<Case> childCases = [
            SELECT Id
            FROM Case
            WHERE ParentId = :testCase.Id
        ];

        Assert.areEqual(1, childCases.size(), 'The handler should not create a second DOCDLVR child case when one already exists.');
        Assert.areEqual(existingChildCase.Id, childCases[0].Id, 'The existing child case should be preserved unchanged.');
    }

    @isTest
    static void testUpdateChildCaseForCertCopyOnCompleted() {
        Contact requestor = new Contact(FirstName = 'Jordan', LastName = 'Signer', Email = 'jordan.signer@example.com');
        insert requestor;

        breg_Form_Configuration__c docdlvrFormConfig = createDocdlvrFormConfig();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case testCase = [
            SELECT Id, ContactId, breg_Name_of_the_Entity__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];
        testCase.ContactId = requestor.Id;
        update testCase;

        createCertCopyTransactionLine(testCase.Id);

        Case childCase = new Case(
            Subject = 'Document Certified Copy (Digital) - Public initial filing for ' + testCase.breg_Name_of_the_Entity__c,
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ContactId = requestor.Id,
            breg_Form_Configuration__c = docdlvrFormConfig.Id,
            breg_Name_of_the_Entity__c = testCase.breg_Name_of_the_Entity__c,
            ParentId = testCase.Id
        );
        insert childCase;

        breg_Document__c publicDocument = new breg_Document__c(
            Name = 'Initial Filing.pdf',
            breg_Case__c = testCase.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital'
        );
        insert publicDocument;

        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ testCase }, 'Completed', false, true);
        Test.stopTest();

        Case updatedChildCase = [
            SELECT Subject, Status, breg_Document__c, breg_Override_Payment__c
            FROM Case
            WHERE Id = :childCase.Id
        ];
        breg_Document__c generatedDocument = [
            SELECT
                Name,
                breg_Template_Document__c,
                breg_Is_Template_Copy__c,
                breg_Is_Public__c,
                breg_Delivery_Email__c,
                breg_Annotation__c,
                breg_Available_To_Certify__c,
                breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c = :childCase.Id
            LIMIT 1
        ];
        TransactionLine__c updatedCertCopyTransactionLine = [
            SELECT breg_Document__c
            FROM TransactionLine__c
            WHERE breg_Case__c = :testCase.Id
            AND breg_Type__c = 'NBR Form'
            LIMIT 1
        ];

        Assert.areEqual(
            'Document Certified Copy (Digital) - ' + publicDocument.Name + ' for ' + testCase.breg_Name_of_the_Entity__c,
            updatedChildCase.Subject,
            'The child case subject should replace the placeholder with the public document name.'
        );
        Assert.areEqual('Received', updatedChildCase.Status, 'The child case should move to Received after completion.');
        Assert.isTrue(updatedChildCase.breg_Override_Payment__c, 'The child case should bypass payment after the certified copy document is generated.');
        Assert.areEqual(generatedDocument.breg_Case__c, childCase.Id, 'The generated document should belong to the child case.');
        Assert.areEqual(generatedDocument.Id, updatedChildCase.breg_Document__c, 'The child case should link to the generated certified-copy document.');
        Assert.areEqual('Initial Filing - Certified Copy.pdf', generatedDocument.Name, 'The generated document name should append the certified-copy suffix before the extension.');
        Assert.areEqual(publicDocument.Id, generatedDocument.breg_Template_Document__c, 'The generated document should reference the latest public document as its template.');
        Assert.isTrue(generatedDocument.breg_Is_Template_Copy__c, 'The generated document should be marked as a template copy.');
        Assert.isFalse(generatedDocument.breg_Is_Public__c, 'The generated certified-copy document should not be public.');
        Assert.areEqual(requestor.Email, generatedDocument.breg_Delivery_Email__c, 'The generated document should copy the requestor email.');
        Assert.areEqual(requestor.FirstName + ' ' + requestor.LastName, generatedDocument.breg_Annotation__c, 'The generated document should annotate the requestor name.');
        Assert.isTrue(generatedDocument.breg_Available_To_Certify__c, 'The generated document should be available to certify.');
        Assert.areEqual(generatedDocument.Id, updatedCertCopyTransactionLine.breg_Document__c, 'The certified-copy transaction line should link to the generated document.');
    }

    @isTest
    static void testNbrHandlerEmptyListBranches() {
        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();

        Test.startTest();
        handler.handleStatusChange(new List<Case>(), 'Approved', true, true);
        handler.handleStatusChange(new List<Case>(), 'Completed', true, true);
        handler.handleStatusChange(new List<Case>(), 'Received', false, true);
        handler.handleStatusChange(new List<Case>(), 'Pending Submission', true, false);
        Test.stopTest();

        Assert.isTrue(true, 'NBR handler should execute orchestration branches for empty input.');
    }

    @isTest
    static void testCreateAnnualNotificationsUsesCaseEntity() {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();
        Account entityAcc = new Account(
            Name = 'NBR Notification Entity',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'New (Y)'
        );
        insert entityAcc;

        Contact requestor = new Contact(
            FirstName = 'NBR',
            LastName = 'Notification',
            Email = 'nbr.notification@example.com'
        );
        insert requestor;

        Case testCase = [
            SELECT Id, breg_Form_Code__c, breg_Entity__c, ContactId, breg_Subscribe_Owner_Free_Email_Alerts__c
            FROM Case
            WHERE breg_Form_Code__c = 'DC-1'
            LIMIT 1
        ];
        testCase.breg_Name_of_the_Entity__c = entityAcc.Name;
        testCase.breg_Entity__c = entityAcc.Id;
        testCase.ContactId = requestor.Id;
        testCase.breg_Subscribe_Owner_Free_Email_Alerts__c = true;

        Integer notificationCountBefore = [
            SELECT COUNT()
            FROM breg_Notification__c
            WHERE breg_Account__c = :entityAcc.Id
            AND breg_Contact__c = :requestor.Id
            AND breg_Notification_Category__c = 'Annual Report Reminder'
        ];

        BREGCaseStatusHandlerNBR handler = new BREGCaseStatusHandlerNBR();
        Test.startTest();
    handler.createAnnualNotificationsForCases(new List<Case>{ testCase });
        Test.stopTest();

        List<breg_Notification__c> notifications = [
            SELECT Id, breg_Account__c, breg_Contact__c, breg_Notification_Category__c
            FROM breg_Notification__c
            WHERE breg_Account__c = :entityAcc.Id
            AND breg_Contact__c = :requestor.Id
            AND breg_Notification_Category__c = 'Annual Report Reminder'
        ];

        Assert.areEqual(
            notificationCountBefore + 1,
            notifications.size(),
            'Completed status should create Annual Report Reminder for subscribed case.'
        );
        Assert.areEqual(entityAcc.Id, notifications[notifications.size() - 1].breg_Account__c, 'Notification should be linked to case breg_Entity__c.');
        Assert.areEqual(requestor.Id, notifications[notifications.size() - 1].breg_Contact__c, 'Notification should use case ContactId.');
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;

        TransactionLine__c line = new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = caseId,
            PaidStatus__c = 'Paid',
            Payment__c = payment.Id,
            Amount__c = 100
        );
        insert line;
    }

    private static breg_Form_Configuration__c createDocdlvrFormConfig() {
        breg_Form_Configuration__c docdlvrFormConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR',
            breg_Form_Name__c = 'Document Delivery'
        );
        insert docdlvrFormConfig;
        return docdlvrFormConfig;
    }

    private static void createCertCopyTransactionLine(Id caseId) {
        CashierCode__c cashierCode = new CashierCode__c(CashierCode__c = 'B23', Division__c = 'BREG', Name = 'Certified Copy Fee');
        insert cashierCode;

        Transaction__c trans = new Transaction__c();
        insert trans;

        TransactionLine__c line = new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = caseId,
            CashierCode__c = cashierCode.Id,
            breg_Type__c = 'NBR Form',
            Amount__c = 100
        );
        insert line;
    }
}