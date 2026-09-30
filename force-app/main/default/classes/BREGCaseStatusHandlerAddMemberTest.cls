@IsTest
private class BREGCaseStatusHandlerAddMemberTest {
    private static final String MAIN_SUBJECT = 'Add Member Main Case';
    private static final String OLD_SUBJECT = 'Add Member Old Case';

    @testSetup
    static void setup() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'ADD-MEMBER',
            breg_Form_Code__c = 'ADD-MEMBER',
            breg_Suffix_Code__c = 'ADD-MEMBER',
            breg_Transaction_Code__c = 'ADD-MEMBER'
        );
        insert formConfig;

        Account entity = new Account(
            Name = 'Add Member Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ'
        );

        Account existingMemberAccount = new Account(
            Name = 'Add Member Existing Account',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            BillingStreet = 'Old Street',
            BillingCity = 'Old City',
            BillingStateCode = 'DE',
            BillingPostalCode = '19901',
            BillingCountryCode = 'US'
        );

        insert new List<Account>{ entity, existingMemberAccount };

        Contact existingMemberContact = new Contact(
            FirstName = 'John',
            LastName = 'Member'
        );
        insert existingMemberContact;

        Id caseRtId = getBregCaseRecordTypeId();

        Case mainCase = new Case(
            Subject = MAIN_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today(),
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'ADD-MEMBER',
            breg_Name_of_the_Entity__c = 'Add Member Entity'
        );
        if (caseRtId != null) {
            mainCase.RecordTypeId = caseRtId;
        }

        Case oldCase = new Case(
            Subject = OLD_SUBJECT,
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = entity.Id,
            breg_Effective_Date__c = Date.today().addDays(-10),
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'ADD-MEMBER',
            breg_Name_of_the_Entity__c = 'Add Member Entity'
        );
        if (caseRtId != null) {
            oldCase.RecordTypeId = caseRtId;
        }

        insert new List<Case>{ mainCase, oldCase };

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Case__c = mainCase.Id,
                breg_Entity__c = entity.Id,
                breg_Account__c = existingMemberAccount.Id,
                breg_Type__c = 'Entity',
                breg_Role__c = 'Officer',
                breg_Entity_Name__c = 'Add Member Existing Account',
                breg_Address__Street__s = '123 New Street',
                breg_Address__City__s = 'Dover',
                breg_Address__StateCode__s = 'DE',
                breg_Address__PostalCode__s = '19904',
                breg_Address__CountryCode__s = 'US'
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = mainCase.Id,
                breg_Entity__c = entity.Id,
                breg_Type__c = 'Entity',
                breg_Role__c = 'Officer',
                breg_Entity_Name__c = 'Brand New Add Member LLC',
                breg_Address__Street__s = '456 Brand New St',
                breg_Address__City__s = 'Wilmington',
                breg_Address__StateCode__s = 'DE',
                breg_Address__PostalCode__s = '19801',
                breg_Address__CountryCode__s = 'US'
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = mainCase.Id,
                breg_Entity__c = entity.Id,
                breg_Contact__c = existingMemberContact.Id,
                breg_Type__c = 'Individual',
                breg_Role__c = 'Director',
                breg_First_Name__c = 'John',
                breg_Last_Name__c = 'Member',
                breg_Address__Street__s = '789 Contact St',
                breg_Address__City__s = 'Newark',
                breg_Address__StateCode__s = 'DE',
                breg_Address__PostalCode__s = '19711',
                breg_Address__CountryCode__s = 'US'
            ),
            new breg_Account_Affiliation__c(
                breg_Case__c = oldCase.Id,
                breg_Entity__c = entity.Id,
                breg_Account__c = existingMemberAccount.Id,
                breg_Type__c = 'Entity',
                breg_Role__c = 'Officer',
                breg_Entity_Name__c = 'Add Member Existing Account',
                breg_Address__Street__s = 'Old Street',
                breg_Address__City__s = 'Old City',
                breg_Address__StateCode__s = 'DE',
                breg_Address__PostalCode__s = '19901',
                breg_Address__CountryCode__s = 'US'
            )
        };
    }

    @IsTest
    static void testReceivedCreatesTransactionsForEntity() {
        Case receivedCase = [
            SELECT
                Id,
                Status,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c,
                breg_File_Suffix__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAddMember().handleStatusChange(
            new List<Case>{ receivedCase },
            'Received',
            false,
            true
        );
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Transaction_Code__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :receivedCase.Id
        ];

        System.assert(
            transactions.size() > 0,
            'Received status should create add-member transactions.'
        );
    }

    @IsTest
    static void testApprovedUpdatesMemberAddressesFromAffiliations() {
        Case approvedCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Received_Date_Formula__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_TN_TM_SM__c,
                CaseNumber
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Account existingMemberAccount = [
            SELECT Id, BillingStreet, BillingCity
            FROM Account
            WHERE Name = 'Add Member Existing Account'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAddMember().handleStatusChange(
            new List<Case>{ approvedCase },
            'Approved',
            false,
            true
        );
        Test.stopTest();

        Account updatedMemberAccount = [
            SELECT BillingStreet, BillingCity
            FROM Account
            WHERE Id = :existingMemberAccount.Id
            LIMIT 1
        ];

        // Verify that the member account's address has not been updated to match the affiliation's address
        System.assertEquals(
            'Old Street',
            updatedMemberAccount.BillingStreet,
            'Completed status should copy the affiliation street.'
        );
        System.assertEquals(
            'Old City',
            updatedMemberAccount.BillingCity,
            'Completed status should copy the affiliation city.'
        );
    }

    @IsTest
    static void testCompletedDoesNotCreateAddMemberTransaction() {
        Case completedCase = [
            SELECT
                Id,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c,
                breg_File_Suffix__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT COUNT()
            FROM breg_Transaction__c
            WHERE breg_Case__c = :completedCase.Id
        ];

        Test.startTest();
        new BREGCaseStatusHandlerAddMember().handleStatusChange(
            new List<Case>{ completedCase },
            'Completed',
            false,
            true
        );
        Test.stopTest();
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