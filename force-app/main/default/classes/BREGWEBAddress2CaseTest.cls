@isTest
private class BREGWEBAddress2CaseTest {
    private static final String BASE_CASE_SUBJECT = 'BREGWEBAddress2CaseTest Base';
    private static final String TNTMSM_CASE_SUBJECT = 'BREGWEBAddress2CaseTest TNTMSM';
    private static final String UPPERCASE_APPLICANT_CASE_SUBJECT = 'BREGWEBAddress2CaseTest Uppercase Applicant';
    private static final String ENTITY_APPLICANT_CASE_SUBJECT = 'BREGWEBAddress2CaseTest Entity Applicant';

    @testSetup
    static void setupData() {
        Case testCase = new Case(Status = 'New', Origin = 'Web', Subject = BASE_CASE_SUBJECT);
        insert testCase;

        insert new List<breg_WEB_WEB_ADDRESSES__c>{
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = testCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'MAIL',
                breg_WEB_ADDRESS_LINE_1__c = '100 Mailing St',
                breg_WEB_ADDRESS_LINE_2__c = 'Suite 200',
                breg_WEB_ADDRESS_LINE_3__c = 'Floor 3',
                breg_WEB_LOCALITY_ID__c = 825, // Honolulu ZIP code to test state lookup
                breg_WEB_CITY__c = 'Honolulu',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_POSTAL_CODE__c = '96813',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = testCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_ADDRESS_LINE_1__c = '200 Principal Ave',
                breg_WEB_ADDRESS_LINE_2__c = 'Unit 5',
                breg_WEB_LOCALITY_ID__c = 825, // Hilo ZIP code to test state lookup
                breg_WEB_CITY__c = 'Hilo',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_POSTAL_CODE__c = '96720',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            )
        };

