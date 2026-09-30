public with sharing class BREGWebPersons2AccountAffiliations extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_PERSONS__c';
    private static final Map<String, String> MEMBER_ROLE_MAP = new Map<String, String>{ 'AGNT' => 'Agent', 'OFCR' => 'Officer' };
    private static final Map<String, String> TITLE_PICKLIST_LABEL_MAP = BREGUtils.getPicklistLabelMap(
        'breg_Account_Affiliation__c',
        'breg_Officer_Director_Titles__c'
    );

    private static final List<String> AGNT_REG_FORMS = new List<String>{ 'X-7', 'X-8' };
    private static final List<String> APPLICANT_FORMS = new List<String>{ 'X-1' };
    private static final List<String> PARTNERS_FORMS = new List<String>{'ANN-FLLP-1', 'ANN-FLP-1', 'ANN-GP-1', 'ANN-LLP-1', 'ANN-LP-1', 'FLP-1', 'GP-1', 'LP-1', 'X-6'};

    public BREGWebPersons2AccountAffiliations(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            List<String> affiliationNamesToUpdate = new List<String>();
            BREGWebFilingWrapper filingWrapper = wrappersByWorkitemId.get(workitemId);
            //Add active affiliations to filing wrapper and collect names for potential update (in case of existing affiliation with same name but different details, we want to update the existing record instead of creating a new one)
            for (SObject record : records) {
                breg_WEB_WEB_PERSONS__c person = (breg_WEB_WEB_PERSONS__c) record;
                if (person.breg_WEB_WEB_ACTION_CODE__c == 'A' || person.breg_WEB_WEB_ACTION_CODE__c == 'N' || person.breg_WEB_WEB_ACTION_CODE__c == 'R') {
                    // Only active affiliations should be considered
                    filingWrapper.AccountAffiliations.add(buildAffiliationWrapper(person));
                    affiliationNamesToUpdate.add(person.breg_WEB_PERSON_NAME__c?.replace(', ', ',') + '_' + person.breg_WEB_PERSON_TYPE__c); // Use combination of name and type to handle potential duplicates with same name but different types (individual vs entity)
                }
            }
            //
            for (SObject record : records) {
                breg_WEB_WEB_PERSONS__c person = (breg_WEB_WEB_PERSONS__c) record;
                if (
                    (person.breg_WEB_WEB_ACTION_CODE__c == 'D' &&
                    !affiliationNamesToUpdate.contains(person.breg_WEB_PERSON_NAME__c?.replace(', ', ',') + '_' + person.breg_WEB_PERSON_TYPE__c)) ||
                    person.breg_WEB_WEB_ACTION_CODE__c == 'X'
                ) {
                    // Only active affiliations should be considered
                    BREGWebAccountAffiliationWrapper wrapper = buildAffiliationWrapper(person);
                    wrapper.accountAffiliation.breg_To_Remove__c = true; // Mark as Inactive for deletions
                    filingWrapper.AccountAffiliations.add(wrapper);
                }
            }
        }

        // Collect entity IDs from Cases linked to each filing wrapper
        Set<Id> entityIds = new Set<Id>();
        for (String workitemId : wrappersByWorkitemId.keySet()) {
            BREGWebFilingWrapper wrapper = wrappersByWorkitemId.get(workitemId);
            if (wrapper.WebCase != null && wrapper.WebCase.breg_Entity__c != null) {
                entityIds.add(wrapper.WebCase.breg_Entity__c);
            }
        }

        if (entityIds.isEmpty()) {
            return resultsByWorkitemId;
        }

        // Query existing active affiliations for those entities to resolve Contact/Account lookups and deduplicate
        List<breg_Account_Affiliation__c> existingAffiliations = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Role__c,
                breg_Type__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Entity_Name__c,
                breg_Contact__c,
                breg_Account__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityIds AND breg_End_Date__c = NULL AND breg_Status__c != 'I'
        ];

        // Build name-keyed map: entityId + role + type-specific name → existing affiliation
        Map<String, breg_Account_Affiliation__c> existingByNameKey = new Map<String, breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c aff : existingAffiliations) {
            String key = buildNameKey(
                aff.breg_Entity__c,
                aff.breg_Role__c,
                aff.breg_Type__c,
                aff.breg_First_Name__c,
                aff.breg_Last_Name__c,
                aff.breg_Entity_Name__c
            );
            if (String.isNotBlank(key) && !existingByNameKey.containsKey(key)) {
                existingByNameKey.put(key, aff);
            }
        }

        // Map Contact/Account lookups from matching existing affiliations onto new wrappers.
        // If a match is found, set the existing Id on the new affiliation record so that
        // BREGWebFilingWrapper.collectAffiliationsToInsert skips it (deduplication).
        for (String workitemId : wrappersByWorkitemId.keySet()) {
            BREGWebFilingWrapper wrapper = wrappersByWorkitemId.get(workitemId);
            if (wrapper.WebCase == null || wrapper.WebCase.breg_Entity__c == null) {
                continue;
            }
            Id entityId = wrapper.WebCase.breg_Entity__c;
            for (BREGWebAccountAffiliationWrapper affiliationWrapper : wrapper.AccountAffiliations) {
                breg_Account_Affiliation__c newAff = affiliationWrapper.accountAffiliation;
                String key = buildNameKey(
                    entityId,
                    newAff.breg_Role__c,
                    newAff.breg_Type__c,
                    newAff.breg_First_Name__c,
                    newAff.breg_Last_Name__c,
                    newAff.breg_Entity_Name__c
                );
                if (String.isBlank(key) || !existingByNameKey.containsKey(key)) {
                    continue;
                }
                breg_Account_Affiliation__c existingAff = existingByNameKey.get(key);
                // Mark as existing so collectAffiliationsToInsert skips insert (deduplication)
                if (existingAff.breg_Contact__c != null) {
                    affiliationWrapper.Contact = new Contact(Id = existingAff.breg_Contact__c);
                    newAff.breg_Contact__c = existingAff.breg_Contact__c;
                }
                if (existingAff.breg_Account__c != null) {
                    affiliationWrapper.Account = new Account(Id = existingAff.breg_Account__c);
                    newAff.breg_Account__c = existingAff.breg_Account__c;
                }
            }
        }

        return resultsByWorkitemId;
    }

    private String buildNameKey(Id entityId, String role, String type, String firstName, String lastName, String entityName) {
        if (entityId == null) {
            return null;
        }
        String roleKey = String.isNotBlank(role) ? role.toLowerCase().trim() : '';
        if (type == 'Individual') {
            String fn = String.isNotBlank(firstName) ? firstName.toLowerCase().trim() : '';
            String ln = String.isNotBlank(lastName) ? lastName.toLowerCase().trim() : '';
            if (String.isBlank(fn) && String.isBlank(ln)) {
                return null;
            }
            return entityId + '_' + roleKey + '_' + fn + '_' + ln;
        }
        if (type == 'Entity' && String.isNotBlank(entityName)) {
            return entityId + '_' + roleKey + '_' + entityName.toLowerCase().trim();
        }
        return null;
    }

    private BREGWebAccountAffiliationWrapper buildAffiliationWrapper(breg_WEB_WEB_PERSONS__c person) {
        BREGWebAccountAffiliationWrapper wrapper = new BREGWebAccountAffiliationWrapper();
        mapToAffiliation(person, wrapper.accountAffiliation);
        return wrapper;
    }

    private void mapToAffiliation(breg_WEB_WEB_PERSONS__c person, breg_Account_Affiliation__c affiliation) {
        affiliation.breg_Role__c = person.breg_WEB_PERSON_OFFICE__c == 'MEM'
            ? 'Member'
            : person.breg_WEB_PERSON_OFFICE__c == 'MGR'
                  ? 'Manager'
                  : MEMBER_ROLE_MAP.get(person.breg_WEB_PERSON_TYPE__c) != null ? MEMBER_ROLE_MAP.get(person.breg_WEB_PERSON_TYPE__c) : 'Other';

        if (
            person.breg_WEB_PERSON_TYPE__c == 'AGNT' &&
            AGNT_REG_FORMS.contains(wrappersByWorkitemId.get(person.breg_WEB_Case__c)?.WebCase.breg_Form_Code__c) &&
            person.breg_WEB_WEB_ACTION_CODE__c != 'D'
        ) {
            affiliation.breg_Role__c = 'New Agent';
        } else if (APPLICANT_FORMS.contains(wrappersByWorkitemId.get(person.breg_WEB_Case__c)?.WebCase.breg_Form_Code__c)) {
            affiliation.breg_Role__c = 'Applicant';
        } else if (PARTNERS_FORMS.contains(wrappersByWorkitemId.get(person.breg_WEB_Case__c)?.WebCase.breg_Form_Code__c) && person.breg_WEB_PERSON_TYPE__c != 'AGNT') {
            affiliation.breg_Role__c = 'Partner';
        }
        // affiliation.breg_Status__c = person.breg_WEB_PERSON_STATUS__c;
        if (person.breg_WEB_PERSON_NAME__c?.endsWith('CO-TRUSTEE')) {
            person.breg_WEB_PERSON_NAME__c = person.breg_WEB_PERSON_NAME__c.replace(', CO-TRUSTEE', '').trim();
            person.breg_WEB_PERSON_NAME__c = person.breg_WEB_PERSON_NAME__c.replace('CO-TRUSTEE', '').trim();
            person.breg_WEB_PERSON_FL__c = 'Y'; // Force classification as Individual for names ending with CO-TRUSTEE, as these are typically trusts with the trustee's name followed by "CO-TRUSTEE"
        }
        splitAndMapOfficeCode(affiliation, person.breg_WEB_PERSON_OFFICE__c);
        Boolean hasIndividualNames = String.isNotBlank(person.breg_WEB_First_Name__c) || String.isNotBlank(person.breg_WEB_Last_Name__c);
        Boolean hasCompanyName = String.isNotBlank(person.breg_WEB_Company_Name__c);
        if (hasIndividualNames && !hasCompanyName) {
            affiliation.breg_Type__c = 'Individual';
        } else if (hasCompanyName && !hasIndividualNames) {
            affiliation.breg_Type__c = 'Entity';
        } else if (person.breg_WEB_Is_Company_Confidence_Pct__c != null) {
            affiliation.breg_Type__c = person.breg_WEB_Is_Company_Confidence_Pct__c >= 50 ? 'Entity' : 'Individual';
        } else {
            Integer wordsNumber = person.breg_WEB_PERSON_NAME__c != null ? person.breg_WEB_PERSON_NAME__c.trim().split(' ').size() : 0;
            Boolean containsTrustIndicator = person.breg_WEB_PERSON_NAME__c != null && person.breg_WEB_PERSON_NAME__c.toLowerCase().contains('trust');
            affiliation.breg_Type__c = person.breg_WEB_PERSON_FL__c == 'Y' && wordsNumber <= 4 && !containsTrustIndicator ? 'Individual' : 'Entity';
        }
        if (affiliation.breg_Type__c == 'Individual') {
            if (hasIndividualNames) {
                affiliation.breg_First_Name__c = person.breg_WEB_First_Name__c;
                affiliation.breg_Last_Name__c = person.breg_WEB_Last_Name__c;
                affiliation.breg_Middle_Name__c = person.breg_WEB_Middle_Name__c;
            } else {
                NameWrapper nameWrapper = splitName(person.breg_WEB_PERSON_NAME__c);
                if (String.isNotBlank(nameWrapper.firstName)) {
                    affiliation.breg_First_Name__c = nameWrapper.firstName;
                }
                if (String.isNotBlank(nameWrapper.lastName)) {
                    affiliation.breg_Last_Name__c = nameWrapper.lastName;
                }
                if (String.isNotBlank(nameWrapper.middleName)) {
                    affiliation.breg_Middle_Name__c = nameWrapper.middleName;
                }
            }
        } else {
            affiliation.breg_Entity_Name__c = String.isNotBlank(person.breg_WEB_Company_Name__c)
                ? person.breg_WEB_Company_Name__c
                : person.breg_WEB_PERSON_NAME__c;
        }
        affiliation.breg_Person_Sequence__c = person.breg_WEB_PERSON_SEQ__c;
        // affiliation.breg_Start_Date__c = person.breg_WEB_START_DT__c;
        // affiliation.breg_End_Date__c = person.breg_WEB_END_DT__c;
        //affiliation.breg_Address__c = person.breg_WEB_ADDRESS_LINE_1__c; - replaced by street build to accommodate multiple address lines
        affiliation.breg_Address__City__s = person.breg_WEB_CITY__c;
        affiliation.breg_Address__CountryCode__s = person.breg_WEB_COUNTRY_CODE_2__c != null
            ? person.breg_WEB_COUNTRY_CODE_2__c
            : BREGZipCodeUtils.getCountryByStateCode(BREGZipCodeUtils.getStateCodeById(Integer.valueOf(person.breg_WEB_LOCALITY_ID__c)));
        affiliation.breg_Address__PostalCode__s = person.breg_WEB_POSTAL_CODE__c;
        if (person.breg_WEB_LOCALITY_ID__c != null) {
            // For US addresses, try to determine state from ZIP code for better data quality
            String stateFromZip = BREGZipCodeUtils.getStateCodeById(Integer.valueOf(person.breg_WEB_LOCALITY_ID__c));
            affiliation.breg_Address__StateCode__s = stateFromZip != null ? stateFromZip : null;
        }
        affiliation.breg_Address__Street__s = person.breg_WEB_ADDRESS_LINE_1__c;
        affiliation.breg_Address_Street_2__c = buildStreet2(person.breg_WEB_ADDRESS_LINE_2__c, person.breg_WEB_ADDRESS_LINE_3__c);
        affiliation.breg_case__c = person.breg_WEB_Case__c;
    }

    private void splitAndMapOfficeCode(breg_Account_Affiliation__c affiliation, String officeCodeString) {
        List<String> matchedTitles = new List<String>();
        List<String> unmatchedCodes = new List<String>();

        if (String.isBlank(officeCodeString)) {
            return;
        }

        String[] officeCodeParts = officeCodeString.split('/');
        Map<String, String> picklistValuesMap = new Map<String, String>();
        for (String key : TITLE_PICKLIST_LABEL_MAP.keySet()) {
            picklistValuesMap.put(TITLE_PICKLIST_LABEL_MAP.get(key).toLowerCase(), key);
        }
        for (String code : officeCodeParts) {
            String trimmedCode = code.trim();
            if (String.isNotBlank(trimmedCode)) {
                if (TITLE_PICKLIST_LABEL_MAP.containsKey(trimmedCode)) {
                    matchedTitles.add(trimmedCode);
                } else if (picklistValuesMap.containsKey(trimmedCode.toLowerCase())) {
                    matchedTitles.add(picklistValuesMap.get(trimmedCode.toLowerCase()));
                } else {
                    unmatchedCodes.add(trimmedCode);
                }
            }
        }

        String matchedTitlesString = matchedTitles.isEmpty() ? null : String.join(matchedTitles, ';');
        String unmatchedCodesString = unmatchedCodes.isEmpty() ? null : String.join(unmatchedCodes, ';');
        affiliation.breg_Officer_Director_Titles__c = matchedTitlesString;
        affiliation.breg_Officer_Director_Other_Title__c = unmatchedCodesString;
        affiliation.breg_Office_Held__c = unmatchedCodesString;
    }

    private NameWrapper splitName(String fullName) {
        NameWrapper nameWrapper = new NameWrapper();
        if (String.isBlank(fullName)) {
            return nameWrapper;
        }

        fullName = fullName.trim();

        // Check if name contains comma: {lastname}, {firstname} {middlename}
        if (fullName.contains(',')) {
            String[] commaSplit = fullName.split(',');
            if (commaSplit.size() >= 1) {
                nameWrapper.lastName = commaSplit[0].trim();
            }
            if (commaSplit.size() >= 2) {
                String[] spaceSplit = commaSplit[1].trim().split(' ');
                if (spaceSplit.size() >= 1) {
                    nameWrapper.firstName = spaceSplit[0].trim();
                }
                if (spaceSplit.size() >= 2) {
                    List<String> middleAndLast = new List<String>();
                    for (Integer i = 1; i < spaceSplit.size(); i++) {
                        middleAndLast.add(spaceSplit[i]);
                    }
                    nameWrapper.middleName = String.join(middleAndLast, ' ').trim();
                }
            }
        } else {
            // Split by space: {firstname} {middlename} {lastname}
            String[] spaceSplit = fullName.split(' ');
            if (spaceSplit.size() >= 1) {
                nameWrapper.firstName = spaceSplit[0].trim();
            }
            if (spaceSplit.size() == 2) {
                nameWrapper.lastName = spaceSplit[1].trim();
            } else if (spaceSplit.size() >= 3) {
                List<String> middleNames = new List<String>();
                for (Integer i = 1; i < spaceSplit.size() - 1; i++) {
                    middleNames.add(spaceSplit[i]);
                }
                nameWrapper.middleName = String.join(middleNames, ' ').trim();
                nameWrapper.lastName = spaceSplit[spaceSplit.size() - 1].trim();
            }
        }

        return nameWrapper;
    }

    private class NameWrapper {
        public String firstName;
        public String middleName;
        public String lastName;
    }
}