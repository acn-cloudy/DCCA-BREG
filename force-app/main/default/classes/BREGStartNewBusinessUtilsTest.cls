@isTest
private class BREGStartNewBusinessUtilsTest {
    @testSetup
    static void setupData() {
        // Insert an account to simulate duplicate name
        Id bregAccountRtId = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName()
        .get('BREG_Account')
        .getRecordTypeId();

        insert new Account(
            Name = 'Duplicate Corporation Name',
            RecordTypeId = bregAccountRtId,
            breg_Entity_Status__c = 'Active (A)'
        );
    }

    @isTest
    static void testBlankEntityName() {
        String result = BREGStartNewBusinessUtils.validateName('', 'DC-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.ENTITY_NAME_CANNOT_BE_BLANK, result);
    }

    @isTest
    static void testCorpValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Test Business', 'DC-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.CORP_MESSAGE, result);
    }

    @isTest
    static void testLP1ValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Test LimP', 'LP-1', 'L5');
        System.assertEquals(BREGStartNewBusinessUtils.LP_MESSAGE, result);
    }

    @isTest
    static void testLLLPValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Test Limited LLP', 'LP-1', 'Q5');
        System.assertEquals(BREGStartNewBusinessUtils.LLLP_MESSAGE, result);
    }

    @isTest
    static void testLLCValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Ordinary Business Name', 'LLC-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.LLC_MESSAGE, result);
    }

    @isTest
    static void testLLPValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Ordinary Business Name', 'LLP-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.LLP_MESSAGE, result);
    }

    @isTest
    static void testCONSValidationFails() {
        String result = BREGStartNewBusinessUtils.validateName('Neighborhood Association Name', 'CONS-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.CONS_MESSAGE, result);
    }

    @isTest
    static void testDuplicateName() {
        String result = BREGStartNewBusinessUtils.validateName('Duplicate Corporation Name', 'DC-1', '');
        System.assertEquals(BREGStartNewBusinessUtils.ENTITY_NAME_ALREADY_EXISTS, result);
    }

    @isTest
    static void testValidCorpName() {
        String result = BREGStartNewBusinessUtils.validateName('Example Corporation', 'DC-1', '');
        System.assertEquals('', result);
    }

    @isTest
    static void testGetAccountsByName() {
        List<Account> results = BREGStartNewBusinessUtils.getAccountsByName('Duplicate Corporation Name');
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetAccountsByName_Blank() {
        List<Account> results = BREGStartNewBusinessUtils.getAccountsByName('');
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testValidateStreet_ValidStreetInOahu() {
        // Assumes '96813' is an Oahu postal code in the custom label
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'US', '96813', '123 Main Street');
        System.assertEquals('', result, 'Valid street address in Oahu should pass validation');
    }

    @isTest
    static void testValidateStreet_POBoxInOahu() {
        // Assumes '96813' is an Oahu postal code in the custom label
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'US', '96813', 'PO Box 123');
        System.assertEquals('A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.', result);
    }

    @isTest
    static void testValidateStreet_POBoxVariationsInOahu() {
        // Test various PO Box formats in Oahu
        String postalCode = '96813'; // Oahu postal code

        System.assertEquals(
            'A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.',
            BREGStartNewBusinessUtils.validateStreet('HI', 'US', postalCode, 'P.O. Box 456'),
            'P.O. Box format should be detected'
        );

        System.assertEquals(
            'A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.',
            BREGStartNewBusinessUtils.validateStreet('HI', 'US', postalCode, 'P O Box 789'),
            'P O Box format should be detected'
        );

        System.assertEquals(
            'A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.',
            BREGStartNewBusinessUtils.validateStreet('HI', 'US', postalCode, 'po box 999'),
            'Lowercase po box should be detected'
        );

        System.assertEquals(
            'A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.',
            BREGStartNewBusinessUtils.validateStreet('HI', 'US', postalCode, 'Box PO 111'),
            'Box PO format should be detected'
        );
    }

    @isTest
    static void testValidateStreet_POBoxOutsideOahu() {
        // Assumes '96720' is a Hawaii but non-Oahu postal code
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'US', '96720', 'PO Box 123');
        System.assertEquals('', result, 'PO Box should be allowed outside Oahu');
    }

    @isTest
    static void testValidateStreet_POBoxOutsideHawaii() {
        String result = BREGStartNewBusinessUtils.validateStreet('CA', 'US', '90210', 'PO Box 456');
        System.assertEquals('', result, 'PO Box should be allowed outside Hawaii');
    }

    @isTest
    static void testValidateStreet_POBoxOutsideUS() {
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'CA', '96813', 'PO Box 789');
        System.assertEquals('', result, 'PO Box should be allowed for non-US country');
    }

    @isTest
    static void testValidateStreet_BlankStreet() {
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'US', '96813', '');
        System.assertEquals('', result, 'Blank street should not trigger PO Box validation');
    }

    @isTest
    static void testValidateStreet_NullStreet() {
        String result = BREGStartNewBusinessUtils.validateStreet('HI', 'US', '96813', null);
        System.assertEquals('', result, 'Null street should not trigger PO Box validation');
    }

    // ========== validatePostalCode Tests ==========

    @isTest
    static void testValidatePostalCode_ValidHawaiiCode() {
        // Assumes '96813' is in the Hawaii postal codes custom label
        String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'US', '96813');
        System.assertEquals('', result, 'Valid Hawaii postal code should pass validation');
    }

    @isTest
    static void testValidatePostalCode_InvalidHawaiiCode() {
        // Using a non-Hawaii postal code for Hawaii state
        String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'US', '90210');
        System.assertEquals('Invalid postal code for Hawaii.', result);
    }

    @isTest
    static void testValidatePostalCode_BlankPostalCode() {
        String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'US', '');
        System.assertEquals('Invalid postal code for Hawaii.', result);
    }

    @isTest
    static void testValidatePostalCode_NullPostalCode() {
        String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'US', null);
        System.assertEquals('Invalid postal code for Hawaii.', result);
    }

    @isTest
    static void testValidatePostalCode_NonHawaiiState() {
        // Postal code validation only applies to Hawaii
        String result = BREGStartNewBusinessUtils.validatePostalCode('CA', 'US', '90210');
        System.assertEquals('', result, 'Non-Hawaii state should not validate postal code');
    }

    @isTest
    static void testValidatePostalCode_NonUSCountry() {
        // Postal code validation only applies to US
        String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'CA', '96813');
        System.assertEquals('', result, 'Non-US country should not validate postal code');
    }

    @isTest
    static void testValidatePostalCode_MultipleHawaiiCodes() {
        // Test multiple known Hawaii postal codes
        // Note: Actual codes depend on BREG_HAWAII_POSTAL_CODES custom label
        List<String> hawaiiCodes = new List<String>{ '96813', '96814', '96815', '96816', '96817' };

        for (String code : hawaiiCodes) {
            String result = BREGStartNewBusinessUtils.validatePostalCode('HI', 'US', code);
            // This will pass if the code is in the custom label, fail otherwise
            System.assert(
                result == '' || result == 'Invalid postal code for Hawaii.',
                'Postal code validation should return either empty string or error message for: ' + code
            );
        }
    }
}