        Case tntmsmCase = new Case(Status = 'New', Origin = 'Web', Subject = TNTMSM_CASE_SUBJECT);
        insert tntmsmCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = tntmsmCase.Id,
            breg_WEB_FORM_TYPE__c = 'T1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Jane Doe'
        );

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = tntmsmCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'MAIL',
            breg_WEB_ADDRESS_LINE_1__c = '400 Applicant St',
            breg_WEB_ADDRESS_LINE_2__c = 'Suite 9',
            breg_WEB_CITY__c = 'Honolulu',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '96813',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );

        insert new Contact(FirstName = 'Jane', LastName = 'Doe');

        Case uppercaseApplicantCase = new Case(Status = 'New', Origin = 'Web', Subject = UPPERCASE_APPLICANT_CASE_SUBJECT);
        insert uppercaseApplicantCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = uppercaseApplicantCase.Id,
            breg_WEB_FORM_TYPE__c = 'T1',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'ALEX SAMPLE'
        );

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = uppercaseApplicantCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'MAIL',
            breg_WEB_ADDRESS_LINE_1__c = '123 TEST HARBOR WAY',
            breg_WEB_CITY__c = 'EXAMPLE CITY',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '99999',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );

        insert new Contact(FirstName = 'Alex', LastName = 'Sample');

        Case entityApplicantCase = new Case(Status = 'New', Origin = 'Web', Subject = ENTITY_APPLICANT_CASE_SUBJECT);
        insert entityApplicantCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = entityApplicantCase.Id,
            breg_WEB_FORM_TYPE__c = 'T2',
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Island Trade LLC'
        );

        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = entityApplicantCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'MAIL',
            breg_WEB_ADDRESS_LINE_1__c = '500 Entity Ave',
            breg_WEB_CITY__c = 'Hilo',
            breg_WEB_LOCALITY_ID__c = 825,
            breg_WEB_POSTAL_CODE__c = '96720',
            breg_WEB_COUNTRY_CODE_2__c = 'US'
        );
    }

    // ─── MAIL address type ────────────────────────────────────────────────────

    @isTest
    static void testMapsMailAddressToMailingFields() {
        Case testCase = getCaseBySubject(BASE_CASE_SUBJECT);
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Assert.isTrue(results.containsKey(testCase.Id), 'Result map should contain the case ID key');

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('100 Mailing St', webCase.breg_Mailing_Address__Street__s, 'Mailing street 1 should be mapped');
        Assert.areEqual('Suite 200\nFloor 3', webCase.breg_Mailing_Address_Number_and_Street_2__c, 'Mailing street 2 should combine lines 2 and 3');
        Assert.areEqual('Honolulu', webCase.breg_Mailing_Address__City__s, 'Mailing city should be mapped');
        Assert.areEqual('HI', webCase.breg_Mailing_Address__StateCode__s, 'Mailing state should be mapped from ZIP code');
        Assert.areEqual('96813', webCase.breg_Mailing_Address__PostalCode__s, 'Mailing zip should be mapped');
        Assert.areEqual('US', webCase.breg_Mailing_Address__CountryCode__s, 'Mailing country should be mapped');
    }

    // ─── PRIN address type ────────────────────────────────────────────────────

    @isTest
    static void testMapsPrinAddressToCompanyFields() {
        Case testCase = getCaseBySubject(BASE_CASE_SUBJECT);
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('200 Principal Ave', webCase.breg_Company_Address__Street__s, 'Company street 1 should be mapped');
        Assert.areEqual('Unit 5', webCase.breg_Company_Address_Street2__c, 'Company street 2 should be mapped from line 2');
        Assert.areEqual('Hilo', webCase.breg_Company_Address__City__s, 'Company city should be mapped');
        Assert.areEqual('HI', webCase.breg_Company_Address__StateCode__s, 'Company state should be mapped from ZIP code');
        Assert.areEqual('96720', webCase.breg_Company_Address__PostalCode__s, 'Company zip should be mapped');
        Assert.areEqual('US', webCase.breg_Company_Address__CountryCode__s, 'Company country should be mapped');
    }

    @isTest
    static void testSingleActiveAddressMapsToBothAddressTargets() {
        Case singleAddressCase = new Case(Status = 'New', Origin = 'Web');
        insert singleAddressCase;

        insert new List<breg_WEB_WEB_ADDRESSES__c>{
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = singleAddressCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'MAIL',
                breg_WEB_ADDRESS_LINE_1__c = '300 Solo St',
                breg_WEB_ADDRESS_LINE_2__c = 'Suite 8',
                breg_WEB_CITY__c = 'Cheyenne',
                breg_WEB_LOCALITY_ID__c = 865,
                breg_WEB_POSTAL_CODE__c = '82001',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = singleAddressCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_ADDRESS_LINE_1__c = 'Should Ignore Delete',
                breg_WEB_CITY__c = 'Deleted City',
                breg_WEB_WEB_ACTION_CODE__c = 'D'
            )
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ singleAddressCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ singleAddressCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(singleAddressCase.Id).WebCase;
        Assert.areEqual('300 Solo St', webCase.breg_Mailing_Address__Street__s, 'Single active address should map to mailing street');
        Assert.areEqual('Suite 8', webCase.breg_Mailing_Address_Number_and_Street_2__c, 'Single active address should map mailing street 2');
        Assert.areEqual('Cheyenne', webCase.breg_Mailing_Address__City__s, 'Single active address should map to mailing city');
        Assert.areEqual('WY', webCase.breg_Mailing_Address__StateCode__s, 'Single active address should map mailing state from ZIP code');
        Assert.areEqual('82001', webCase.breg_Mailing_Address__PostalCode__s, 'Single active address should map mailing zip');
        Assert.areEqual('US', webCase.breg_Mailing_Address__CountryCode__s, 'Single active address should map mailing country');
        Assert.areEqual('300 Solo St', webCase.breg_Company_Address__Street__s, 'Single active address should also map to company street');
        Assert.areEqual('Suite 8', webCase.breg_Company_Address_Street2__c, 'Single active address should also map company street 2');
        Assert.areEqual('Cheyenne', webCase.breg_Company_Address__City__s, 'Single active address should also map to company city');
        Assert.areEqual('WY', webCase.breg_Company_Address__StateCode__s, 'Single active address should also map company state from ZIP code');
        Assert.areEqual('82001', webCase.breg_Company_Address__PostalCode__s, 'Single active address should also map company zip');
        Assert.areEqual('US', webCase.breg_Company_Address__CountryCode__s, 'Single active address should also map company country');
    }

    @isTest
    static void testAddTntmsmAddressPairMapsCurrentAndNewMailing() {
        Case addCase = new Case(Status = 'New', Origin = 'Web');
        insert addCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = addCase.Id,
            breg_WEB_FORM_TYPE__c = 'ADD',
            breg_WEB_RDPMS_WFNEW_NAME__c = 'Trade Name Update'
        );

        insert new List<breg_WEB_WEB_ADDRESSES__c>{
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'TNMA',
                breg_WEB_WEB_ACTION_CODE__c = 'D',
                breg_WEB_ADDRESS_LINE_1__c = '10 Current TN St',
                breg_WEB_ADDRESS_LINE_2__c = 'Suite 1',
                breg_WEB_CITY__c = 'Honolulu',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96813',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'TNMA',
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_ADDRESS_LINE_1__c = '20 New TN St',
                breg_WEB_ADDRESS_LINE_2__c = 'Suite 2',
                breg_WEB_CITY__c = 'Hilo',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96720',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            )
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ addCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ addCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(addCase.Id).WebCase;
        Assert.areEqual('10 Current TN St', webCase.breg_Mailing_Address__Street__s, 'Deleted TNMA address should map to current mailing street');
        Assert.areEqual('Suite 1', webCase.breg_Mailing_Address_Number_and_Street_2__c, 'Deleted TNMA address should map to current mailing street 2');
        Assert.areEqual('Honolulu', webCase.breg_Mailing_Address__City__s, 'Deleted TNMA address should map to current mailing city');
        Assert.areEqual('HI', webCase.breg_Mailing_Address__StateCode__s, 'Deleted TNMA address should map to current mailing state code');
        Assert.areEqual('96813', webCase.breg_Mailing_Address__PostalCode__s, 'Deleted TNMA address should map to current mailing postal code');
        Assert.areEqual('US', webCase.breg_Mailing_Address__CountryCode__s, 'Deleted TNMA address should map to current mailing country');
        Assert.areEqual('20 New TN St', webCase.breg_New_Mailing_Address__Street__s, 'Added TNMA address should map to new mailing street');
        Assert.areEqual('Suite 2', webCase.breg_New_Mailing_Address_Street_2__c, 'Added TNMA address should map to new mailing street 2');
        Assert.areEqual('Hilo', webCase.breg_New_Mailing_Address__City__s, 'Added TNMA address should map to new mailing city');
        Assert.areEqual('HI', webCase.breg_New_Mailing_Address__StateCode__s, 'Added TNMA address should map to new mailing state code');
        Assert.areEqual('96720', webCase.breg_New_Mailing_Address__PostalCode__s, 'Added TNMA address should map to new mailing postal code');
        Assert.areEqual('US', webCase.breg_New_Mailing_Address__CountryCode__s, 'Added TNMA address should map to new mailing country');
        Assert.areEqual(true, webCase.breg_Mailing_Address_Has_Changed__c, 'TNMA ADD mapping should leave mailing changed flag true');
        Assert.areEqual(false, webCase.breg_Company_Address_Has_Changed__c, 'TNMA ADD mapping should leave company changed flag false');
    }

    @isTest
    static void testAddEntityAddressPairsMapCurrentAndNewAddresses() {
        Case addCase = new Case(Status = 'New', Origin = 'Web');
        insert addCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = addCase.Id,
            breg_WEB_FORM_TYPE__c = 'ADD'
        );

        insert new List<breg_WEB_WEB_ADDRESSES__c>{
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'MAIL',
                breg_WEB_WEB_ACTION_CODE__c = 'D',
                breg_WEB_ADDRESS_LINE_1__c = '100 Current Mailing St',
                breg_WEB_CITY__c = 'Honolulu',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96813',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'MAIL',
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_ADDRESS_LINE_1__c = '101 New Mailing St',
                breg_WEB_CITY__c = 'Hilo',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96720',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_WEB_ACTION_CODE__c = 'D',
                breg_WEB_ADDRESS_LINE_1__c = '200 Current Company St',
                breg_WEB_CITY__c = 'Kailua',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96734',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_ADDRESS_LINE_1__c = '201 New Company St',
                breg_WEB_CITY__c = 'Pearl City',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96782',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            )
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ addCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ addCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(addCase.Id).WebCase;
        Assert.areEqual('100 Current Mailing St', webCase.breg_Mailing_Address__Street__s, 'Deleted MAIL address should map to current mailing street');
        Assert.areEqual('101 New Mailing St', webCase.breg_New_Mailing_Address__Street__s, 'Added MAIL address should map to new mailing street');
        Assert.areEqual('200 Current Company St', webCase.breg_Company_Address__Street__s, 'Deleted PRIN address should map to current company street');
        Assert.areEqual('201 New Company St', webCase.breg_New_Company_Address__Street__s, 'Added PRIN address should map to new company street');
        Assert.areEqual(true, webCase.breg_Mailing_Address_Has_Changed__c, 'MAIL pair should set mailing changed flag true');
        Assert.areEqual(true, webCase.breg_Company_Address_Has_Changed__c, 'PRIN pair should set company changed flag true');
    }

    @isTest
    static void testTntmsmApplicantAffiliationUsesUniqueContactAsIndividual() {
        Case tntmsmCase = getCaseBySubject(TNTMSM_CASE_SUBJECT);
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ tntmsmCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(tntmsmCase.Id).WebCase.Id = tntmsmCase.Id;

        Test.startTest();
        new BREGWEBAddress2Case(wrapperMap).PrepareData(new Set<String>{ tntmsmCase.Id });
        Test.stopTest();

        List<BREGWebAccountAffiliationWrapper> affiliations = wrapperMap.get(tntmsmCase.Id).AccountAffiliations;
        Assert.areEqual(1, affiliations.size(), 'TNTMSM filing should create one applicant affiliation');
        breg_Account_Affiliation__c affiliation = affiliations[0].accountAffiliation;
        Assert.areEqual('Applicant', affiliation.breg_Role__c, 'Applicant role should be assigned');
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'Unique contact match should classify applicant as individual');
        Assert.areEqual('Jane', affiliation.breg_First_Name__c, 'First name should come from matched contact');
        Assert.areEqual('Doe', affiliation.breg_Last_Name__c, 'Last name should come from matched contact');
        Assert.isNull(affiliation.breg_Entity_Name__c, 'Entity name should remain blank for individual applicant');
        Assert.areEqual('400 Applicant St', affiliation.breg_Address__Street__s, 'Applicant street should come from TNTMSM address');
        Assert.areEqual('Suite 9', affiliation.breg_Address_Street_2__c, 'Applicant street 2 should come from TNTMSM address');
        Assert.areEqual('Honolulu', affiliation.breg_Address__City__s, 'Applicant city should come from TNTMSM address');
        Assert.areEqual('HI', affiliation.breg_Address__StateCode__s, 'Applicant state should be derived from locality');
        Assert.areEqual('96813', affiliation.breg_Address__PostalCode__s, 'Applicant postal code should come from TNTMSM address');
        Assert.areEqual('US', affiliation.breg_Address__CountryCode__s, 'Applicant country should come from TNTMSM address');
        Assert.areEqual(tntmsmCase.Id, affiliation.breg_Case__c, 'Applicant affiliation should link to the Case');
        Assert.isNull(wrapperMap.get(tntmsmCase.Id).WebCase.breg_Mailing_Address__Street__s, 'TNTMSM filing should not populate Case mailing address');
        Assert.isNull(wrapperMap.get(tntmsmCase.Id).WebCase.breg_Company_Address__Street__s, 'TNTMSM filing should not populate Case company address');
    }

    @isTest
    static void testTntmsmApplicantAffiliationFallsBackToEntityWhenNoContactMatch() {
        Case entityApplicantCase = getCaseBySubject(ENTITY_APPLICANT_CASE_SUBJECT);
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ entityApplicantCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(entityApplicantCase.Id).WebCase.Id = entityApplicantCase.Id;

        Test.startTest();
        new BREGWEBAddress2Case(wrapperMap).PrepareData(new Set<String>{ entityApplicantCase.Id });
        Test.stopTest();

        List<BREGWebAccountAffiliationWrapper> affiliations = wrapperMap.get(entityApplicantCase.Id).AccountAffiliations;
        Assert.areEqual(1, affiliations.size(), 'TNTMSM filing should create one applicant affiliation');
        breg_Account_Affiliation__c affiliation = affiliations[0].accountAffiliation;
        Assert.areEqual('Applicant', affiliation.breg_Role__c, 'Applicant role should be assigned');
        Assert.areEqual('Entity', affiliation.breg_Type__c, 'Applicant should default to entity when no unique contact match exists');
        Assert.areEqual('Island Trade LLC', affiliation.breg_Entity_Name__c, 'Entity name should come from filing info company name');
        Assert.isNull(affiliation.breg_First_Name__c, 'First name should remain blank for entity applicant');
        Assert.isNull(affiliation.breg_Last_Name__c, 'Last name should remain blank for entity applicant');
        Assert.areEqual('500 Entity Ave', affiliation.breg_Address__Street__s, 'Applicant street should come from TNTMSM address');
        Assert.areEqual(entityApplicantCase.Id, affiliation.breg_Case__c, 'Applicant affiliation should link to the Case');
        Assert.isNull(wrapperMap.get(entityApplicantCase.Id).WebCase.breg_Mailing_Address__Street__s, 'TNTMSM filing should not populate Case mailing address');
        Assert.isNull(wrapperMap.get(entityApplicantCase.Id).WebCase.breg_Company_Address__Street__s, 'TNTMSM filing should not populate Case company address');
    }

    @isTest
    static void testTntmsmApplicantAffiliationMatchesContactCaseInsensitively() {
        Case uppercaseApplicantCase = getCaseBySubject(UPPERCASE_APPLICANT_CASE_SUBJECT);
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ uppercaseApplicantCase.Id => new BREGWebFilingWrapper() };
        wrapperMap.get(uppercaseApplicantCase.Id).WebCase.Id = uppercaseApplicantCase.Id;

        Test.startTest();
        new BREGWEBAddress2Case(wrapperMap).PrepareData(new Set<String>{ uppercaseApplicantCase.Id });
        Test.stopTest();

        breg_Account_Affiliation__c affiliation = wrapperMap.get(uppercaseApplicantCase.Id).AccountAffiliations[0].accountAffiliation;
        Assert.areEqual('Individual', affiliation.breg_Type__c, 'Contact name match should be case-insensitive');
        Assert.areEqual('ALEX', affiliation.breg_First_Name__c, 'First name should come from the first word of filing info company name');
        Assert.areEqual('SAMPLE', affiliation.breg_Last_Name__c, 'Last name should come from the remaining words of filing info company name');
        Assert.isNotNull(affiliation.breg_Contact__c, 'Matched contact should be linked on the affiliation');
        Assert.isNull(affiliation.breg_Entity_Name__c, 'Entity name should stay blank when a contact match exists');
    }

    @isTest
    static void testAddEntitySingleAddressPairMapsOneTypeAndClearsOtherFlag() {
        Case addCase = new Case(Status = 'New', Origin = 'Web');
        insert addCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = addCase.Id,
            breg_WEB_FORM_TYPE__c = 'ADD'
        );

        insert new List<breg_WEB_WEB_ADDRESSES__c>{
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_WEB_ACTION_CODE__c = 'D',
                breg_WEB_ADDRESS_LINE_1__c = '300 Current Only Company St',
                breg_WEB_CITY__c = 'Kapolei',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96707',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            ),
            new breg_WEB_WEB_ADDRESSES__c(
                breg_WEB_Case__c = addCase.Id,
                breg_WEB_ADDRESS_TYPE__c = 'PRIN',
                breg_WEB_WEB_ACTION_CODE__c = 'A',
                breg_WEB_ADDRESS_LINE_1__c = '301 New Only Company St',
                breg_WEB_CITY__c = 'Waipahu',
                breg_WEB_OTHER_LOCALITY__c = 'HI',
                breg_WEB_LOCALITY_ID__c = 825,
                breg_WEB_POSTAL_CODE__c = '96797',
                breg_WEB_COUNTRY_CODE_2__c = 'US'
            )
        };

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ addCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ addCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(addCase.Id).WebCase;
        Assert.areEqual('300 Current Only Company St', webCase.breg_Company_Address__Street__s, 'Deleted PRIN address should map to current company street');
        Assert.areEqual('301 New Only Company St', webCase.breg_New_Company_Address__Street__s, 'Added PRIN address should map to new company street');
        Assert.areEqual(true, webCase.breg_Company_Address_Has_Changed__c, 'Present address pair should set company changed flag true');
        Assert.areEqual(false, webCase.breg_Mailing_Address_Has_Changed__c, 'Missing mailing pair should set mailing changed flag false');
        Assert.isNull(webCase.breg_New_Mailing_Address__Street__s, 'Missing mailing pair should not populate new mailing address');
    }

    // ─── Street 2 building ────────────────────────────────────────────────────

    @isTest
    static void testStreet2WithOnlyLine2() {
        Case testCase = getCaseBySubject(BASE_CASE_SUBJECT);
        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'MAIL',
            breg_WEB_ADDRESS_LINE_1__c = '1 Test Blvd',
            breg_WEB_ADDRESS_LINE_2__c = 'Apt 4B'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // Pick the record that was last applied (last MAIL wins)
        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areEqual('Apt 4B', webCase.breg_Mailing_Address_Number_and_Street_2__c, 'Only line 2 should be returned when line 3 is blank');
    }

    @isTest
    static void testStreet2NullWhenBothLinesBlank() {
        Case testCase = getCaseBySubject(BASE_CASE_SUBJECT);
        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'PRIN',
            breg_WEB_ADDRESS_LINE_1__c = '1 Test Blvd'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.isNull(webCase.breg_Company_Address_Street2__c, 'Street 2 should be null when both address lines 2 and 3 are blank');
    }

    // ─── Unknown address type ─────────────────────────────────────────────────

    @isTest
    static void testUnknownAddressTypeIsIgnored() {
        Case testCase = getCaseBySubject(BASE_CASE_SUBJECT);
        insert new breg_WEB_WEB_ADDRESSES__c(
            breg_WEB_Case__c = testCase.Id,
            breg_WEB_ADDRESS_TYPE__c = 'OTHER',
            breg_WEB_ADDRESS_LINE_1__c = '999 Unknown Rd',
            breg_WEB_CITY__c = 'Somewhere'
        );

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ testCase.Id => new BREGWebFilingWrapper() };
        // Pre-populate with known state so we can detect if it changed
        wrapperMap.get(testCase.Id).WebCase.breg_Mailing_Address__City__s = 'OriginalCity';

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        mapper.PrepareData(new Set<String>{ testCase.Id });
        Test.stopTest();

        // The MAIL record in setupData overrides city to 'Honolulu'; OTHER should not touch it further
        Case webCase = wrapperMap.get(testCase.Id).WebCase;
        Assert.areNotEqual('Somewhere', webCase.breg_Mailing_Address__City__s, 'Unknown address type should not update mailing address fields');
        Assert.areNotEqual('Somewhere', webCase.breg_Company_Address__City__s, 'Unknown address type should not update company address fields');
    }

    // ─── Edge cases ───────────────────────────────────────────────────────────

    @isTest
    static void testNoAddressesReturnsEmptyResult() {
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>{ emptyCase.Id => new BREGWebFilingWrapper() };

        Test.startTest();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>{ emptyCase.Id });
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Result map should be empty when no address records exist');
    }

    @isTest
    static void testNullWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(null);
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Null workitemIds should return empty map');
    }

    @isTest
    static void testEmptyWorkitemIds() {
        Map<String, BREGWebFilingWrapper> wrapperMap = new Map<String, BREGWebFilingWrapper>();
        BREGWEBAddress2Case mapper = new BREGWEBAddress2Case(wrapperMap);

        Test.startTest();
        Map<String, List<SObject>> results = mapper.PrepareData(new Set<String>());
        Test.stopTest();

        Assert.isNotNull(results);
        Assert.isTrue(results.isEmpty(), 'Empty workitemIds should return empty map');
    }

    private static Case getCaseBySubject(String subject) {
        return [SELECT Id FROM Case WHERE Subject = :subject LIMIT 1];
    }
}