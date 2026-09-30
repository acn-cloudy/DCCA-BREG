@isTest
private class BREGWebFilingInfo2CaseTest {
    private static final String ANNUAL_CASE_SUBJECT = 'Web Filing Info Annual';
    private static final String NAME_CHANGE_CASE_SUBJECT = 'Web Filing Info Name Change';
    private static final String NBR_CASE_SUBJECT = 'Web Filing Info NBR';
    private static final String TNTMSM_CASE_SUBJECT = 'Web Filing Info TNTMSM';
    private static final String ADD_ENTITY_CASE_SUBJECT = 'Web Filing Info ADD Entity';

    @testSetup
    static void setupData() {
        Case annualCase = new Case(Status = 'New', Origin = 'Web', Subject = ANNUAL_CASE_SUBJECT);
        Case nameChangeCase = new Case(Status = 'New', Origin = 'Web', Subject = NAME_CHANGE_CASE_SUBJECT);
        Case nbrCase = new Case(Status = 'New', Origin = 'Web', Subject = NBR_CASE_SUBJECT);
        Case tntmsmCase = new Case(Status = 'New', Origin = 'Web', Subject = TNTMSM_CASE_SUBJECT);
        Case addEntityCase = new Case(Status = 'New', Origin = 'Web', Subject = ADD_ENTITY_CASE_SUBJECT);
        insert new List<Case>{ annualCase, nameChangeCase, nbrCase, tntmsmCase, addEntityCase };

        insert new List<breg_WEB_WEB_FILING_INFO__c>{
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = annualCase.Id,
                breg_WEB_FORM_TYPE__c = 'ANN',
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'North Shore Bakery LLC',
                breg_WEB_FILING_DT__c = Date.newInstance(2026, 2, 14),
                breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 2, 15),
                breg_WEB_RDPMS_WFSCAN_TIME__c = '10:17 AM',
                breg_WEB_SUBMITTER_SIGNATURE__c = 'Morgan Hale',
                breg_WEB_SUBMITTER_NAME__c = 'Morgan Hale',
                breg_WEB_SUBMITTER_TITLE__c = 'Managing Member',
                breg_WEB_RDPMS_WFNO_CHANGE__c = '1',
                breg_WEB_RDPMS_WFYEAR__c = '2025'
            ),
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = nameChangeCase.Id,
                breg_WEB_FORM_TYPE__c = 'DC2',
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Island Robotics Corporation',
                breg_WEB_RDPMS_WFNEW_NAME__c = 'Island Robotics Pacific Corporation',
                breg_WEB_FILING_DT__c = Date.newInstance(2026, 3, 3),
                breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 3, 4),
                breg_WEB_SUBMITTER_NAME__c = 'Casey Rowan',
                breg_WEB_SUBMITTER_SIGNATURE__c = 'Casey Rowan'
            ),
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = nbrCase.Id,
                breg_WEB_FORM_TYPE__c = 'DC1',
                breg_WEB_RDPMS_WFBATCH_TYPE__c = 'NBR',
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Harbor Ridge Consulting Inc.',
                breg_WEB_FILING_DT__c = Date.newInstance(2026, 2, 18),
                breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 2, 19),
                breg_WEB_SUBMITTER_NAME__c = 'Jordan Ames',
                breg_WEB_CONTACT_NAME__c = 'Jordan Ames',
                breg_WEB_RDPMS_WFEXP_REG1__c = 'E'
            ),
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = tntmsmCase.Id,
                breg_WEB_FORM_TYPE__c = 'T1',
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Blue Wave Ventures LLC',
                breg_WEB_RDPMS_WFNEW_NAME__c = 'Blue Wave Market',
                breg_WEB_FILING_DT__c = Date.newInstance(2026, 4, 5),
                breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 4, 6),
                breg_WEB_SUBMITTER_NAME__c = 'Taylor Brooks'
            ),
            new breg_WEB_WEB_FILING_INFO__c(
                breg_WEB_Case__c = addEntityCase.Id,
                breg_WEB_FORM_TYPE__c = 'ADD',
                breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Acrofest Entity Name',
                breg_WEB_RDPMS_WFNEW_NAME__c = 'Acrofest New Trade Name',
                breg_WEB_FILING_DT__c = Date.newInstance(2026, 4, 20),
                breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 4, 21),
                breg_WEB_SUBMITTER_NAME__c = 'Taylor Brooks'
            )
        };

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = addEntityCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'MAIL',
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_ADDRESS_LINE_1__c = '123 Entity St',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_OTHER_LOCALITY__c = 'HI',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );
    }

    @isTest
    static void testMapsAnnualFilingInfoToCaseWrapper() {
        Case annualCase = [SELECT Id FROM Case WHERE Subject = :ANNUAL_CASE_SUBJECT LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ annualCase.Id => new BREGWebFilingWrapper() };
        Account entityAccount = BREGTestDataFactory.createEntityAccounts(1)[0];
        breg_Annual__c annual = new breg_Annual__c(breg_Account__c = entityAccount.Id, breg_Filing_Year__c = '2025');
        insert annual;
        wrapperMap.get(annualCase.Id).WebCase.breg_Entity__c = entityAccount.Id;

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ annualCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(annualCase.Id), 'Result map should contain the case ID key');
        Assert.areEqual(1, results.get(annualCase.Id).size(), 'Annual case should have one filing info record');

        Case mappedCase = wrapperMap.get(annualCase.Id).WebCase;
        Assert.areEqual('North Shore Bakery LLC', mappedCase.breg_Name_of_the_Entity__c, 'Entity name should map for non-TNTMSM forms');
        Assert.areEqual(Datetime.newInstanceGmt(2026, 2, 14, 10, 0, 0), mappedCase.breg_Filing_Date__c, 'Filing date should map as Hawaii datetime');
        Assert.areEqual(
            Datetime.newInstanceGmt(2026, 2, 15, 20, 17, 0),
            mappedCase.breg_Submission_Date__c,
            'Submission date should map using Hawaii scan time converted to GMT'
        );
        Assert.areEqual('Morgan Hale', mappedCase.breg_Signature__c, 'Signature should map from filing info');
        Assert.areEqual('Morgan Hale', mappedCase.breg_Signed_By_Name__c, 'Submitter name should map to signed by name');
        Assert.areEqual('Managing Member', mappedCase.breg_Signed_By_Title_Text__c, 'Submitter title should map to signed by title');
        Assert.areEqual('Individual', mappedCase.breg_Signed_By__c, 'Signed by should be Individual when signature equals submitter name');
        Assert.areEqual('Morgan', mappedCase.breg_Signed_By_First_Name__c, 'First name should be first token from submitter name');
        Assert.areEqual('Hale', mappedCase.breg_Signed_By_Last_Name__c, 'Last name should be the remainder of submitter name after first space');
        Assert.isNull(mappedCase.breg_Signed_By_Entity_Name__c, 'Entity name should be blank for Individual signer type');
        Assert.areEqual(true, mappedCase.breg_No_Changes__c, 'No changes flag should map when the source value is 1');
        Assert.isNull(
            mappedCase.breg_Annual_Report_Filing_Year__c,
            'Annual report filing year should remain null when this mapper no longer populates it'
        );
        Assert.areEqual(annual.Id, mappedCase.breg_Annual__c, 'Annual lookup should populate when account, year, and barcode match');
        Assert.areEqual('Normal', mappedCase.breg_Processing_Speed__c, 'Processing speed should be Normal when WFEXP_REG1 is null');
    }

    @isTest
    static void testGetAnnualsByAccountsAndYearsReturnsMatchesByCompositeKey() {
        List<Account> entityAccounts = BREGTestDataFactory.createEntityAccounts(2);
        List<breg_Annual__c> annuals = new List<breg_Annual__c>{
            new breg_Annual__c(breg_Account__c = entityAccounts[0].Id, breg_Filing_Year__c = '2024'),
            new breg_Annual__c(breg_Account__c = entityAccounts[1].Id, breg_Filing_Year__c = '2025')
        };
        insert annuals;

        Test.startTest();
        Map<String, breg_Annual__c> annualsByKey = BREGWebFilingInfo2Case.getAnnualsByAccountsAndYears(
            new List<String>{ entityAccounts[0].Id, entityAccounts[1].Id },
            new List<String>{ '2024', '2025' }
        );
        Test.stopTest();

        Assert.areEqual(2, annualsByKey.size(), 'Method should return one result per matching account/year pair');
        Assert.areEqual(annuals[0].Id, annualsByKey.get(entityAccounts[0].Id + '_2024').Id, 'First annual should be keyed by account and year');
        Assert.areEqual(annuals[1].Id, annualsByKey.get(entityAccounts[1].Id + '_2025').Id, 'Second annual should be keyed by account and year');
        Assert.isNull(annualsByKey.get(entityAccounts[0].Id + '_2025'), 'Method should not create keys for unmatched year combinations');
    }

    @isTest
    static void testMapsEntityNameChangeFields() {
        Case nameChangeCase = [SELECT Id FROM Case WHERE Subject = :NAME_CHANGE_CASE_SUBJECT LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ nameChangeCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ nameChangeCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(nameChangeCase.Id).WebCase;
        Assert.areEqual('Island Robotics Corporation', mappedCase.breg_Name_of_the_Entity__c, 'Entity name should still map for DC2 filings');
        Assert.areEqual(
            'Island Robotics Pacific Corporation',
            mappedCase.breg_New_Entity_Name__c,
            'New entity name should map from WFNEW_COMPANY_NAME for entity change forms'
        );
        Assert.areEqual(
            Datetime.newInstanceGmt(2026, 3, 3, 10, 0, 0),
            mappedCase.breg_Filing_Date__c,
            'Filing date should still map as Hawaii datetime for name change forms'
        );
        Assert.areEqual(
            Datetime.newInstanceGmt(2026, 3, 4, 10, 0, 0),
            mappedCase.breg_Submission_Date__c,
            'Submission date should still map as Hawaii datetime for name change forms'
        );
    }

    @isTest
    static void testMapsNbrRegistrationLikeStandardEntityForm() {
        Case nbrCase = [SELECT Id FROM Case WHERE Subject = :NBR_CASE_SUBJECT LIMIT 1];
        Contact matchedContact = new Contact(FirstName = 'Jordan', LastName = 'Ames', Email = 'jordan.ames@example.com');
        insert matchedContact;

        breg_WEB_WEB_FILING_INFO__c nbrFilingInfo = [
            SELECT Id
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c = :nbrCase.Id
            LIMIT 1
        ];
        nbrFilingInfo.breg_WEB_CONTACT_EMAIL__c = 'JORDAN.AMES@EXAMPLE.COM';
        update nbrFilingInfo;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ nbrCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ nbrCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(nbrCase.Id), 'Result map should contain the NBR case ID key');
        Assert.areEqual(1, results.get(nbrCase.Id).size(), 'NBR case should have one filing info record');

        Case mappedCase = wrapperMap.get(nbrCase.Id).WebCase;
        Assert.areEqual('Harbor Ridge Consulting Inc.', mappedCase.breg_Name_of_the_Entity__c, 'NBR forms should map company name to entity name');
        Assert.areEqual(Datetime.newInstanceGmt(2026, 2, 18, 10, 0, 0), mappedCase.breg_Filing_Date__c, 'NBR filing date should map as Hawaii datetime');
        Assert.areEqual(
            Datetime.newInstanceGmt(2026, 2, 19, 10, 0, 0),
            mappedCase.breg_Submission_Date__c,
            'NBR submission date should map as Hawaii datetime'
        );
        Assert.areEqual('Jordan Ames', mappedCase.breg_Signed_By_Name__c, 'NBR submitter name should map to signed by name');
        Assert.isNull(mappedCase.breg_Signature__c, 'Signature should remain null when the source signature is blank');
        Assert.areEqual('Individual', mappedCase.breg_Signed_By__c, 'Signed by should be Individual when signature is blank');
        Assert.areEqual('Jordan', mappedCase.breg_Signed_By_First_Name__c, 'First name should be first token from submitter name when signature is blank');
        Assert.areEqual('Ames', mappedCase.breg_Signed_By_Last_Name__c, 'Last name should be remainder of submitter name when signature is blank');
        Assert.isNull(mappedCase.breg_Signed_By_Entity_Name__c, 'Entity name should be blank for Individual signer type');
        Assert.areEqual(false, mappedCase.breg_No_Changes__c, 'No changes flag should be false when the source value is blank');
        Assert.isNull(mappedCase.breg_Annual_Report_Filing_Year__c, 'Annual report filing year should remain null when the source year is blank');
        Assert.isNull(mappedCase.breg_New_Entity_Name__c, 'NBR forms should not map new entity name in this mapper');
        Assert.areEqual(matchedContact.Id, mappedCase.ContactId, 'Contact should map when name and email match exactly after normalization');
        Assert.areEqual('Expedited', mappedCase.breg_Processing_Speed__c, 'Processing speed should be Expedited when WFEXP_REG1 is not null and not R');
    }

    @isTest
    static void testX1ExpirationDateUsesEffectiveDatePlus120Days() {
        Case x1Case = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info X1 Expiration');
        insert x1Case;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = x1Case.Id,
            breg_WEB_FORM_TYPE__c = 'X1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Reserved Name LLC',
            breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 1, 15)
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ x1Case.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebFilingInfo2Case(wrapperMap).PrepareData(new Set<String>{ x1Case.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(x1Case.Id).WebCase;
        Assert.areEqual(Date.newInstance(2026, 1, 15), mappedCase.breg_Effective_Date__c, 'Effective date should still map from submission date');
        Assert.areEqual(
            Date.newInstance(2026, 5, 15),
            mappedCase.breg_Expiration_Date__c,
            'X1 expiration date should be the effective date plus 120 days without Hawaii timezone conversion'
        );
    }

    @isTest
    static void testDoesNotMapContactWhenNameAndEmailAreAmbiguous() {
        Case ambiguousContactCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Ambiguous Contact');
        insert ambiguousContactCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = ambiguousContactCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Harbor Ridge Consulting Inc.',
            breg_WEB_CONTACT_NAME__c = 'Harbor Compliance',
            breg_WEB_CONTACT_EMAIL__c = 'corporate@harborcompliance.com'
        );

        insert new List<Contact>{
            new Contact(FirstName = 'Harbor', LastName = 'Compliance', Email = 'corporate@harborcompliance.com'),
            new Contact(FirstName = 'Harbor', LastName = 'Compliance', Email = 'corporate@harborcompliance.com')
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ ambiguousContactCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ ambiguousContactCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(ambiguousContactCase.Id).WebCase;
        Assert.isNull(mappedCase.ContactId, 'Contact should remain null when multiple contacts have the same normalized name and email');
    }

    @isTest
    static void testDoesNotMapContactWhenEmailIsMissing() {
        Case noEmailCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info No Email');
        insert noEmailCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = noEmailCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Test Company Inc.',
            breg_WEB_CONTACT_NAME__c = 'John Smith'
        );

        insert new Contact(FirstName = 'John', LastName = 'Smith', Email = 'john.smith@example.com');

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ noEmailCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ noEmailCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(noEmailCase.Id).WebCase;
        Assert.isNull(mappedCase.ContactId, 'Contact should remain null when filing info has no email address');
    }

    @isTest
    static void testExpeditedFlagWhenWfexp() {
        Case expeditedCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Expedited');
        insert expeditedCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = expeditedCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Test Corp Inc.',
            breg_WEB_FILING_DT__c = Date.newInstance(2026, 5, 1),
            breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 5, 2),
            breg_WEB_RDPMS_WFEXP_REG1__c = 'E'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ expeditedCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ expeditedCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(expeditedCase.Id).WebCase;
        Assert.areEqual('Expedited', mappedCase.breg_Processing_Speed__c, 'Processing speed should be Expedited when WFEXP_REG1 is E');
    }

    @isTest
    static void testExpeditedFlagFalseWhenWfexpIsR() {
        Case notExpeditedCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Not Expedited');
        insert notExpeditedCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = notExpeditedCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Test Corp Inc.',
            breg_WEB_FILING_DT__c = Date.newInstance(2026, 5, 1),
            breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 5, 2),
            breg_WEB_RDPMS_WFEXP_REG1__c = 'R'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ notExpeditedCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ notExpeditedCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(notExpeditedCase.Id).WebCase;
        Assert.areEqual('Normal', mappedCase.breg_Processing_Speed__c, 'Processing speed should be Normal when WFEXP_REG1 is R');
    }

    @isTest
    static void testMapsTntmsmFormWithoutEntityName() {
        Case tntmsmCase = [SELECT Id FROM Case WHERE Subject = :TNTMSM_CASE_SUBJECT LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ tntmsmCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ tntmsmCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(tntmsmCase.Id).WebCase;
        Assert.isNull(mappedCase.breg_Name_of_the_Entity__c, 'Entity name should not map for TNTMSM forms');
        Assert.isNull(mappedCase.breg_New_Entity_Name__c, 'New entity name should remain null for TNTMSM forms');
    }

    @isTest
    static void testMapsT4DescriptionFromNewCompanyName() {
        Case t4Case = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info T4');
        insert t4Case;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = t4Case.Id,
            breg_WEB_FORM_TYPE__c = 'T4',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Blue Wave Ventures LLC',
            breg_WEB_RDPMS_WFNEW_NAME__c = 'Blue Wave Market',
            breg_WEB_SUBMITTER_TITLE__c = 'Owner'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ t4Case.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebFilingInfo2Case(wrapperMap).PrepareData(new Set<String>{ t4Case.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(t4Case.Id).WebCase;
        Assert.areEqual('Blue Wave Market', mappedCase.breg_TNTMSM_Description__c, 'T4 filings should map new company name into TNTMSM description');
        Assert.areEqual('Owner', mappedCase.breg_Signed_By_Office_Held__c, 'TNTMSM forms should map submitter title into office held');
        Assert.isNull(mappedCase.breg_Name_of_the_Entity__c, 'T4 filings should not map company name into entity name');
    }

    @isTest
    static void testMapsEntityNameForAddWhenNoTnmaAddressExists() {
        Case addEntityCase = [SELECT Id FROM Case WHERE Subject = :ADD_ENTITY_CASE_SUBJECT LIMIT 1];
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ addEntityCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebFilingInfo2Case(wrapperMap).PrepareData(new Set<String>{ addEntityCase.Id });
        Test.stopTest();

        Assert.areEqual(
            'Acrofest Entity Name',
            wrapperMap.get(addEntityCase.Id).WebCase.breg_Name_of_the_Entity__c,
            'ADD filings without a TNMA address should map company name into entity name'
        );
    }

    @isTest
    static void testIsAddTnTmSmFormReturnsTrueOnlyForAddWithTnmaAddress() {
        breg_WEB_WEB_FILING_INFO__c addFilingInfo = new breg_WEB_WEB_FILING_INFO__c(breg_WEB_FORM_TYPE__c = 'ADD');
        breg_WEB_WEB_FILING_INFO__c nonAddFilingInfo = new breg_WEB_WEB_FILING_INFO__c(breg_WEB_FORM_TYPE__c = 'DC1');

        Assert.areEqual(
            true,
            BREGWebFilingInfo2Case.isAddTnTmSmForm(addFilingInfo, true),
            'Helper should return true for ADD filings that include a TNMA address'
        );
        Assert.areEqual(
            false,
            BREGWebFilingInfo2Case.isAddTnTmSmForm(addFilingInfo, false),
            'Helper should return false when the ADD filing does not include a TNMA address'
        );
        Assert.areEqual(
            false,
            BREGWebFilingInfo2Case.isAddTnTmSmForm(nonAddFilingInfo, true),
            'Helper should return false for non-ADD filings even when a TNMA address exists'
        );
    }

    @isTest
    static void testGetWorkitemIdsWithTnmaAddressReturnsOnlyMatchingCases() {
        Case addEntityCase = [SELECT Id FROM Case WHERE Subject = :ADD_ENTITY_CASE_SUBJECT LIMIT 1];
        Case otherCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info ADD TNMA Other');
        insert otherCase;

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = addEntityCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'TNMA',
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_ADDRESS_LINE_1__c = '456 TNMA St',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_OTHER_LOCALITY__c = 'HI',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );

        Set<String> result = BREGWebFilingInfo2Case.getWorkitemIdsWithTnmaAddress(new Set<String>{ addEntityCase.Id, otherCase.Id });

        Assert.areEqual(true, result.contains(addEntityCase.Id), 'Case with TNMA address should be returned');
        Assert.areEqual(false, result.contains(otherCase.Id), 'Case without TNMA address should not be returned');
    }

    @isTest
    static void testMapsAddTnTmSmFieldsFromLatestMatchingRecord() {
        Case addEntityCase = [SELECT Id FROM Case WHERE Subject = :ADD_ENTITY_CASE_SUBJECT LIMIT 1];

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = addEntityCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'TNMA',
            breg_WEB_WEB_ACTION_CODE__c = 'A',
            breg_WEB_ADDRESS_LINE_1__c = '789 TNMA St',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_OTHER_LOCALITY__c = 'HI',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );

        insert new List<breg_TN_TM_SM__c>{
            new breg_TN_TM_SM__c(
                Name = 'Acrofest New Trade Name',
                breg_Type__c = 'Trade Name',
                breg_Trade_Name__c = 'Older Trade Name',
                breg_Cert_Number__c = 'CERT-OLD',
                breg_TM_SM_Category__c = '35 - Advertising and Business',
                breg_File__c = 'OLD-FILE',
                breg_Registration_Date__c = Date.newInstance(2024, 1, 1)
            ),
            new breg_TN_TM_SM__c(
                Name = 'Acrofest New Trade Name',
                breg_Type__c = 'Trademark',
                breg_Trade_Name__c = 'Latest Trade Name',
                breg_Cert_Number__c = 'CERT-LATEST',
                breg_TM_SM_Category__c = '42 - Computer, Scientific & Legal',
                breg_File__c = 'LATEST-FILE',
                breg_Registration_Date__c = Date.newInstance(2025, 1, 1)
            )
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ addEntityCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebFilingInfo2Case(wrapperMap).PrepareData(new Set<String>{ addEntityCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(addEntityCase.Id).WebCase;
        Assert.areEqual('Trademark', mappedCase.breg_TNTMSM_Type__c, 'ADD + TNMA should map TNTMSM type from latest matching record');
        Assert.areEqual('Acrofest New Trade Name', mappedCase.breg_TNTMSM_Description__c, 'ADD + TNMA should map description from filing info WFNEW_NAME');
        Assert.areEqual('CERT-LATEST', mappedCase.breg_TNTMSM_Certificate__c, 'ADD + TNMA should map certificate from latest matching record');
        Assert.areEqual(
            '42 - Computer, Scientific & Legal',
            mappedCase.breg_TNTMSM_Classification__c,
            'ADD + TNMA should map classification from latest matching record'
        );
        Assert.areEqual('LATEST-FILE', mappedCase.breg_File__c, 'ADD + TNMA should map file from latest matching record');
    }

    @isTest
    static void testSubmissionDateFallsBackWhenScanTimeIsInvalid() {
        Case scanFallbackCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Scan Time Fallback');
        insert scanFallbackCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = scanFallbackCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Fallback Test Inc.',
            breg_WEB_SUBMISSION_DT__c = Date.newInstance(2026, 6, 1),
            breg_WEB_RDPMS_WFSCAN_TIME__c = 'bad value'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ scanFallbackCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        new BREGWebFilingInfo2Case(wrapperMap).PrepareData(new Set<String>{ scanFallbackCase.Id });
        Test.stopTest();

        Assert.areEqual(
            Datetime.newInstanceGmt(2026, 6, 1, 10, 0, 0),
            wrapperMap.get(scanFallbackCase.Id).WebCase.breg_Submission_Date__c,
            'Invalid scan times should fall back to the default Hawaii datetime mapping'
        );
    }

    @isTest
    static void testMapsSignedByEntityWhenSignatureDiffersFromSubmitterName() {
        Case entitySignerCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Entity Signer');
        insert entitySignerCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = entitySignerCase.Id,
            breg_WEB_FORM_TYPE__c = 'DC1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Test Company Inc.',
            breg_WEB_SUBMITTER_SIGNATURE__c = 'Alexis Caesar M. Diego',
            breg_WEB_SUBMITTER_NAME__c = 'Lepeuli LLC'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ entitySignerCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ entitySignerCase.Id });
        Test.stopTest();

        Case mappedCase = wrapperMap.get(entitySignerCase.Id).WebCase;
        Assert.areEqual('Entity', mappedCase.breg_Signed_By__c, 'Signed by should be Entity when signature differs from submitter name');
        Assert.areEqual(
            'Alexis',
            mappedCase.breg_Signed_By_First_Name__c,
            'First name should be first token from submitter signature for Entity signer type'
        );
        Assert.areEqual(
            'Caesar M. Diego',
            mappedCase.breg_Signed_By_Last_Name__c,
            'Last name should be remainder of submitter signature for Entity signer type'
        );
        Assert.isNull(mappedCase.breg_Signed_By_Name__c, 'Signed by name should be blank for Entity signer type');
        Assert.areEqual('Lepeuli LLC', mappedCase.breg_Signed_By_Entity_Name__c, 'Entity name should come from submitter name when signer type is Entity');
    }

    @isTest
    static void testNoSourceRecordLeavesCaseWrapperUnchanged() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web', Subject = 'Web Filing Info Empty');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no filing info exists');
        Assert.isNull(wrapperMap.get(emptyCase.Id).WebCase.breg_Name_of_the_Entity__c, 'Entity name should remain null when nothing is mapped');
    }

    @isTest
    static void testNullWorkitemIdsReturnsEmptyMap() {
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(new Map<String, BREGWebFilingWrapper>());

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results, 'Null workitemIds should still return a map');
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return an empty map');
    }

    @isTest
    static void testEmptyWorkitemIdsReturnsEmptyMap() {
        BREGWebFilingInfo2Case mapper = new BREGWebFilingInfo2Case(new Map<String, BREGWebFilingWrapper>());

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results, 'Empty workitemIds should still return a map');
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return an empty map');
    }
}