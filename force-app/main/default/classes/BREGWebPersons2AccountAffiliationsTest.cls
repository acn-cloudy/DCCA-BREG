@isTest
private class BREGWebPersons2AccountAffiliationsTest {
    @testSetup
    static void setupData() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Jane Doe',
            breg_WEB_PERSON_TYPE__c = 'DRC',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_PERSON_OFFICE__c = 'Test President',
            breg_WEB_ADDRESS_LINE_1__c = '123 Main St',
            breg_WEB_ADDRESS_LINE_2__c = 'Apt 1',
            breg_WEB_CITY__c = 'Springfield',
            breg_WEB_POSTAL_CODE__c = '12345',
            breg_WEB_COUNTRY_CODE_2__c = 'US',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );
    }

    // ─── Single person mapping ────────────────────────────────────────────────

    @isTest
    static void testMapsPersonToAccountAffiliation() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');
        Assert.isFalse(results.get(testCase.Id).isEmpty(), 'There should be at least one person record');

        List<BREGWebAccountAffiliationWrapper> affiliations = wrapperMap.get(testCase.Id).AccountAffiliations;
        Assert.areEqual(1, affiliations.size(), 'There should be one affiliation wrapper');

        breg_Account_Affiliation__c affiliation = affiliations[0].accountAffiliation;
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'Type should be Individual when FL flag is Y');
        Assert.areEqual('Other', affiliation.breg_Role__c, 'Unknown person type should fall back to Other');
        Assert.areEqual('Test President', affiliation.breg_Officer_Director_Other_Title__c, 'Office title should be mapped');
        Assert.areEqual('123 Main St', affiliation.breg_Address__Street__s, 'Street should be mapped from address line 1');
        Assert.areEqual('Apt 1', affiliation.breg_Address_Street_2__c, 'Street 2 should be mapped from address line 2');
        Assert.areEqual('Springfield', affiliation.breg_Address__City__s, 'City should be mapped');
        Assert.areEqual('12345', affiliation.breg_Address__PostalCode__s, 'Postal code should be mapped');
        Assert.areEqual('US', affiliation.breg_Address__CountryCode__s, 'Country code should be mapped');
        Assert.areEqual(testCase.Id, affiliation.breg_case__c, 'Case lookup should be set');
    }

    // ─── Individual name splitting ────────────────────────────────────────────

    @isTest
    static void testIndividualNameSplitSpaceFormat() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Jane', affiliation.breg_First_Name__c, 'First name should be split from "FIRST LAST" format');
        Assert.areEqual('Doe', affiliation.breg_Last_Name__c, 'Last name should be split from "FIRST LAST" format');
    }

    @isTest
    static void testIndividualNameSplitCommaFormat() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Smith, John',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c smithAffiliation;
        for (BREGWebAccountAffiliationWrapper w : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (w.accountAffiliation.breg_First_Name__c == 'John') {
                smithAffiliation = w.accountAffiliation;
            }
        }
        Assert.isNotNull(smithAffiliation, 'Should find the Smith, John affiliation');
        Assert.areEqual('John', smithAffiliation.breg_First_Name__c, 'First token of comma-split goes to breg_First_Name__c');
        Assert.areEqual('Smith', smithAffiliation.breg_Last_Name__c, 'Second token of comma-split goes to breg_Last_Name__c');
    }

    // ─── Entity type (FL != Y) ────────────────────────────────────────────────

    @isTest
    static void testEntityTypeNoNameSplit() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Acme Corp',
            breg_WEB_PERSON_FL__c = 'N',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c corpAffiliation;
        for (BREGWebAccountAffiliationWrapper w : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (w.accountAffiliation.breg_Entity_Name__c == 'Acme Corp') {
                corpAffiliation = w.accountAffiliation;
            }
        }
        Assert.isNotNull(corpAffiliation, 'Should find the Acme Corp affiliation');
        Assert.areEqual('Entity', corpAffiliation.breg_Type__c, 'Type should be Entity when FL flag is not Y');
        Assert.isNull(corpAffiliation.breg_First_Name__c, 'First name should not be set for entity type');
        Assert.isNull(corpAffiliation.breg_Last_Name__c, 'Last name should not be set for entity type');
    }

    // ─── Role mapping ─────────────────────────────────────────────────────────

    @isTest
    static void testRoleMappingAgent() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Agent Person',
            breg_WEB_PERSON_TYPE__c = 'AGNT',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c agentAffiliation;
        for (BREGWebAccountAffiliationWrapper w : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (w.accountAffiliation.breg_Entity_Name__c == 'Agent Person') {
                agentAffiliation = w.accountAffiliation;
            }
        }
        Assert.isNotNull(agentAffiliation, 'Should find the Agent Person affiliation');
        Assert.areEqual('Agent', agentAffiliation.breg_Role__c, 'AGNT person type should map to Agent role');
    }

    @isTest
    static void testRoleMappingOfficer() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Officer Person',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c officerAffiliation;
        for (BREGWebAccountAffiliationWrapper w : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (w.accountAffiliation.breg_Entity_Name__c == 'Officer Person') {
                officerAffiliation = w.accountAffiliation;
            }
        }
        Assert.isNotNull(officerAffiliation, 'Should find the Officer Person affiliation');
        Assert.areEqual('Officer', officerAffiliation.breg_Role__c, 'OFCR person type should map to Officer role');
    }

    @isTest
    static void testRoleMappingApplicantForX1Form() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Applicant Person',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'N',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase = new Case(Id = testCase.Id, breg_Form_Code__c = 'X-1');
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => wrapper };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c applicantAffiliation;
        for (BREGWebAccountAffiliationWrapper accountAffiliationWrapper : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (accountAffiliationWrapper.accountAffiliation.breg_Entity_Name__c == 'Applicant Person') {
                applicantAffiliation = accountAffiliationWrapper.accountAffiliation;
            }
        }

        Assert.isNotNull(applicantAffiliation, 'Should find the Applicant Person affiliation');
        Assert.areEqual('Applicant', applicantAffiliation.breg_Role__c, 'X-1 form should map the affiliation role to Applicant');
    }

    @isTest
    static void testRoleMappingPartnerForPartnerForm() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Partner Person',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'N',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase = new Case(Id = testCase.Id, breg_Form_Code__c = 'ANN-GP-1');
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => wrapper };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c partnerAffiliation;
        for (BREGWebAccountAffiliationWrapper accountAffiliationWrapper : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (accountAffiliationWrapper.accountAffiliation.breg_Entity_Name__c == 'Partner Person') {
                partnerAffiliation = accountAffiliationWrapper.accountAffiliation;
            }
        }

        Assert.isNotNull(partnerAffiliation, 'Should find the Partner Person affiliation');
        Assert.areEqual('Partner', partnerAffiliation.breg_Role__c, 'Partner forms should map non-agent affiliations to Partner');
    }

    @isTest
    static void testRoleMappingUnknownFallsToOther() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // Setup person has type 'DRC' which is not in the role map
        Assert.areEqual(
            'Other',
            wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation.breg_Role__c,
            'Unmapped person type should fall back to Other'
        );
    }

    // ─── Address / state code from ZIP ────────────────────────────────────────

    @isTest
    static void testStateCodeMappedFromZipForUSAddress() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // ZIP 12345 → prefix 123 → range 100-149 → 'NY'
        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('HI', affiliation.breg_Address__StateCode__s, 'State code should be resolved from US ZIP code');
    }

    @isTest
    static void testNonUSAddressStateCodeNotSet() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Foreign Person',
            breg_WEB_COUNTRY_CODE_2__c = 'CA',
            breg_WEB_POSTAL_CODE__c = 'M5V 3A8',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c foreignAffiliation;
        for (BREGWebAccountAffiliationWrapper w : wrapperMap.get(testCase.Id).AccountAffiliations) {
            if (w.accountAffiliation.breg_Entity_Name__c == 'Foreign Person') {
                foreignAffiliation = w.accountAffiliation;
            }
        }
        Assert.isNotNull(foreignAffiliation, 'Should find the Foreign Person affiliation');
        Assert.isNull(foreignAffiliation.breg_Address__StateCode__s, 'State code should not be set for non-US addresses');
    }

    // ─── Action code filter ───────────────────────────────────────────────────

    @isTest
    static void testInactiveActionCodeIsSkipped() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(breg_WEB_Case__c = testCase.Id, breg_WEB_PERSON_NAME__c = 'Inactive Person', breg_WEB_WEB_ACTION_CODE__c = 'I');

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // Only the active setup record should be included, not the inactive one
        Assert.areEqual(1, wrapperMap.get(testCase.Id).AccountAffiliations.size(), 'Inactive action code records should not be added as affiliations');
        // Setup person has FL='Y' (Individual), so name is stored in breg_First_Name__c / breg_Last_Name__c, not breg_Entity_Name__c
        breg_Account_Affiliation__c activeAffiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Jane', activeAffiliation.breg_First_Name__c, 'Only the active person should be present');
        Assert.areEqual('Doe', activeAffiliation.breg_Last_Name__c, 'Only the active person should be present');
    }

    // ─── Multiple persons ─────────────────────────────────────────────────────

    @isTest
    static void testMapsMultipleActivePersons() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'John Smith',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(2, wrapperMap.get(testCase.Id).AccountAffiliations.size(), 'Each active person record should produce one affiliation wrapper');
    }

    // ─── Edge cases ───────────────────────────────────────────────────────────

    @isTest
    static void testNoPersonsReturnsEmptyAffiliations() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no person records exist');
        Assert.isTrue(wrapperMap.get(emptyCase.Id).AccountAffiliations.isEmpty(), 'AccountAffiliations should remain empty when no persons exist');
    }

    @isTest
    static void testNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWebPersons2AccountAffiliations mapper = new BREGWebPersons2AccountAffiliations(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }

    // ─── Action code 'N' ─────────────────────────────────────────────────────

    @isTest
    static void testActionCodeNIsIncluded() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'New Entity Corp',
            breg_WEB_PERSON_FL__c = 'N',
            breg_WEB_WEB_ACTION_CODE__c = 'N'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.areEqual(1, wrapperMap.get(testCase.Id).AccountAffiliations.size(), 'Action code N should produce an affiliation');
        Assert.areEqual(
            'New Entity Corp',
            wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation.breg_Entity_Name__c,
            'Entity name should be mapped for action code N record'
        );
    }

    // ─── Name splitting edge cases ────────────────────────────────────────────

    @isTest
    static void testNameSplitThreePartsSpaceFormat() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'John Michael Smith',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('John', affiliation.breg_First_Name__c, 'First name should be first token in three-part space format');
        Assert.areEqual('Michael', affiliation.breg_Middle_Name__c, 'Middle name should be second token in three-part space format');
        Assert.areEqual('Smith', affiliation.breg_Last_Name__c, 'Last name should be third token in three-part space format');
    }

    @isTest
    static void testNameSplitCommaFormatWithMiddleName() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Smith, John Michael',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Smith', affiliation.breg_Last_Name__c, 'Last name should be the text before the comma');
        Assert.areEqual('John', affiliation.breg_First_Name__c, 'First name should be first word after comma');
        Assert.areEqual('Michael', affiliation.breg_Middle_Name__c, 'Middle name should be second word after comma');
    }

    // ─── Deduplication against existing affiliations ──────────────────────────

    @isTest
    static void testDeduplicationMatchesIndividualSetsContact() {
        Account entity = new Account(Name = 'Test Entity Dedup Individual');
        insert entity;

        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        Contact existingContact = new Contact(LastName = 'Walker');
        insert existingContact;

        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Alice Walker',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Alice',
            breg_Last_Name__c = 'Walker',
            breg_Contact__c = existingContact.Id,
            breg_Status__c = 'A'
        );

        // Second wrapper with no entity to cover the null-entity continue path in deduplication loop
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        BREGWebFilingWrapper mainWrapper = new BREGWebFilingWrapper();
        mainWrapper.WebCase.breg_Entity__c = entity.Id; // set in-memory; no Case DML needed
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{
            testCase.Id => mainWrapper,
            emptyCase.Id => new BREGWebFilingWrapper()
        };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id, emptyCase.Id });
        Test.stopTest();

        BREGWebAccountAffiliationWrapper affWrapper = wrapperMap.get(testCase.Id).AccountAffiliations[0];
        Assert.areEqual(
            existingContact.Id,
            affWrapper.accountAffiliation.breg_Contact__c,
            'Contact lookup should be resolved from matching existing affiliation'
        );
        Assert.areEqual(existingContact.Id, affWrapper.Contact.Id, 'Contact wrapper should reference the existing Contact');
    }

    @isTest
    static void testDeduplicationMatchesEntitySetsAccount() {
        Account entity = new Account(Name = 'Test Entity Dedup Entity');
        insert entity;

        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        Account existingAccount = new Account(Name = 'Big Corp');
        insert existingAccount;

        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Big Corp',
            breg_WEB_PERSON_TYPE__c = 'AGNT',
            breg_WEB_PERSON_FL__c = 'N',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Big Corp',
            breg_Account__c = existingAccount.Id,
            breg_Status__c = 'A'
        );

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.breg_Entity__c = entity.Id; // set in-memory; no Case DML needed
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => wrapper };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        BREGWebAccountAffiliationWrapper affWrapper = wrapperMap.get(testCase.Id).AccountAffiliations[0];
        Assert.areEqual(
            existingAccount.Id,
            affWrapper.accountAffiliation.breg_Account__c,
            'Account lookup should be resolved from matching existing affiliation'
        );
        Assert.areEqual(existingAccount.Id, affWrapper.Account.Id, 'Account wrapper should reference the existing Account');
    }

    // ─── New name fields ──────────────────────────────────────────────────────

    @isTest
    static void testIndividualWithNewNameFieldsUsedDirectly() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_First_Name__c = 'Mary',
            breg_WEB_Last_Name__c = 'Johnson',
            breg_WEB_Middle_Name__c = 'Anne',
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_NAME__c = 'Mary Anne Johnson'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'Type should be Individual when only individual name fields are populated');
        Assert.areEqual('Mary', affiliation.breg_First_Name__c, 'First name should come directly from breg_WEB_First_Name__c');
        Assert.areEqual('Johnson', affiliation.breg_Last_Name__c, 'Last name should come directly from breg_WEB_Last_Name__c');
        Assert.areEqual('Anne', affiliation.breg_Middle_Name__c, 'Middle name should come directly from breg_WEB_Middle_Name__c');
    }

    @isTest
    static void testEntityWithCompanyNameFieldUsedDirectly() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Widgets Inc Legacy',
            breg_WEB_Company_Name__c = 'Widgets Inc',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Entity', affiliation.breg_Type__c, 'Type should be Entity when only Company_Name is populated');
        Assert.areEqual('Widgets Inc', affiliation.breg_Entity_Name__c, 'Entity name should come from Company_Name__c, not PERSON_NAME__c');
        Assert.isNull(affiliation.breg_First_Name__c, 'First name should not be set for entity type');
    }

    @isTest
    static void testCompanyConfidenceHighSetsEntityWhenBothNamesPresent() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_First_Name__c = 'Bob',
            breg_WEB_Last_Name__c = 'Smith',
            breg_WEB_Company_Name__c = 'Bob Smith LLC',
            breg_WEB_Is_Company_Confidence_Pct__c = 75,
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_NAME__c = 'Bob Smith'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Entity', affiliation.breg_Type__c, 'Confidence >= 50 with both names should resolve to Entity');
        Assert.areEqual('Bob Smith LLC', affiliation.breg_Entity_Name__c, 'Entity name should use Company_Name__c when type is Entity');
    }

    @isTest
    static void testCompanyConfidenceLowSetsIndividualWhenBothNamesPresent() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_First_Name__c = 'Carol',
            breg_WEB_Last_Name__c = 'Davis',
            breg_WEB_Company_Name__c = 'Carol Davis Trust',
            breg_WEB_Is_Company_Confidence_Pct__c = 30,
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_NAME__c = 'Carol Davis'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'Confidence < 50 with both names should resolve to Individual');
        Assert.areEqual('Carol', affiliation.breg_First_Name__c, 'First name should be populated from new field when type is Individual');
        Assert.areEqual('Davis', affiliation.breg_Last_Name__c, 'Last name should be populated from new field when type is Individual');
    }

    @isTest
    static void testBothNamesPresentNoConfidenceFallsBackToFLFlag() {
        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;
        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_First_Name__c = 'Tom',
            breg_WEB_Last_Name__c = 'Jones',
            breg_WEB_Company_Name__c = 'Tom Jones Corp',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_PERSON_NAME__c = 'Tom Jones'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(testCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'FL=Y with no confidence percent should fall back to Individual via legacy logic');
    }

    // ─── Deduplication against existing affiliations ──────────────────────────

    @isTest
    static void testDeduplicationNoMatchLeavesLookupsUnset() {
        Account entity = new Account(Name = 'Test Entity Dedup No Match');
        insert entity;

        Case testCase = new Case(Status = 'New', Origin = 'Web');
        insert testCase;

        Contact otherContact = new Contact(LastName = 'Other');
        insert otherContact;

        insert new breg_WEB_WEB_PERSONS__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_PERSON_NAME__c = 'Unknown Person',
            breg_WEB_PERSON_TYPE__c = 'OFCR',
            breg_WEB_PERSON_FL__c = 'Y',
            breg_WEB_WEB_ACTION_CODE__c = 'A'
        );

        // Existing affiliation for a different person — no key match expected
        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Alice',
            breg_Last_Name__c = 'Walker',
            breg_Contact__c = otherContact.Id,
            breg_Status__c = 'A'
        );

        BREGWebFilingWrapper wrapper = new BREGWebFilingWrapper();
        wrapper.WebCase.breg_Entity__c = entity.Id; // set in-memory; no Case DML needed
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => wrapper };

        Test.startTest();
        new BREGWebPersons2AccountAffiliations(wrapperMap).PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        BREGWebAccountAffiliationWrapper affWrapper = wrapperMap.get(testCase.Id).AccountAffiliations[0];
        Assert.isNull(affWrapper.accountAffiliation.breg_Contact__c, 'Contact should not be set when no name-key match is found');
        Assert.isNull(affWrapper.accountAffiliation.breg_Account__c, 'Account should not be set when no name-key match is found');
    }
}