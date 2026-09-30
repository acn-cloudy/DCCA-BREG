public with sharing class BREGWEBAddress2Case extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_ADDRESSES__c';
    private static final String FORM_TYPE_ADD = 'ADD';
    private static final List<String> FORM_TYPE_T = new List<String>{'T1', 'T2', 'T3'};
    private static final String ADDRESS_TYPE_MAIL = 'MAIL';
    private static final String ADDRESS_TYPE_PRIN = 'PRIN';
    private static final String ADDRESS_TYPE_TNMA = 'TNMA';
    private static final String ACTION_CODE_ADD = 'A';
    private static final String ACTION_CODE_NEW = 'N';
    private static final String ACTION_CODE_DELETE = 'D';

    private class AddAddressBuckets {
        Map<String, breg_WEB_WEB_ADDRESSES__c> currentByType = new Map<String, breg_WEB_WEB_ADDRESSES__c>();
        Map<String, breg_WEB_WEB_ADDRESSES__c> newByType = new Map<String, breg_WEB_WEB_ADDRESSES__c>();
    }

    public BREGWEBAddress2Case(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);
        Map<String, breg_WEB_WEB_FILING_INFO__c> filingInfoByWorkitemId = getFilingInfoByWorkitemId(resultsByWorkitemId.keySet());
        Map<String, Contact> uniqueContactByApplicantName = getUniqueContactByApplicantName(filingInfoByWorkitemId.values());

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            BREGWebFilingWrapper filingWrapper = wrappersByWorkitemId.get(workitemId);
            if (filingWrapper == null) {
                continue;
            }
            Case webCase = wrappersByWorkitemId.get(workitemId).WebCase;
            breg_WEB_WEB_FILING_INFO__c filingInfo = filingInfoByWorkitemId.get(workitemId);

            if (tryMapAddAddressChange(records, filingInfo, webCase)) {
                continue;
            }

            List<breg_WEB_WEB_ADDRESSES__c> activeAddresses = getActiveAddresses(records);
            maybeAddTntmsmApplicantAffiliation(filingWrapper, filingInfo, activeAddresses, uniqueContactByApplicantName);
            if (isTntmsmForm(filingInfo)) {
                continue;
            }
            if (activeAddresses.size() == 1) {
                mapSingleAddressToBoth(activeAddresses[0], webCase);
                continue;
            }

            mapAddressesByType(activeAddresses, webCase);
        }
        return resultsByWorkitemId;
    }

    private Map<String, breg_WEB_WEB_FILING_INFO__c> getFilingInfoByWorkitemId(Set<String> workitemIds) {
        Map<String, breg_WEB_WEB_FILING_INFO__c> filingInfoByWorkitemId = new Map<String, breg_WEB_WEB_FILING_INFO__c>();
        if (workitemIds == null || workitemIds.isEmpty()) {
            return filingInfoByWorkitemId;
        }

        for (breg_WEB_WEB_FILING_INFO__c filingInfo : [
            SELECT breg_WEB_Case__c, breg_WEB_FORM_TYPE__c, breg_WEB_RDPMS_WFNEW_NAME__c, breg_WEB_RDPMS_WFCOMPANY_NAME__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c IN :workitemIds
        ]) {
            filingInfoByWorkitemId.put(filingInfo.breg_WEB_Case__c, filingInfo);
        }
        return filingInfoByWorkitemId;
    }

    private Map<String, Contact> getUniqueContactByApplicantName(Iterable<breg_WEB_WEB_FILING_INFO__c> filingInfos) {
        Map<String, Contact> uniqueContactByApplicantName = new Map<String, Contact>();
        Set<String> applicantNames = new Set<String>();

        for (breg_WEB_WEB_FILING_INFO__c filingInfo : filingInfos) {
            if (isTntmsmForm(filingInfo) && String.isNotBlank(filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c)) {
                applicantNames.add(filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c.trim());
            }
        }

        if (applicantNames.isEmpty()) {
            return uniqueContactByApplicantName;
        }

        Map<String, List<Contact>> contactsByName = new Map<String, List<Contact>>();
        for (Contact matchedContact : [
            SELECT Id, Name
            FROM Contact
            WHERE Name IN :applicantNames
        ]) {
            String normalizedApplicantName = normalizeApplicantName(matchedContact.Name);
            if (!contactsByName.containsKey(normalizedApplicantName)) {
                contactsByName.put(normalizedApplicantName, new List<Contact>());
            }
            contactsByName.get(normalizedApplicantName).add(matchedContact);
        }

        for (String applicantName : contactsByName.keySet()) {
            if (contactsByName.get(applicantName).size() == 1) {
                uniqueContactByApplicantName.put(applicantName, contactsByName.get(applicantName)[0]);
            }
        }

        return uniqueContactByApplicantName;
    }

    private void maybeAddTntmsmApplicantAffiliation(
        BREGWebFilingWrapper filingWrapper,
        breg_WEB_WEB_FILING_INFO__c filingInfo,
        List<breg_WEB_WEB_ADDRESSES__c> activeAddresses,
        Map<String, Contact> uniqueContactByApplicantName
    ) {
        if (!isTntmsmForm(filingInfo) || filingWrapper == null || filingWrapper.WebCase == null) {
            return;
        }
        if (hasApplicantAffiliation(filingWrapper)) {
            return;
        }

        String applicantName = filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c != null
            ? filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c.trim()
            : null;
        if (String.isBlank(applicantName)) {
            return;
        }

        String normalizedApplicantName = normalizeApplicantName(applicantName);

        BREGWebAccountAffiliationWrapper affiliationWrapper = new BREGWebAccountAffiliationWrapper();
        breg_Account_Affiliation__c affiliation = affiliationWrapper.accountAffiliation;
        affiliation.breg_Role__c = 'Applicant';
        affiliation.breg_Case__c = filingWrapper.WebCase.Id;

        Contact matchedContact = uniqueContactByApplicantName.get(normalizedApplicantName);
        if (matchedContact != null) {
            List<String> applicantNameParts = applicantName.split('\\s+', 2);
            affiliation.breg_Type__c = 'Individual';
            affiliation.breg_First_Name__c = applicantNameParts[0];
            affiliation.breg_Last_Name__c = applicantNameParts.size() > 1 ? applicantNameParts[1] : null;
            affiliationWrapper.Contact = matchedContact;
            affiliation.breg_Contact__c = matchedContact.Id;
        } else {
            affiliation.breg_Type__c = 'Entity';
            affiliation.breg_Entity_Name__c = applicantName;
        }

        breg_WEB_WEB_ADDRESSES__c applicantAddress = getApplicantAddress(activeAddresses);
        if (applicantAddress != null) {
            mapToAffiliationAddress(applicantAddress, affiliation);
        }

        filingWrapper.AccountAffiliations.add(affiliationWrapper);
    }

    private String normalizeApplicantName(String applicantName) {
        return String.isBlank(applicantName) ? null : applicantName.trim().toUpperCase();
    }

    private Boolean isTntmsmForm(breg_WEB_WEB_FILING_INFO__c filingInfo) {
        return filingInfo != null && FORM_TYPE_T.contains(filingInfo.breg_WEB_FORM_TYPE__c);
    }

    private Boolean hasApplicantAffiliation(BREGWebFilingWrapper filingWrapper) {
        for (BREGWebAccountAffiliationWrapper existingWrapper : filingWrapper.AccountAffiliations) {
            if (existingWrapper != null && existingWrapper.accountAffiliation != null && existingWrapper.accountAffiliation.breg_Role__c == 'Applicant') {
                return true;
            }
        }
        return false;
    }

    private breg_WEB_WEB_ADDRESSES__c getApplicantAddress(List<breg_WEB_WEB_ADDRESSES__c> activeAddresses) {
        if (activeAddresses == null || activeAddresses.isEmpty()) {
            return null;
        }

        for (breg_WEB_WEB_ADDRESSES__c address : activeAddresses) {
            if (ADDRESS_TYPE_MAIL.equals(address.breg_WEB_ADDRESS_TYPE__c)) {
                return address;
            }
        }
        return null;
    }

    private void mapToAffiliationAddress(breg_WEB_WEB_ADDRESSES__c address, breg_Account_Affiliation__c affiliation) {
        affiliation.breg_Address__Street__s = address.breg_WEB_ADDRESS_LINE_1__c;
        affiliation.breg_Address_Street_2__c = buildStreet2(address.breg_WEB_ADDRESS_LINE_2__c, address.breg_WEB_ADDRESS_LINE_3__c);
        affiliation.breg_Address__City__s = address.breg_WEB_CITY__c;
        affiliation.breg_Address__StateCode__s = getStateCode(address);
        affiliation.breg_Address__PostalCode__s = address.breg_WEB_POSTAL_CODE__c;
        affiliation.breg_Address__CountryCode__s = address.breg_WEB_COUNTRY_CODE_2__c;
    }

    private Boolean tryMapAddAddressChange(
        List<SObject> records,
        breg_WEB_WEB_FILING_INFO__c filingInfo,
        Case webCase
    ) {
        if (!isAddFilingInfo(filingInfo)) {
            return false;
        }

        AddAddressBuckets buckets = buildAddAddressBuckets(records);
        if (tryMapAddTntmsmAddressChange(filingInfo, buckets, webCase)) {
            return true;
        }

        if (String.isNotBlank(filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c)) {
            return false;
        }

        return tryMapAddEntityAddressChange(buckets, webCase);
    }

    private Boolean isAddFilingInfo(breg_WEB_WEB_FILING_INFO__c filingInfo) {
        return filingInfo != null && filingInfo.breg_WEB_FORM_TYPE__c == FORM_TYPE_ADD;
    }

    private AddAddressBuckets buildAddAddressBuckets(List<SObject> records) {
        AddAddressBuckets buckets = new AddAddressBuckets();
        for (SObject record : records) {
            breg_WEB_WEB_ADDRESSES__c address = (breg_WEB_WEB_ADDRESSES__c) record;
            if (address.breg_WEB_WEB_ACTION_CODE__c == ACTION_CODE_DELETE) {
                buckets.currentByType.put(address.breg_WEB_ADDRESS_TYPE__c, address);
            } else if (isNewActionCode(address.breg_WEB_WEB_ACTION_CODE__c)) {
                buckets.newByType.put(address.breg_WEB_ADDRESS_TYPE__c, address);
            }
        }
        return buckets;
    }

    private Boolean tryMapAddTntmsmAddressChange(
        breg_WEB_WEB_FILING_INFO__c filingInfo,
        AddAddressBuckets buckets,
        Case webCase
    ) {
        if (String.isBlank(filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c) || !hasAddressPair(buckets.currentByType, buckets.newByType, ADDRESS_TYPE_TNMA)) {
            return false;
        }

        mapToMailingAddress(buckets.currentByType.get(ADDRESS_TYPE_TNMA), webCase);
        mapToNewMailingAddress(buckets.newByType.get(ADDRESS_TYPE_TNMA), webCase);
        webCase.breg_Mailing_Address_Has_Changed__c = true;
        webCase.breg_Company_Address_Has_Changed__c = false;
        return true;
    }

    private Boolean tryMapAddEntityAddressChange(AddAddressBuckets buckets, Case webCase) {
        Boolean hasMailPair = hasAddressPair(buckets.currentByType, buckets.newByType, ADDRESS_TYPE_MAIL);
        Boolean hasCompanyPair = hasAddressPair(buckets.currentByType, buckets.newByType, ADDRESS_TYPE_PRIN);

        if (hasMailPair && hasCompanyPair) {
            mapAddEntityAddressPair(buckets, ADDRESS_TYPE_MAIL, webCase);
            mapAddEntityAddressPair(buckets, ADDRESS_TYPE_PRIN, webCase);
            webCase.breg_Mailing_Address_Has_Changed__c = true;
            webCase.breg_Company_Address_Has_Changed__c = true;
            return true;
        }

        if (hasMailPair) {
            mapAddEntityAddressPair(buckets, ADDRESS_TYPE_MAIL, webCase);
            webCase.breg_Mailing_Address_Has_Changed__c = true;
            webCase.breg_Company_Address_Has_Changed__c = false;
            return true;
        }

        if (hasCompanyPair) {
            mapAddEntityAddressPair(buckets, ADDRESS_TYPE_PRIN, webCase);
            webCase.breg_Company_Address_Has_Changed__c = true;
            webCase.breg_Mailing_Address_Has_Changed__c = false;
            return true;
        }

        return false;
    }

    private void mapAddEntityAddressPair(AddAddressBuckets buckets, String addressType, Case webCase) {
        if (ADDRESS_TYPE_MAIL == addressType) {
            mapToMailingAddress(buckets.currentByType.get(addressType), webCase);
            mapToNewMailingAddress(buckets.newByType.get(addressType), webCase);
            return;
        }

        mapToCompanyAddress(buckets.currentByType.get(addressType), webCase);
        mapToNewCompanyAddress(buckets.newByType.get(addressType), webCase);
    }

    private Boolean hasAddressPair(
        Map<String, breg_WEB_WEB_ADDRESSES__c> currentAddressByType,
        Map<String, breg_WEB_WEB_ADDRESSES__c> newAddressByType,
        String addressType
    ) {
        return currentAddressByType.containsKey(addressType) && newAddressByType.containsKey(addressType);
    }

    private Boolean isNewActionCode(String actionCode) {
        return actionCode == ACTION_CODE_ADD || actionCode == ACTION_CODE_NEW;
    }

    private List<breg_WEB_WEB_ADDRESSES__c> getActiveAddresses(List<SObject> records) {
        List<breg_WEB_WEB_ADDRESSES__c> activeAddresses = new List<breg_WEB_WEB_ADDRESSES__c>();
        for (SObject record : records) {
            breg_WEB_WEB_ADDRESSES__c address = (breg_WEB_WEB_ADDRESSES__c) record;
            if (address.breg_WEB_WEB_ACTION_CODE__c != ACTION_CODE_DELETE) {
                activeAddresses.add(address);
            }
        }
        return activeAddresses;
    }

    private void mapSingleAddressToBoth(breg_WEB_WEB_ADDRESSES__c address, Case webCase) {
        mapToMailingAddress(address, webCase);
        mapToCompanyAddress(address, webCase);
    }

    private void mapAddressesByType(List<breg_WEB_WEB_ADDRESSES__c> addresses, Case webCase) {
        for (breg_WEB_WEB_ADDRESSES__c address : addresses) {
            String addressType = address.breg_WEB_ADDRESS_TYPE__c;
            if (ADDRESS_TYPE_MAIL.equals(addressType)) {
                mapToMailingAddress(address, webCase);
            } else if (ADDRESS_TYPE_PRIN.equals(addressType)) {
                mapToCompanyAddress(address, webCase);
            }
        }
    }

    private void mapToMailingAddress(breg_WEB_WEB_ADDRESSES__c address, Case webCase) {
        String stateCode = getStateCode(address);
        webCase.breg_Mailing_Address__Street__s = address.breg_WEB_ADDRESS_LINE_1__c;
        webCase.breg_Mailing_Address_Number_and_Street_2__c = buildStreet2(address.breg_WEB_ADDRESS_LINE_2__c, address.breg_WEB_ADDRESS_LINE_3__c);
        webCase.breg_Mailing_Address__City__s = address.breg_WEB_CITY__c;
        webCase.breg_Mailing_Address__StateCode__s = stateCode;
        webCase.breg_Mailing_Address__PostalCode__s = address.breg_WEB_POSTAL_CODE__c;
        webCase.breg_Mailing_Address__CountryCode__s = address.breg_WEB_COUNTRY_CODE_2__c;
    }

    private void mapToNewMailingAddress(breg_WEB_WEB_ADDRESSES__c address, Case webCase) {
        String stateCode = getStateCode(address);
        webCase.breg_New_Mailing_Address__Street__s = address.breg_WEB_ADDRESS_LINE_1__c;
        webCase.breg_New_Mailing_Address_Street_2__c = buildStreet2(address.breg_WEB_ADDRESS_LINE_2__c, address.breg_WEB_ADDRESS_LINE_3__c);
        webCase.breg_New_Mailing_Address__City__s = address.breg_WEB_CITY__c;
        webCase.breg_New_Mailing_Address__StateCode__s = stateCode;
        webCase.breg_New_Mailing_Address__PostalCode__s = address.breg_WEB_POSTAL_CODE__c;
        webCase.breg_New_Mailing_Address__CountryCode__s = address.breg_WEB_COUNTRY_CODE_2__c;
    }

    private void mapToCompanyAddress(breg_WEB_WEB_ADDRESSES__c address, Case webCase) {
        String stateCode = getStateCode(address);
        webCase.breg_Company_Address__Street__s = address.breg_WEB_ADDRESS_LINE_1__c;
        webCase.breg_Company_Address_Street2__c = buildStreet2(address.breg_WEB_ADDRESS_LINE_2__c, address.breg_WEB_ADDRESS_LINE_3__c);
        webCase.breg_Company_Address__City__s = address.breg_WEB_CITY__c;
        webCase.breg_Company_Address__StateCode__s = stateCode;
        webCase.breg_Company_Address__PostalCode__s = address.breg_WEB_POSTAL_CODE__c;
        webCase.breg_Company_Address__CountryCode__s = address.breg_WEB_COUNTRY_CODE_2__c;
    }

    private void mapToNewCompanyAddress(breg_WEB_WEB_ADDRESSES__c address, Case webCase) {
        String stateCode = getStateCode(address);
        webCase.breg_New_Company_Address__Street__s = address.breg_WEB_ADDRESS_LINE_1__c;
        webCase.breg_New_Company_Address_Street_2__c = buildStreet2(address.breg_WEB_ADDRESS_LINE_2__c, address.breg_WEB_ADDRESS_LINE_3__c);
        webCase.breg_New_Company_Address__City__s = address.breg_WEB_CITY__c;
        webCase.breg_New_Company_Address__StateCode__s = stateCode;
        webCase.breg_New_Company_Address__PostalCode__s = address.breg_WEB_POSTAL_CODE__c;
        webCase.breg_New_Company_Address__CountryCode__s = address.breg_WEB_COUNTRY_CODE_2__c;
    }

    private String getStateCode(breg_WEB_WEB_ADDRESSES__c address) {
        if (address.breg_WEB_LOCALITY_ID__c == null) {
            return null;
        }

        return BREGZipCodeUtils.getStateCodeById(Integer.valueOf(address.breg_WEB_LOCALITY_ID__c));
    }
}