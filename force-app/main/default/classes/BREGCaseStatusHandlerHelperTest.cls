@IsTest
private class BREGCaseStatusHandlerHelperTest {
    private static final String MAIN_SUBJECT = 'Helper Main Case';
    private static final String OLD_SUBJECT = 'Helper Old Case';

    @testSetup
    static void setup() {
        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account entity = new Account(
            Name = 'Main Entity',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ'
        );

        Account existingMemberAccount = new Account(
            Name = 'Existing Member Account',
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
            breg_Form_Code__c = 'ADD',
            breg_Name_of_the_Entity__c = 'Main Entity'
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
            breg_Form_Code__c = 'ADD',
            breg_Name_of_the_Entity__c = 'Main Entity'
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
                breg_Entity_Name__c = 'Existing Member Account',
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
                breg_Entity_Name__c = 'Brand New Member LLC',
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
                breg_Entity_Name__c = 'Existing Member Account',
                breg_Address__Street__s = 'Old Street',
                breg_Address__City__s = 'Old City',
                breg_Address__StateCode__s = 'DE',
                breg_Address__PostalCode__s = '19901',
                breg_Address__CountryCode__s = 'US',
                breg_Status__c = 'A',
                breg_Start_Date__c = Date.today().addDays(-20)
            )
        };
    }

    @IsTest
    static void testPopulateEntityRelatedFields_clearsWhenAccountIsMissing() {
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Account__c = Id.valueOf('001000000000001AAA'),
            breg_Entity_Name__c = 'Should Be Cleared',
            breg_Entity_Type__c = 'Corporation',
            breg_Entity_Type_Description__c = 'Domestic Corporation',
            breg_Suffix__c = 'D1',
            breg_File__c = '12345',
            breg_Number_of_shares__c = 100,
            breg_Entity_Location__c = 'United States, Hawaii'
        );

        Test.startTest();
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(new List<breg_Account_Affiliation__c>{ affiliation });
        Test.stopTest();

        Assert.isNull(affiliation.breg_Entity_Name__c, 'Entity name should be cleared when the related account is not found');
        Assert.isNull(affiliation.breg_Entity_Type__c, 'Entity type should be cleared when the related account is not found');
        Assert.isNull(affiliation.breg_Entity_Location__c, 'Entity location should be cleared when the related account is not found');
    }

    @IsTest
    static void testPopulateEntityRelatedFields_coversEarlyReturnsAndExistingAccount() {
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(null);
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(new List<breg_Account_Affiliation__c>());

        Account entity = [SELECT Id, Name FROM Account WHERE Name = 'Main Entity' LIMIT 1];
        breg_Account_Affiliation__c existingAffiliation = [
            SELECT Id, breg_Account__c, breg_Entity_Name__c
            FROM breg_Account_Affiliation__c
            LIMIT 1
        ];
        String originalName = existingAffiliation.breg_Entity_Name__c;
        Map<Id, breg_Account_Affiliation__c> oldMap = new Map<Id, breg_Account_Affiliation__c>{
            existingAffiliation.Id => new breg_Account_Affiliation__c(
                Id = existingAffiliation.Id,
                breg_Account__c = existingAffiliation.breg_Account__c
            )
        };
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(
            new List<breg_Account_Affiliation__c>{ existingAffiliation },
            oldMap
        );
        Assert.areEqual(originalName, existingAffiliation.breg_Entity_Name__c, 'Unchanged account lookup should skip population');

        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(
            new List<breg_Account_Affiliation__c>{ new breg_Account_Affiliation__c() }
        );

        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(breg_Account__c = entity.Id);
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(new List<breg_Account_Affiliation__c>{ affiliation });
        Assert.areEqual('Main Entity', affiliation.breg_Entity_Name__c, 'Existing account should populate affiliation entity name');
    }

    @IsTest
    static void testUpdateMemberAddressesFromAffiliations() {
        Case mainCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                CaseNumber,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Account existingMemberAccount = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingStateCode, BillingPostalCode, BillingCountryCode
            FROM Account
            WHERE Name = 'Existing Member Account'
            LIMIT 1
        ];

        Map<Id, Case> memberCaseMap = new Map<Id, Case>{
            existingMemberAccount.Id => mainCase
        };

        Test.startTest();
        BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
            memberCaseMap,
            new List<Case>{ mainCase }
        );
        Test.stopTest();

        Account updatedMemberAccount = [
            SELECT Id, BillingStreet, BillingCity
            FROM Account
            WHERE Id = :existingMemberAccount.Id
            LIMIT 1
        ];
        // The member Account address is no longer touched; the change lives on the affiliation
        // and on the transaction address history.
        System.assertEquals('Old Street', updatedMemberAccount.BillingStreet, 'Member Account address should be left untouched.');
        System.assertEquals('Old City', updatedMemberAccount.BillingCity, 'Member Account address should be left untouched.');

        Account newMemberAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Brand New Member LLC'
            LIMIT 1
        ];
        System.assertNotEquals(null, newMemberAccount.Id);

        List<breg_Account_Affiliation__c> updatedAffs = [
            SELECT Id, breg_Account__c, breg_Status__c, breg_Start_Date__c, breg_Entity_Name__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :mainCase.Id
            ORDER BY CreatedDate ASC
        ];
        System.assert(!updatedAffs.isEmpty(), 'Affiliations should be updated.');

        breg_Account_Affiliation__c oldAff = [
            SELECT Id, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__r.Subject = :OLD_SUBJECT
            LIMIT 1
        ];
        System.assertEquals('I', oldAff.breg_Status__c);
        System.assertNotEquals(null, oldAff.breg_End_Date__c);
    }

    @IsTest
    static void testUpdateMemberAddressesFromAffiliations_detectsChangeEvenWhenMemberCaseMapMissesTarget() {
        Case mainCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_File_Suffix__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                CaseNumber,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Account existingMemberAccount = [
            SELECT Id, Name, BillingStreet, BillingCity
            FROM Account
            WHERE Name = 'Existing Member Account'
            LIMIT 1
        ];

        // Empty map simulates memberCaseMap not surfacing this member at all.
        Map<Id, Case> memberCaseMap = new Map<Id, Case>();

        Test.startTest();
        BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
            memberCaseMap,
            new List<Case>{ mainCase }
        );
        Test.stopTest();

        Account updatedMemberAccount = [
            SELECT Id, BillingStreet, BillingCity
            FROM Account
            WHERE Id = :existingMemberAccount.Id
            LIMIT 1
        ];
        System.assertEquals(
            'Old Street',
            updatedMemberAccount.BillingStreet,
            'Member Account address should be left untouched.'
        );
        System.assertEquals('Old City', updatedMemberAccount.BillingCity, 'Member Account address should be left untouched.');
    }

    @IsTest
    static void testUpdateMemberAddressesFromAffiliations_skipsWhenAddressMatchesPreviousAffiliation() {
        Case mainCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_File_Suffix__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                CaseNumber,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Account existingMemberAccount = [SELECT Id FROM Account WHERE Name = 'Existing Member Account' LIMIT 1];

        // Keep only the affiliation for the existing member and give it the same address as the
        // entity's previous active affiliation, so nothing actually changed for this member.
        List<breg_Account_Affiliation__c> mainAffiliations = [
            SELECT Id, breg_Account__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :mainCase.Id
        ];
        breg_Account_Affiliation__c unchangedAff;
        List<breg_Account_Affiliation__c> toDelete = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c aff : mainAffiliations) {
            if (aff.breg_Account__c == existingMemberAccount.Id) {
                unchangedAff = aff;
            } else {
                toDelete.add(aff);
            }
        }
        delete toDelete;

        unchangedAff.breg_Address__Street__s = 'Old Street';
        unchangedAff.breg_Address__City__s = 'Old City';
        unchangedAff.breg_Address__StateCode__s = 'DE';
        unchangedAff.breg_Address__PostalCode__s = '19901';
        unchangedAff.breg_Address__CountryCode__s = 'US';
        unchangedAff.breg_Bypass_Validation_Token__c = Datetime.now();
        update unchangedAff;

        Test.startTest();
        BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
            new Map<Id, Case>{ existingMemberAccount.Id => mainCase },
            new List<Case>{ mainCase }
        );
        Test.stopTest();

        breg_Account_Affiliation__c previousAff = [
            SELECT Id, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__r.Subject = :OLD_SUBJECT
            LIMIT 1
        ];
        System.assertNotEquals(
            'I',
            previousAff.breg_Status__c,
            'Previous affiliation should stay active when the filed address is unchanged.'
        );
        System.assertEquals(null, previousAff.breg_End_Date__c, 'Previous affiliation should not be end-dated.');

        Integer transAddressCount = [
            SELECT COUNT()
            FROM breg_Transaction_Address__c
            WHERE breg_Account__c = :mainCase.breg_Entity__c
        ];
        System.assertEquals(0, transAddressCount, 'No transaction address should be created when the address is unchanged.');
    }

    @IsTest
    static void testGetAccountAffiliationCaseMap_and_getMembersCaseMap() {
        List<Case> cases = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
        ];

        Test.startTest();
        Map<Id, Case> allRolesMap = BREGCaseStatusHandlerHelper.getAccountAffiliationCaseMap(cases, true);
        Map<Id, Case> filteredMap = BREGCaseStatusHandlerHelper.getAccountAffiliationCaseMap(
            cases,
            false,
            new List<String>{ 'Officer' }
        );
        Map<Id, Case> membersMap = BREGCaseStatusHandlerHelper.getMembersCaseMap(cases);
        Test.stopTest();

        System.assert(allRolesMap.size() >= 2, 'Expected account/contact affiliations to be returned.');
        System.assert(filteredMap.size() >= 1, 'Expected at least Officer affiliation.');
        System.assert(membersMap.size() >= 1, 'Expected wrapper method to return affiliations.');
    }

    @IsTest
    static void testGetChangedFields_and_getFieldsFromFieldSet() {
        Account oldAcc = new Account(
            Name = 'Old Name',
            BillingCity = 'Old City'
        );
        Account newAcc = new Account(
            Name = 'New Name',
            BillingCity = 'Old City'
        );

        Set<String> changedFields = BREGCaseStatusHandlerHelper.getChangedFields(
            oldAcc,
            newAcc,
            new List<String>{ 'Name', 'BillingCity' }
        );
        System.assert(changedFields.contains('Name'));
        System.assert(!changedFields.contains('BillingCity'));

        Set<String> allChangedFields = BREGCaseStatusHandlerHelper.getChangedFields(
            null,
            newAcc,
            new List<String>{ 'Name', 'BillingCity' }
        );
        System.assertEquals(2, allChangedFields.size());

        List<String> existingFieldSetFields = BREGCaseStatusHandlerHelper.getFieldsFromFieldSet(
            'Account',
            'BREG_TBI_Fields_Set'
        );
        System.assertNotEquals(null, existingFieldSetFields);

        List<String> missingFieldSetFields = BREGCaseStatusHandlerHelper.getFieldsFromFieldSet(
            'Account',
            'Missing_Field_Set'
        );
        System.assertEquals(0, missingFieldSetFields.size());
    }

    @IsTest
    static void testPopulateAffiliationEntityFieldsFromEntity_populatesFromEntity() {
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Entity_Name__c = 'Old Name',
            breg_Entity_Type__c = 'Other',
            breg_Entity_Type_Description__c = 'Old Description',
            breg_Suffix__c = 'OL',
            breg_File__c = '1111111',
            breg_Number_of_shares__c = 10
        );

        Account entity = new Account(
            Name = 'Mapped Entity Name',
            breg_Entity_Type__c = 'D1',
            breg_Entity_Type_Description__c = 'Domestic Corporation',
            breg_File_Suffix__c = 'D1',
            breg_File__c = '7654321',
            breg_Authorized_Shares_Count__c = 500,
            breg_Formation_Country__c = 'US',
            breg_Formation_Country_Label__c = 'United States',
            breg_Formation_State__c = 'HI',
            breg_Formation_State_Label__c = 'Hawaii'
        );

        BREGCaseStatusHandlerHelper.populateAffiliationEntityFieldsFromEntity(affiliation, entity);

        System.assertEquals('Mapped Entity Name', affiliation.breg_Entity_Name__c);
        System.assertEquals('Corporation', affiliation.breg_Entity_Type__c);
        System.assertEquals('Domestic Corporation', affiliation.breg_Entity_Type_Description__c);
        System.assertEquals('D1', affiliation.breg_Suffix__c);
        System.assertEquals('7654321', affiliation.breg_File__c);
        System.assertEquals(500, affiliation.breg_Number_of_shares__c);
        System.assertEquals('United States, Hawaii', affiliation.breg_Entity_Location__c);
    }

    @IsTest
    static void testPopulateAffiliationEntityFieldsFromEntity_preservesExistingAffiliationValuesWhenEntityMissingThem() {
        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Entity_Type_Description__c = 'Existing Description',
            breg_Suffix__c = 'EX',
            breg_File__c = '9999999',
            breg_Number_of_shares__c = 33,
            breg_Entity_Location__c = 'Keep Existing Location'
        );

        Account entity = new Account(
            Name = 'Partnership Entity',
            breg_Entity_Type__c = 'G5'
        );

        BREGCaseStatusHandlerHelper.populateAffiliationEntityFieldsFromEntity(affiliation, entity);

        System.assertEquals('Partnership', affiliation.breg_Entity_Type__c);
        System.assertEquals('G5', affiliation.breg_Entity_Type_Description__c);
        System.assertEquals('EX', affiliation.breg_Suffix__c);
        System.assertEquals('9999999', affiliation.breg_File__c);
        System.assertEquals(33, affiliation.breg_Number_of_shares__c);
        System.assertEquals('Keep Existing Location', affiliation.breg_Entity_Location__c);
    }

    @IsTest
    static void testGetGeneralEntityTypeAndLocationFallbacks() {
        Assert.areEqual('Limited Liability Company', BREGCaseStatusHandlerHelper.getGeneralEntityType('C5'));
        Assert.areEqual('Limited Liability Partnership', BREGCaseStatusHandlerHelper.getGeneralEntityType('K5'));
        Assert.areEqual('Unincorporated Association', BREGCaseStatusHandlerHelper.getGeneralEntityType('Unincorporated Association'));
        Assert.areEqual('Other', BREGCaseStatusHandlerHelper.getGeneralEntityType('ZZ'));

        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c();
        Account entity = new Account(
            Name = 'Fallback Location Entity',
            breg_Entity_Type__c = 'C5',
            breg_Formation_Country__c = 'US',
            breg_Formation_State__c = 'HI'
        );
        BREGCaseStatusHandlerHelper.populateAffiliationEntityFieldsFromEntity(affiliation, entity);
        Assert.areEqual('US, HI', affiliation.breg_Entity_Location__c);
        Assert.areEqual('Limited Liability Company', affiliation.breg_Entity_Type__c);
        Assert.areEqual('C5', affiliation.breg_Entity_Type_Description__c);
    }

    @IsTest
    static void testCreateBusinessInfoLogsAndUpdate_minimal() {
        Case mainCase = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Account entity = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :mainCase.breg_Entity__c
            LIMIT 1
        ];

        entity.Name = 'Main Entity Updated';

        Test.startTest();
        BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(
            new List<Account>{ entity },
            new Map<Id, Set<String>>{
                entity.Id => new Set<String>()
            },
            new Map<Id, Case>{
                entity.Id => mainCase
            }
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :entity.Id
            LIMIT 1
        ];
        System.assertEquals('Main Entity Updated', refreshed.Name);
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

    @IsTest
    static void testUpdateMemberAddressesFromAffiliations_createsNewAccountAndContactForExistingAccountAffiliations() {
        Case mainCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                CaseNumber,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Id bregAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account sourceEntityAffAccount = new Account(
            Name = 'Old Entity Member Name',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            BillingStreet = '1 Old St',
            BillingCity = 'Oldtown',
            BillingStateCode = 'DE',
            BillingPostalCode = '19901',
            BillingCountryCode = 'US'
        );

        Account sourceIndividualAffAccount = new Account(
            Name = 'Old Individual Holder',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Type__c = 'ZZ',
            BillingStreet = '2 Old St',
            BillingCity = 'Oldtown',
            BillingStateCode = 'DE',
            BillingPostalCode = '19901',
            BillingCountryCode = 'US'
        );

        insert new List<Account>{ sourceEntityAffAccount, sourceIndividualAffAccount };

        breg_Account_Affiliation__c entityAff = new breg_Account_Affiliation__c(
            breg_Case__c = mainCase.Id,
            breg_Entity__c = mainCase.breg_Entity__c,
            breg_Account__c = sourceEntityAffAccount.Id,
            breg_Type__c = 'Entity',
            breg_Role__c = 'Officer',
            breg_Entity_Name__c = 'Renamed Entity Member LLC',
            breg_Address__Street__s = '100 New Entity St',
            breg_Address__City__s = 'Dover',
            breg_Address__StateCode__s = 'DE',
            breg_Address__PostalCode__s = '19904',
            breg_Address__CountryCode__s = 'US'
        );

        breg_Account_Affiliation__c individualAff = new breg_Account_Affiliation__c(
            breg_Case__c = mainCase.Id,
            breg_Entity__c = mainCase.breg_Entity__c,
            breg_Account__c = sourceIndividualAffAccount.Id,
            breg_Type__c = 'Individual',
            breg_Role__c = 'Officer',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '200 New Contact St',
            breg_Address__City__s = 'Wilmington',
            breg_Address__StateCode__s = 'DE',
            breg_Address__PostalCode__s = '19801',
            breg_Address__CountryCode__s = 'US'
        );

        insert new List<breg_Account_Affiliation__c>{ entityAff, individualAff };

        Map<Id, Case> memberCaseMap = new Map<Id, Case>{
            sourceEntityAffAccount.Id => mainCase,
            sourceIndividualAffAccount.Id => mainCase
        };

        Test.startTest();
        BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
            memberCaseMap,
            new List<Case>{ mainCase }
        );
        Test.stopTest();

        Account createdEntityMember = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Renamed Entity Member LLC'
            LIMIT 1
        ];
        System.assertNotEquals(null, createdEntityMember.Id);

        Contact createdIndividualMember = [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE FirstName = 'Jane' AND LastName = 'Doe'
            LIMIT 1
        ];
        System.assertNotEquals(null, createdIndividualMember.Id);
    }

    @IsTest
    static void testUpdateMemberAddressesFromAffiliations_createsRecordsFromExistingContactAffiliations() {
        Case mainCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                CaseNumber,
                breg_Received_Date_Formula__c,
                breg_TN_TM_SM__c
            FROM Case
            WHERE Subject = :MAIN_SUBJECT
            LIMIT 1
        ];

        Contact entitySourceContact = new Contact(
            FirstName = 'Entity',
            LastName = 'Source',
            MailingStreet = '1 Old St',
            MailingCity = 'Oldtown',
            MailingStateCode = 'DE',
            MailingPostalCode = '19901',
            MailingCountryCode = 'US'
        );

        Contact individualSourceContact = new Contact(
            FirstName = 'Old',
            LastName = 'Person',
            MailingStreet = '2 Old St',
            MailingCity = 'Oldtown',
            MailingStateCode = 'DE',
            MailingPostalCode = '19901',
            MailingCountryCode = 'US'
        );

        insert new List<Contact>{ entitySourceContact, individualSourceContact };

        breg_Account_Affiliation__c contactEntityAff = new breg_Account_Affiliation__c(
            breg_Case__c = mainCase.Id,
            breg_Entity__c = mainCase.breg_Entity__c,
            breg_Contact__c = entitySourceContact.Id,
            breg_Type__c = 'Entity',
            breg_Role__c = 'Officer',
            breg_Entity_Name__c = 'Created From Contact Entity',
            breg_Address__Street__s = '100 Entity St',
            breg_Address__City__s = 'Dover',
            breg_Address__StateCode__s = 'DE',
            breg_Address__PostalCode__s = '19904',
            breg_Address__CountryCode__s = 'US'
        );

        breg_Account_Affiliation__c contactIndividualAff = new breg_Account_Affiliation__c(
            breg_Case__c = mainCase.Id,
            breg_Entity__c = mainCase.breg_Entity__c,
            breg_Contact__c = individualSourceContact.Id,
            breg_Type__c = 'Individual',
            breg_Role__c = 'Officer',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '200 Contact St',
            breg_Address__City__s = 'Wilmington',
            breg_Address__StateCode__s = 'DE',
            breg_Address__PostalCode__s = '19801',
            breg_Address__CountryCode__s = 'US'
        );

        insert new List<breg_Account_Affiliation__c>{ contactEntityAff, contactIndividualAff };

        Map<Id, Case> memberCaseMap = new Map<Id, Case>{
            entitySourceContact.Id => mainCase,
            individualSourceContact.Id => mainCase
        };

        Test.startTest();
        BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
            memberCaseMap,
            new List<Case>{ mainCase }
        );
        Test.stopTest();

        Account createdAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Created From Contact Entity'
            LIMIT 1
        ];
        System.assertNotEquals(null, createdAccount.Id);

        Contact createdContact = [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE FirstName = 'Jane' AND LastName = 'Doe'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertNotEquals(null, createdContact.Id);
    }
}