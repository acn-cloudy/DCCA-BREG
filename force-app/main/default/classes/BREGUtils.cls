public with sharing class BREGUtils {
    // Cache for form settings loaded via SOQL (getAll() truncates fields at 255 chars)
    private static Map<String, BREG_Form_Setting__mdt> formSettingsCache;
    private static final BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
    private static final String authSalt = setting.COGS_Authorization_Code_Hash_Salt__c;
    private static final Integer authLength = (Integer) setting.Authorization_Code_Length__c;

    public static final List<String> DISSOLUTION_DECREE_GROUP_ORDER = new List<String>{
        'K5, K6',
        'C6',
        'C5',
        'D2, D9, A2, C2',
        'D1, P1, A1, C1, S1',
        'F1, F2',
        'G5, G6, L5, L6, Q5, Q6'
    };

    public static final Map<String, String> ENTITY_TYPE_TO_DISSOLUTION_DECREE_GROUP = new Map<String, String>{
        'K5' => 'K5, K6',
        'K6' => 'K5, K6',
        'C6' => 'C6',
        'C5' => 'C5',
        'D2' => 'D2, D9, A2, C2',
        'D9' => 'D2, D9, A2, C2',
        'A2' => 'D2, D9, A2, C2',
        'C2' => 'D2, D9, A2, C2',
        'D1' => 'D1, P1, A1, C1, S1',
        'P1' => 'D1, P1, A1, C1, S1',
        'A1' => 'D1, P1, A1, C1, S1',
        'C1' => 'D1, P1, A1, C1, S1',
        'S1' => 'D1, P1, A1, C1, S1',
        'F1' => 'F1, F2',
        'F2' => 'F1, F2',
        'G5' => 'G5, G6, L5, L6, Q5, Q6',
        'G6' => 'G5, G6, L5, L6, Q5, Q6',
        'L5' => 'G5, G6, L5, L6, Q5, Q6',
        'L6' => 'G5, G6, L5, L6, Q5, Q6',
        'Q5' => 'G5, G6, L5, L6, Q5, Q6',
        'Q6' => 'G5, G6, L5, L6, Q5, Q6'
    };

    public static final Map<String, String> DISSOLUTION_DECREE_TEMPLATE_NAME_BY_GROUP = new Map<String, String>{
        'K5, K6' => 'K5,K6 - Certificate of Revocation - Template.docx',
        'C6' => 'C6 - Certificate of Revocation - Template.docx',
        'C5' => 'C5 - Decree of Termination - Template.docx',
        'D2, D9, A2, C2' => 'D2,D9,A2,C2 - Decree of Dissolution - Template.docx',
        'D1, P1, A1, C1, S1' => 'D1,P1,A1,C1,S1 - Decree of Dissolution - Template.docx',
        'F1, F2' => 'F1,F2 - Certificate of Revocation - Template.docx',
        'G5, G6, L5, L6, Q5, Q6' => 'G5,G6,L5,L6,Q5,Q6 - Order of Cancellation - Template.docx'
    };

    // Lazy-loaded form code lists
    private static List<String> nbrFormCodes;
    private static List<String> nbrFormCodesWithStock;
    private static List<String> tntmsmFormCodes;
    private static List<String> nameReservationFormCodes;
    private static List<String> mergerFormCodes;
    private static List<String> annualFormCodes;
    private static List<String> changeFormCodes;
    private static List<String> craRegistrationFormCodes;
    private static List<String> withdrawalFormCodes;

    private static Id logDocGenRecordTypeId;
    private static Id logErrorRecordTypeId;

    /**
     * @description Loads form settings via SOQL to get full field values (getAll() truncates at 255 chars)
     * @return Map of DeveloperName to BREG_Form_Setting__mdt records
     */
    private static Map<String, BREG_Form_Setting__mdt> getFormSettings() {
        if (formSettingsCache == null) {
            formSettingsCache = new Map<String, BREG_Form_Setting__mdt>();
            for (BREG_Form_Setting__mdt setting : [
                SELECT DeveloperName, breg_Form_Codes__c
                FROM BREG_Form_Setting__mdt
            ]) {
                formSettingsCache.put(setting.DeveloperName, setting);
            }
        }
        return formSettingsCache;
    }

    /**
     * @description Gets form codes list for a given setting developer name
     * @param developerName The DeveloperName of the form setting
     * @return List of form codes, or empty list if not found
     */
    private static List<String> getFormCodesList(String developerName) {
        BREG_Form_Setting__mdt setting = getFormSettings().get(developerName);
        if (setting != null && String.isNotBlank(setting.breg_Form_Codes__c)) {
            return setting.breg_Form_Codes__c.split(';');
        }
        return new List<String>();
    }

    public static List<String> getNbrFormCodes() {
        if (nbrFormCodes == null) {
            nbrFormCodes = getFormCodesList('NBR_Form_Codes');
        }
        return nbrFormCodes;
    }

    public static List<String> getNbrFormCodesWithStock() {
        if (nbrFormCodesWithStock == null) {
            nbrFormCodesWithStock = getFormCodesList('NBR_Form_Codes_With_Stock');
        }
        return nbrFormCodesWithStock;
    }

    public static List<String> getTntmsmFormCodes() {
        if (tntmsmFormCodes == null) {
            tntmsmFormCodes = getFormCodesList('TNTMSM_Form_Codes');
        }
        return tntmsmFormCodes;
    }

    public static List<String> getNameReservationFormCodes() {
        if (nameReservationFormCodes == null) {
            nameReservationFormCodes = getFormCodesList('NameReservation_Form_Codes');
        }
        return nameReservationFormCodes;
    }

    public static List<String> getMergerFormCodes() {
        if (mergerFormCodes == null) {
            mergerFormCodes = getFormCodesList('Merger_Form_Codes');
        }
        return mergerFormCodes;
    }

    public static List<String> getAnnualFormCodes() {
        if (annualFormCodes == null) {
            annualFormCodes = getFormCodesList('Annual_Form_Codes');
        }
        return annualFormCodes;
    }

    public static List<String> getChangeFormCodes() {
        if (changeFormCodes == null) {
            changeFormCodes = getFormCodesList('Change_Form_Codes');
        }
        return changeFormCodes;
    }

    public static List<String> getCraRegistrationFormCodes() {
        if (craRegistrationFormCodes == null) {
            craRegistrationFormCodes = getFormCodesList('CRA_Registration_Form_Codes');
        }
        return craRegistrationFormCodes;
    }

    public static List<String> getWithdrawalFormCodes() {
        if (withdrawalFormCodes == null) {
            withdrawalFormCodes = getFormCodesList('Withdrawal_Form_Codes');
        }
        return withdrawalFormCodes;
    }

    private static final Map<String, String> SUFFIX_STANDARDIZATION = new Map<String, String>{
        'LLC' => 'LLC',
        'L.L.C.' => 'LLC',
        'L.L.C' => 'LLC',
        'LIMITED LIABILITY COMPANY' => 'LLC',
        'INC' => 'INC',
        'INCORPORATED' => 'INC',
        'CORP' => 'CORP',
        'CORPORATION' => 'CORP',
        'LTD' => 'LTD',
        'LIMITED' => 'LTD',
        'CO' => 'COMPANY',
        'COMPANY' => 'COMPANY',
        'PARTNERSHIP' => 'PARTNERSHIP',
        'LP' => 'LP',
        'LLP' => 'LLP',
        'BRG' => 'BREG'
    };

    // Static cache for picklist value-to-label mappings to avoid repeated Schema.Describe calls
    private static Map<String, Map<String, String>> picklistLabelCache = new Map<String, Map<String, String>>();
    private static Map<String, Boolean> countryHasStatesCache;
    private static final String ADDRESS_PICKLIST_OBJECT_API_NAME = 'Account';
    private static final String ADDRESS_COUNTRY_FIELD_API_NAME = 'BillingCountryCode';
    private static final String ADDRESS_STATE_FIELD_API_NAME = 'BillingStateCode';

    /** Matches legacy attorney-style names: FIRST <LAST< remainder (e.g. FIRST <MUNRO,< SUFFIX). Also accepts ‹ (U+2039) in place of <. */
    private static final Pattern BREG_BRACKET_NAME_REORDER_PATTERN = Pattern.compile('^(.+?)\\s*[<\\u2039]\\s*([^<\\u2039]+?)\\s*[<\u2039]\\s*(.*)$');

    public static Boolean isNBRForm(String formCode) {
        return getNbrFormCodes().contains(formCode);
    }

    public static Boolean isNBRFormWithStock(String formCode) {
        return getNbrFormCodesWithStock().contains(formCode);
    }

    public static Boolean isCRARegistrationForm(String formCode) {
        return getCraRegistrationFormCodes().contains(formCode);
    }

    public static Boolean isTNTMSMForm(String formCode) {
        return getTntmsmFormCodes().contains(formCode);
    }

    public static Boolean isNameReservationForm(String formCode) {
        return getNameReservationFormCodes().contains(formCode);
    }

    public static Boolean isMergerForm(String formCode) {
        return getMergerFormCodes().contains(formCode);
    }

    public static Boolean isAnnualForm(String formCode) {
        return getAnnualFormCodes().contains(formCode);
    }

    public static Boolean isChangeForm(String formCode) {
        return getChangeFormCodes().contains(formCode);
    }

    public static Boolean isWithdrawalForm(String formCode) {
        return getWithdrawalFormCodes().contains(formCode);
    }

    public static String getDissolutionDecreeGroupForEntityType(String entityType) {
        return ENTITY_TYPE_TO_DISSOLUTION_DECREE_GROUP.get(entityType);
    }

    public static String getDissolutionDecreeTemplateName(String groupLabel) {
        String templateName = DISSOLUTION_DECREE_TEMPLATE_NAME_BY_GROUP.get(groupLabel);
        return String.isBlank(templateName) ? groupLabel + '.docx' : templateName;
    }

    @AuraEnabled
    public static String checkFormCategory(String formCode) {
        String formCategory;
        if (isNBRForm(formCode)) {
            formCategory = 'NBR';
        } else if (isTNTMSMForm(formCode)) {
            formCategory = 'TNTMSM';
        } else if (isAnnualForm(formCode)) {
            formCategory = 'Annual';
        } else if (isChangeForm(formCode)) {
            formCategory = 'Change';
        } else if (isNameReservationForm(formCode)) {
            formCategory = 'Name Reservation';
        } else if (isCRARegistrationForm(formCode)) {
            formCategory = 'CRA Registration';
        } else if (isWithdrawalForm(formCode)) {
            formCategory = 'Withdrawal';
        }
        return formCategory;
    }

    public static Id getCommunityUserContactId() {
        Id currentUserId = UserInfo.getUserId();
        Id contactId = [SELECT ContactId FROM User WHERE Id = :currentUserId LIMIT 1].ContactId;

        // if (contactId == null) {
        //     throw new AuraHandledException('Contact not linked to user.');
        // }
        return contactId;
    }

    public static Object getHandlerInstance(String handlerClassName) {
        Type t = Type.forName(handlerClassName);
        if (t == null) {
            throw new BREGUtilsException('Handler class not found: ' + handlerClassName);
        }
        return t.newInstance();
    }

    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Utility class for configuring label field mappings in triggers
     * Maps a source field and optional dependent picklist controller to label fields
     */
    public class LabelFieldConfig {
        public String sourceFieldApiName;
        public String targetLabelFieldApiName;
        public String controllerFieldApiName;
        public Map<String, String> valueToLabelMap;

        public LabelFieldConfig(
            String sourceFieldApiName,
            String targetLabelFieldApiName,
            String controllerFieldApiName,
            Map<String, String> valueToLabelMap
        ) {
            this.sourceFieldApiName = sourceFieldApiName;
            this.targetLabelFieldApiName = targetLabelFieldApiName;
            this.controllerFieldApiName = controllerFieldApiName;
            this.valueToLabelMap = valueToLabelMap;
        }

        public Boolean isDependentPicklist() {
            return String.isNotBlank(controllerFieldApiName);
        }
    }

    /**
     * @description Extracts field values from a list of records
     * @param records List of SObjects to extract values from
     * @param fieldApiName The field API name to extract
     * @return Set of field values as strings
     */
    public static Set<String> extractFieldValuesAsSet(List<SObject> records, String fieldApiName) {
        Set<String> values = new Set<String>();
        if (records == null || String.isBlank(fieldApiName)) {
            return values;
        }

        for (SObject record : records) {
            Object fieldValue = record.get(fieldApiName);
            if (fieldValue != null) {
                values.add(String.valueOf(fieldValue));
            }
        }

        return values;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getEntityTypeOptions() {
        Set<String> uniqueValues = new Set<String>();

        for (breg_Form_Configuration__c config : [
            SELECT breg_Entity_Type__c
            FROM breg_Form_Configuration__c
            WHERE breg_Entity_Type__c != NULL
        ]) {
            uniqueValues.add(config.breg_Entity_Type__c.trim());
        }

        List<PicklistOption> options = new List<PicklistOption>();
        options.add(new PicklistOption('All', 'all'));

        for (String val : uniqueValues) {
            options.add(new PicklistOption(val, val));
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getFormTypeOptions() {
        Set<String> uniqueValues = new Set<String>();
        for (breg_Form_Configuration__c config : [
            SELECT breg_Form_Code__c, breg_Business_Process__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c != NULL AND breg_Form_Code__c != NULL
        ]) {
            uniqueValues.add(config.breg_Form_Code__c.trim());
        }

        List<PicklistOption> options = new List<PicklistOption>();
        options.add(new PicklistOption('All', 'all'));

        for (String val : uniqueValues) {
            options.add(new PicklistOption(val, val));
        }

        return options;
    }

    /**
     * @description Gets a map of all picklist values to labels for a field.
     * @param objectApiName The API name of the object
     * @param fieldApiName The API name of the field
     * @return Map of picklist values to their labels
     */
    public static Map<String, String> getPicklistLabelMap(String objectApiName, String fieldApiName) {
        String cacheKey = objectApiName + '.' + fieldApiName;

        // Return from cache if available
        if (picklistLabelCache.containsKey(cacheKey)) {
            return picklistLabelCache.get(cacheKey);
        }

        // Build and cache the map
        Map<String, String> valueToLabel = new Map<String, String>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            Schema.SObjectField field = fieldMap.get(fieldApiName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();

            for (Schema.PicklistEntry entry : picklistEntries) {
                valueToLabel.put(entry.getValue(), entry.getLabel());
            }
        } catch (Exception e) {
            // Return empty map on error
        }

        picklistLabelCache.put(cacheKey, valueToLabel);
        return valueToLabel;
    }

    /**
     * @description Builds country-state label mapping using key format 'countryCode.stateCode'.
     *              Example: 'US.CA' -> 'California'.
     *              Uses Account.BillingCountryCode (controller) and Account.BillingStateCode (dependent).
     * @param records Records that contain a country code field used to filter the mapping
     * @param recordCountryFieldApiName Country code field API name on input records
     * @return Map key: countryCode.stateCode, value: state label
     */
    public static Map<String, String> getStateLabelMapByCountry(List<SObject> records, String recordCountryFieldApiName) {
        Map<String, String> countryStateToLabelMap = new Map<String, String>();
        if (records == null || String.isBlank(recordCountryFieldApiName)) {
            return countryStateToLabelMap;
        }

        // Collect all country codes present on incoming records to keep mapping focused and small.
        Set<String> countryCodesFromRecords = collectCountryCodesFromRecords(records, recordCountryFieldApiName);
        if (countryCodesFromRecords.isEmpty()) {
            return countryStateToLabelMap;
        }

        return getStateLabelMapByCountrySet(countryCodesFromRecords);
    }

    /**
     * @description Builds country-state label mapping using key format 'countryCode.stateCode'.
     *              Accepts a set of country codes directly for reuse across multiple records/fields.
     *              Example: 'US.CA' -> 'California'.
     *              Uses Account.BillingCountryCode (controller) and Account.BillingStateCode (dependent).
     * @param countryCodesToMap Set of country codes to build state mapping for
     * @return Map key: countryCode.stateCode, value: state label
     */
    public static Map<String, String> getStateLabelMapByCountrySet(Set<String> countryCodesToMap) {
        Map<String, String> countryStateToLabelMap = new Map<String, String>();
        if (countryCodesToMap == null || countryCodesToMap.isEmpty()) {
            return countryStateToLabelMap;
        }

        Map<String, Schema.SObjectField> metadataFieldMap = getAddressMetadataFieldMap();
        if (metadataFieldMap == null) {
            return countryStateToLabelMap;
        }

        Schema.SObjectField countryControllerField = metadataFieldMap.get(ADDRESS_COUNTRY_FIELD_API_NAME);
        Schema.SObjectField stateDependentField = metadataFieldMap.get(ADDRESS_STATE_FIELD_API_NAME);
        if (countryControllerField == null || stateDependentField == null) {
            return countryStateToLabelMap;
        }

        // Build index -> country map so we can decode dependent picklist validFor bits.
        List<Schema.PicklistEntry> countryEntries = countryControllerField.getDescribe().getPicklistValues();
        Map<Integer, String> countryIndexToCodeMap = buildCountryIndexToCodeMap(countryEntries, countryCodesToMap);
        if (countryIndexToCodeMap.isEmpty()) {
            return countryStateToLabelMap;
        }

        // Decode dependent state metadata and map only states valid for selected countries.
        List<Schema.PicklistEntry> stateEntries = stateDependentField.getDescribe().getPicklistValues();
        populateCountryStateLabelMap(countryStateToLabelMap, countryIndexToCodeMap, stateEntries);

        return countryStateToLabelMap;
    }

    private static Set<String> collectCountryCodesFromRecords(List<SObject> records, String recordCountryFieldApiName) {
        Set<String> countryCodes = new Set<String>();
        for (SObject inputRecord : records) {
            if (inputRecord == null) {
                continue;
            }
            Object countryCodeObj = inputRecord.get(recordCountryFieldApiName);
            if (countryCodeObj != null) {
                countryCodes.add(String.valueOf(countryCodeObj));
            }
        }
        return countryCodes;
    }

    private static Map<String, Schema.SObjectField> getAddressMetadataFieldMap() {
        Schema.SObjectType metadataObjectType = Schema.getGlobalDescribe().get(ADDRESS_PICKLIST_OBJECT_API_NAME);
        if (metadataObjectType == null) {
            return null;
        }
        return metadataObjectType.getDescribe().fields.getMap();
    }

    private static Map<Integer, String> buildCountryIndexToCodeMap(List<Schema.PicklistEntry> countryEntries, Set<String> countryCodesFromRecords) {
        Map<Integer, String> countryIndexToCodeMap = new Map<Integer, String>();
        for (Integer countryIndex = 0; countryIndex < countryEntries.size(); countryIndex++) {
            String countryCode = countryEntries[countryIndex].getValue();
            if (countryCodesFromRecords.contains(countryCode)) {
                countryIndexToCodeMap.put(countryIndex, countryCode);
            }
        }
        return countryIndexToCodeMap;
    }

    private static void populateCountryStateLabelMap(
        Map<String, String> countryStateToLabelMap,
        Map<Integer, String> countryIndexToCodeMap,
        List<Schema.PicklistEntry> stateEntries
    ) {
        List<Object> stateEntriesJson = (List<Object>) JSON.deserializeUntyped(JSON.serialize(stateEntries));
        for (Object stateEntryObj : stateEntriesJson) {
            Map<String, Object> stateEntry = (Map<String, Object>) stateEntryObj;
            String stateCode = (String) stateEntry.get('value');
            String stateLabel = (String) stateEntry.get('label');
            String validForBase64 = (String) stateEntry.get('validFor');
            if (String.isBlank(validForBase64)) {
                continue;
            }

            for (Integer countryIndex : countryIndexToCodeMap.keySet()) {
                if (isControllerValueEnabled(validForBase64, countryIndex)) {
                    String key = countryIndexToCodeMap.get(countryIndex) + '.' + stateCode;
                    countryStateToLabelMap.put(key, stateLabel);
                }
            }
        }
    }

    /**
     * @description Gets the label for a picklist value. Uses cached map to avoid repeated Schema.Describe calls.
     * @param objectApiName The API name of the object
     * @param fieldApiName The API name of the field
     * @param picklistValue The picklist value to get the label for
     * @return The label for the picklist value, or the value itself if label not found
     */
    public static String getPicklistLabel(String objectApiName, String fieldApiName, String picklistValue) {
        if (String.isBlank(picklistValue)) {
            return picklistValue;
        }

        Map<String, String> labelMap = getPicklistLabelMap(objectApiName, fieldApiName);
        String label = labelMap.get(picklistValue);
        return label != null ? label : picklistValue;
    }

    /**
     * @description Gets a map of all picklist labels to values for a field.
     * @param objectApiName The API name of the object
     * @param fieldApiName The API name of the field
     * @return Map of picklist labels to their values
     */
    public static Map<String, String> getPicklistLabelToValueMap(String objectApiName, String fieldApiName) {
        Map<String, String> valueToLabel = getPicklistLabelMap(objectApiName, fieldApiName);
        Map<String, String> labelToValue = new Map<String, String>();
        for (String value : valueToLabel.keySet()) {
            labelToValue.put(valueToLabel.get(value), value);
        }
        return labelToValue;
    }

    public static String returnFielLabelByApiName(String objectApiName, String fieldApiName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            Schema.SObjectField field = fieldMap.get(fieldApiName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            return fieldDescribe.getLabel();
        } catch (Exception e) {
            return null;
        }
    }

    class BREGUtilsException extends Exception {
    }
    public static Id getQueueId(String queueName) {
        Group queue = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND Name = :queueName
            LIMIT 1
        ];
        if (queue == null) {
            throw new BREGUtilsException('Queue not found: ' + queueName);
        }
        return queue.Id;
    }

    public static String mapJurisdictionToPicklists(String jurisdiction) {
        if (String.isBlank(jurisdiction))
            return null;

        Set<String> stateValues = new Set<String>();
        for (Schema.PicklistEntry pe : Account.BillingState.getDescribe().getPicklistValues()) {
            stateValues.add(pe.getValue().toLowerCase());
        }

        Set<String> countryValues = new Set<String>();
        for (Schema.PicklistEntry pe : Account.breg_Formation_Country__c.getDescribe().getPicklistValues()) {
            countryValues.add(pe.getValue().toLowerCase());
        }

        String jLower = jurisdiction.toLowerCase().trim();

        if (stateValues.contains(jLower)) {
            return 'State';
        } else if (countryValues.contains(jLower)) {
            return 'Country';
        } else {
            return null;
        }
    }

    /**
     * @description Returns whether a given Billing country has at least one active dependent Billing state.
     *              Uses Account.BillingCountryCode (controller) and Account.BillingStateCode (dependent) metadata.
     * @param countryCode The Billing country code value (e.g., US, CA)
     * @return True if the country has at least one dependent active state; otherwise false
     */
    public static Boolean doesCountryHaveStates(String countryCode) {
        if (String.isBlank(countryCode)) {
            return false;
        }

        if (countryHasStatesCache == null) {
            countryHasStatesCache = buildCountryHasStatesCache();
        }

        return countryHasStatesCache.containsKey(countryCode) ? countryHasStatesCache.get(countryCode) : false;
    }

    private static Map<String, Boolean> buildCountryHasStatesCache() {
        Map<String, Boolean> result = new Map<String, Boolean>();

        Schema.DescribeFieldResult countryDescribe = Account.BillingCountryCode.getDescribe();
        Schema.DescribeFieldResult stateDescribe = Account.BillingStateCode.getDescribe();

        List<Schema.PicklistEntry> countryPicklistEntries = countryDescribe.getPicklistValues();
        for (Schema.PicklistEntry countryEntry : countryPicklistEntries) {
            if (countryEntry.isActive()) {
                result.put(countryEntry.getValue(), false);
            }
        }

        for (Schema.PicklistEntry stateEntry : stateDescribe.getPicklistValues()) {
            if (!stateEntry.isActive()) {
                continue;
            }

            Map<String, Object> stateMetadata = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(stateEntry));
            String validFor = (String) stateMetadata.get('validFor');
            if (String.isBlank(validFor)) {
                continue;
            }

            for (Integer countryIndex = 0; countryIndex < countryPicklistEntries.size(); countryIndex++) {
                Schema.PicklistEntry countryEntry = countryPicklistEntries[countryIndex];
                if (!countryEntry.isActive()) {
                    continue;
                }

                if (isControllerValueEnabled(validFor, countryIndex)) {
                    result.put(countryEntry.getValue(), true);
                }
            }
        }

        return result;
    }

    private static Boolean isControllerValueEnabled(String validFor, Integer controllerIndex) {
        if (String.isBlank(validFor) || controllerIndex == null || controllerIndex < 0) {
            return false;
        }

        String base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        Integer charIndex = controllerIndex / 6;
        if (charIndex >= validFor.length()) {
            return false;
        }

        Integer bitIndex = Math.mod(controllerIndex, 6);
        Integer mask = 1 << (5 - bitIndex);
        Integer charValue = base64Chars.indexOf(validFor.substring(charIndex, charIndex + 1));

        return charValue >= 0 && (charValue & mask) != 0;
    }

    

    public static String normalizeBusinessName(String businessName) {
        if (String.isBlank(businessName)) {
            return '';
        }
        //String normalized = businessName;
        String normalized = applyBracketNameReorder(businessName.trim());

        // Convert to uppercase for case-insensitive comparison
        normalized = normalized.toUpperCase();

        normalized = normalizeHAWAIIANCharacters(normalized);

        // Remove punctuation (keep spaces)
        normalized = normalized.replaceAll('[^A-Z0-9@ ]', ' ');

        // Remove leading "THE "
        normalized = normalized.replaceAll('^THE\\s+', '');

        // Standardize AND / &
        normalized = normalized.replaceAll('\\s+AND\\s+', ' AND ');
        normalized = normalized.replaceAll('\\s*&\\s*', ' AND ');

        // Standardize suffixes
        for (String suffix : SUFFIX_STANDARDIZATION.keySet()) {
            String standardized = SUFFIX_STANDARDIZATION.get(suffix);
            // Match suffix at end of string with word boundaries
            String pattern = '\\b' + Pattern.quote(suffix) + '\\b$';
            normalized = normalized.replaceAll(pattern, standardized);
        }

        // Remove extra whitespace
        normalized = normalized.replaceAll('\\s+', ' ').trim();

        return normalized;
    }

    public static String normalizeVowels(String input) {
        if (String.isBlank(input)) {
            return input;
        }

        String result = input.substring(0, 1);
        Set<String> vowels = new Set<String>{ 'O', 'U' };
        Integer nonWildcardCount = vowels.contains(result) ? 0 : 1;
        for (Integer i = 1; i < input.length(); i++) {
            String ch = input.substring(i, i + 1);
            String previousCh = input.substring(i - 1, i);
            if (vowels.contains(ch) && !previousCh.equals(' ')) {
                result += '?';
            } else {
                result += ch;
                nonWildcardCount++;
            }
        }

        if (nonWildcardCount < 2) {
            return input;
        }
        input = result;
        return input;
    }

    public static Integer countWildcardCharacters(String input) {
        if (String.isBlank(input)) {
            return 0;
        }

        Integer count = 0;
        for (Integer i = 0; i < input.length(); i++) {
            String ch = input.substring(i, i + 1);
            if (ch.equals('?')) {
                count++;
            }
        }
        return count;
    }

    /**
     * @description Normalizes a business or mark name for breg_Search_Name__c to align with legacy
     *              migration rules: optional FIRST &lt;LAST&lt; reorder, Hawaiian okina/macron handling,
     *              Latin accent folding, removal of leading "THE ", stripping punctuation and symbols
     *              (replaced with spaces), and collapsing whitespace.
     * @param businessName The source Name field value
     * @return Normalized search string (Salesforce truncates Text(255) on save if longer)
     */
    public static String cleanBusinessName(String businessName) {
        if (String.isBlank(businessName)) {
            return businessName;
        }

        String normalized = applyBracketNameReorder(businessName.trim());

        // Step 1: Strip all Okina variants AND Step 3 alt macron variant (ˉ U+02C9)
        // Includes: U+02BB, U+02BC, U+FF07, U+2018, U+2019, U+0060, U+00B4, U+0027, U+02C9
        normalized = normalized.replaceAll('[\\u02BB\\u02BC\\uFF07\\u2018\\u2019\\u0060\\u00B4\\u0027\\u02C9]', '');

        // Step 2 & 3: Replace Kahako (macron) vowels & alt macrons with base letters
        // A: Ā (U+0100), ā (U+0101), Ᾱ (U+1FB9)
        normalized = normalized.replaceAll('[\\u0100\\u0101\\u1FB9]', 'A');

        // E: Ē (U+0112), ē (U+0113)
        normalized = normalized.replaceAll('[\\u0112\\u0113]', 'E');

        // I: Ī (U+012A), ī (U+012B), ῑ (U+1FD1)
        normalized = normalized.replaceAll('[\\u012A\\u012B\\u1FD1]', 'I');

        // O: Ō (U+014C), ō (U+014D)
        normalized = normalized.replaceAll('[\\u014C\\u014D]', 'O');

        // U: Ū (U+016A), ū (U+016B)
        normalized = normalized.replaceAll('[\\u016A\\u016B]', 'U');

        // Step 4: Uppercase entire string
        normalized = normalized.toUpperCase();

        // Fold Latin accented letters; strip combining marks (e.g. NFD vowel + U+0304)
        normalized = foldLatinAccentedLettersToAscii(normalized);
        normalized = normalized.replaceAll('\\p{M}', '');

        // Leading "THE " removed
        normalized = normalized.replaceAll('^THE\\s+', '');

        // Punctuation, symbols, and & become word separators; keep A–Z and 0–9 only
        normalized = normalized.replaceAll('[^A-Z0-9]+', ' ');

        // Step 5: Collapse multiple spaces to single space
        normalized = normalized.replaceAll('\\s+', ' ').trim();

        return normalized;
    }

    /**
     * @description Normalizes a business name and removes all whitespace for no-space search fields.
     *              Calls cleanBusinessName() then strips spaces. Result is truncated to 255 characters
     *              to fit Text(255) field limits.
     * @param businessName The source Name field value
     * @return Normalized search string without spaces, max 255 chars; null/blank input returns as-is
     */
    public static String cleanBusinessNameNoSpaces(String businessName) {
        if (businessName == null) {
            return null;
        }
        businessName = businessName.replaceAll('[\'`\u2018\u2019\u02BB\u02BC]S', ' ');
        String cleaned = cleanBusinessName(businessName);
        if (String.isBlank(cleaned)) {
            return cleaned;
        }
        String noSpaces = cleaned.replaceAll('\\s+', '');
        return noSpaces.length() > 255 ? noSpaces.substring(0, 255) : noSpaces;
    }

    /**
     * @description Reorders legacy FIRST &lt;LAST&lt; suffix patterns to LAST FIRST suffix before other normalization.
     * @param trimmedName Name trimmed of leading/trailing whitespace
     * @return Reordered name when the pattern matches; otherwise the original trimmed name
     */
    private static String applyBracketNameReorder(String trimmedName) {
        Matcher bracketMatcher = BREG_BRACKET_NAME_REORDER_PATTERN.matcher(trimmedName);
        if (!bracketMatcher.matches()) {
            return trimmedName;
        }

        String firstPart = bracketMatcher.group(1).trim();
        String lastPart = bracketMatcher.group(2).trim().replaceAll(',\\s*$', '');
        String suffixPart = bracketMatcher.group(3).trim();

        if (String.isBlank(firstPart) || String.isBlank(lastPart)) {
            return trimmedName;
        }

        if (String.isBlank(suffixPart)) {
            return lastPart + ' ' + firstPart;
        }
        return lastPart + ' ' + firstPart + ' ' + suffixPart;
    }

    /**
     * @description Folds common Latin accented letters to ASCII. Expects uppercase input.
     * @param input Uppercase string
     * @return Same string with accented Latin letters replaced by base letters
     */
    private static String foldLatinAccentedLettersToAscii(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        return input
            .replaceAll('[ÀÁÂÃÄÅĀĂǺǍ]', 'A')
            .replaceAll('[ĆĈĊČ]', 'C')
            .replaceAll('[Ď]', 'D')
            .replaceAll('[ĒĔĖĚÈÉÊË]', 'E')
            .replaceAll('[ĜĞĠ]', 'G')
            .replaceAll('[Ĥ]', 'H')
            .replaceAll('[ĨĪĬİÌǏÍÎÏ]', 'I')
            .replaceAll('[Ĵ]', 'J')
            .replaceAll('[Ĺ]', 'L')
            .replaceAll('[ŃŇÑ]', 'N')
            .replaceAll('[ÒÓÔÕÖŌŎŐǑ]', 'O')
            .replaceAll('[ŔŘ]', 'R')
            .replaceAll('[ŚŜŠ]', 'S')
            .replaceAll('[Ť]', 'T')
            .replaceAll('[ÙÚÛÜŨŪŬŮŰǓ]', 'U')
            .replaceAll('[Ŵ]', 'W')
            .replaceAll('[ÝŶŸ]', 'Y')
            .replaceAll('[ŹŻŽ]', 'Z');
    }

    public static Map<Id, Id> getRelatedPayments(Set<Id> caseIds) {
        Map<Id, Id> paymentToCaseIdMap = new Map<Id, Id>();
        if (caseIds == null || caseIds.isEmpty()) {
            return paymentToCaseIdMap;
        }

        Map<Id, pymt__PaymentX__c> latestPaymentByCase = new Map<Id, pymt__PaymentX__c>();

        List<pymt__PaymentX__c> payments = [
            SELECT Id, breg_Case__c, CreatedDate
            FROM pymt__PaymentX__c
            WHERE breg_Case__c IN :caseIds
            ORDER BY CreatedDate DESC
        ];

        for (pymt__PaymentX__c payment : payments) {
            if (!latestPaymentByCase.containsKey(payment.breg_Case__c)) {
                latestPaymentByCase.put(payment.breg_Case__c, payment);
            }
        }

        Set<Id> caseIdsWithoutDirectPayment = new Set<Id>(caseIds);
        caseIdsWithoutDirectPayment.removeAll(latestPaymentByCase.keySet());

        if (!caseIdsWithoutDirectPayment.isEmpty()) {
            for (TransactionLine__c line : [
                SELECT breg_Case__c, Payment__c, Payment__r.CreatedDate
                FROM TransactionLine__c
                WHERE breg_Case__c IN :caseIdsWithoutDirectPayment AND Payment__c != NULL
                ORDER BY Payment__r.CreatedDate DESC
            ]) {
                if (!latestPaymentByCase.containsKey(line.breg_Case__c)) {
                    latestPaymentByCase.put(
                        line.breg_Case__c,
                        new pymt__PaymentX__c(Id = line.Payment__c, breg_Case__c = line.breg_Case__c)
                    );
                }
            }
        }

        for (pymt__PaymentX__c payment : latestPaymentByCase.values()) {
            if (payment.Id != null && payment.breg_Case__c != null) {
                paymentToCaseIdMap.put(payment.Id, payment.breg_Case__c);
            }
        }

        return paymentToCaseIdMap;
    }

    public static Boolean anyFieldInFieldSet(String objectApiName, Set<String> fieldApiNames, String fieldSetName) {
        if (fieldApiNames == null || fieldApiNames.isEmpty())
            return false;

        Set<String> fsFields = getFieldSetFields(objectApiName, fieldSetName);

        for (String fieldName : fieldApiNames) {
            if (!String.isBlank(fieldName) && fsFields.contains(fieldName)) {
                return true;
            }
        }
        return false;
    }

    public static String getBaseUrl() {
        // e.g. https://hi-dcca--pacxadfull.sandbox.my.salesforce.com
        String url = URL.getOrgDomainUrl().toExternalForm();
        // e.g. https://hi-dcca--pacxadfull.sandbox.my.site.com
        return url.replace('salesforce', 'site');
    }

    private static Set<String> getFieldSetFields(String objectApiName, String fieldSetName) {
        Set<String> fields = new Set<String>();

        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectApiName);
        if (t != null) {
            Schema.FieldSet fs = t.getDescribe().fieldSets.getMap().get(fieldSetName);
            if (fs != null) {
                for (Schema.FieldSetMember m : fs.getFields()) {
                    fields.add(m.getFieldPath());
                }
            }
        }

        return fields;
    }

    private static String normalizeHAWAIIANCharacters(String input) {
        if (String.isBlank(input)) {
            return input;
        }

        // Replace common Hawaiian characters with their normalized equivalents
        String output = foldLatinAccentedLettersToAscii(input).replaceAll('[\'`\u2018\u2019\u02BB\u02BC]', '').replaceAll('[^\\p{Alnum}]+', ' ');
        return output;
    }

    public static List<Case> getLinkedGPCasesForLLPCases(Set<Id> llpCaseIds) {
        List<Case> gpCases = new List<Case>();
        if (llpCaseIds == null || llpCaseIds.isEmpty()) {
            return gpCases;
        }

        for (Case gpChildCase : [
            SELECT Id, breg_Form_Code__c, breg_Is_LLP_Registration__c, ParentId, breg_Form_Configuration__c, Origin, breg_Override_Payment__c, breg_Form_Action__c
            FROM Case
            WHERE ParentId IN :llpCaseIds AND breg_Form_Code__c = 'GP-1' AND breg_Is_LLP_Registration__c = TRUE
        ]) {
            gpCases.add(gpChildCase);
        }
        return gpCases;
    }

    public static Integer refreshStaleDocumentGenerationStatuses() {
        return refreshStaleDocumentGenerationStatuses((Set<Id>) null);
    }

    public static Integer refreshStaleDocumentGenerationStatuses(Id recordId) {
        if (recordId == null) {
            return 0;
        }
        return refreshStaleDocumentGenerationStatuses(new Set<Id>{ recordId });
    }


    public static Integer refreshStaleDocumentGenerationStatuses(Set<Id> recordIdsFilter) {
        List<breg_Log__c> activeLogs = getActiveDocumentGenerationLogs(recordIdsFilter);

        if (activeLogs.isEmpty()) {
            return 0;
        }

        Map<Id, breg_Log__c> latestLogByRecordId = getLatestLogByRecordId(activeLogs);
        Map<String, String> workflowIdToActualStatus = getActualStatusesByWorkflowId(activeLogs);
        List<breg_Log__c> logsToUpdate = getWorkflowLogsToUpdate(activeLogs, workflowIdToActualStatus);
        Map<Id, Case> caseIdToUpdateMap = getCasesToUpdateFromLatestLogs(latestLogByRecordId, workflowIdToActualStatus);

        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }
        if (!caseIdToUpdateMap.isEmpty()) {
            List<Case> casesToUpdate = new List<Case>(caseIdToUpdateMap.values());
            update casesToUpdate;
        }

        return logsToUpdate.size();
    }

    private static List<breg_Log__c> getActiveDocumentGenerationLogs() {
        return getActiveDocumentGenerationLogs((Set<Id>) null);
    }

    private static List<breg_Log__c> getActiveDocumentGenerationLogs(Set<Id> recordIdsFilter) {
        Set<String> workflowStatusesToCheck = new Set<String>{ 'Executing', 'Pending', 'Waiting', 'Paused' };

        if (recordIdsFilter != null && !recordIdsFilter.isEmpty()) {
            return [
                SELECT Id, breg_Case__c, breg_Account__c, breg_Workflow_Instance_Id__c, breg_Workflow_Status__c, CreatedDate
                FROM breg_Log__c
                WHERE
                    breg_Type__c = 'Document Generation'
                    AND breg_Workflow_Status__c IN :workflowStatusesToCheck
                    AND breg_Workflow_Instance_Id__c != NULL
                    AND (breg_Case__c IN :recordIdsFilter OR breg_Account__c IN :recordIdsFilter)
                ORDER BY CreatedDate DESC
            ];
        }

        return [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Workflow_Instance_Id__c, breg_Workflow_Status__c, CreatedDate
            FROM breg_Log__c
            WHERE
                breg_Type__c = 'Document Generation'
                AND breg_Workflow_Status__c IN :workflowStatusesToCheck
                AND breg_Workflow_Instance_Id__c != NULL
                AND (breg_Case__c != NULL OR breg_Account__c != NULL)
            ORDER BY CreatedDate DESC
        ];
    }

    private static Map<Id, breg_Log__c> getLatestLogByRecordId(List<breg_Log__c> logs) {
        Map<Id, breg_Log__c> latestByRecordId = new Map<Id, breg_Log__c>();
        for (breg_Log__c logRecord : logs) {
            Id relatedRecordId = getRelatedRecordId(logRecord);
            if (relatedRecordId != null && !latestByRecordId.containsKey(relatedRecordId)) {
                latestByRecordId.put(relatedRecordId, logRecord);
            }
        }
        return latestByRecordId;
    }

    private static Map<String, String> getActualStatusesByWorkflowId(List<breg_Log__c> logs) {
        Map<String, String> workflowIdToActualStatus = new Map<String, String>();
        for (breg_Log__c logRecord : logs) {
            String workflowInstanceId = logRecord.breg_Workflow_Instance_Id__c;
            if (!workflowIdToActualStatus.containsKey(workflowInstanceId)) {
                workflowIdToActualStatus.put(workflowInstanceId, DocuSignAPI.getWorkflowStatus(workflowInstanceId));
            }
        }
        return workflowIdToActualStatus;
    }

    private static List<breg_Log__c> getWorkflowLogsToUpdate(List<breg_Log__c> logs, Map<String, String> workflowIdToActualStatus) {
        List<breg_Log__c> logsToUpdate = new List<breg_Log__c>();
        for (breg_Log__c logRecord : logs) {
            String actualStatus = workflowIdToActualStatus.get(logRecord.breg_Workflow_Instance_Id__c);
            if (!String.isBlank(actualStatus) && actualStatus != logRecord.breg_Workflow_Status__c) {
                logsToUpdate.add(new breg_Log__c(Id = logRecord.Id, breg_Workflow_Status__c = actualStatus));
            }
        }
        return logsToUpdate;
    }

    private static Map<Id, Case> getCasesToUpdateFromLatestLogs(Map<Id, breg_Log__c> latestLogByRecordId, Map<String, String> workflowIdToActualStatus) {
        Map<Id, Case> casesToUpdate = new Map<Id, Case>();
        if (latestLogByRecordId.isEmpty()) {
            return casesToUpdate;
        }

        Set<Id> caseIdsToQuery = new Set<Id>();
        for (breg_Log__c latestLog : latestLogByRecordId.values()) {
            if (latestLog.breg_Case__c != null) {
                caseIdsToQuery.add(latestLog.breg_Case__c);
            }
        }

        if (caseIdsToQuery.isEmpty()) {
            return casesToUpdate;
        }

        Map<Id, Case> currentCasesById = new Map<Id, Case>([
            SELECT Id, breg_Document_Generation_Status__c
            FROM Case
            WHERE Id IN :caseIdsToQuery
        ]);

        for (Id recordId : latestLogByRecordId.keySet()) {
            breg_Log__c latestLog = latestLogByRecordId.get(recordId);
            if (latestLog.breg_Case__c == null) {
                continue;
            }

            Id caseId = latestLog.breg_Case__c;
            String latestActualStatus = workflowIdToActualStatus.get(latestLog.breg_Workflow_Instance_Id__c);
            String mappedCaseStatus = mapWorkflowStatusToCaseStatus(latestActualStatus);
            Case currentCase = currentCasesById.get(caseId);

            if (!String.isBlank(mappedCaseStatus) && currentCase != null && currentCase.breg_Document_Generation_Status__c != mappedCaseStatus) {
                casesToUpdate.put(caseId, new Case(Id = caseId, breg_Document_Generation_Status__c = mappedCaseStatus));
            }
        }

        return casesToUpdate;
    }

    private static Id getRelatedRecordId(breg_Log__c logRecord) {
        if (logRecord == null) {
            return null;
        }

        if (logRecord.breg_Case__c != null) {
            return logRecord.breg_Case__c;
        }

        return logRecord.breg_Account__c;
    }

    public static void completeOldestInProcessDocumentGenerationLogs(List<Case> changedDocumentGenerationStatusCases) {
        if (changedDocumentGenerationStatusCases == null || changedDocumentGenerationStatusCases.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        for (Case caseRecord : changedDocumentGenerationStatusCases) {
            if (caseRecord != null && caseRecord.Id != null) {
                caseIds.add(caseRecord.Id);
            }
        }

        if (caseIds.isEmpty()) {
            return;
        }

        Map<Id, breg_Log__c> oldestInProcessLogByCaseId = new Map<Id, breg_Log__c>();
        for (breg_Log__c logRecord : [
            SELECT Id, breg_Case__c
            FROM breg_Log__c
            WHERE
                breg_Type__c = 'Document Generation'
                AND breg_Case__c IN :caseIds
                AND breg_Workflow_Status__c = 'Executing'
            ORDER BY CreatedDate ASC
        ]) {
            if (!oldestInProcessLogByCaseId.containsKey(logRecord.breg_Case__c)) {
                oldestInProcessLogByCaseId.put(logRecord.breg_Case__c, logRecord);
            }
        }

        if (oldestInProcessLogByCaseId.isEmpty()) {
            return;
        }

        List<breg_Log__c> logsToUpdate = new List<breg_Log__c>();
        for (breg_Log__c logRecord : oldestInProcessLogByCaseId.values()) {
            logsToUpdate.add(new breg_Log__c(Id = logRecord.Id, breg_Workflow_Status__c = 'Completed'));
        }

        update logsToUpdate;
    }

    public static String syncWorkflowLogStatusByInstanceId(String workflowInstanceId) {
        if (String.isBlank(workflowInstanceId)) {
            return null;
        }

        String actualWorkflowStatus = DocuSignAPI.getWorkflowStatus(workflowInstanceId);
        if (String.isBlank(actualWorkflowStatus)) {
            return null;
        }

        List<breg_Log__c> logsToUpdate = new List<breg_Log__c>();
        for (breg_Log__c logRecord : [
            SELECT Id, breg_Workflow_Status__c
            FROM breg_Log__c
            WHERE breg_Workflow_Instance_Id__c = :workflowInstanceId AND breg_Type__c = 'Document Generation'
        ]) {
            if (logRecord.breg_Workflow_Status__c != actualWorkflowStatus) {
                logsToUpdate.add(new breg_Log__c(Id = logRecord.Id, breg_Workflow_Status__c = actualWorkflowStatus));
            }
        }

        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }

        return actualWorkflowStatus;
    }

    private static String getWorkflowInstanceIdFromHref(String href) {
        if (String.isBlank(href)) {
            return null;
        }
        return href.substringAfterLast('/');
    }

    private static String buildWorkflowActivityLink(String workflowInstanceId) {
        if (String.isBlank(workflowInstanceId)) {
            return null;
        }

        breg_Docusign_Auth__mdt authData = breg_Docusign_Auth__mdt.getInstance('DocuSignAuth');
        if (authData == null || String.isBlank(authData.Docusign_API_Account_Id__c)) {
            return null;
        }

        return 'https://uatna11.springcm.com/atlas/workflow/monitorworkflowactivity?aid=' +
            EncodingUtil.urlEncode(authData.Docusign_API_Account_Id__c, 'UTF-8') +
            '&workflowinstanceuid=' + EncodingUtil.urlEncode(workflowInstanceId, 'UTF-8');
    }

    private static String mapWorkflowStatusToCaseStatus(String workflowStatus) {
        if (String.isBlank(workflowStatus)) {
            return null;
        }

        Map<String, String> workflowToCaseStatusMap = new Map<String, String>{
            'Executing' => 'Generation in Process',
            'Pending' => 'Pending',
            'Paused' => 'Paused',
            'Waiting' => 'Pending',
            'Completed' => 'Completed',
            'Failed' => 'Failed'
        };
        return workflowToCaseStatusMap.get(workflowStatus);
    }

    private without sharing class WorkflowLogDmlService {
        public void insertLog(breg_Log__c logRecord) {
            insert logRecord;
        }

        public List<Database.SaveResult> insertLogs(List<breg_Log__c> logRecords) {
            return Database.insert(logRecords, false);
        }

        public void updateLog(breg_Log__c logRecord) {
            update logRecord;
        }

        public void updateCaseStatus(Id caseId, String caseStatus) {
            update new Case(Id = caseId, breg_Document_Generation_Status__c = caseStatus);
        }
    }

    public static Id insertWorkflowsLog(Id recordId, String docusignResponse, String startedFrom) {
        Id logId = createWorkflowLog(recordId, startedFrom);
        updateWorkflowsLog(logId, recordId, docusignResponse);
        return logId;
    }

    public static void createTemplateSettingsExecutionLog(
        Id relatedRecordId,
        String startedFrom,
        String status,
        String errorMessage,
        String stackTrace,
        String level
    ) {
        breg_Log__c newLog = buildTemplateSettingsExecutionLog(
            relatedRecordId,
            startedFrom,
            status,
            errorMessage,
            stackTrace,
            level
        );
        insertTemplateSettingsExecutionLogs(new List<breg_Log__c>{ newLog });
    }

    public static breg_Log__c buildTemplateSettingsExecutionLog(
        Id relatedRecordId,
        String startedFrom,
        String status,
        String errorMessage,
        String stackTrace,
        String level
    ) {
        breg_Log__c newLog = new breg_Log__c();
        newLog.RecordTypeId = getLogErrorRecordTypeId();
        newLog.breg_Level__c = String.isBlank(level) ? 'INFO' : level;
        newLog.breg_Object__c = 'BREG_Docusign_Templates_Setting__mdt';
        newLog.breg_Related_Record_Id__c = relatedRecordId == null ? null : String.valueOf(relatedRecordId);
        newLog.breg_Started_By_User__c = UserInfo.getUserId();
        newLog.breg_Started_From__c = startedFrom;
        newLog.breg_Status__c = String.isBlank(status) ? 'Pending' : status;
        newLog.breg_Type__c = 'Error';
        newLog.breg_Error_Message__c = errorMessage;
        newLog.breg_Stack_Trace__c = stackTrace;
        return newLog;
    }

    public static void insertTemplateSettingsExecutionLogs(List<breg_Log__c> logsToInsert) {
        if (logsToInsert == null || logsToInsert.isEmpty()) {
            return;
        }

        WorkflowLogDmlService dmlService = new WorkflowLogDmlService();
        List<Database.SaveResult> saveResults = dmlService.insertLogs(logsToInsert);

        for (Integer index = 0; index < saveResults.size(); index++) {
            if (saveResults[index].isSuccess()) {
                continue;
            }

            breg_Log__c failedLog = logsToInsert[index];
            for (Database.Error saveError : saveResults[index].getErrors()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Failed to insert template settings execution log. Index=' +
                    index +
                    ', RelatedRecordId=' +
                    failedLog.breg_Related_Record_Id__c +
                    ', Status=' +
                    failedLog.breg_Status__c +
                    ', Error=' +
                    saveError.getStatusCode() +
                    ': ' +
                    saveError.getMessage()
                );
            }
        }
    }

    public static Id createWorkflowLog(Id recordId, String startedFrom) {
        if (recordId == null) {
            return null;
        }

        breg_Log__c newLog = buildDocumentGenerationLog(recordId, startedFrom);

        WorkflowLogDmlService dmlService = new WorkflowLogDmlService();
        dmlService.insertLog(newLog);
        return newLog.Id;
    }

    public static void updateWorkflowsLog(Id logId, Id recordId, String docusignResponse) {
        if (logId == null || recordId == null || String.isBlank(docusignResponse)) {
            return;
        }

        Map<String, Object> responseMap = parseWorkflowResponse(docusignResponse);
        if (responseMap == null) {
            return;
        }

        breg_Log__c logToUpdate = new breg_Log__c(Id = logId);
        populateDocumentGenerationLog(logToUpdate, recordId, responseMap);

        WorkflowLogDmlService dmlService = new WorkflowLogDmlService();
        dmlService.updateLog(logToUpdate);
        if (recordId.getSObjectType() == Case.sObjectType) {
            String mappedCaseStatus = mapWorkflowStatusToCaseStatus((String) responseMap.get('Status'));

            if (!String.isBlank(mappedCaseStatus)) {
                Boolean previousDisableTrigger = TriggerUtils.disableTrigger;
                TriggerUtils.disableTrigger = true;
                try {
                    dmlService.updateCaseStatus(recordId, mappedCaseStatus);
                } finally {
                    TriggerUtils.disableTrigger = previousDisableTrigger;
                }
            }
        }
    }

    private static void populateDocumentGenerationLog(
        breg_Log__c log,
        Id recordId,
        Map<String, Object> responseMap
    ) {
        if (log == null || recordId == null || responseMap == null) {
            return;
        }

        applyDocumentGenerationLogRecordLink(log, recordId);
        String workflowStatus = (String) responseMap.get('Status');
        String workflowInstanceId = getWorkflowInstanceIdFromHref((String) responseMap.get('Href'));
        log.breg_Workflow_Name__c = (String) responseMap.get('Name');
        log.breg_Workflow_Status__c = workflowStatus;
        log.breg_Workflow_Instance_Id__c = workflowInstanceId;
        log.breg_Workflow_Activity_Link__c = buildWorkflowActivityLink(workflowInstanceId);
    }

    private static Map<String, Object> parseWorkflowResponse(String docusignResponse) {
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(docusignResponse);
        } catch (Exception e) {
            return null;
        }
    }
    private static Id getLogDocGenRecordTypeId() {
        if (logDocGenRecordTypeId == null) {
            logDocGenRecordTypeId = Schema.SObjectType.breg_Log__c.getRecordTypeInfosByName().get('Document Generation log').getRecordTypeId();
        }
        return logDocGenRecordTypeId;
    }

    private static Id getLogErrorRecordTypeId() {
        if (logErrorRecordTypeId == null) {
            logErrorRecordTypeId = Schema.SObjectType.breg_Log__c.getRecordTypeInfosByDeveloperName().get('breg_Error_Log').getRecordTypeId();
        }
        return logErrorRecordTypeId;
    }

    private static breg_Log__c buildDocumentGenerationLog(Id recordId, String startedFrom) {
        breg_Log__c log = new breg_Log__c();
        log.breg_Type__c = 'Document Generation';
        log.breg_Workflow_Status__c = 'Pending';
        log.RecordTypeId = getLogDocGenRecordTypeId();
        applyDocumentGenerationLogRecordLink(log, recordId);
        log.breg_Started_By_User__c = UserInfo.getUserId();
        log.breg_Started_From__c = startedFrom;

        return log;
    }

    private static void applyDocumentGenerationLogRecordLink(breg_Log__c log, Id recordId) {
        if (recordId.getSObjectType() == Case.sObjectType) {
            log.breg_Case__c = recordId;
        } else if (recordId.getSObjectType() == Account.sObjectType) {
            log.breg_Account__c = recordId;
        }
    }

    @InvocableMethod(label='Generate Auth Code' description='Generates an authentication code for a given certificate record.')
     public static List<String> generateAuthCode(List<breg_Certificate__c> certs) {
        List<String> authCodes = new List<String>();
        authCodes.add(generateAuthCode(certs[0]));
        return authCodes;
    }

    public static String generateAuthCode(breg_Certificate__c cert) {
        Integer numberOfSymbolsFromEnd = 2;
        String publishedDate = cert.breg_Published_Timestamp__c.format('yyyy-MM-dd');
        String stringToConvert = cert.Id + publishedDate + authSalt;
        Blob targetBlob = Blob.valueOf(stringToConvert);
        Blob hash = Crypto.generateDigest('MD5', targetBlob);
        String convertedString = EncodingUtil.base64Encode(hash);
        Integer endIndex = convertedString.length() - numberOfSymbolsFromEnd;
        Integer startIndex = endIndex - authLength;
        String authCode = convertedString.substring(startIndex, endIndex);
        return authCode;
    }
}