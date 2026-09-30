/**
 * @description Test class for QualPhoneFormatter
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualPhoneFormatterTest {
    
    @IsTest
    static void testFormatToE164_USPhone() {
        // Test standard US phone formats
        Test.startTest();
        
        String result1 = QualPhoneFormatter.formatToE164('(555) 123-4567', '1');
        System.assertEquals('+15551234567', result1, 'Should format US phone with parentheses');
        
        String result2 = QualPhoneFormatter.formatToE164('555-123-4567', '1');
        System.assertEquals('+15551234567', result2, 'Should format US phone with dashes');
        
        String result3 = QualPhoneFormatter.formatToE164('5551234567', '1');
        System.assertEquals('+15551234567', result3, 'Should format US phone without formatting');
        
        String result4 = QualPhoneFormatter.formatToE164('15551234567', '1');
        System.assertEquals('+15551234567', result4, 'Should handle phone with country code');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_InternationalPhone() {
        Test.startTest();
        
        // UK phone
        String ukPhone = QualPhoneFormatter.formatToE164('07903568586', '44');
        System.assertEquals('+447903568586', ukPhone, 'Should format UK phone');
        
        // German phone
        String dePhone = QualPhoneFormatter.formatToE164('1234567890', '49');
        System.assertEquals('+491234567890', dePhone, 'Should format German phone');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_LeadingZero() {
        Test.startTest();
        
        // Phone with leading zero (common in some countries)
        String result = QualPhoneFormatter.formatToE164('0555-123-4567', '1');
        System.assertEquals('+15551234567', result, 'Should remove leading zero');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_NullAndEmpty() {
        Test.startTest();
        
        String nullResult = QualPhoneFormatter.formatToE164(null, '1');
        System.assertEquals(null, nullResult, 'Should return null for null input');
        
        String emptyResult = QualPhoneFormatter.formatToE164('', '1');
        System.assertEquals(null, emptyResult, 'Should return null for empty input');
        
        String blankResult = QualPhoneFormatter.formatToE164('   ', '1');
        System.assertEquals(null, blankResult, 'Should return null for blank input');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_DefaultCountryCode() {
        Test.startTest();
        
        // Use default country code (US)
        String result = QualPhoneFormatter.formatToE164('5551234567');
        System.assertEquals('+15551234567', result, 'Should use default US country code');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_InvalidPhone() {
        Test.startTest();
        
        // Too short
        String shortResult = QualPhoneFormatter.formatToE164('123', '1');
        System.assertEquals(null, shortResult, 'Should return null for too short phone');
        
        // Non-numeric
        String nonNumericResult = QualPhoneFormatter.formatToE164('abc-def-ghij', '1');
        System.assertEquals(null, nonNumericResult, 'Should return null for non-numeric');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFormatToE164_PhoneWithPlusPrefix() {
        Test.startTest();

        String result = QualPhoneFormatter.formatToE164('+15551234567', '1');
        System.assertEquals('+15551234567', result, 'Should handle phone already containing + prefix');

        Test.stopTest();
    }

    @IsTest
    static void testFormatToE164_NullCountryCode() {
        Test.startTest();

        String result = QualPhoneFormatter.formatToE164('5551234567', null);
        System.assertEquals('+15551234567', result, 'Should default to country code 1 when null');

        Test.stopTest();
    }

    @IsTest
    static void testFormatToE164_BlankCountryCode() {
        Test.startTest();

        String result = QualPhoneFormatter.formatToE164('5551234567', '');
        System.assertEquals('+15551234567', result, 'Should default to country code 1 when blank');

        Test.stopTest();
    }

    @IsTest
    static void testFormatToE164_VeryLongPhone() {
        Test.startTest();

        // 20-digit number — exceeds E.164 max but formatToE164 doesn't enforce upper bound
        String result = QualPhoneFormatter.formatToE164('12345678901234567890', '1');
        System.assertNotEquals(null, result, 'Should return a value for very long phone');
        System.assert(result.startsWith('+'), 'Should start with +');

        Test.stopTest();
    }

    @IsTest
    static void testIsValidE164() {
        Test.startTest();
        
        // Valid E.164
        System.assertEquals(true, QualPhoneFormatter.isValidE164('+15551234567'), 'Should validate US E.164');
        System.assertEquals(true, QualPhoneFormatter.isValidE164('+447903568586'), 'Should validate UK E.164');
        
        // Invalid E.164
        System.assertEquals(false, QualPhoneFormatter.isValidE164('5551234567'), 'Should reject without plus');
        System.assertEquals(false, QualPhoneFormatter.isValidE164('+123'), 'Should reject too short');
        System.assertEquals(false, QualPhoneFormatter.isValidE164(null), 'Should reject null');
        System.assertEquals(false, QualPhoneFormatter.isValidE164(''), 'Should reject empty');
        System.assertEquals(false, QualPhoneFormatter.isValidE164('+0551234567'), 'Should reject leading zero after plus');
        
        Test.stopTest();
    }
}