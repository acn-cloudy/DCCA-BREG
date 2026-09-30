public with sharing class BREGStartNewBusinessUtils {
    public static final Integer MAX_NAME_LENGTH = 80;
    public static final List<String> CORP_FORMS = new List<String>{ 'DC-1', 'DC-2', 'PC-1', 'SBC-1', 'D1', 'P1', 'S1' };
    public static final List<String> LP_FORMS = new List<String>{ 'LP-1', 'L5' };
    public static final List<String> LLLP_FORMS = new List<String>{ 'LP-1', 'Q5' };
    public static final List<String> LLC_FORMS = new List<String>{ 'LLC-1', 'LLC-2', 'C5' };
    public static final List<String> LLP_FORMS = new List<String>{ 'LLP-1', 'K5' };
    public static final List<String> CONS_FORMS = new List<String>{ 'CONS-1', 'C1', 'C2' };
    public static final String CORP_MESSAGE = 'The name must contain either the words "Corporation" or "Incorporated" or "Limited" or the abbreviation Corp., or Inc., or Ltd.';
    public static final String LP_MESSAGE = 'The name must contain either the word "Limited Partnership" or the abbreviation ""L.P." or "LP"';
    public static final String LLLP_MESSAGE = 'The name must contain either the word "Limited Liability Limited Partnership" or the abbreviation "L.L.L.P." or "LLLP"';
    public static final String LLC_MESSAGE = 'The name must contain either the words "Limited Liability Company" or "Limited Liability Law Company" or the abbreviation "L.L.C." or "LLC" or "L.L.L.C." or "LLLC"';
    public static final String LLP_MESSAGE = 'The name must contain either the words "Registered Limited Liability Partnership", "Limited Liability Law Partnership", "Limited Liability Partnership" or the abbreviation "R.L.L.P.", "L.L.P.", "RLLP", or "LLP" ';
    public static final String CONS_MESSAGE = 'The name of the association shall contain the term “cooperative” or "coop.", "co-op"';
    public static final String ENTITY_NAME_CANNOT_BE_BLANK = 'Name cannot be blank.';
    public static final String FORM_NAME_CANNOT_BE_BLANK = 'Form name cannot be blank.';
    public static final String ENTITY_NAME_TOO_LONG = 'Entity name cannot exceed 80 characters.';
    public static final String ENTITY_NAME_ALREADY_EXISTS = 'An account with this name already exists.';
    public static final String COMPLETED_STATUS = 'Completed';

    public static final Set<String> HAWAII_POSTAL_CODES = getPostalCodesFromLabel(System.Label.BREG_HAWAII_POSTAL_CODES);
    public static final Set<String> OAHU_POSTAL_CODES = getPostalCodesFromLabel(System.Label.BREG_OAHU_POSTAL_CODES);

    public static final List<String> PO_BOX_POSSIBLE_VALUES = new List<String>{ 'POBOX', 'BOXPO' }; // Spaces and punctuation are removed before checking

    public BREGStartNewBusinessUtils() {
    }

    public static String validateName(String entityName, String formCode, String entityType) {
        return validateName(entityName, formCode, entityType, null);
    }
    @AuraEnabled(cacheable=false)
    public static String validateName(String entityName, String formCode, String entityType, String caseStatus) {
        String errorMessage = '';
        if (String.isBlank(entityName)) {
            errorMessage = ENTITY_NAME_CANNOT_BE_BLANK;
        } else if (String.isBlank(formCode)) {
            errorMessage = ENTITY_NAME_CANNOT_BE_BLANK;
        } else if (entityName.length() > MAX_NAME_LENGTH) {
            throw new AuraHandledException(ENTITY_NAME_TOO_LONG);
        } else if (
            (CORP_FORMS.contains(formCode) || CORP_FORMS.contains(entityType)) &&
            !entityName.toUpperCase().contains('CORPORATION') &&
            !entityName.toUpperCase().contains('INCORPORATED') &&
            !entityName.toUpperCase().contains('LIMITED') &&
            !entityName.toUpperCase().contains('CORP.') &&
            !entityName.toUpperCase().contains('INC.') &&
            !entityName.toUpperCase().contains('LTD.')
        ) {
            errorMessage = CORP_MESSAGE;
        } else if (
            (LP_FORMS.contains(formCode) || LP_FORMS.contains(entityType)) &&
            entityType != null &&
            entityType == 'L5' &&
            !entityName.toUpperCase().contains('LIMITED PARTNERSHIP') &&
            !entityName.toUpperCase().contains('L.P.') &&
            !entityName.toUpperCase().contains('LP')
        ) {
            errorMessage = LP_MESSAGE;
        } else if (
            (LLLP_FORMS.contains(formCode) || LLLP_FORMS.contains(entityType)) &&
            entityType != null &&
            entityType == 'Q5' &&
            !entityName.toUpperCase().contains('LIMITED LIABILITY LIMITED PARTNERSHIP') &&
            !entityName.toUpperCase().contains('L.L.L.P.') &&
            !entityName.toUpperCase().contains('LLLP')
        ) {
            errorMessage = LLLP_MESSAGE;
        } else if (
            (LLC_FORMS.contains(formCode) || LLC_FORMS.contains(entityType)) &&
            !entityName.toUpperCase().contains('LIMITED LIABILITY COMPANY') &&
            !entityName.toUpperCase().contains('LIMITED LIABILITY LAW COMPANY') &&
            !entityName.toUpperCase().contains('L.L.C.') &&
            !entityName.toUpperCase().contains('LLC') &&
            !entityName.toUpperCase().contains('L.L.L.C.') &&
            !entityName.toUpperCase().contains('LLLC')
        ) {
            errorMessage = LLC_MESSAGE;
        } else if (
            (LLP_FORMS.contains(formCode) || LLP_FORMS.contains(entityType)) &&
            !entityName.toUpperCase().contains('REGISTERED LIMITED LIABILITY PARTNERSHIP') &&
            !entityName.toUpperCase().contains('LIMITED LIABILITY LAW PARTNERSHIP') &&
            !entityName.toUpperCase().contains('LIMITED LIABILITY PARTNERSHIP') &&
            !entityName.toUpperCase().contains('R.L.L.P.') &&
            !entityName.toUpperCase().contains('L.L.P.') &&
            !entityName.toUpperCase().contains('RLLP') &&
            !entityName.toUpperCase().contains('LLP')
        ) {
            errorMessage = LLP_MESSAGE;
        } else if (
            (CONS_FORMS.contains(formCode) || CONS_FORMS.contains(entityType)) &&
            !entityName.toUpperCase().contains('COOPERATIVE') &&
            !entityName.toUpperCase().contains('COOP.') &&
            !entityName.toUpperCase().contains('CO-OP')
        ) {
            errorMessage = CONS_MESSAGE;
        } else {
            List<Account> existingAccounts = getAccountsByName(entityName);
            if (
                existingAccounts.size() > 0 &&
                caseStatus != COMPLETED_STATUS &&
                !(
                    formCode == 'LLP-1' &&
                    (
                        existingAccounts[0].breg_Entity_Type__c == 'G5' ||
                        existingAccounts[0].breg_Entity_Type__c == 'G6'
                    )
                )
            ) {
                errorMessage = ENTITY_NAME_ALREADY_EXISTS;
            }
        }
        return errorMessage;
    }
    //should be done without sharing
    public static List<Account> getAccountsByName(String entityName) {
        if (String.isBlank(entityName)) {
            return new List<Account>();
        }

        List<Account> results = [SELECT Id, Name, breg_Entity_Type__c FROM Account WHERE Name = :entityName AND breg_Entity_Status__c = 'Active (A)' AND RecordType.DeveloperName = 'BREG_Account' LIMIT 10];
        //TODO check if need to search in name reservations
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static String validateStreet(String state, String country, String postalCode, String street) {
        String errorMessage = '';

        if (state == 'HI' && country == 'US') {
            // If postal code within O'ahu postal codes -> street must not contain "PO Box"
            if (isOahuPostalCode(postalCode) && containsPOBox(street)) {
                errorMessage = 'A Post Office Box address cannot be entered for the "Initial Street Address" if address is on Oahu.';
            }
        }

        return errorMessage;
    }

    @AuraEnabled(cacheable=false)
    public static String validatePostalCode(String state, String country, String postalCode) {
        String errorMessage = '';

        // If State = HI and Country = US -> postal code must match Hawaii postal codes
        if (state == 'HI' && country == 'US') {
            if (!isValidHawaiiPostalCode(postalCode)) {
                errorMessage = 'Invalid postal code for Hawaii.';
            }
        }

        return errorMessage;
    }

    private static Boolean isValidHawaiiPostalCode(String postalCode) {
        if (String.isBlank(postalCode)) {
            return false;
        }
        return HAWAII_POSTAL_CODES.contains(postalCode);
    }

    private static Boolean isOahuPostalCode(String postalCode) {
        if (String.isBlank(postalCode)) {
            return false;
        }
        return OAHU_POSTAL_CODES.contains(postalCode);
    }

    private static Set<String> getPostalCodesFromLabel(String labelValue) {
        Set<String> codes = new Set<String>();
        if (String.isBlank(labelValue)) {
            return codes;
        }
        for (String code : labelValue.split(',')) {
            String trimmed = code != null ? code.trim() : '';
            if (!String.isBlank(trimmed)) {
                codes.add(trimmed);
            }
        }
        return codes;
    }

    private static Boolean containsPOBox(String street) {
        if (String.isBlank(street)) {
            return false;
        }
        // Remove all non-alphanumeric characters (spaces, dots, commas, hyphens, etc.)
        String cleanedStreet = street.toUpperCase().replaceAll('[^A-Z0-9]', '');

        // Check if the cleaned string contains any PO Box pattern
        for (String poBoxPattern : PO_BOX_POSSIBLE_VALUES) {
            if (cleanedStreet.contains(poBoxPattern)) {
                return true;
            }
        }
        return false;
    }
}