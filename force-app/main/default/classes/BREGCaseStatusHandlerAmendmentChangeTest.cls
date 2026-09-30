@IsTest
private class BREGCaseStatusHandlerAmendmentChangeTest {
    private static final String RECEIVED_SUBJECT = 'AmendmentChanges Received Test';
    private static final String COMPLETED_SUBJECT = 'AmendmentChanges Completed Test';

    @testSetup
    static void setup() {
        List<breg_Form_Configuration__c> formConfigurations = BREGTestDataFactory.createFormConfigurations();
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account llpEntity = new Account(Name = 'Test LLP Entity', RecordTypeId = bregAccountRtId, breg_Entity_Type__c = ConstantsHelper.K5_ENTITY_TYPE);

        Account completedEntity = new Account(Name = 'Original Entity Name', RecordTypeId = bregAccountRtId, breg_Entity_Type__c = 'ZZ');

        insert new List<Account>{ llpEntity, completedEntity };

        Account gpEntity = new Account(
            Name = 'Test GP Entity',
            ParentId = llpEntity.Id,
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = ConstantsHelper.G5_ENTITY_TYPE
        );
        insert gpEntity;

        Id caseRtId = getBregCaseRecordTypeId();

        Case receivedCase = new Case(
            Subject = RECEIVED_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = llpEntity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Code__c = 'DC-2',
            breg_Form_Configuration__c = formConfigurations[7].Id,
            breg_Name_of_the_Entity__c = 'Test LLP Entity'
        );
        if (caseRtId != null) {
            receivedCase.RecordTypeId = caseRtId;
        }

        Case completedCase = new Case(
            Subject = COMPLETED_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = completedEntity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_New_Entity_Name__c = 'Updated Entity Name',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__Street__s = '123 Main St',
            breg_Mailing_Address_Number_and_Street_2__c = 'Suite 100',
            breg_Mailing_Address__StateCode__s = 'DE',
            breg_Mailing_Address__City__s = 'Dover',
            breg_Mailing_Address__PostalCode__s = '19901',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__Street__s = '1 Corporate Way',
            breg_Company_Address_Street2__c = 'Floor 2',
            breg_Company_Address__StateCode__s = 'DE',
            breg_Company_Address__City__s = 'Wilmington',
            breg_Company_Address__PostalCode__s = '19801'
        );
        if (caseRtId != null) {
            completedCase.RecordTypeId = caseRtId;
        }

        insert new List<Case>{ receivedCase, completedCase };

        insert new breg_Stock__c(breg_Case__c = completedCase.Id, breg_Account__c = completedEntity.Id);

        insert new breg_Stock__c(breg_Account__c = completedEntity.Id, breg_Start_Date__c = Date.today().addDays(-10));

        insert new breg_Document__c(Name = 'Approved Initial Filing - Test', breg_Account__c = completedEntity.Id, breg_Is_Public__c = false);
    }

    @IsTest
    static void testPendingSubmissionValidation_futureDates() {
        Case c = new Case(
            Subject = 'Validation Test',
            Status = 'New',
            Origin = 'Phone',
            breg_Form_Code__c = 'DC-2',
            breg_Amendment_Adoption_Date__c = Date.today().addDays(1),
            breg_Written_Consent_Date__c = Date.today().addDays(2)
        );

        try {
            Test.startTest();
            new BREGCaseStatusHandlerAmendmentChanges().handleStatusChange(new List<Case>{ c }, 'Pending Submission', true, false);
            Test.stopTest();
            System.assert(false, 'Expected validation exception was not thrown.');
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            System.assert(e.getMessage().contains('Amendment Adoption Date cannot be a future date.'), 'Unexpected exception message: ' + e.getMessage());
        }
    }

    @IsTest
    static void testReceived_createsEntityAndGPTransactionsForLLP() {
        Case receivedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Transaction_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :RECEIVED_SUBJECT
            LIMIT 1
        ];
        String expectedTransactionCode = receivedCase.breg_Form_Configuration__r.breg_Transaction_Code__c;

