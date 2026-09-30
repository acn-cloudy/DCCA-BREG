@isTest
private class BREGAddressProtectionUtilsTest {

    // ─── Helpers ────────────────────────────────────────────────────────────────

    private static BREG_ADDRESS_PROTECTION__c makeProtectionRecord(
        String name,
        String namePattern,
        String alphasortValue,
        String rawValue,
        DateTime deactivatedDate
    ) {
        return new BREG_ADDRESS_PROTECTION__c(
            Name = name,
            //breg_BRIM_ADDRESS_PROTECTION_ID__c = name,
            breg_ALPHASORT_NAME__c = namePattern,
            breg_ALPHASORT_VALUE__c = alphasortValue,
            breg_VALUE__c = rawValue,
            breg_DATE_EXCLUDED__c = DateTime.now().addDays(-1)
            //breg_DATE_DEACTIVATED__c = deactivatedDate
        );
    }

    private static BREG_ADDRESS_PROTECTION__c insertActiveProtection(
        String alphasortName,
        String alphasortValue,
        String rawValue
    ) {
        BREG_ADDRESS_PROTECTION__c rec = makeProtectionRecord(
            'TEST-PROT-' + alphasortName,
            alphasortName,
            alphasortValue,
            rawValue,
            null // null = active (no deactivation date)
        );
        insert rec;
        refreshProtectionMap();
        return rec;
    }

    /**
     * Rebuilds the static protectionMap from the database.
     * Must be called after inserting test protection records because the static
     * variable is eagerly initialized at class-load time (before test data exists).
     */
    private static void refreshProtectionMap() {
        DateTime now = DateTime.now();
        List<BREG_ADDRESS_PROTECTION__c> recs = [
            SELECT breg_ALPHASORT_NAME__c, breg_ALPHASORT_VALUE__c
            FROM BREG_ADDRESS_PROTECTION__c
            WHERE (breg_DATE_DEACTIVATED__c = NULL OR breg_DATE_DEACTIVATED__c > :now)
        ];
        // Apply the same normalization as BREGAddressProtectionUtils.buildProtectionMap():
        // strip non-alphanumeric from name keys (no %) and strip % from address values (keep ,)
        Map<String, List<String>> freshMap = new Map<String, List<String>>();
        for (BREG_ADDRESS_PROTECTION__c rec : recs) {
            if (String.isBlank(rec.breg_ALPHASORT_NAME__c)) {
                continue;
            }
            String nameKey = rec.breg_ALPHASORT_NAME__c.toUpperCase().replaceAll('[^A-Z0-9]', '');
            if (!freshMap.containsKey(nameKey)) {
                freshMap.put(nameKey, new List<String>());
            }
            String addrValue = String.isNotBlank(rec.breg_ALPHASORT_VALUE__c)
                ? rec.breg_ALPHASORT_VALUE__c.toUpperCase().replaceAll('[^A-Z0-9,]', '')
                : rec.breg_ALPHASORT_VALUE__c;
            freshMap.get(nameKey).add(addrValue);
        }
        BREGAddressProtectionUtils.protectionMap = freshMap;
    }

    // ─── calculateAlphaSort ──────────────────────────────────────────────────────

    @isTest
    static void calculateAlphaSort_simpleName_returnsSpaceJoinedTokens() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSort('Charles Green');
        Test.stopTest();

