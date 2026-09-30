@IsTest
private class BREGCaseStatusHandlerAnnualsTest {
    private static final String APPROVED_SUBJECT = 'Annuals Approved Case';
    private static final String RECEIVED_SUBJECT = 'Annuals Received Case';
    private static final String COMPLETED_SUBJECT = 'Annuals Completed LLP Case';

    @testSetup
    static void setup() {
        Id caseRtId = getBregCaseRecordTypeId();
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        breg_Form_Configuration__c agFormConfig = new breg_Form_Configuration__c(
            Name = 'ANN-AG-1 Config',
            breg_Form_Code__c = 'ANN-AG-1',
            breg_Transaction_Code__c = 'ANN',
            breg_Suffix_Code__c = 'AG'
        );
        breg_Form_Configuration__c llpFormConfig = new breg_Form_Configuration__c(
            Name = 'ANN-LLP-1 Config',
            breg_Form_Code__c = 'ANN-LLP-1',
            breg_Transaction_Code__c = 'ANN',
            breg_Suffix_Code__c = 'LLP'
        );
        insert new List<breg_Form_Configuration__c>{ agFormConfig, llpFormConfig };

        Account annualEntity = new Account(
            Name = 'Annual Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            breg_Entity_Status__c = 'Active (A)'
        );

        Account llpEntity = new Account(
            Name = 'LLP Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Active (A)',
            breg_Good_Standing__c = true
        );

        insert new List<Account>{ annualEntity, llpEntity };

        Account gpEntity = new Account(
            Name = 'GP Entity',
            ParentId = llpEntity.Id,
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)',
            breg_Good_Standing__c = false
        );
        insert gpEntity;

        breg_Annual__c annualRecord = new breg_Annual__c(
            breg_Account__c = annualEntity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Filing_Date__c = Date.today(),
            breg_Status__c = 'N'
        );

        breg_Annual__c llpAnnual = new breg_Annual__c(
            breg_Account__c = llpEntity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Filing_Date__c = Date.today(),
            breg_Status__c = 'N'
        );

        breg_Annual__c gpAnnual = new breg_Annual__c(
            breg_Account__c = gpEntity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Filing_Date__c = Date.today(),
            breg_Status__c = 'N'
        );

        insert new List<breg_Annual__c>{ annualRecord, llpAnnual, gpAnnual };

        Case approvedCase = new Case(
            Subject = APPROVED_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = annualEntity.Id,
            breg_Annual__c = annualRecord.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'ANN-AG-1',
            breg_Form_Configuration__c = agFormConfig.Id,
            breg_Name_of_the_Entity__c = 'Annual Entity',
            breg_No_Changes__c = false,
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__Street__s = '123 Main St',
            breg_Mailing_Address_Number_and_Street_2__c = 'Suite 100',
            breg_Mailing_Address__StateCode__s = 'DE',
            breg_Mailing_Address__City__s = 'Dover',
            breg_Mailing_Address__PostalCode__s = '19901',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__Street__s = '1 Corp Way',
            breg_Company_Address_Street2__c = 'Floor 2',
            breg_Company_Address__StateCode__s = 'DE',
            breg_Company_Address__City__s = 'Wilmington',
            breg_Company_Address__PostalCode__s = '19801',
            breg_Entity_Nature_Of_Business__c = 'Updated annual activities'
        );
        if (caseRtId != null) {
            approvedCase.RecordTypeId = caseRtId;
        }

        Case receivedCase = new Case(
            Subject = RECEIVED_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = annualEntity.Id,
            breg_Annual__c = annualRecord.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'ANN-AG-1',
            breg_Form_Configuration__c = agFormConfig.Id,
            breg_Name_of_the_Entity__c = 'Annual Entity',
            breg_No_Changes__c = true
        );
        if (caseRtId != null) {
            receivedCase.RecordTypeId = caseRtId;
        }

        Case completedCase = new Case(
            Subject = COMPLETED_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = llpEntity.Id,
            breg_Annual__c = llpAnnual.Id,
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'ANN-LLP-1',
            breg_Form_Configuration__c = llpFormConfig.Id,
            breg_Name_of_the_Entity__c = 'LLP Entity',
            breg_No_Changes__c = false,
            breg_Entity_Nature_Of_Business__c = 'Consulting',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__Street__s = '500 LLP St',
            breg_Mailing_Address_Number_and_Street_2__c = 'Suite 5',
            breg_Mailing_Address__StateCode__s = 'DE',
            breg_Mailing_Address__City__s = 'Dover',
            breg_Mailing_Address__PostalCode__s = '19901',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__Street__s = '600 LLP Corp',
            breg_Company_Address_Street2__c = 'Floor 6',
            breg_Company_Address__StateCode__s = 'DE',
            breg_Company_Address__City__s = 'Wilmington',
            breg_Company_Address__PostalCode__s = '19801'
        );
        if (caseRtId != null) {
            completedCase.RecordTypeId = caseRtId;
        }

