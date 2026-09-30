/**
 * @description Utility class for formatting phone numbers to E.164 format
 * @author Qualtrics Integration Team
 */
public with sharing class QualPhoneFormatter {
    
    private static final String PLUS_SIGN = '+';
    private static final Pattern DIGITS_ONLY = Pattern.compile('[^0-9]');
    
    /**
     * @description Format phone number to E.164 format (+1XXXXXXXXXX)
     * @param phone Raw phone number
     * @param countryCode Default country code (without +)
     * @return Formatted phone number or null if invalid
     */
    public static String formatToE164(String phone, String countryCode) {
        if (String.isBlank(phone)) {
            return null;
        }
        
        // Remove all non-digit characters
        String digitsOnly = DIGITS_ONLY.matcher(phone).replaceAll('');
        
        if (String.isBlank(digitsOnly)) {
            return null;
        }
        
        // Remove leading zero if present (common in some countries)
        if (digitsOnly.startsWith('0') && digitsOnly.length() > 1) {
            digitsOnly = digitsOnly.substring(1);
        }
        
        // Determine if country code is already present
        String defaultCode = String.isBlank(countryCode) ? '1' : countryCode;
        
        // If number starts with country code, don't add it again
        if (!digitsOnly.startsWith(defaultCode)) {
            // For US/Canada (country code 1), check if it's a 10-digit number
            if (defaultCode == '1' && digitsOnly.length() == 10) {
                digitsOnly = defaultCode + digitsOnly;
            } else if (defaultCode != '1' && digitsOnly.length() < 12) {
                // For other countries, prepend if number seems to be national format
                digitsOnly = defaultCode + digitsOnly;
            }
        }
        
        // Validate minimum length (country code + some digits)
        if (digitsOnly.length() < 7) {
            return null;
        }
        
        return PLUS_SIGN + digitsOnly;
    }
    
    /**
     * @description Format phone with default US country code
     * @param phone Raw phone number
     * @return Formatted phone number
     */
    public static String formatToE164(String phone) {
        return formatToE164(phone, '1');
    }
    
    /**
     * @description Validate if phone is already in E.164 format
     * @param phone Phone number to validate
     * @return True if valid E.164 format
     */
    public static Boolean isValidE164(String phone) {
        if (String.isBlank(phone)) {
            return false;
        }
        
        // E.164 format: + followed by 7-15 digits
        Pattern e164Pattern = Pattern.compile('^\\+[1-9]\\d{6,14}$');
        return e164Pattern.matcher(phone).matches();
    }
}