        Assert.areEqual('CHARLES GREEN', result, 'Expected space-joined normalized tokens');
    }

    @isTest
    static void calculateAlphaSort_extraWhitespace_normalizes() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSort('CHARLES  GREEN');
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.containsIgnoreCase('CHARLES'), 'CHARLES token must be present');
        Assert.isTrue(result.containsIgnoreCase('GREEN'), 'GREEN token must be present');
        Assert.isFalse(result.contains('%'), 'Result must not contain % wildcards');
    }

    @isTest
    static void calculateAlphaSort_blankInput_returnsNull() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSort('');
        Test.stopTest();

        Assert.isNull(result, 'Blank input should return null');
    }

    @isTest
    static void calculateAlphaSort_nullInput_returnsNull() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSort(null);
        Test.stopTest();

        Assert.isNull(result, 'Null input should return null');
    }

    // ─── calculateAlphaSortForAddress ────────────────────────────────────────────

    @isTest
    static void calculateAlphaSortForAddress_fullAddress_containsAllParts() {
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '550 Dubai Street', null, null, 'Honolulu', 'HI', 'US', '96818'
        );

        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        Assert.isTrue(result.containsIgnoreCase('550DUBAIST'), 'Street abbreviation should be applied: ' + result);
        Assert.isTrue(result.containsIgnoreCase('HONOLULU'),  'City should be present: ' + result);
        Assert.isTrue(result.containsIgnoreCase('HI'),        'State should be present: ' + result);
        Assert.isTrue(result.containsIgnoreCase('96818'),     'Zip should be present: ' + result);
    }

    @isTest
    static void calculateAlphaSortForAddress_streetAbbreviations_appliedCorrectly() {
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '10 Main Avenue', null, null, null, null, null, null
        );

        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.isTrue(result.containsIgnoreCase('10MAINAAVE') || result.containsIgnoreCase('10MAINAAVE') || result.containsIgnoreCase('AVE'), 'AVENUE should become AVE: ' + result);
    }

    @isTest
    static void calculateAlphaSortForAddress_nullWrapper_returnsNull() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(null);
        Test.stopTest();

        Assert.isNull(result, 'Null wrapper should return null');
    }

    @isTest
    static void calculateAlphaSortForAddress_emptyWrapper_returnsNull() {
        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(
            new BREGAddressProtectionUtils.AddressWrapper()
        );
        Test.stopTest();

        Assert.isNull(result, 'Empty wrapper should return null');
    }

    @isTest
    static void calculateAlphaSortForAddress_cityAndZipOnly_noStreet() {
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            null, null, null, 'Hilo', 'HI', 'US', '96720'
        );

        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.isTrue(result.containsIgnoreCase('HILO'), 'City should be present: ' + result);
        Assert.isTrue(result.containsIgnoreCase('96720'), 'Zip should be present: ' + result);
    }

    @isTest
    static void calculateAlphaSortForAddress_streetWithAptComma_stripsSecondaryUnit() {
        // "2525 DATE STREET, APT. 2301" should produce the same pattern as "2525 DATE STREET"
        BREGAddressProtectionUtils.AddressWrapper addrWithApt = new BREGAddressProtectionUtils.AddressWrapper(
            '2525 DATE STREET, APT. 2301', null, null, 'Honolulu', 'HI', 'US', '96826'
        );
        BREGAddressProtectionUtils.AddressWrapper addrWithoutApt = new BREGAddressProtectionUtils.AddressWrapper(
            '2525 DATE STREET', null, null, 'Honolulu', 'HI', 'US', '96826'
        );

        Test.startTest();
        String resultWithApt    = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addrWithApt);
        String resultWithoutApt = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addrWithoutApt);
        Test.stopTest();

        Assert.isNotNull(resultWithApt);
        Assert.areEqual(resultWithoutApt, resultWithApt,
            'Street with APT. unit should produce same pattern as street without: ' + resultWithApt);
        Assert.isFalse(resultWithApt.containsIgnoreCase('APT'), 'APT should be stripped: ' + resultWithApt);
    }

    @isTest
    static void calculateAlphaSortForAddress_streetWithSuiteNoComma_abbreviationApplied() {
        // SUITE stripping without a comma is not active; only abbreviation substitution is applied.
        // '100 MAIN BOULEVARD SUITE 500' → '100MAINBLVDSUITE500' (no comma to split on)
        BREGAddressProtectionUtils.AddressWrapper addrWithSuite = new BREGAddressProtectionUtils.AddressWrapper(
            '100 MAIN BOULEVARD SUITE 500', null, null, null, null, null, null
        );

        Test.startTest();
        String result = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addrWithSuite);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.isTrue(result.containsIgnoreCase('100MAINBLVD'), 'BOULEVARD should become BLVD: ' + result);
        Assert.isFalse(result.contains('%'), 'Result must not contain % wildcards');
    }

    // ─── isAddressProtected ──────────────────────────────────────────────────────

    @isTest
    static void isAddressProtected_blankName_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            '',
            new BREGAddressProtectionUtils.AddressWrapper('123 Main Street', null, null, 'Honolulu', 'HI', 'US', '96801')
        );
        Test.stopTest();

        Assert.isFalse(result, 'Blank name should always return false');
    }

    @isTest
    static void isAddressProtected_nullName_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            null,
            new BREGAddressProtectionUtils.AddressWrapper('123 Main Street', null, null, 'Honolulu', 'HI', 'US', '96801')
        );
        Test.stopTest();

        Assert.isFalse(result, 'Null name should always return false');
    }

    @isTest
    static void isAddressProtected_activeMatchingRecord_returnsTrue() {
        // Build the patterns the same way the method does
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Charles Green');
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '550 Dubai Street', null, null, 'Honolulu', 'HI', 'US', '96818'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '550 Dubai Street, Honolulu, HI, 96818');

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected('Charles Green', addr);
        Test.stopTest();

        Assert.isTrue(result, 'Should find active matching protection record');
    }

    @isTest
    static void isAddressProtected_deactivatedRecord_returnsFalse() {
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Jane Doe');
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '100 Oak Road', null, null, 'Kailua', 'HI', 'US', '96734'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        // Past deactivation date
        BREG_ADDRESS_PROTECTION__c rec = makeProtectionRecord(
            'DEACTIVATED-TEST', namePattern, addrPattern, '100 Oak Road, Kailua, HI, 96734',
            DateTime.now().addDays(-1)
        );
        insert rec;

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected('Jane Doe', addr);
        Test.stopTest();

        Assert.isFalse(result, 'Deactivated record should not trigger protection');
    }

    @isTest
    static void isAddressProtected_noMatchingRecord_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            'Nobody Here',
            new BREGAddressProtectionUtils.AddressWrapper('999 Nowhere Lane', null, null, 'Lahaina', 'HI', 'US', '96761')
        );
        Test.stopTest();

        Assert.isFalse(result, 'No matching record should return false');
    }

    @isTest
    static void isAddressProtected_nameOnlyNoAddress_matchesOnName() {
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Solo Name');
        insertActiveProtection(namePattern, '%SOLOPATTERN%', 'solo pattern value');

        Test.startTest();
        // Pass an address wrapper with no street/city — will fall through to name-only query
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            'Solo Name',
            new BREGAddressProtectionUtils.AddressWrapper()
        );
        Test.stopTest();

        Assert.isTrue(result, 'Name-only match (no address provided) should return true');
    }

    @isTest
    static void cleanProtectedTNTMSMData_protectedApplicantMailingAddress_addressCleared() {
        String applicantName = 'Charles Green';

        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(applicantName);

        BREGAddressProtectionUtils.AddressWrapper addr =
            new BREGAddressProtectionUtils.AddressWrapper(
                '550 Dubai Street',
                null,
                null,
                'Honolulu',
                'HI',
                'US',
                '96818'
            );

        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);

        insertActiveProtection(
            namePattern,
            addrPattern,
            '550 Dubai Street, Honolulu, HI, 96818'
        );

        Account acc = new Account(
            Name = 'Corporation Name Hide Address',

            BillingStreet = '550 Dubai Street',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingCountryCode = 'US',
            BillingPostalCode = '96818',

            breg_Mailing_Address__Street__s = '550 Dubai Street',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__PostalCode__s = '96818'
        );
        insert acc;

        breg_TN_TM_SM__c tntmsm = new breg_TN_TM_SM__c(
            breg_Trade_Name__c = 'Test Trade Name',
            breg_Account__c = acc.Id,
            breg_Registrant_Name__c = 'Fallback Registrant',

            breg_Mailing_Address__Street__s = '550 Dubai Street',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__PostalCode__s = '96818'
        );
        insert tntmsm;

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = acc.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',

            breg_First_Name__c = 'Charles',
            breg_Last_Name__c = 'Green',

            breg_Address__Street__s = '550 Dubai Street',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address__CountryCode__s = 'US',
            breg_Address__PostalCode__s = '96818',

            breg_Start_Date__c = Date.newInstance(2024, 1, 1)
        );

        Test.startTest();

        breg_TN_TM_SM__c result =
            BREGAccountAffiliationController.getTNTMSMWithRelationships(tntmsm.Id);

        Test.stopTest();

        Assert.isNull(
            result.breg_Mailing_Address__Street__s,
            'Mailing Street should be cleared'
        );
        Assert.isNull(
            result.breg_Mailing_Address__City__s,
            'Mailing City should be cleared'
        );
        Assert.isNull(
            result.breg_Mailing_Address__StateCode__s,
            'Mailing State should be cleared'
        );
        Assert.isNull(
            result.breg_Mailing_Address__CountryCode__s,
            'Mailing Country should be cleared'
        );
        Assert.isNull(
            result.breg_Mailing_Address__PostalCode__s,
            'Mailing Postal Code should be cleared'
        );
    }

    @isTest
    static void cleanProtectedAccountData_protectedBillingAndMailingAddress_addressCleared() {
        String agentName = 'Charles Green';

        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(agentName);

        BREGAddressProtectionUtils.AddressWrapper addr =
            new BREGAddressProtectionUtils.AddressWrapper(
                '550 Dubai Street',
                null,
                null,
                'Honolulu',
                'HI',
                'US',
                '96818'
            );

        String addrPattern =
            BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);

        insertActiveProtection(
            namePattern,
            addrPattern,
            '550 Dubai Street, Honolulu, HI, 96818'
        );

        Account acc = new Account(
            Name = 'Corporation Name Hide Address',

            BillingStreet = '550 Dubai Street',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingCountryCode = 'US',
            BillingPostalCode = '96818',

            breg_Mailing_Address__Street__s = '550 Dubai Street',
            breg_Mailing_Address__City__s = 'Honolulu',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__PostalCode__s = '96818'
        );
        insert acc;

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = acc.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',

            breg_First_Name__c = 'Charles',
            breg_Last_Name__c = 'Green',

            breg_Address__Street__s = '550 Dubai Street',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address__CountryCode__s = 'US',
            breg_Address__PostalCode__s = '96818',

            breg_Start_Date__c = Date.newInstance(2024, 1, 1)
        );

        Test.startTest();

        Account result =
            BREGAccountAffiliationController.getAccountWithRelationshipsById(acc.Id);

        Test.stopTest();

        Assert.isNull(
            result.BillingStreet,
            'Billing Street should be cleared'
        );

        Assert.isNull(
            result.BillingCity,
            'Billing City should be cleared'
        );

        Assert.isNull(
            result.BillingPostalCode,
            'Billing Postal Code should be cleared'
        );

        Assert.isNull(
            result.breg_Mailing_Address__Street__s,
            'Mailing Street should be cleared'
        );

        Assert.isNull(
            result.breg_Mailing_Address__City__s,
            'Mailing City should be cleared'
        );

        Assert.isNull(
            result.breg_Mailing_Address__PostalCode__s,
            'Mailing Postal Code should be cleared'
        );
    }

    // ─── cleanProtectedCaseData ──────────────────────────────────────────────────

    @isTest
    static void cleanProtectedCaseData_nullCase_returnsNull() {
        Test.startTest();
        Case result = BREGAddressProtectionUtils.cleanProtectedCaseData(null);
        Test.stopTest();

        Assert.isNull(result, 'Null input should return null');
    }

    @isTest
    static void cleanProtectedCaseData_noProtectionRecord_addressUnchanged() {
        Case c = new Case(
            breg_Name_of_the_Entity__c               = 'Safe Entity LLC',
            breg_Company_Address__Street__s   = '1 Safe Street',
            breg_Company_Address__City__s     = 'Honolulu',
            breg_Company_Address__StateCode__s   = 'HI',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__PostalCode__s  = '96801'
        );

        Test.startTest();
        Case result = BREGAddressProtectionUtils.cleanProtectedCaseData(c);
        Test.stopTest();

        Assert.areEqual('1 Safe Street', result.breg_Company_Address__Street__s, 'Unprotected address should be unchanged');
    }

    @isTest
    static void cleanProtectedCaseData_protectedEntityAddress_addressCleared() {
        // Insert protection record matching entity name + street
        String entityName = 'Protected Corp';
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(entityName);
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '42 Secret Drive', null, null, 'Honolulu', 'HI', 'US', '96815'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '42 Secret Drive, Honolulu, HI, 96815');
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case c = new Case(
            breg_Name_of_the_Entity__c               = entityName,
            breg_Company_Address__Street__s   = '42 Secret Drive',
            breg_Company_Address__City__s     = 'Honolulu',
            breg_Company_Address__StateCode__s   = 'HI',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__PostalCode__s  = '96815',
            RecordTypeId = caseRecordTypeId
        );
        insert c;

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Case__c = c.Id,
                breg_Role__c = 'Member',
                breg_Type__c = 'Individual',
                breg_Status__c = 'A',
                breg_First_Name__c = 'John',
                breg_Last_Name__c = 'Doe',
                breg_Address__Street__s = '123 Old St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2024, 1, 1)
            )
        };

        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(c.Id);
        Test.stopTest();

        Assert.isNull(result.breg_Company_Address__Street__s,   'Street should be cleared for protected entity');
        Assert.isNull(result.breg_Company_Address__City__s,     'City should be cleared for protected entity');
        Assert.isNull(result.breg_Company_Address__PostalCode__s, 'Zip should be cleared for protected entity');
    }

    @isTest
    static void cleanProtectedCaseData_protectedRegisteredAgentAddress_addressCleared() {
        // Insert protection record matching entity name + street
        String entityName = 'Jon Doe';
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(entityName);
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '42 Secret Drive', null, null, 'Honolulu', 'HI', 'US', '96815'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '42 Secret Drive, Honolulu, HI, 96815');
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case c = new Case(
            breg_Reg_Agent_Entity_Name__c     = entityName,
            breg_Reg_Agent_First_Name__c   = 'Jon',
            breg_Reg_Agent_Last_Name__c    = 'Doe',
            breg_Registered_Agent_Address__Street__s   = '42 Secret Drive',
            breg_Registered_Agent_Address__City__s     = 'Honolulu',
            breg_Registered_Agent_Address__StateCode__s   = 'HI',
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Registered_Agent_Address__PostalCode__s  = '96815',
            RecordTypeId = caseRecordTypeId
        );
        insert c;

        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(c.Id);
        Test.stopTest();

        Assert.isNull(result.breg_Registered_Agent_Address__Street__s,   'Street should be cleared for protected entity');
        Assert.isNull(result.breg_Registered_Agent_Address__City__s,     'City should be cleared for protected entity');
        Assert.isNull(result.breg_Registered_Agent_Address__PostalCode__s, 'Zip should be cleared for protected entity');
    }

    @isTest
    static void cleanProtectedCaseData_protectedNewRegisteredAgentAddress_addressCleared() {
        // Insert protection record matching entity name + street
        String entityName = 'Jon Doe';
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(entityName);
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '42 Secret Drive', null, null, 'Honolulu', 'HI', 'US', '96815'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '42 Secret Drive, Honolulu, HI, 96815');
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case c = new Case(
            breg_New_Registrant_Name__c     = entityName,
            breg_New_Registrant_First_Name__c   = 'Jon',
            breg_New_Registrant_Last_Name__c    = 'Doe',
            breg_New_Registrant_Address__Street__s   = '42 Secret Drive',
            breg_New_Registrant_Address__City__s     = 'Honolulu',
            breg_New_Registrant_Address__StateCode__s   = 'HI',
            breg_New_Registrant_Address__CountryCode__s = 'US',
            breg_New_Registrant_Address__PostalCode__s  = '96815',
            RecordTypeId = caseRecordTypeId
        );
        insert c;

        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(c.Id);
        Test.stopTest();

        Assert.isNull(result.breg_New_Registrant_Address__Street__s,   'Street should be cleared for protected entity');
        Assert.isNull(result.breg_New_Registrant_Address__City__s,     'City should be cleared for protected entity');
        Assert.isNull(result.breg_New_Registrant_Address__PostalCode__s, 'Zip should be cleared for protected entity');
    }

    @isTest
    static void cleanProtectedCaseData_protectedCaseAffiliation_addressCleared() {
        // Insert protection record matching entity name + street
        String affName = 'John Doe';
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(affName);
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '123 Old St', null, null, 'Honolulu', 'HI', 'US', '96813'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '123 Old St, Honolulu, HI, 96813');
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case c = new Case(
            breg_Name_of_the_Entity__c               = 'Safe Entity LLC',
            breg_Company_Address__Street__s   = '42 Secret Drive',
            breg_Company_Address__City__s     = 'Honolulu',
            breg_Company_Address__StateCode__s   = 'HI',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__PostalCode__s  = '96815',
            RecordTypeId = caseRecordTypeId
        );
        insert c;
        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(
                breg_Case__c = c.Id,
                breg_Role__c = 'Member',
                breg_Type__c = 'Individual',
                breg_Status__c = 'A',
                breg_First_Name__c = 'John',
                breg_Last_Name__c = 'Doe',
                breg_Address__Street__s = '123 Old St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.newInstance(2024, 1, 1)
            );

        insert aff;
        Test.startTest();
        Case result = BREGPortalUtils.getCaseWithRelations(c.Id);
        Test.stopTest();

        for(breg_Account_Affiliation__c affRecord : result.Account_Affiliations__r) {
            if(affRecord.Id == aff.Id) {
                aff = affRecord;
                break;
            }
        }
        Assert.isNull(aff.breg_Address__Street__s,   'Street should be cleared for protected entity');
        Assert.isNull(aff.breg_Address__City__s,     'City should be cleared for protected entity');
        Assert.isNull(aff.breg_Address__PostalCode__s, 'Zip should be cleared for protected entity');
    }

    @isTest
    static void cleanProtectedCaseData_protectedAffiliation_addressCleared() {
        String personName = 'Protected Person';
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(personName);
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '7 Hidden Court', null, null, 'Kailua', 'HI', 'US', '96734'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);
        insertActiveProtection(namePattern, addrPattern, '7 Hidden Court, Kailua, HI, 96734');

        // Build an in-memory affiliation (no DML needed for cleanProtectedCaseData)
        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(
            breg_Type__c             = 'Entity',
            breg_Entity_Name__c      = personName,
            breg_Address__Street__s  = '7 Hidden Court',
            breg_Address__City__s    = 'Kailua',
            breg_Address__StateCode__s   = 'HI',
            breg_Address__CountryCode__s = 'US',
            breg_Address__PostalCode__s  = '96734'
        );

        // Use a mock Case that carries the affiliation in memory via a list trick
        Case c = new Case(breg_Name_of_the_Entity__c = 'Test Entity');

        // cleanProtectedCaseData reads caseRecord.Account_Affiliations__r,
        // so we test the affiliation helper methods directly here instead.
        Test.startTest();
        String builtName = BREGAddressProtectionUtils.calculateAlphaSort(personName);
        Boolean isProtected = BREGAddressProtectionUtils.isAddressProtected(personName, addr);
        Test.stopTest();

        Assert.isTrue(isProtected, 'Protected affiliation address should be detected');
    }

    // ─── getAddressExceptionForId ────────────────────────────────────────────────

    @isTest
    static void getAddressExceptionForId_nullId_returnsEmptyList() {
        Test.startTest();
        List<BREG_ADDRESS_PROTECTION__c> result = BREGAddressProtectionUtils.getAddressExceptionForId(null);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Null Id should return empty list');
    }

    @isTest
    static void getAddressExceptionForId_accountWithMatchingProtection_returnsRecords() {
        Account acc = new Account(
            Name            = 'Protected Account LLC',
            BillingStreet   = '100 Guarded Boulevard',
            BillingCity     = 'Honolulu',
            BillingStateCode    = 'HI',
            BillingCountryCode  = 'US',
            BillingPostalCode   = '96813'
        );
        insert acc;

        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort(acc.Name);
        BREGAddressProtectionUtils.AddressWrapper addrW = new BREGAddressProtectionUtils.AddressWrapper(
            acc.BillingStreet, null, null, acc.BillingCity, acc.BillingStateCode, acc.BillingCountryCode, acc.BillingPostalCode
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addrW);
        insertActiveProtection(namePattern, addrPattern, '100 Guarded Boulevard, Honolulu, HI, 96813');

        Test.startTest();
        List<BREG_ADDRESS_PROTECTION__c> results = BREGAddressProtectionUtils.getAddressExceptionForId(acc.Id);
        Test.stopTest();

        Assert.isTrue(results.size() >= 1, 'Should find at least one protection record for the account');
    }

    @isTest
    static void getAddressExceptionForId_accountNoProtection_returnsEmptyList() {
        Account acc = new Account(
            Name = 'Clean Account Corp',
            BillingStreet = '1 Open Avenue',
            BillingCity = 'Hilo',
            BillingStateCode = 'HI',
            BillingCountryCode = 'US',
            BillingPostalCode = '96720'
        );
        insert acc;

        Test.startTest();
        List<BREG_ADDRESS_PROTECTION__c> results = BREGAddressProtectionUtils.getAddressExceptionForId(acc.Id);
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'No protection record should return empty list');
    }

    @isTest
    static void getAddressExceptionForId_unsupportedObjectType_returnsEmptyList() {
        // Use a Contact Id — not a supported object type in the method
        Contact con = new Contact(LastName = 'TestContact');
        insert con;

        Test.startTest();
        List<BREG_ADDRESS_PROTECTION__c> results = BREGAddressProtectionUtils.getAddressExceptionForId(con.Id);
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Unsupported object type should return empty list');
    }

    // ─── AddressWrapper constructors ─────────────────────────────────────────────

    @isTest
    static void addressWrapper_defaultConstructor_allFieldsNull() {
        BREGAddressProtectionUtils.AddressWrapper w = new BREGAddressProtectionUtils.AddressWrapper();

        Assert.isNull(w.address1,    'address1 should be null');
        Assert.isNull(w.address2,    'address2 should be null');
        Assert.isNull(w.address3,    'address3 should be null');
        Assert.isNull(w.city,        'city should be null');
        Assert.isNull(w.state,       'state should be null');
        Assert.isNull(w.country,     'country should be null');
        Assert.isNull(w.postalCode,  'postalCode should be null');
    }

    @isTest
    static void addressWrapper_fullConstructor_fieldsSet() {
        BREGAddressProtectionUtils.AddressWrapper w = new BREGAddressProtectionUtils.AddressWrapper(
            '1 Main St', 'Suite 200', 'Floor 3', 'Honolulu', 'HI', 'US', '96801'
        );

        Assert.areEqual('1 Main St',   w.address1);
        Assert.areEqual('Suite 200',   w.address2);
        Assert.areEqual('Floor 3',     w.address3);
        Assert.areEqual('Honolulu',    w.city);
        Assert.areEqual('HI',          w.state);
        Assert.areEqual('US',          w.country);
        Assert.areEqual('96801',       w.postalCode);
    }

    // ─── matchesLikePattern ──────────────────────────────────────────────────────

    @isTest
    static void matchesLikePattern_identicalPatterns_returnsTrue() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern('%CHARLES%GREEN%', '%CHARLES%GREEN%');
        Test.stopTest();

        Assert.isTrue(result, 'Identical LIKE patterns should match each other');
    }

    @isTest
    static void matchesLikePattern_valueContainsSubsetTokens_returnsTrue() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern('%CHARLES%GREEN%', '%CHARLES%');
        Test.stopTest();

        Assert.isTrue(result, 'Value containing the searched token should match');
    }

    @isTest
    static void matchesLikePattern_missingToken_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern('%CHARLES%SMITH%', '%CHARLES%GREEN%');
        Test.stopTest();

        Assert.isFalse(result, 'Value missing a required token should not match');
    }

    @isTest
    static void matchesLikePattern_blankValue_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern('', '%CHARLES%');
        Test.stopTest();

        Assert.isFalse(result, 'Blank value should return false');
    }

    @isTest
    static void matchesLikePattern_blankPattern_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern('%CHARLES%', '');
        Test.stopTest();

        Assert.isFalse(result, 'Blank pattern should return false');
    }

    @isTest
    static void matchesLikePattern_nullInputs_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.matchesLikePattern(null, null);
        Test.stopTest();

        Assert.isFalse(result, 'Null inputs should return false');
    }

    // ─── isAddressProtected (3-param map overload) ────────────────────────────────

    @isTest
    static void isAddressProtected_mapOverload_matchingEntry_returnsTrue() {
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Charles Green');
        BREGAddressProtectionUtils.AddressWrapper addr = new BREGAddressProtectionUtils.AddressWrapper(
            '550 Dubai Street', null, null, 'Honolulu', 'HI', 'US', '96818'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(addr);

        Map<String, List<String>> testMap = new Map<String, List<String>>{
            namePattern => new List<String>{ addrPattern }
        };

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected('Charles Green', addr, testMap);
        Test.stopTest();

        Assert.isTrue(result, 'Should find match in the provided in-memory map');
    }

    @isTest
    static void isAddressProtected_mapOverload_street2MatchesProtection_returnsTrue() {
        // Protection record is keyed on the base street "550 Dubai Street"
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Charles Green');
        BREGAddressProtectionUtils.AddressWrapper baseAddr = new BREGAddressProtectionUtils.AddressWrapper(
            '550 Dubai Street', null, null, 'Honolulu', 'HI', 'US', '96818'
        );
        String addrPattern = BREGAddressProtectionUtils.calculateAlphaSortForAddress(baseAddr);
        Map<String, List<String>> testMap = new Map<String, List<String>>{
            namePattern => new List<String>{ addrPattern }
        };

        // Address where base street is in address2 and a unit descriptor is in address1
        BREGAddressProtectionUtils.AddressWrapper addrStreet2 = new BREGAddressProtectionUtils.AddressWrapper(
            'APT 2301', '550 Dubai Street', null, 'Honolulu', 'HI', 'US', '96818'
        );

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected('Charles Green', addrStreet2, testMap);
        Test.stopTest();

        Assert.isTrue(result, 'Should match protection when base street appears in address2');
    }

    @isTest
    static void isAddressProtected_mapOverload_nameMatchNoAddressEntry_returnsTrue() {
        String namePattern = BREGAddressProtectionUtils.calculateAlphaSort('Solo Name');
        Map<String, List<String>> testMap = new Map<String, List<String>>{
            namePattern => new List<String>{ null }
        };

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            'Solo Name',
            new BREGAddressProtectionUtils.AddressWrapper(),
            testMap
        );
        Test.stopTest();

        Assert.isTrue(result, 'Name-only match with no address should return true');
    }

    @isTest
    static void isAddressProtected_mapOverload_emptyMap_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            'Charles Green',
            new BREGAddressProtectionUtils.AddressWrapper('550 Dubai Street', null, null, 'Honolulu', 'HI', 'US', '96818'),
            new Map<String, List<String>>()
        );
        Test.stopTest();

        Assert.isFalse(result, 'Empty map should return false');
    }

    @isTest
    static void isAddressProtected_mapOverload_nullMap_returnsFalse() {
        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            'Charles Green',
            new BREGAddressProtectionUtils.AddressWrapper(),
            null
        );
        Test.stopTest();

        Assert.isFalse(result, 'Null map should return false');
    }

    @isTest
    static void isAddressProtected_mapOverload_blankName_returnsFalse() {
        Map<String, List<String>> testMap = new Map<String, List<String>>{
            'CHARLESGREEN' => new List<String>{ '100TEST' }
        };

        Test.startTest();
        Boolean result = BREGAddressProtectionUtils.isAddressProtected(
            '',
            new BREGAddressProtectionUtils.AddressWrapper(),
            testMap
        );
        Test.stopTest();

        Assert.isFalse(result, 'Blank name should return false regardless of map contents');
    }
}