        Test.startTest();
        new BREGCaseStatusHandlerAmendmentChanges().handleStatusChange(new List<Case>{ receivedCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c, breg_Case__r.breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :receivedCase.Id AND breg_Transaction_Code__c = :expectedTransactionCode
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(2, transactions.size(), 'Received LLP case should create entity and GP transactions.');

        Set<Id> accountIds = new Set<Id>();
        for (breg_Transaction__c t : transactions) {
            accountIds.add(t.breg_Account__c);
            System.assertEquals(t.breg_Case__r.breg_Transaction_Code__c, t.breg_Transaction_Code__c);
            System.assertEquals('R', t.breg_Status__c);
        }

        Account gpEntity = [
            SELECT Id
            FROM Account
            WHERE ParentId = :receivedCase.breg_Entity__c
            LIMIT 1
        ];

        System.assert(accountIds.contains(receivedCase.breg_Entity__c), 'Entity transaction should exist.');
        System.assert(accountIds.contains(gpEntity.Id), 'GP entity transaction should exist.');
    }

    @IsTest
    static void testCompleted_updatesEntity_linksCaseStocks_and_updatesDocuments() {
        Case completedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_New_Entity_Name__c,
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
                breg_Company_Address__City__s,
                breg_Company_Address_City__c,
                breg_Company_Address__PostalCode__s,
                breg_Form_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Form_Configuration__c,
                CaseNumber,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = :COMPLETED_SUBJECT
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAmendmentChanges().handleStatusChange(new List<Case>{ completedCase }, 'Completed', false, true);
        Test.stopTest();

        Account updatedEntity = [
            SELECT
                Id,
                Name,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Street_2__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                BillingCountryCode,
                BillingStreet,
                breg_Billing_Address_Street_2__c,
                BillingCity,
                BillingPostalCode
            FROM Account
            WHERE Id = :completedCase.breg_Entity__c
            LIMIT 1
        ];

        System.assertEquals('Updated Entity Name', updatedEntity.Name);
        System.assertEquals('US', updatedEntity.breg_Mailing_Address__CountryCode__s);
        System.assertEquals('123 Main St', updatedEntity.breg_Mailing_Address__Street__s);
        System.assertEquals('Suite 100', updatedEntity.breg_Mailing_Address_Street_2__c);
        System.assertEquals('Dover', updatedEntity.breg_Mailing_Address__City__s);
        System.assertEquals('19901', updatedEntity.breg_Mailing_Address__PostalCode__s);
        System.assertEquals('US', updatedEntity.BillingCountryCode);
        System.assertEquals('1 Corporate Way', updatedEntity.BillingStreet);
        System.assertEquals('Floor 2', updatedEntity.breg_Billing_Address_Street_2__c);
        System.assertEquals('Wilmington', updatedEntity.BillingCity);
        System.assertEquals('19801', updatedEntity.BillingPostalCode);

        List<breg_Stock__c> caseStocks = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Start_Date__c, breg_End_Date__c
            FROM breg_Stock__c
            WHERE breg_Case__c = :completedCase.Id
            ORDER BY CreatedDate ASC
        ];

        System.assert(!caseStocks.isEmpty(), 'Case-linked stock should exist after Completed.');

        Integer startedCount = 0;
        for (breg_Stock__c stock : caseStocks) {
            if (stock.breg_Account__c == completedCase.breg_Entity__c && stock.breg_Start_Date__c == completedCase.breg_Effective_Date__c) {
                startedCount++;
            }
        }

        System.assertEquals(1, startedCount, 'Case stock should get start date and stay linked to entity.');

        breg_Document__c doc = [
            SELECT Id, breg_Is_Public__c
            FROM breg_Document__c
            WHERE breg_Account__c = :completedCase.breg_Entity__c AND Name LIKE '%Approved Initial Filing%'
            LIMIT 1
        ];
        System.assertEquals(true, doc.breg_Is_Public__c, 'Approved Initial Filing document should become public.');
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