public with sharing class BREGWebFilingInfo2Case extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_FILING_INFO__c';
    private static final Time HAWAII_DATE_TIME_OFFSET = Time.newInstance(10, 0, 0, 0);
    private static final Integer HAWAII_TO_GMT_OFFSET_HOURS = 10;
    private static final String ADDRESS_TYPE_TNMA = 'TNMA';
    private static final List<String> TNTMSM_FORMS = new List<String>{ 'T1', 'T2', 'T3', 'T4' };
    private static final List<String> ENTITY_NAME_CHANGE_FORMS = new List<String>{ 'DC2', 'DNP2', 'GP2', 'LLC2' };
    private static final List<String> NAME_RESERVATION_FORMS = new List<String>{ 'X1', 'X2' };
    private static final String T4_FORM_TYPE = 'T4';
    private static final String X11_FORM_TYPE = 'X11';
    private static final String ADD_FORM_TYPE = 'ADD';
    private static final String X1_FORM_TYPE = 'X1';

    public BREGWebFilingInfo2Case(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);
        Map<String, Id> contactIdByWorkitemId = getMatchedContactIdsByWorkitemId(resultsByWorkitemId);
        Set<String> workitemIdsWithTnmaAddress = getWorkitemIdsWithTnmaAddress(resultsByWorkitemId.keySet());
        Map<String, breg_TN_TM_SM__c> latestTnTmSmByName = getLatestTnTmSmByName(resultsByWorkitemId, workitemIdsWithTnmaAddress);

        // Collect account IDs and years in bulk for a single annual lookup query
        Set<String> accountIds = new Set<String>();
        Set<String> years = new Set<String>();
        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            breg_WEB_WEB_FILING_INFO__c filingInfo = (breg_WEB_WEB_FILING_INFO__c) records[0];
            String accountId = wrappersByWorkitemId.get(workitemId).WebCase.breg_Entity__c;
            if (String.isNotBlank(accountId)) {
                accountIds.add(accountId);
            }
            if (String.isNotBlank(filingInfo.breg_WEB_RDPMS_WFYEAR__c)) {
                years.add(filingInfo.breg_WEB_RDPMS_WFYEAR__c);
            }
        }

        Map<String, breg_Annual__c> annualsByKey = getAnnualsByAccountsAndYears(new List<String>(accountIds), new List<String>(years));

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            breg_WEB_WEB_FILING_INFO__c filingInfo = (breg_WEB_WEB_FILING_INFO__c) records[0];
            Case webCase = wrappersByWorkitemId.get(workitemId).WebCase;
            if (webCase.Priority == null) {
                webCase.Priority = webCase.breg_Processing_Speed__c == 'Expedited' ? 'Priority 2' : 'Priority 3';
            }

            Boolean addTnTmSmForm = isAddTnTmSmForm(filingInfo, workitemIdsWithTnmaAddress.contains(workitemId));
            breg_TN_TM_SM__c matchedTnTmSm = addTnTmSmForm ? latestTnTmSmByName.get(filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c) : null;

            if (X11_FORM_TYPE.equals(filingInfo.breg_WEB_FORM_TYPE__c)) {
                webCase.breg_Reg_Agent_Entity_Name__c = filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c;
            } else if (NAME_RESERVATION_FORMS.contains(filingInfo.breg_WEB_FORM_TYPE__c)) {
                webCase.breg_Name_for_Reservation__c = filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c;
            } else if (!TNTMSM_FORMS.contains(filingInfo.breg_WEB_FORM_TYPE__c) && !addTnTmSmForm) {
                webCase.breg_Name_of_the_Entity__c = filingInfo.breg_WEB_RDPMS_WFCOMPANY_NAME__c;
            }

            if (ENTITY_NAME_CHANGE_FORMS.contains(filingInfo.breg_WEB_FORM_TYPE__c)) {
                webCase.breg_New_Entity_Name__c = filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c;
            } else if (T4_FORM_TYPE.equals(filingInfo.breg_WEB_FORM_TYPE__c) || addTnTmSmForm) {
                webCase.breg_TNTMSM_Description__c = filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c;
            }

            if (addTnTmSmForm && matchedTnTmSm != null) {
                webCase.breg_TNTMSM_Type__c = matchedTnTmSm.breg_Type__c;
                webCase.breg_TNTMSM_Certificate__c = matchedTnTmSm.breg_Cert_Number__c;
                webCase.breg_TNTMSM_Classification__c = matchedTnTmSm.breg_TM_SM_Category__c;
                webCase.breg_File__c = matchedTnTmSm.breg_File__c;
            }

            // Populate contact if we have a unique match based on name and email
            if (contactIdByWorkitemId.containsKey(workitemId) && webCase.ContactId == null) {
                webCase.ContactId = contactIdByWorkitemId.get(workitemId);
            }

            // Populate dates
            if (webCase.breg_Effective_Date__c == null) {
                webCase.breg_Effective_Date__c = filingInfo.breg_WEB_SUBMISSION_DT__c;
            }
            if (webCase.breg_Filing_Date__c == null) {
                webCase.breg_Filing_Date__c = toHawaiiDateTime(filingInfo.breg_WEB_FILING_DT__c);
            }
            if (webCase.breg_Submission_Date__c == null) {
                webCase.breg_Submission_Date__c = toSubmissionDateTime(filingInfo.breg_WEB_SUBMISSION_DT__c, filingInfo.breg_WEB_RDPMS_WFSCAN_TIME__c);
            }
            if (webCase.breg_Entity_Type__c == null && filingInfo.breg_WEB_RDPMS_WFT8__c != null && filingInfo.breg_WEB_RDPMS_WFT8__c.length() >= 2) {
                webCase.breg_Entity_Type__c = filingInfo.breg_WEB_RDPMS_WFT8__c.substring(
                    filingInfo.breg_WEB_RDPMS_WFT8__c.length() - 2,
                    filingInfo.breg_WEB_RDPMS_WFT8__c.length()
                );
            }
            if (X1_FORM_TYPE.equals(filingInfo.breg_WEB_FORM_TYPE__c) && webCase.breg_Effective_Date__c != null) {
                webCase.breg_Expiration_Date__c = webCase.breg_Effective_Date__c.addDays(120);
            }

            // Populate signature part
            String submitterSignature = trimToNull(filingInfo.breg_WEB_SUBMITTER_SIGNATURE__c);
            String submitterName = trimToNull(filingInfo.breg_WEB_SUBMITTER_NAME__c);

            Boolean isIndividualSigner = String.isBlank(submitterSignature) || areEqualIgnoreCase(submitterSignature, submitterName);
            String nameSource = isIndividualSigner ? submitterName : submitterSignature;
            NameParts parts = splitName(nameSource);

            webCase.breg_Signed_By__c = isIndividualSigner ? 'Individual' : 'Entity';
            webCase.breg_Signed_By_First_Name__c = parts.firstName;
            webCase.breg_Signed_By_Last_Name__c = parts.lastName;
            webCase.breg_Signed_By_Name__c = isIndividualSigner ? submitterName : null;
            webCase.breg_Signed_By_Entity_Name__c = isIndividualSigner ? null : submitterName;

            webCase.breg_Signature__c = filingInfo.breg_WEB_SUBMITTER_SIGNATURE__c;
            if (TNTMSM_FORMS.contains(filingInfo.breg_WEB_FORM_TYPE__c)) {
                webCase.breg_Signed_By_Office_Held__c = filingInfo.breg_WEB_SUBMITTER_TITLE__c;
            } else {
                webCase.breg_Signed_By_Title_Text__c = filingInfo.breg_WEB_SUBMITTER_TITLE__c;
            }

            // Populate expedited flag
            webCase.breg_Processing_Speed__c = filingInfo.breg_WEB_RDPMS_WFEXP_REG1__c != null &&
                filingInfo.breg_WEB_RDPMS_WFEXP_REG1__c != 'R'
                ? 'Expedited'
                : 'Normal';

            // Populate no change flag for annual filings
            webCase.breg_No_Changes__c = filingInfo.breg_WEB_RDPMS_WFNO_CHANGE__c == '1' ? true : false;
            String accountId = webCase.breg_Entity__c;
            String year = filingInfo.breg_WEB_RDPMS_WFYEAR__c;
            if (String.isNotBlank(accountId) && String.isNotBlank(year) && filingInfo.breg_WEB_FORM_TYPE__c == 'ANN') {
                breg_Annual__c annual = annualsByKey.get(accountId + '_' + year);
                if (annual != null) {
                    webCase.breg_Annual__c = annual.Id;
                }
            }
        }

        return resultsByWorkitemId;
    }

    @TestVisible
    private static Map<String, breg_Annual__c> getAnnualsByAccountsAndYears(List<String> accountIds, List<String> years) {
        Map<String, breg_Annual__c> resultsByKey = new Map<String, breg_Annual__c>();
        if (accountIds == null || accountIds.isEmpty() || years == null || years.isEmpty()) {
            return resultsByKey;
        }
        for (breg_Annual__c annual : [
            SELECT Id, breg_Account__c, breg_Filing_Year__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :accountIds AND breg_Filing_Year__c IN :years
        ]) {
            resultsByKey.put(annual.breg_Account__c + '_' + annual.breg_Filing_Year__c, annual);
        }
        return resultsByKey;
    }

    @TestVisible
    private static Set<String> getWorkitemIdsWithTnmaAddress(Set<String> workitemIds) {
        Set<String> workitemIdsWithTnmaAddress = new Set<String>();
        if (workitemIds == null || workitemIds.isEmpty()) {
            return workitemIdsWithTnmaAddress;
        }

        for (breg_WEB_WEB_ADDRESSES__c webAddress : [
            SELECT breg_WEB_Case__c
            FROM breg_WEB_WEB_ADDRESSES__c
            WHERE breg_WEB_Case__c IN :workitemIds AND breg_WEB_ADDRESS_TYPE__c = :ADDRESS_TYPE_TNMA
        ]) {
            workitemIdsWithTnmaAddress.add(webAddress.breg_WEB_Case__c);
        }

        return workitemIdsWithTnmaAddress;
    }

    @TestVisible
    private static Boolean isAddTnTmSmForm(breg_WEB_WEB_FILING_INFO__c filingInfo, Boolean hasTnmaAddress) {
        return filingInfo != null && filingInfo.breg_WEB_FORM_TYPE__c == ADD_FORM_TYPE && hasTnmaAddress == true;
    }

    @TestVisible
    private static Map<String, breg_TN_TM_SM__c> getLatestTnTmSmByName(
        Map<String, List<SObject>> resultsByWorkitemId,
        Set<String> workitemIdsWithTnmaAddress
    ) {
        Map<String, breg_TN_TM_SM__c> latestTnTmSmByName = new Map<String, breg_TN_TM_SM__c>();
        if (resultsByWorkitemId == null || resultsByWorkitemId.isEmpty() || workitemIdsWithTnmaAddress == null || workitemIdsWithTnmaAddress.isEmpty()) {
            return latestTnTmSmByName;
        }

        Set<String> tntmsmNames = new Set<String>();
        for (String workitemId : resultsByWorkitemId.keySet()) {
            if (!workitemIdsWithTnmaAddress.contains(workitemId)) {
                continue;
            }

            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records == null || records.isEmpty()) {
                continue;
            }

            breg_WEB_WEB_FILING_INFO__c filingInfo = (breg_WEB_WEB_FILING_INFO__c) records[0];
            if (filingInfo.breg_WEB_FORM_TYPE__c == ADD_FORM_TYPE && String.isNotBlank(filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c)) {
                tntmsmNames.add(filingInfo.breg_WEB_RDPMS_WFNEW_NAME__c);
            }
        }

        if (tntmsmNames.isEmpty()) {
            return latestTnTmSmByName;
        }

        for (breg_TN_TM_SM__c tntmsm : [
            SELECT Id, Name, breg_Type__c, breg_Trade_Name__c, breg_Cert_Number__c, breg_TM_SM_Category__c, breg_File__c, breg_Registration_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Name IN :tntmsmNames
            ORDER BY breg_Registration_Date__c DESC, CreatedDate DESC
        ]) {
            if (!latestTnTmSmByName.containsKey(tntmsm.Name)) {
                latestTnTmSmByName.put(tntmsm.Name, tntmsm);
            }
        }

        return latestTnTmSmByName;
    }

    @TestVisible
    private static Map<String, Id> getMatchedContactIdsByWorkitemId(Map<String, List<SObject>> resultsByWorkitemId) {
        Map<String, Id> contactIdByWorkitemId = new Map<String, Id>();
        if (resultsByWorkitemId == null || resultsByWorkitemId.isEmpty()) {
            return contactIdByWorkitemId;
        }

        Map<String, String> nameByWorkitemId = new Map<String, String>();
        Map<String, String> normalizedEmailByWorkitemId = new Map<String, String>();
        Set<String> contactNames = new Set<String>();

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records == null || records.isEmpty()) {
                continue;
            }

            breg_WEB_WEB_FILING_INFO__c filingInfo = (breg_WEB_WEB_FILING_INFO__c) records[0];
            String contactName = normalizeText(filingInfo.breg_WEB_CONTACT_NAME__c);
            String contactEmail = normalizeEmail(filingInfo.breg_WEB_CONTACT_EMAIL__c);

            if (String.isBlank(contactName) || String.isBlank(contactEmail)) {
                continue;
            }

            contactNames.add(contactName);
            nameByWorkitemId.put(workitemId, contactName);
            normalizedEmailByWorkitemId.put(workitemId, contactEmail);
        }

        if (contactNames.isEmpty()) {
            return contactIdByWorkitemId;
        }

        Map<String, List<Id>> contactIdsByNameAndEmailKey = new Map<String, List<Id>>();

        for (Contact contactRecord : [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Name IN :contactNames AND Email != NULL
        ]) {
            String normalizedContactName = normalizeText(contactRecord.Name);
            String normalizedContactEmail = normalizeEmail(contactRecord.Email);

            if (String.isNotBlank(normalizedContactEmail)) {
                String emailKey = buildMatchKey(normalizedContactName, normalizedContactEmail);
                if (!contactIdsByNameAndEmailKey.containsKey(emailKey)) {
                    contactIdsByNameAndEmailKey.put(emailKey, new List<Id>());
                }
                contactIdsByNameAndEmailKey.get(emailKey).add(contactRecord.Id);
            }
        }

        for (String workitemId : nameByWorkitemId.keySet()) {
            String contactName = nameByWorkitemId.get(workitemId);
            String normalizedEmail = normalizedEmailByWorkitemId.get(workitemId);

            String emailKey = buildMatchKey(contactName, normalizedEmail);
            List<Id> matchedByEmail = contactIdsByNameAndEmailKey.get(emailKey);
            if (matchedByEmail != null && matchedByEmail.size() == 1) {
                contactIdByWorkitemId.put(workitemId, matchedByEmail[0]);
            }
        }

        return contactIdByWorkitemId;
    }

    private static String buildMatchKey(String normalizedName, String normalizedSecondaryValue) {
        return normalizedName + '|' + normalizedSecondaryValue;
    }

    private static String normalizeText(String input) {
        return String.isBlank(input) ? null : input.trim().toLowerCase();
    }

    private static String normalizeEmail(String input) {
        return normalizeText(input);
    }

    private static Boolean areEqualIgnoreCase(String firstValue, String secondValue) {
        if (String.isBlank(firstValue) || String.isBlank(secondValue)) {
            return false;
        }
        return firstValue.trim().toLowerCase() == secondValue.trim().toLowerCase();
    }

    private static String trimToNull(String input) {
        return String.isBlank(input) ? null : input.trim();
    }

    private static Datetime toHawaiiDateTime(Date sourceDate) {
        return sourceDate == null ? null : Datetime.newInstanceGmt(sourceDate, HAWAII_DATE_TIME_OFFSET);
    }

    private static Datetime toSubmissionDateTime(Date sourceDate, String hawaiiTimeText) {
        if (sourceDate == null) {
            return null;
        }

        Time scanTime = parseHawaiiScanTime(hawaiiTimeText);
        if (scanTime == null) {
            return toHawaiiDateTime(sourceDate);
        }

        return Datetime.newInstanceGmt(sourceDate, scanTime).addHours(HAWAII_TO_GMT_OFFSET_HOURS);
    }

    @TestVisible
    private static Time parseHawaiiScanTime(String hawaiiTimeText) {
        if (String.isBlank(hawaiiTimeText)) {
            return null;
        }

        String normalizedTime = hawaiiTimeText.trim().toUpperCase().replaceAll('\\s+', ' ');
        List<String> timeParts = normalizedTime.split(' ');
        if (timeParts.size() != 2) {
            return null;
        }

        List<String> hourMinuteParts = timeParts[0].split(':');
        if (hourMinuteParts.size() != 2) {
            return null;
        }

        Integer hourValue;
        Integer minuteValue;
        try {
            hourValue = Integer.valueOf(hourMinuteParts[0]);
            minuteValue = Integer.valueOf(hourMinuteParts[1]);
        } catch (Exception ex) {
            return null;
        }

        if (minuteValue < 0 || minuteValue > 59 || hourValue < 1 || hourValue > 12) {
            return null;
        }

        String meridiem = timeParts[1];
        if (meridiem == 'AM') {
            hourValue = hourValue == 12 ? 0 : hourValue;
        } else if (meridiem == 'PM') {
            hourValue = hourValue == 12 ? 12 : hourValue + 12;
        } else {
            return null;
        }

        return Time.newInstance(hourValue, minuteValue, 0, 0);
    }

    private static NameParts splitName(String fullName) {
        NameParts parts = new NameParts();
        if (String.isBlank(fullName)) {
            return parts;
        }

        String normalizedName = fullName.trim();
        Integer firstSpacePosition = normalizedName.indexOf(' ');
        if (firstSpacePosition < 0) {
            parts.firstName = normalizedName;
            parts.lastName = null;
            return parts;
        }

        parts.firstName = normalizedName.substring(0, firstSpacePosition);
        String remainingName = normalizedName.substring(firstSpacePosition + 1).trim();
        parts.lastName = String.isBlank(remainingName) ? null : remainingName;
        return parts;
    }

    private class NameParts {
        String firstName;
        String lastName;
    }

    public class BREGWebFilingInfo2CaseException extends Exception {
    }
}