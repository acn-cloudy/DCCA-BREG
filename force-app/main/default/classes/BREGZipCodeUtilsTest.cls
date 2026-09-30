@IsTest
private class BREGZipCodeUtilsTest {
    // ─── getStateCodeById ────────────────────────────────────────────────────

    @IsTest
    static void testGetStateCodeByIdReturnsStateCode() {
        String result = BREGZipCodeUtils.getStateCodeById(825);
        System.assertEquals('HI', result, 'Id 825 should map to state code HI');
    }

    @IsTest
    static void testGetStateCodeByIdCanadianProvince() {
        String result = BREGZipCodeUtils.getStateCodeById(881);
        System.assertEquals('ON', result, 'Id 881 should map to state code ON');
    }

    @IsTest
    static void testGetStateCodeByIdAustralianState() {
        String result = BREGZipCodeUtils.getStateCodeById(924);
        System.assertEquals('VIC', result, 'Id 924 should map to state code VIC');
    }

    @IsTest
    static void testGetStateCodeByIdNegativeId() {
        String result = BREGZipCodeUtils.getStateCodeById(-1);
        System.assertEquals('NL', result, 'Id -1 (NO LOCALITY) should map to state code NL');
    }

    @IsTest
    static void testGetStateCodeByIdUnknownIdReturnsNull() {
        String result = BREGZipCodeUtils.getStateCodeById(99999);
        System.assertEquals(null, result, 'Unknown id should return null');
    }

    @IsTest
    static void testGetStateCodeByIdNullReturnsNull() {
        String result = BREGZipCodeUtils.getStateCodeById(null);
        System.assertEquals(null, result, 'Null id should return null');
    }

    // ─── getCountryByStateCode ───────────────────────────────────────────────

    @IsTest
    static void testGetCountryByStateCodeUSState() {
        String result = BREGZipCodeUtils.getCountryByStateCode('HI');
        System.assertEquals('US', result, 'State HI should map to country US');
    }

    @IsTest
    static void testGetCountryByStateCodeCanadianProvince() {
        String result = BREGZipCodeUtils.getCountryByStateCode('ON');
        System.assertEquals('CA', result, 'State ON should map to country CA');
    }

    @IsTest
    static void testGetCountryByStateCodeAustralianState() {
        String result = BREGZipCodeUtils.getCountryByStateCode('VIC');
        System.assertEquals('AU', result, 'State VIC should map to country AU');
    }

    @IsTest
    static void testGetCountryByStateCodeUnknownReturnsNull() {
        String result = BREGZipCodeUtils.getCountryByStateCode('ZZ');
        System.assertEquals(null, result, 'Unknown state code should return null');
    }

    @IsTest
    static void testGetCountryByStateCodeNullReturnsNull() {
        String result = BREGZipCodeUtils.getCountryByStateCode(null);
        System.assertEquals(null, result, 'Null state code should return null');
    }

    @IsTest
    static void testGetCountryByStateCodeBlankReturnsNull() {
        String result = BREGZipCodeUtils.getCountryByStateCode('   ');
        System.assertEquals(null, result, 'Blank state code should return null');
    }

    // ─── STATE_DATA completeness ─────────────────────────────────────────────

    @IsTest
    static void testStateDataIsNotEmpty() {
        System.assert(!BREGZipCodeUtils.STATE_DATA.isEmpty(), 'STATE_DATA should not be empty');
    }

    @IsTest
    static void testStateDataContainsExpectedEntryCount() {
        // 85 entries as defined in the class
        System.assertEquals(85, BREGZipCodeUtils.STATE_DATA.size(), 'STATE_DATA should have 85 entries');
    }

    @IsTest
    static void testStateEntryFieldsArePopulated() {
        BREGZipCodeUtils.StateEntry entry = BREGZipCodeUtils.STATE_DATA[0];
        System.assertNotEquals(null, entry.id, 'StateEntry.id should not be null');
        System.assertNotEquals(null, entry.name, 'StateEntry.name should not be null');
        System.assertNotEquals(null, entry.stateCode, 'StateEntry.stateCode should not be null');
        System.assertNotEquals(null, entry.countryCode, 'StateEntry.countryCode should not be null');
    }
}