        insert new List<Case>{ approvedCase, receivedCase, completedCase };

        insert new List<breg_Stock__c>{
            new breg_Stock__c(breg_Account__c = annualEntity.Id, breg_Case__c = approvedCase.Id),
            new breg_Stock__c(breg_Account__c = annualEntity.Id, breg_Start_Date__c = Date.today().addDays(-10))
        };

        insert new breg_Document__c(Name = 'LLP Initial Filing Document', breg_Account__c = llpEntity.Id, breg_Is_Public__c = true);
    }

    @IsTest
    static void testApproved_validationThrowsWhenAnnualMissing() {
        Id caseRtId = getBregCaseRecordTypeId();
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account entity = new Account(
            Name = 'Validation Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        Case c = new Case(
            Subject = 'Validation Case',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = entity.Id,
            breg_Form_Code__c = 'ANN-AG-1',
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = 'Validation Entity',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__Street__s = '123 Main St',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__PostalCode__s = '96813',

            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__Street__s = '456 Main St',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__PostalCode__s = '96813',
            breg_Override_Payment__c = true,
            breg_File__c = '12345-D1'
        );
        if (caseRtId != null) {
            c.RecordTypeId = caseRtId;
        }
        insert c;

        Case caseForTest = [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Override_Payment__c,
                CaseNumber,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_File__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('Annual or Entity is blank.'), 'Unexpected exception message: ' + e.getMessage());
        }
    }

    @IsTest
    static void testReceivedDate_updatesAnnual() {
        Case receivedCase = [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                CaseNumber
            FROM Case
            WHERE Subject = :RECEIVED_SUBJECT
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        Test.stopTest();

        breg_Annual__c annualRecord = [
            SELECT Id, breg_Status__c, breg_Received_Date__c
            FROM breg_Annual__c
            WHERE Id = :receivedCase.breg_Annual__c
            LIMIT 1
        ];

        System.assertEquals('F', annualRecord.breg_Status__c);
        System.assertNotEquals(null, annualRecord.breg_Received_Date__c);
    }

    @IsTest
    static void testReceived_expiresDraftCasesForSameAnnual() {
        Case baseCase = getCaseBySubject(RECEIVED_SUBJECT);
        Id caseRtId = getBregCaseRecordTypeId();

        Case newDraftCase = new Case(
            Subject = 'Annual Draft New Case to Expire',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = baseCase.breg_Entity__c,
            breg_Annual__c = baseCase.breg_Annual__c,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = baseCase.breg_Form_Code__c,
            breg_Form_Configuration__c = baseCase.breg_Form_Configuration__c,
            breg_Name_of_the_Entity__c = baseCase.breg_Name_of_the_Entity__c,
            breg_No_Changes__c = true
        );
        Case pendingDraftCase = new Case(
            Subject = 'Annual Draft Pending Case to Expire',
            Status = 'Pending Submission',
            Origin = 'Phone',
            breg_Entity__c = baseCase.breg_Entity__c,
            breg_Annual__c = baseCase.breg_Annual__c,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = baseCase.breg_Form_Code__c,
            breg_Form_Configuration__c = baseCase.breg_Form_Configuration__c,
            breg_Name_of_the_Entity__c = baseCase.breg_Name_of_the_Entity__c,
            breg_No_Changes__c = true
        );
        if (caseRtId != null) {
            newDraftCase.RecordTypeId = caseRtId;
            pendingDraftCase.RecordTypeId = caseRtId;
        }
        insert new List<Case>{ newDraftCase, pendingDraftCase };

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ baseCase }, 'Received', false, true);
        Test.stopTest();

        List<Case> refreshedDraftCases = [
            SELECT Id, Status
            FROM Case
            WHERE Id IN :new Set<Id>{ newDraftCase.Id, pendingDraftCase.Id }
            ORDER BY Status
        ];

        System.assertEquals(2, refreshedDraftCases.size(), 'There should be two draft cases tied to the annual.');
        for (Case refreshedDraftCase : refreshedDraftCases) {
            System.assertEquals('Expired', refreshedDraftCase.Status, 'Draft annual case should expire when a paid case is received for the same annual.');
        }
    }

    @IsTest
    static void testReceived_updatesAnnualDueDateToNextCalendarYear() {
        Case receivedCase = getCaseBySubject(RECEIVED_SUBJECT);
        Date originalDueDate = Date.newInstance(2020, 1, 15);
        Date expectedDueDate = Date.newInstance(Date.today().year() + 1, 1, 15);

        update new Account(
            Id = receivedCase.breg_Entity__c,
            breg_Annuals_Due_Date__c = originalDueDate
        );

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        Test.stopTest();

        Account updatedEntity = [
            SELECT breg_Annuals_Due_Date__c
            FROM Account
            WHERE Id = :receivedCase.breg_Entity__c
            LIMIT 1
        ];

        System.assertEquals(expectedDueDate, updatedEntity.breg_Annuals_Due_Date__c);
    }

    @IsTest
    static void testReceived_updatesAnnualDueDateWithDuplicateEntityCases() {
        Case firstReceivedCase = getCaseBySubject(RECEIVED_SUBJECT);
        Date originalDueDate = Date.newInstance(2020, 1, 15);
        Date expectedDueDate = Date.newInstance(Date.today().year() + 1, 1, 15);

        update new Account(
            Id = firstReceivedCase.breg_Entity__c,
            breg_Annuals_Due_Date__c = originalDueDate
        );

        Id caseRtId = getBregCaseRecordTypeId();
        Case secondReceivedCase = new Case(
            Subject = 'Annuals Received Duplicate Entity Case',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = firstReceivedCase.breg_Entity__c,
            breg_Annual__c = firstReceivedCase.breg_Annual__c,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = firstReceivedCase.breg_Form_Code__c,
            breg_Form_Configuration__c = firstReceivedCase.breg_Form_Configuration__c,
            breg_Name_of_the_Entity__c = firstReceivedCase.breg_Name_of_the_Entity__c,
            breg_No_Changes__c = true
        );
        if (caseRtId != null) {
            secondReceivedCase.RecordTypeId = caseRtId;
        }
        insert secondReceivedCase;

        Case secondCaseForTest = getCaseBySubject('Annuals Received Duplicate Entity Case');

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(
            new List<Case>{ firstReceivedCase, secondCaseForTest },
            'Received',
            false,
            true
        );
        Test.stopTest();

        Account updatedEntity = [
            SELECT breg_Annuals_Due_Date__c
            FROM Account
            WHERE Id = :firstReceivedCase.breg_Entity__c
            LIMIT 1
        ];

        System.assertEquals(expectedDueDate, updatedEntity.breg_Annuals_Due_Date__c);
    }

    @IsTest
    static void testReceived_createsEntityAndGpTransactionsForLlp() {
        Case receivedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Transaction_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Annual__r.breg_Filing_Date__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :COMPLETED_SUBJECT
            LIMIT 1
        ];

        Account gpEntity = [
            SELECT Id
            FROM Account
            WHERE ParentId = :receivedCase.breg_Entity__c
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Account__c, breg_Status__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :receivedCase.Id
        ];

        System.assertEquals(2, transactions.size(), 'Received LLP case should create transactions for entity and GP child.');
        Set<Id> accountIds = new Set<Id>();
        for (breg_Transaction__c t : transactions) {
            accountIds.add(t.breg_Account__c);
            System.assertEquals('R', t.breg_Status__c, 'Received transactions should use status R.');
            System.assertEquals('ANN', t.breg_Transaction_Code__c, 'Annuals received transactions should use ANN transaction code.');
        }

        System.assert(accountIds.contains(receivedCase.breg_Entity__c), 'Entity transaction should exist.');
        System.assert(accountIds.contains(gpEntity.Id), 'GP child transaction should exist.');
    }

    @IsTest
    static void testApproved_updatesAnnualOnly() {
        Case approvedCase = [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_City__c,
                breg_Company_Address__PostalCode__s,
                breg_Annual_Activities__c,
                breg_Number_of_Shareholders__c,
                breg_Number_of_initial_members__c,
                breg_Membership_Fees_Received__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Formation_State__c,
                breg_Partnership_Location__c,
                CaseNumber,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Entity__r.breg_Entity_Status__c,
                breg_Entity__r.breg_Status_Effective_Date__c,
                breg_Entity__r.ParentId,
                breg_Override_Payment__c,
                breg_Received_Date_Formula__c,
                breg_Transaction_Code__c
            FROM Case
            WHERE Subject = :APPROVED_SUBJECT
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ approvedCase }, 'Approved', false, true);
        Test.stopTest();

        breg_Annual__c annualRecord = [
            SELECT Id, breg_Status__c, breg_No_Changes__c
            FROM breg_Annual__c
            WHERE Id = :approvedCase.breg_Annual__c
            LIMIT 1
        ];
        System.assertEquals('P', annualRecord.breg_Status__c);
        System.assertEquals(false, annualRecord.breg_No_Changes__c);
    }

    @IsTest
    static void testCompleted_updatesEntityAndGpEntity() {
        Case completedCase = [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_City__c,
                breg_Company_Address__PostalCode__s,
                CaseNumber,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Entity__r.breg_Entity_Status__c,
                breg_Entity__r.breg_Status_Effective_Date__c,
                breg_Entity__r.ParentId,
                breg_Annual__r.breg_Filing_Year__c,
                breg_Annual__r.breg_Status__c,
                breg_Annual__r.breg_No_Changes__c,
                breg_Annual__r.breg_Account__c,
                breg_Transaction_Code__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = :COMPLETED_SUBJECT
            LIMIT 1
        ];

        Account gpEntity = [
            SELECT Id, ParentId
            FROM Account
            WHERE ParentId = :completedCase.breg_Entity__c
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ completedCase }, 'Approved', false, true);
        Test.stopTest();

        breg_Annual__c llpAnnual = [
            SELECT Id, breg_Status__c, breg_No_Changes__c
            FROM breg_Annual__c
            WHERE Id = :completedCase.breg_Annual__c
            LIMIT 1
        ];
        System.assertEquals('P', llpAnnual.breg_Status__c);
        System.assertEquals(false, llpAnnual.breg_No_Changes__c);

        Account updatedLlp = [
            SELECT
                Id,
                breg_Purpose__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                BillingStreet,
                BillingCity,
                BillingPostalCode
            FROM Account
            WHERE Id = :completedCase.breg_Entity__c
            LIMIT 1
        ];
        System.assertEquals('Consulting', updatedLlp.breg_Purpose__c);
        System.assertEquals('500 LLP St', updatedLlp.breg_Mailing_Address__Street__s);
        System.assertEquals('Dover', updatedLlp.breg_Mailing_Address__City__s);
        System.assertEquals('19901', updatedLlp.breg_Mailing_Address__PostalCode__s);
        System.assertEquals('600 LLP Corp', updatedLlp.BillingStreet);
        System.assertEquals('Wilmington', updatedLlp.BillingCity);
        System.assertEquals('19801', updatedLlp.BillingPostalCode);

        Account refreshedGp = [
            SELECT Id, breg_Entity_Status__c, breg_Good_Standing__c
            FROM Account
            WHERE Id = :gpEntity.Id
            LIMIT 1
        ];
        System.assertEquals('Active (A)', refreshedGp.breg_Entity_Status__c);
        System.assertEquals(true, refreshedGp.breg_Good_Standing__c);

        Integer gpAnnualCount = [
            SELECT COUNT()
            FROM breg_Annual__c
            WHERE breg_Account__c = :gpEntity.Id
        ];
        System.assert(gpAnnualCount > 0, 'Expected GP annual records to exist.');
    }

    @IsTest
    static void testApprovedDoesNotOverwriteEntityStatusWhenLaterAnnualIsProcessed() {
        TestDataBundle data = createValidationData('Processed Later Annual Entity', 'ZZ', 'Active (A)', null, null);
        data.annual.breg_Filing_Year__c = String.valueOf(Date.today().year() - 1);
        update data.annual;

        insert new breg_Annual__c(
            breg_Account__c = data.entity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Status__c = 'P'
        );

        Case caseForTest = getCaseForValidation(data.caseRecord.Id);

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', false, true);
        Test.stopTest();

        Account updatedEntity = [
            SELECT breg_Entity_Status__c
            FROM Account
            WHERE Id = :data.entity.Id
        ];
        System.assertEquals(
            'Active (A)',
            updatedEntity.breg_Entity_Status__c,
            'An older annual must not overwrite entity status after a later annual has been processed.'
        );
    }

    @IsTest
    static void testApproved_validationThrowsWhenEntityStatusNotEligible() {
        Id caseRtId = getBregCaseRecordTypeId();
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account entity = new Account(
            Name = 'Bad Status Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            breg_Entity_Status__c = 'Merged (M)'
        );
        insert entity;

        breg_Annual__c annualRecord = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Status__c = 'N'
        );
        insert annualRecord;

        Case c = buildAnnualCase('Validation Entity Status Case', entity, annualRecord.Id, 'ANN-AG-1');
        c.breg_Override_Payment__c = true;
        c.breg_File__c = '12345-D2';
        if (caseRtId != null) {
            c.RecordTypeId = caseRtId;
        }
        insert c;

        Case caseForTest = [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Override_Payment__c,
                CaseNumber,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_File__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(
                e.getMessage().contains('Entity not in Active (A), Annual report 1 yr delinquent (1) or Annual report 2 yr delinquent (2) status.'),
                'Unexpected exception message: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void testApproved_validationThrowsWhenConflictingTransactionExists() {
        TestDataBundle data = createValidationData('Conflict Entity', 'ZZ', 'Active (A)', null, null);

        breg_Form_Configuration__c x8Config = new breg_Form_Configuration__c(
            Name = 'X-8 Conflict Config',
            breg_Form_Code__c = 'X-8',
            breg_Transaction_Code__c = 'ADD',
            breg_Suffix_Code__c = 'D1'
        );
        insert x8Config;

        Case conflictCase = new Case(
            Subject = 'Conflicting X-8 Case',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = data.entity.Id,
            breg_Form_Code__c = 'X-8',
            breg_Form_Configuration__c = x8Config.Id,
            breg_Name_of_the_Entity__c = data.entity.Name
        );
        Id caseRtId = getBregCaseRecordTypeId();
        if (caseRtId != null) {
            conflictCase.RecordTypeId = caseRtId;
        }
        insert conflictCase;

        Case caseForTest = getCaseForValidation(data.caseRecord.Id);

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('No conflicting transactions must be pending'), e.getMessage());
        }
    }

    @IsTest
    static void testApproved_doesNotBlockWhenConflictingTransactionWasSubmittedAfterAnnual() {
        TestDataBundle data = createValidationData('Later Conflict Entity', 'ZZ', 'Active (A)', null, null);

        breg_Form_Configuration__c x8Config = new breg_Form_Configuration__c(
            Name = 'X-8 Later Conflict Config',
            breg_Form_Code__c = 'X-8',
            breg_Transaction_Code__c = 'ADD',
            breg_Suffix_Code__c = 'D2'
        );
        insert x8Config;

        Case annualCase = getCaseForValidation(data.caseRecord.Id);
        annualCase.breg_Submission_Date__c = System.now().addHours(-1);
        update annualCase;

        Case conflictCase = new Case(
            Subject = 'Conflicting X-8 Case Submitted Later',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = data.entity.Id,
            breg_Form_Code__c = 'X-8',
            breg_Form_Configuration__c = x8Config.Id,
            breg_Name_of_the_Entity__c = data.entity.Name,
            breg_Submission_Date__c = System.now().addHours(1)
        );
        Id caseRtId = getBregCaseRecordTypeId();
        if (caseRtId != null) {
            conflictCase.RecordTypeId = caseRtId;
        }
        insert conflictCase;

        Case caseForTest = getCaseForValidation(annualCase.Id);

        Boolean threwException = false;
        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            threwException = true;
        }

        System.assertEquals(false, threwException, 'Later submitted conflicting case should not block annual approval.');
    }

    @IsTest
    static void testApproved_validationThrowsWhenDelinquentPeriodExpired() {
        TestDataBundle data = createValidationData(
            'Expired Delinquent Entity',
            'ZZ',
            'Annual report 2 yr delinquent (2)',
            Date.today().addDays(-61),
            null
        );

        Case caseForTest = getCaseForValidation(data.caseRecord.Id);

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('The delinquent filing period is not active.'), e.getMessage());
        }
    }

    @IsTest
    static void testApproved_validationThrowsWhenGpHasParent() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account parentEntity = new Account(
            Name = 'Parent LLP For GP Validation',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'K5',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert parentEntity;

        TestDataBundle data = createValidationData(
            'GP With Parent Entity',
            'G5',
            'Active (A)',
            null,
            parentEntity.Id
        );

        Case caseForTest = getCaseForValidation(data.caseRecord.Id);

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ caseForTest }, 'Approved', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('GP entity has a corresponding LLP'), e.getMessage());
        }
    }

    @IsTest
    static void testRejected_updatesAnnualStatus() {
        Case rejectedCase = getCaseBySubject(RECEIVED_SUBJECT);

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ rejectedCase }, 'Rejected', false, true);
        Test.stopTest();

        breg_Annual__c annualRecord = [
            SELECT Id, breg_Status__c
            FROM breg_Annual__c
            WHERE Id = :rejectedCase.breg_Annual__c
            LIMIT 1
        ];

        System.assertEquals('N', annualRecord.breg_Status__c);
    }

    @IsTest
    static void testPendingSubmission_updatesLlpAndGpAnnualStatuses() {
        Case llpCase = getCaseBySubject(COMPLETED_SUBJECT);

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ llpCase }, 'Received', false, true);
        Test.stopTest();

        breg_Annual__c llpAnnual = [
            SELECT Id, breg_Status__c, breg_Received_Date__c
            FROM breg_Annual__c
            WHERE Id = :llpCase.breg_Annual__c
            LIMIT 1
        ];

        breg_Annual__c gpAnnual = getGpAnnualByLlpEntityId(llpCase.breg_Entity__c);

        System.assertEquals('F', llpAnnual.breg_Status__c, 'LLP annual should be set to Filed on Pending Submission.');
        System.assertNotEquals(null, llpAnnual.breg_Received_Date__c, 'LLP annual should have received date on Pending Submission.');

        System.assertEquals('F', gpAnnual.breg_Status__c, 'GP annual should be set to Filed on Pending Submission.');
        System.assertNotEquals(null, gpAnnual.breg_Received_Date__c, 'GP annual should have received date on Pending Submission.');
    }

    @IsTest
    static void testRejected_updatesLlpAndGpAnnualStatuses() {
        Case llpCase = getCaseBySubject(COMPLETED_SUBJECT);

        Test.startTest();
        new BREGCaseStatusHandlerAnnuals().handleStatusChange(new List<Case>{ llpCase }, 'Rejected', false, true);
        Test.stopTest();

        breg_Annual__c llpAnnual = [
            SELECT Id, breg_Status__c
            FROM breg_Annual__c
            WHERE Id = :llpCase.breg_Annual__c
            LIMIT 1
        ];

        breg_Annual__c gpAnnual = getGpAnnualByLlpEntityId(llpCase.breg_Entity__c);

        System.assertEquals('N', llpAnnual.breg_Status__c, 'LLP annual should be reset to Not Filed when rejected from active status.');
        System.assertEquals('D', gpAnnual.breg_Status__c, 'GP annual should stay delinquent when GP entity is delinquent.');
    }
    // BREG-3720: removed Completed updateAnnual as per new requirements
    // @IsTest
    // static void testCompleted_setsAnnualStatusForVariousAnnualFormTypes() {
    //     Id caseRtId = getBregCaseRecordTypeId();
    //     Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

    //     List<String> formCodes = new List<String>{
    //         'ANN-AG-1',
    //         'ANN-CONS-1',
    //         'ANN-DC-1',
    //         'ANN-DNP-1',
    //         'ANN-FC-1',
    //         'ANN-FLLC-1',
    //         'ANN-FLLP-1',
    //         'ANN-FLP-1',
    //         'ANN-GP-1',
    //         'ANN-LLC-1',
    //         'ANN-LLP-1',
    //         'ANN-LP-1',
    //         'ANN-PC-1',
    //         'ANN-SBC-1',
    //         'ANN-SOLE-1'
    //     };

    //     List<breg_Form_Configuration__c> configs = new List<breg_Form_Configuration__c>();
    //     for (String code : formCodes) {
    //         configs.add(
    //             new breg_Form_Configuration__c(
    //                 Name = code + ' Config',
    //                 breg_Form_Code__c = code,
    //                 breg_Transaction_Code__c = 'ANN',
    //                 breg_Suffix_Code__c = code.replace('ANN-', '').replace('-1', '')
    //             )
    //         );
    //     }
    //     insert configs;

    //     Map<String, Id> codeToConfigId = new Map<String, Id>();
    //     for (breg_Form_Configuration__c cfg : configs) {
    //         codeToConfigId.put(cfg.breg_Form_Code__c, cfg.Id);
    //     }

    //     List<Account> entities = new List<Account>();
    //     for (String code : formCodes) {
    //         entities.add(
    //             new Account(
    //                 Name = code + ' Entity',
    //                 RecordTypeId = bregAccountRtId,
    //                 breg_Entity_Type__c = 'ZZ',
    //                 breg_Entity_Status__c = 'Active (A)'
    //             )
    //         );
    //     }
    //     insert entities;

    //     Map<String, Id> codeToEntityId = new Map<String, Id>();
    //     for (Integer i = 0; i < formCodes.size(); i++) {
    //         codeToEntityId.put(formCodes[i], entities[i].Id);
    //     }

    //     List<breg_Annual__c> annuals = new List<breg_Annual__c>();
    //     for (String code : formCodes) {
    //         annuals.add(
    //             new breg_Annual__c(
    //                 breg_Account__c = codeToEntityId.get(code),
    //                 breg_Filing_Year__c = String.valueOf(Date.today().year()),
    //                 breg_Status__c = 'N'
    //             )
    //         );
    //     }
    //     insert annuals;

    //     Map<String, Id> codeToAnnualId = new Map<String, Id>();
    //     for (Integer i = 0; i < formCodes.size(); i++) {
    //         codeToAnnualId.put(formCodes[i], annuals[i].Id);
    //     }

    //     List<Case> casesToInsert = new List<Case>();
    //     for (String code : formCodes) {
    //         Case c = new Case(
    //             Subject = code + ' Completed Coverage',
    //             Status = 'New',
    //             Origin = 'Phone',
    //             breg_Entity__c = codeToEntityId.get(code),
    //             breg_Annual__c = codeToAnnualId.get(code),
    //             breg_Effective_Date__c = Date.today(),
    //             breg_Form_Code__c = code,
    //             breg_Form_Configuration__c = codeToConfigId.get(code),
    //             breg_Name_of_the_Entity__c = code + ' Entity',
    //             breg_No_Changes__c = false,
    //             breg_Mailing_Address__CountryCode__s = 'US',
    //             breg_Mailing_Address__Street__s = '100 Main St',
    //             breg_Mailing_Address__StateCode__s = 'DE',
    //             breg_Mailing_Address__City__s = 'Dover',
    //             breg_Mailing_Address__PostalCode__s = '19901',
    //             breg_Company_Address__CountryCode__s = 'US',
    //             breg_Company_Address__Street__s = '200 Corp St',
    //             breg_Company_Address__StateCode__s = 'DE',
    //             breg_Company_Address__City__s = 'Wilmington',
    //             breg_Company_Address__PostalCode__s = '19801',
    //             breg_Entity_Nature_Of_Business__c = code + ' Purpose',
    //             breg_Formation_State__c = 'DE',
    //             breg_Partnership_Location__c = 'DE'
    //         );
    //         if (caseRtId != null) {
    //             c.RecordTypeId = caseRtId;
    //         }
    //         casesToInsert.add(c);
    //     }
    //     insert casesToInsert;

    //     addStockPairsForCases(new Set<String>{ 'ANN-PC-1', 'ANN-SBC-1' });

    //     List<Case> casesForTest = [
    //         SELECT
    //             Id,
    //             breg_Annual__c,
    //             breg_Entity__c,
    //             breg_No_Changes__c,
    //             breg_Form_Code__c,
    //             breg_Form_Configuration__c,
    //             breg_Name_of_the_Entity__c,
    //             breg_Effective_Date__c,
    //             breg_Mailing_Address__CountryCode__s,
    //             breg_Mailing_Address__Street__s,
    //             breg_Mailing_Address_Number_and_Street_2__c,
    //             breg_Mailing_Address__StateCode__s,
    //             breg_Mailing_Address__City__s,
    //             breg_Mailing_Address__PostalCode__s,
    //             breg_Company_Address__CountryCode__s,
    //             breg_Company_Address__Street__s,
    //             breg_Company_Address_Street2__c,
    //             breg_Company_Address__StateCode__s,
    //             breg_Company_Address__City__s,
    //             breg_Company_Address__PostalCode__s,
    //             breg_Annual_Activities__c,
    //             breg_Number_of_Shareholders__c,
    //             breg_Number_of_initial_members__c,
    //             breg_Membership_Fees_Received__c,
    //             breg_Entity_Nature_Of_Business__c,
    //             breg_Formation_State__c,
    //             breg_Partnership_Location__c,
    //             CaseNumber,
    //             breg_Entity__r.breg_Entity_Type__c,
    //             breg_Entity__r.breg_Entity_Status__c,
    //             breg_Entity__r.breg_Status_Effective_Date__c,
    //             breg_Company_Address_City__c,
    //             breg_Override_Payment__c,
    //             breg_Transaction_Code__c,
    //             breg_File_Suffix__c,
    //             breg_Received_Date_Formula__c
    //         FROM Case
    //         WHERE Subject LIKE 'ANN-% Completed Coverage'
    //     ];

    //     Test.startTest();
    //     new BREGCaseStatusHandlerAnnuals().handleStatusChange(casesForTest, 'Completed', false, true);
    //     Test.stopTest();

    //     Integer approvedAnnualCount = [
    //         SELECT COUNT()
    //         FROM breg_Annual__c
    //         WHERE Id IN :codeToAnnualId.values()
    //           AND breg_Status__c = 'P'
    //     ];
    //     System.assertEquals(formCodes.size(), approvedAnnualCount);
    // }

    // private static void addStockPairsForCases(Set<String> formCodes) {
    //     List<Case> stockCases = [
    //         SELECT Id, breg_Entity__c, breg_Form_Code__c
    //         FROM Case
    //         WHERE breg_Form_Code__c IN :formCodes
    //     ];

    //     List<breg_Stock__c> stocks = new List<breg_Stock__c>();

    //     for (Case c : stockCases) {
    //         stocks.add(new breg_Stock__c(
    //             breg_Account__c = c.breg_Entity__c,
    //             breg_Case__c = c.Id,
    //             breg_Stock_Class__c = getStockClassValue(),
    //             breg_Number_of_Issued_Shares__c = '100'
    //         ));

    //         stocks.add(new breg_Stock__c(
    //             breg_Account__c = c.breg_Entity__c,
    //             breg_Start_Date__c = Date.today().addDays(-5),
    //             breg_Stock_Class__c = getStockClassValue(),
    //             breg_Number_of_Issued_Shares__c = '200'
    //         ));
    //     }

    //     insert stocks;
    // }

    private static String getStockClassValue() {
        Schema.DescribeFieldResult dfr = breg_Stock__c.breg_Stock_Class__c.getDescribe();

        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    private static Case buildAnnualCase(String subject, Account entity, Id annualId, String formCode) {
        return new Case(
            Subject = subject,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = entity.Id,
            breg_Annual__c = annualId,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = formCode,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_No_Changes__c = false,
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__Street__s = '123 Main St',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__PostalCode__s = '96813',

            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__Street__s = '456 Main St',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__PostalCode__s = '96813',
            breg_Override_Payment__c = true,
            breg_File__c = '12345-D1'
        );
    }

    private class TestDataBundle {
        Account entity;
        breg_Annual__c annual;
        Case caseRecord;

        TestDataBundle(Account entity, breg_Annual__c annual, Case caseRecord) {
            this.entity = entity;
            this.annual = annual;
            this.caseRecord = caseRecord;
        }
    }

    private static TestDataBundle createValidationData(
        String entityName,
        String entityType,
        String entityStatus,
        Date statusEffectiveDate,
        Id parentId
    ) {
        Id caseRtId = getBregCaseRecordTypeId();
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account entity = new Account(
            Name = entityName,
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = entityType,
            breg_Entity_Status__c = entityStatus,
            breg_Status_Effective_Date__c = statusEffectiveDate,
            ParentId = parentId
        );
        insert entity;

        breg_Annual__c annualRecord = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Status__c = 'N'
        );
        insert annualRecord;

        Case caseRecord = buildAnnualCase(entityName + ' Annual Case', entity, annualRecord.Id, 'ANN-AG-1');
        if (caseRtId != null) {
            caseRecord.RecordTypeId = caseRtId;
        }
        insert caseRecord;

        return new TestDataBundle(entity, annualRecord, caseRecord);
    }

    private static Case getCaseBySubject(String subjectValue) {
        return [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Annual_Report_Filing_Year__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address_State__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_State__c,
                breg_Company_Address__City__s,
                breg_Company_Address__PostalCode__s,
                //breg_Annual_Activities__c,
                breg_Number_of_Shareholders__c,
                breg_Number_of_initial_members__c,
                breg_Membership_Fees_Received__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Formation_State__c,
                breg_Partnership_Location__c,
                breg_File_Suffix__c,
                CaseNumber,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Entity__r.breg_Entity_Status__c,
                breg_Entity__r.breg_Status_Effective_Date__c,
                breg_Entity__r.ParentId,
                breg_Annual__r.breg_Filing_Year__c,
                breg_Annual__r.breg_Status__c,
                breg_Annual__r.breg_No_Changes__c,
                breg_Annual__r.breg_Account__c,
                breg_Submission_Date__c,
                breg_Transaction_Code__c,
                breg_Override_Payment__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = :subjectValue
            LIMIT 1
        ];
    }

    private static breg_Annual__c getGpAnnualByLlpEntityId(Id llpEntityId) {
        return [
            SELECT Id, breg_Status__c, breg_Received_Date__c
            FROM breg_Annual__c
            WHERE breg_Account__r.ParentId = :llpEntityId
            LIMIT 1
        ];
    }

    private static Case getCaseForValidation(Id caseId) {
        return [
            SELECT
                Id,
                breg_Annual__c,
                breg_Entity__c,
                breg_No_Changes__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_Effective_Date__c,
                breg_Override_Payment__c,
                CaseNumber,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Submission_Date__c,
                breg_File__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    private static Id getBregCaseRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND Name = 'BREG Case'
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }
}