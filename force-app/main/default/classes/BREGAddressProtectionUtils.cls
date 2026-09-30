public without sharing class BREGAddressProtectionUtils {

    private static final Map<String, String> STREET_SUFFIXES = new Map<String, String>{
        'STREET' => 'ST',
        'AVENUE' => 'AVE',
        'BOULEVARD' => 'BLVD',
        'DRIVE' => 'DR',
        'ROAD' => 'RD',
        'LANE' => 'LN',
        'COURT' => 'CT',
        'PLACE' => 'PL',
        'CIRCLE' => 'CIR',
        'HIGHWAY' => 'HWY',
        'TRAIL' => 'TRL',
        'TERRACE' => 'TER'
    };

    public static Map<String, List<String>> protectionMap = buildProtectionMap(loadActiveProtectionRecords());

    public class AddressWrapper {
        public String country { get; set; }
        public String state { get; set; }
        public String city { get; set; }
        public String address1 { get; set; }
        public String address2 { get; set; }
        public String address3 { get; set; }
        public String postalCode { get; set; }

        public AddressWrapper() {
        }

        public AddressWrapper(
            String address1,
            String address2,
            String address3,
            String city,
            String state,
            String country,
            String postalCode
        ) {
            this.address1 = address1;
            this.address2 = address2;
            this.address3 = address3;
            this.city = city;
            this.state = state;
            this.country = country;
            this.postalCode = postalCode;
        }
    }

    /**
     * @description Goes through all address groups on the Case and its Account_Affiliations__r,
     *              clears fields where the name+address combination matches an active protection record.
     *              NOTE: Contains SOQL queries in a loop — known anti-pattern, candidate for future optimization.
     * @param caseRecord Case sObject with Account_Affiliations__r pre-loaded
     * @return Case sObject with protected address fields nulled out
     */
    public static Case cleanProtectedCaseData(Case caseRecord) {
        if (caseRecord == null) {
            return null;
        }

        breg_Account_Affiliation__c agentAffiliation = null;
        // --- Account Affiliations ---
        if (caseRecord.Account_Affiliations__r != null) {
            for (breg_Account_Affiliation__c aff : caseRecord.Account_Affiliations__r) {
                String name = buildAffiliationName(aff);
                AddressWrapper addr = buildAddressFromAffiliation(aff);
                if (String.isNotBlank(name) && isAddressProtected(name, addr, protectionMap)) {
                    clearAffiliationAddressFields(aff);
                }

                if(aff.breg_Role__c == 'Agent' || aff.breg_Role__c == 'New Agent') {
                    agentAffiliation = aff;
                }
            }
        }

        // --- Case address groups ---
        
        System.debug('Agent affiliation for address protection: ' + agentAffiliation);
        // Company Address (entity name)
        String entityName = agentAffiliation != null ? buildAffiliationName(agentAffiliation) : caseRecord.breg_Entity_Name__c;
        System.debug('Entity name for address protection: ' + entityName);
        if (String.isNotBlank(entityName)) {
            if (isAddressProtected(
                entityName,
                new AddressWrapper(
                    caseRecord.breg_Company_Address__Street__s,
                    caseRecord.breg_Company_Address_Street2__c,
                    null,
                    caseRecord.breg_Company_Address__City__s,
                    caseRecord.breg_Company_Address__StateCode__s,
                    caseRecord.breg_Company_Address__CountryCode__s,
                    caseRecord.breg_Company_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_Company_Address__Street__s = null;
                caseRecord.breg_Company_Address_Street2__c = null;
                caseRecord.breg_Company_Address__City__s = null;
                caseRecord.breg_Company_Address__StateCode__s = null;
                caseRecord.breg_Company_Address__CountryCode__s = null;
                caseRecord.breg_Company_Address__PostalCode__s = null;
            }

            // Mailing Address (same entity)
            if (isAddressProtected(
                entityName,
                new AddressWrapper(
                    caseRecord.breg_Mailing_Address__Street__s,
                    caseRecord.breg_Mailing_Address_Number_and_Street_2__c,
                    null,
                    caseRecord.breg_Mailing_Address__City__s,
                    caseRecord.breg_Mailing_Address__StateCode__s,
                    caseRecord.breg_Mailing_Address__CountryCode__s,
                    caseRecord.breg_Mailing_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_Mailing_Address__Street__s = null;
                caseRecord.breg_Mailing_Address_Number_and_Street_2__c = null;
                caseRecord.breg_Mailing_Address__City__s = null;
                caseRecord.breg_Mailing_Address__StateCode__s = null;
                caseRecord.breg_Mailing_Address__CountryCode__s = null;
                caseRecord.breg_Mailing_Address__PostalCode__s = null;
            }
        }

        // Registered Agent Address
        String regAgentName = buildRegAgentName(caseRecord);
        if (String.isNotBlank(regAgentName)) {
            if (isAddressProtected(
                regAgentName,
                new AddressWrapper(
                    caseRecord.breg_Registered_Agent_Address__Street__s,
                    caseRecord.breg_Reg_Agent_Address_Street2__c,
                    null,
                    caseRecord.breg_Registered_Agent_Address__City__s,
                    caseRecord.breg_Registered_Agent_Address__StateCode__s,
                    caseRecord.breg_Registered_Agent_Address__CountryCode__s,
                    caseRecord.breg_Registered_Agent_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_Registered_Agent_Address__Street__s = null;
                caseRecord.breg_Reg_Agent_Address_Street2__c = null;
                caseRecord.breg_Registered_Agent_Address__City__s = null;
                caseRecord.breg_Registered_Agent_Address__StateCode__s = null;
                caseRecord.breg_Registered_Agent_Address__CountryCode__s = null;
                caseRecord.breg_Registered_Agent_Address__PostalCode__s = null;
            }
        }

        // New Entity — Company Address
        String newEntityName = entityName;
        if (String.isNotBlank(newEntityName)) {
            if (isAddressProtected(
                newEntityName,
                new AddressWrapper(
                    caseRecord.breg_New_Company_Address__Street__s,
                    caseRecord.breg_New_Company_Address_Street_2__c,
                    null,
                    caseRecord.breg_New_Company_Address__City__s,
                    caseRecord.breg_New_Company_Address__StateCode__s,
                    caseRecord.breg_New_Company_Address__CountryCode__s,
                    caseRecord.breg_New_Company_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_New_Company_Address__Street__s = null;
                caseRecord.breg_New_Company_Address_Street_2__c = null;
                caseRecord.breg_New_Company_Address__City__s = null;
                caseRecord.breg_New_Company_Address__StateCode__s = null;
                caseRecord.breg_New_Company_Address__CountryCode__s = null;
                caseRecord.breg_New_Company_Address__PostalCode__s = null;
            }

            // New Entity — Mailing Address
            if (isAddressProtected(
                newEntityName,
                new AddressWrapper(
                    caseRecord.breg_New_Mailing_Address__Street__s,
                    caseRecord.breg_New_Mailing_Address_Street_2__c,
                    null,
                    caseRecord.breg_New_Mailing_Address__City__s,
                    caseRecord.breg_New_Mailing_Address__StateCode__s,
                    caseRecord.breg_New_Mailing_Address__CountryCode__s,
                    caseRecord.breg_New_Mailing_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_New_Mailing_Address__Street__s = null;
                caseRecord.breg_New_Mailing_Address_Street_2__c = null;
                caseRecord.breg_New_Mailing_Address__City__s = null;
                caseRecord.breg_New_Mailing_Address__StateCode__s = null;
                caseRecord.breg_New_Mailing_Address__CountryCode__s = null;
                caseRecord.breg_New_Mailing_Address__PostalCode__s = null;
            }
        }

        // New Registrant Address
        String newRegistrantName = buildNewRegistrantName(caseRecord);
        if (String.isNotBlank(newRegistrantName)) {
            if (isAddressProtected(
                newRegistrantName,
                new AddressWrapper(
                    caseRecord.breg_New_Registrant_Address__Street__s,
                    caseRecord.breg_New_Registrant_Address_Street_2__c,
                    null,
                    caseRecord.breg_New_Registrant_Address__City__s,
                    caseRecord.breg_New_Registrant_Address__StateCode__s,
                    caseRecord.breg_New_Registrant_Address__CountryCode__s,
                    caseRecord.breg_New_Registrant_Address__PostalCode__s
                ),
                protectionMap
            )) {
                caseRecord.breg_New_Registrant_Address__Street__s = null;
                caseRecord.breg_New_Registrant_Address_Street_2__c = null;
                caseRecord.breg_New_Registrant_Address__City__s = null;
                caseRecord.breg_New_Registrant_Address__StateCode__s = null;
                caseRecord.breg_New_Registrant_Address__CountryCode__s = null;
                caseRecord.breg_New_Registrant_Address__PostalCode__s = null;
            }
        }

        return caseRecord;
    }

    public static Account cleanProtectedAccountData(Account accountRecord) {
        if (accountRecord == null) {
            return null;
        }


        breg_Account_Affiliation__c agentAffiliation = null;

        // --- Account Affiliations ---
        if (accountRecord.breg_Account_Affiliations_Entity__r != null) {
            for (breg_Account_Affiliation__c aff : accountRecord.breg_Account_Affiliations_Entity__r) {
                String name = buildAffiliationName(aff);
                AddressWrapper addr = buildAddressFromAffiliation(aff);

                if (String.isNotBlank(name) && isAddressProtected(name, addr, protectionMap)) {
                    clearAffiliationAddressFields(aff);
                }

                if (aff.breg_Role__c == 'Agent' || aff.breg_Role__c == 'New Agent') {
                    agentAffiliation = aff;
                }
            }
        }

        String accountName = agentAffiliation != null
            ? buildAffiliationName(agentAffiliation)
            : accountRecord.Name;

        if (String.isBlank(accountName)) {
            return accountRecord;
        }

        // Billing Address
        if (isAddressProtected(
            accountName,
            new AddressWrapper(
                accountRecord.BillingStreet,
                null,
                null,
                accountRecord.BillingCity,
                accountRecord.BillingStateCode,
                accountRecord.BillingCountryCode,
                accountRecord.BillingPostalCode
            ),
            protectionMap
        )) {
            accountRecord.BillingStreet = null;
            accountRecord.BillingCity = null;
            accountRecord.BillingStateCode = null;
            accountRecord.BillingCountryCode = null;
            accountRecord.BillingPostalCode = null;
        }

        // breg_Mailing_Address__c
        if (isAddressProtected(
            accountName,
            new AddressWrapper(
                accountRecord.breg_Mailing_Address__Street__s,
                accountRecord.breg_Mailing_Address_Street_2__c,
                null,
                accountRecord.breg_Mailing_Address__City__s,
                accountRecord.breg_Mailing_Address__StateCode__s,
                accountRecord.breg_Mailing_Address__CountryCode__s,
                accountRecord.breg_Mailing_Address__PostalCode__s
            ),
            protectionMap
        )) {
            accountRecord.breg_Mailing_Address__Street__s = null;
            accountRecord.breg_Mailing_Address_Street_2__c = null;
            accountRecord.breg_Mailing_Address__City__s = null;
            accountRecord.breg_Mailing_Address__StateCode__s = null;
            accountRecord.breg_Mailing_Address__CountryCode__s = null;
            accountRecord.breg_Mailing_Address__PostalCode__s = null;
        }

        return accountRecord;
    }

    public static breg_TN_TM_SM__c cleanProtectedTNTMSMData(breg_TN_TM_SM__c tntmsmRecord) {
        if (tntmsmRecord == null) {
            return null;
        }

        breg_Account_Affiliation__c applicantAffiliation = null;

        breg_Account_Affiliation__c agentAffiliation = BREGBusinessDetailsController.getActiveAgent(tntmsmRecord.breg_Account__c);
        // --- Account Affiliations ---
        if (tntmsmRecord.breg_Account_Affiliations__r != null) {
            for (breg_Account_Affiliation__c aff : tntmsmRecord.breg_Account_Affiliations__r) {
                String name = buildAffiliationName(aff);
                AddressWrapper addr = buildAddressFromAffiliation(aff);

                if (String.isNotBlank(name) && isAddressProtected(name, addr, protectionMap)) {
                    clearAffiliationAddressFields(aff);
                }

                if (aff.breg_Role__c == 'Applicant') {
                    applicantAffiliation = aff;
                }
            }
        }

        // String applicantName = applicantAffiliation != null
        //     ? buildAffiliationName(applicantAffiliation)
        //     : tntmsmRecord.breg_Registrant_Name__c;
        String agentName = agentAffiliation != null
            ? buildAffiliationName(agentAffiliation)
            : tntmsmRecord.breg_Registrant_Name__c;
        if (String.isBlank(agentName)) {
            return tntmsmRecord;
        }

        // Mailing Address
        if (isAddressProtected(
            agentName,
            new AddressWrapper(
                tntmsmRecord.breg_Mailing_Address__Street__s,
                null,
                null,
                tntmsmRecord.breg_Mailing_Address__City__s,
                tntmsmRecord.breg_Mailing_Address__StateCode__s,
                tntmsmRecord.breg_Mailing_Address__CountryCode__s,
                tntmsmRecord.breg_Mailing_Address__PostalCode__s
            ),
            protectionMap
        )) {
            tntmsmRecord.breg_Mailing_Address__Street__s = null;
            tntmsmRecord.breg_Mailing_Address__City__s = null;
            tntmsmRecord.breg_Mailing_Address__StateCode__s = null;
            tntmsmRecord.breg_Mailing_Address__CountryCode__s = null;
            tntmsmRecord.breg_Mailing_Address__PostalCode__s = null;
        }

        return tntmsmRecord;
    }

    /**
     * @description Computes a normalized alphasort string from a name.
     *              Each whitespace-separated token is uppercased, stripped of non-alphanumeric chars,
     *              then joined with spaces.
     *              E.g. "Charles Green" → "CHARLES GREEN"
     * @param value Input string
     * @return Space-joined normalized token string, or null if blank input
     */
    public static String calculateAlphaSort(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = BREGUtils.normalizeBusinessName(value);
        List<String> tokens = normalized.split('\\s+');
        List<String> parts = new List<String>();
        for (String token : tokens) {
            if (String.isNotBlank(token)) {
                // Strip all non-alphanumeric characters so patterns are consistent
                // regardless of punctuation differences (e.g. "O'Brien" → "OBRIEN")
                String cleaned = token.toUpperCase().replaceAll('[^A-Z0-9]', '');
                if (String.isNotBlank(cleaned)) {
                    parts.add(cleaned);
                }
            }
        }
        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    /**
     * @description Checks whether a name + address combination matches an active BREG_ADDRESS_PROTECTION__c record.
     *              Performs SOQL query(ies) against BREG_ADDRESS_PROTECTION__c.
     * @param name   Person or entity name to check
     * @param address AddressWrapper with address details
     * @return true if a matching active protection record exists
     */
    public static Boolean isAddressProtected(String name, AddressWrapper address) {
        if (String.isBlank(name)) {
            return false;
        }
      
        return isAddressProtected(name, address, protectionMap);
    }

    /**
     * @description Computes a normalized address string for in-memory comparison.
     *              Street abbreviations are applied and non-alphanumeric chars stripped.
     *              Components are comma-separated: "<street>,<city>,<state>,<zip>"
     *              E.g. street="550 Dubai Street", city="Honolulu", state="HI", zip="96818"
     *                   → "550DUBAIST,HONOLULU,HI,96818"
     * @param address AddressWrapper
     * @return Comma-separated normalized address string, or null if no address components provided
     */
    public static String calculateAlphaSortForAddress(AddressWrapper address) {
        if (address == null) {
            return null;
        }
        List<String> parts = new List<String>();

        if (String.isNotBlank(address.address1)) {
            String street = address.address1.toUpperCase().trim();
            // Strip secondary address components (e.g. ", APT. 2301" or "SUITE 100") before normalization
            // so that "2525 DATE STREET, APT. 2301" matches a protection record for "2525 DATE STREET"
            if (street.contains(',')) {
                street = street.substringBefore(',').trim();
            }
            //street = street.replaceAll('\\b(APT\\.?|APARTMENT|SUITE|STE\\.?|UNIT|#)\\b.*', '').trim();
            for (String suffix : STREET_SUFFIXES.keySet()) {
                street = street.replaceAll('\\b' + suffix + '\\b', STREET_SUFFIXES.get(suffix));
            }
            parts.add(street.replaceAll('\\s+', '').replaceAll('[^A-Z0-9]+', ''));
        }

        if (String.isNotBlank(address.city)) {
            parts.add(address.city.trim().toUpperCase());
        }

        String stateZip = '';
        if (String.isNotBlank(address.state)) {
            stateZip = address.state.trim().toUpperCase();
        }
        if (String.isNotBlank(address.postalCode)) {
            stateZip += (String.isNotBlank(stateZip) ? ',' : '') + address.postalCode.trim();
        }
        if (String.isNotBlank(stateZip)) {
            parts.add(stateZip);
        }

        return parts.isEmpty() ? null : String.join(parts, ',');
    }

    /**
     * @description Returns active BREG_ADDRESS_PROTECTION__c records linked to the given record.
     *              Supported object types: Case, Account, breg_Account_Affiliation__c.
     *              For Transaction Address and Transaction Business Info, extend the if-else chain below.
     * @param recordId Salesforce record Id
     * @return Matching active BREG_ADDRESS_PROTECTION__c records, or empty list if unsupported type
     */
    public static List<BREG_ADDRESS_PROTECTION__c> getAddressExceptionForId(Id recordId) {
        if (recordId == null) {
            return new List<BREG_ADDRESS_PROTECTION__c>();
        }

        String objectType = recordId.getSObjectType().getDescribe().getName();
        String namePattern;
        AddressWrapper addr;

        if (objectType == 'Case') {
            Case c = [
                SELECT breg_Name_of_the_Entity__c,
                    breg_Company_Address__Street__s,
                    breg_Company_Address_Street2__c,
                    breg_Company_Address__City__s,
                    breg_Company_Address__StateCode__s,
                    breg_Company_Address__CountryCode__s,
                    breg_Company_Address__PostalCode__s
                FROM Case
                WHERE Id = :recordId
                LIMIT 1
            ];
            namePattern = calculateAlphaSort(c.breg_Name_of_the_Entity__c);
            addr = new AddressWrapper(
                c.breg_Company_Address__Street__s,
                c.breg_Company_Address_Street2__c,
                null,
                c.breg_Company_Address__City__s,
                c.breg_Company_Address__StateCode__s,
                c.breg_Company_Address__CountryCode__s,
                c.breg_Company_Address__PostalCode__s
            );
        } else if (objectType == 'Account') {
            Account acc = [
                SELECT Name,
                    BillingStreet,
                    BillingCity,
                    BillingStateCode,
                    BillingCountryCode,
                    BillingPostalCode
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            namePattern = calculateAlphaSort(acc.Name);
            addr = new AddressWrapper(
                acc.BillingStreet,
                null,
                null,
                acc.BillingCity,
                acc.BillingStateCode,
                acc.BillingCountryCode,
                acc.BillingPostalCode
            );
        } else if (objectType == 'breg_Account_Affiliation__c') {
            breg_Account_Affiliation__c aff = [
                SELECT breg_First_Name__c,
                    breg_Last_Name__c,
                    breg_Entity_Name__c,
                    breg_Address__Street__s,
                    breg_Address_Street_2__c,
                    breg_Address__City__s,
                    breg_Address__StateCode__s,
                    breg_Address__CountryCode__s,
                    breg_Address__PostalCode__s
                FROM breg_Account_Affiliation__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            namePattern = calculateAlphaSort(
                buildAffiliationNameFromFields(aff.breg_First_Name__c, aff.breg_Last_Name__c, aff.breg_Entity_Name__c)
            );
            addr = new AddressWrapper(
                aff.breg_Address__Street__s,
                aff.breg_Address_Street_2__c,
                null,
                aff.breg_Address__City__s,
                aff.breg_Address__StateCode__s,
                aff.breg_Address__CountryCode__s,
                aff.breg_Address__PostalCode__s
            );
        } else {
            // TODO: add support for Transaction Address and Transaction Business Info object types
            return new List<BREG_ADDRESS_PROTECTION__c>();
        }

        if (namePattern == null) {
            return new List<BREG_ADDRESS_PROTECTION__c>();
        }

        DateTime now = DateTime.now();
        String addressPattern = calculateAlphaSortForAddress(addr);

        // calculateAlphaSort / calculateAlphaSortForAddress return plain strings (no %).
        // Wrap with % wildcards here for SOQL LIKE usage only.
        String soqlNamePattern = '%' + namePattern.replaceAll('\\s+', '%') + '%';

        if (String.isNotBlank(addressPattern)) {
            String soqlAddrPattern = '%' + addressPattern.replaceAll(',', '%,%') + '%';
            return [
                SELECT Id,
                    Name,
                    breg_VALUE__c,
                    breg_ALPHASORT_NAME__c,
                    breg_ALPHASORT_VALUE__c,
                    breg_BRIM_ADDRESS_PROTECTION_ID__c,
                    breg_DATE_DEACTIVATED__c,
                    breg_DATE_EXCLUDED__c
                FROM BREG_ADDRESS_PROTECTION__c
                WHERE breg_ALPHASORT_NAME__c LIKE :soqlNamePattern
                    AND breg_ALPHASORT_VALUE__c LIKE :soqlAddrPattern
                    AND (breg_DATE_DEACTIVATED__c = NULL OR breg_DATE_DEACTIVATED__c > :now)
            ];
        }

        return [
            SELECT Id,
                Name,
                breg_VALUE__c,
                breg_ALPHASORT_NAME__c,
                breg_ALPHASORT_VALUE__c,
                breg_BRIM_ADDRESS_PROTECTION_ID__c,
                breg_DATE_DEACTIVATED__c,
                breg_DATE_EXCLUDED__c
            FROM BREG_ADDRESS_PROTECTION__c
            WHERE breg_ALPHASORT_NAME__c LIKE :soqlNamePattern
                AND (breg_DATE_DEACTIVATED__c = NULL OR breg_DATE_DEACTIVATED__c > :now)
        ];
    }

    // ─── Private helpers ────────────────────────────────────────────────────────

    /**
     * Builds a SOQL LIKE pattern targeting breg_ALPHASORT_VALUE__c.
     * Uses the street address (preferred) or city as the discriminating component.
     * SOQL LIKE is case-insensitive, so the stored mixed-case value will be matched.
     */
    private static String buildQueryAddressPattern(AddressWrapper address) {
        if (address == null) {
            return null;
        }
        if (String.isNotBlank(address.address1)) {
            String street = address.address1.toUpperCase().trim();
            // Strip secondary address components before normalization
            if (street.contains(',')) {
                street = street.substringBefore(',').trim();
            }
            //street = street.replaceAll('\\b(APT\\.?|APARTMENT|SUITE|STE\\.?|UNIT|#)\\b.*', '').trim();
            for (String suffix : STREET_SUFFIXES.keySet()) {
                street = street.replaceAll('\\b' + suffix + '\\b', STREET_SUFFIXES.get(suffix));
            }
            return '%' + street.replaceAll('\\s+', '') + '%';
        }
        if (String.isNotBlank(address.city)) {
            return '%' + address.city.trim().toUpperCase() + '%';
        }
        return null;
    }

    public static String buildAffiliationName(breg_Account_Affiliation__c affiliation) {
        if (affiliation == null) {
            return null;
        }

        return affiliation.breg_Type__c == 'Individual' ? buildAffiliationNameFromFields(
            affiliation.breg_First_Name__c,
            affiliation.breg_Last_Name__c,
            null // Last name is not included in the affiliation name for address protection purposes, per BRIM team guidance
            
        ) : buildAffiliationNameFromFields(
            null,
            null,
            affiliation.breg_Entity_Name__c
        );
    }

    private static String buildAffiliationNameFromFields(String firstName, String lastName, String entityName) {
        if (String.isNotBlank(entityName)) {
            return entityName;
        }
        String fullName = '';
        if (String.isNotBlank(firstName)) {
            fullName += firstName.trim();
        }
        if (String.isNotBlank(lastName)) {
            fullName += (String.isNotBlank(fullName) ? ' ' : '') + lastName.trim();
        }
        return String.isNotBlank(fullName) ? fullName : null;
    }

    public static AddressWrapper buildAddressFromAffiliation(breg_Account_Affiliation__c affiliation) {
        if (affiliation == null) {
            return new AddressWrapper();
        }

        return new AddressWrapper(
            affiliation?.breg_Address__Street__s,
            affiliation?.breg_Address_Street_2__c,
            null,
            affiliation?.breg_Address__City__s,
            affiliation?.breg_Address__StateCode__s,
            affiliation?.breg_Address__CountryCode__s,
            affiliation?.breg_Address__PostalCode__s
        );
    }

    public static void clearAffiliationAddressFields(breg_Account_Affiliation__c affiliation) {
        if(affiliation == null) {
            return;
        }

        affiliation.breg_Address__Street__s = null;
        affiliation.breg_Address_Street_2__c = null;
        affiliation.breg_Address__City__s = null;
        affiliation.breg_Address__StateCode__s = null;
        //affiliation.breg_Address__CountryCode__s = null;
        affiliation.breg_Address__PostalCode__s = null;
    }

    private static String buildRegAgentName(Case caseRecord) {
        if (caseRecord == null) {
            return null;
        }

        if (String.isNotBlank(caseRecord.breg_Reg_Agent_Entity_Name__c)) {
            return caseRecord.breg_Reg_Agent_Entity_Name__c;
        }
        String fullName = '';
        if (String.isNotBlank(caseRecord.breg_Reg_Agent_First_Name__c)) {
            fullName += caseRecord.breg_Reg_Agent_First_Name__c.trim();
        }
        if (String.isNotBlank(caseRecord.breg_Reg_Agent_Last_Name__c)) {
            fullName += (String.isNotBlank(fullName) ? ' ' : '') + caseRecord.breg_Reg_Agent_Last_Name__c.trim();
        }
        return String.isNotBlank(fullName) ? fullName : null;
    }

    private static String buildNewRegistrantName(Case caseRecord) {
        if (caseRecord == null) {
            return null;
        }

        if (String.isNotBlank(caseRecord.breg_New_Registrant_Name__c)) {
            return caseRecord.breg_New_Registrant_Name__c;
        }
        String fullName = '';
        if (String.isNotBlank(caseRecord.breg_New_Registrant_First_Name__c)) {
            fullName += caseRecord.breg_New_Registrant_First_Name__c.trim();
        }
        if (String.isNotBlank(caseRecord.breg_New_Registrant_Last_Name__c)) {
            fullName += (String.isNotBlank(fullName) ? ' ' : '') + caseRecord.breg_New_Registrant_Last_Name__c.trim();
        }
        return String.isNotBlank(fullName) ? fullName : null;
    }

    // ─── Protection map helpers ──────────────────────────────────────────────────

    /**
     * @description Fetches all active BREG_ADDRESS_PROTECTION__c records.
     *              Called once per entry-point method to avoid repeated SOQL in loops.
     */
    private static List<BREG_ADDRESS_PROTECTION__c> loadActiveProtectionRecords() {
        DateTime now = DateTime.now();
        return [
            SELECT Id,
                breg_ALPHASORT_NAME__c,
                breg_ALPHASORT_VALUE__c
            FROM BREG_ADDRESS_PROTECTION__c
            WHERE (breg_DATE_DEACTIVATED__c = NULL)
            LIMIT 10000
        ];
    }

    /**
     * @description Builds a map of stored name patterns to their associated address patterns
     *              from a pre-fetched list of protection records.
     * @param records Active BREG_ADDRESS_PROTECTION__c records
     * @return Map where key = breg_ALPHASORT_NAME__c, value = list of breg_ALPHASORT_VALUE__c
     */
    private static Map<String, List<String>> buildProtectionMap(List<BREG_ADDRESS_PROTECTION__c> records) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (BREG_ADDRESS_PROTECTION__c rec : records) {
            if (String.isBlank(rec.breg_ALPHASORT_NAME__c)) {
                continue;
            }
            // Normalize stored name: uppercase and strip all non-alphanumeric chars (including %).
            // This matches the format produced by calculateAlphaSort() — plain concatenated tokens.
            String nameKey = rec.breg_ALPHASORT_NAME__c.toUpperCase().replaceAll('[^A-Z0-9]', '');
            if (!result.containsKey(nameKey)) {
                result.put(nameKey, new List<String>());
            }
            // Normalize stored address: uppercase, strip % wildcards, keep , separator.
            // This matches the format produced by calculateAlphaSortForAddress().
            String addrValue = String.isNotBlank(rec.breg_ALPHASORT_VALUE__c)
                ? rec.breg_ALPHASORT_VALUE__c.toUpperCase().replaceAll('[^A-Z0-9,]', '')
                : rec.breg_ALPHASORT_VALUE__c;
            result.get(nameKey).add(addrValue);
        }
        return result;
    }

    /**
     * @description In-memory equivalent of SOQL LIKE. Case-insensitive; supports only % wildcards.
     * @param value   The stored field value to test
     * @param pattern The LIKE pattern (e.g. %CHARLES%GREEN%)
     * @return true if value matches pattern
     */
    @TestVisible
    private static Boolean matchesLikePattern(String value, String pattern) {
        if (String.isBlank(value) || String.isBlank(pattern)) {
            return false;
        }
        String v = value.toUpperCase();
        String p = pattern.toUpperCase();
        List<String> segments = p.split('%', -1);
        Integer pos = 0;

        for (Integer i = 0; i < segments.size(); i++) {
            String seg = segments[i];
            if (seg.length() == 0) {
                continue;
            }
            if (i == 0) {
                // No leading %, so value must start with this segment
                if (!v.startsWith(seg)) {
                    return false;
                }
                pos = seg.length();
            } else {
                Integer idx = v.indexOf(seg, pos);
                if (idx == -1) {
                    return false;
                }
                pos = idx + seg.length();
            }
        }

        // No trailing %, so value must end with the last non-empty segment
        if (!p.endsWith('%') && segments.size() > 0) {
            String lastSeg = segments[segments.size() - 1];
            if (lastSeg.length() > 0 && !v.endsWith(lastSeg)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @description In-memory address protection check against a pre-built protection map.
     *              Avoids SOQL — use this overload inside loops or when records are already loaded.
     * @param name          Person or entity name to check
     * @param address       AddressWrapper with address details
     * @param protectionMap Map built by buildProtectionMap()
     * @return true if a matching active protection record exists in the map
     */
    @TestVisible
    private static Boolean isAddressProtected(String name, AddressWrapper address, Map<String, List<String>> protectionMap) {
        if (String.isBlank(name) || protectionMap == null || protectionMap.isEmpty()) {
            return false;
        }
        // calculateAlphaSort returns space-joined tokens: "CHARLES GREEN"
        // buildProtectionMap stores concatenated tokens (% stripped): "CHARLESGREEN"
        // Name match: all tokens of the computed name must appear as substrings in the stored value.
        String namePattern = calculateAlphaSort(name);
        System.debug('Checking address protection for name: ' + name + ', pattern: ' + namePattern + ', address: ' + address);
        if (namePattern == null) {
            return false;
        }

        // Build a pattern from Street1 (address1). Comma-based secondary unit stripping is applied inside.
        String addressPattern1 = calculateAlphaSortForAddress(address);
        // Also build a pattern treating Street2 (address2) as the primary street.
        // Some forms store the base street number in address2 (e.g. address1="APT 2301", address2="2525 DATE ST"),
        // so we check both fields independently against the stored protection record.
        String addressPattern2 = null;
        if (address != null && String.isNotBlank(address.address2)) {
            addressPattern2 = calculateAlphaSortForAddress(new AddressWrapper(
                address.address2, null, null,
                address.city, address.state, address.country, address.postalCode
            ));
        }

        System.debug('Calculated address pattern (street1): ' + addressPattern1);
        System.debug('Calculated address pattern (street2): ' + addressPattern2);
        System.debug('Protection map keys: ' + protectionMap.keySet());

        Boolean hasAddressPattern = String.isNotBlank(addressPattern1) || String.isNotBlank(addressPattern2);
        List<String> nameTokens = namePattern.split('\\s+');
        for (String storedNameKey : protectionMap.keySet()) {
            System.debug('Comparing stored name key: ' + storedNameKey + ' with input pattern: ' + namePattern);
            System.debug('Stored address patterns for this name: ' + protectionMap.get(storedNameKey));
            // Check that every token from the computed name appears as a substring in the stored name key
            Boolean nameMatches = true;
            for (String token : nameTokens) {
                if (!storedNameKey.contains(token)) {
                    nameMatches = false;
                    break;
                }
            }
            if (!nameMatches) {
                continue;
            }
            if (hasAddressPattern) {
                for (String storedAddrPattern : protectionMap.get(storedNameKey)) {
                    if (String.isNotBlank(storedAddrPattern)) {
                        // Match against Street1
                        if (String.isNotBlank(addressPattern1) &&
                            (storedAddrPattern.contains(addressPattern1) || addressPattern1.contains(storedAddrPattern))) {
                            return true;
                        }
                        // Match against Street2 (fallback — handles reversed or split street entry)
                        if (String.isNotBlank(addressPattern2) &&
                            (storedAddrPattern.contains(addressPattern2) || addressPattern2.contains(storedAddrPattern))) {
                            return true;
                        }
                    }
                }
            } else {
                return true;
            }
        }
        return false;
    }
}