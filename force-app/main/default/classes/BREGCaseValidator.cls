public with sharing class BREGCaseValidator {
    private static final String REJECTED_STATUS = 'Rejected';
    private static final String APPROVED_STATUS = 'Approved';
    private static final String COMPLETED_STATUS = 'Completed';
    private static final String REQUIRED_FIELD_MESSAGE = ' is a required field. Please fill it to proceed.';
    private static final String FUTURE_DATE_MESSAGE = ' cannot be a future date.';
    private static final String PAST_DATE_MESSAGE = ' cannot be a past date.';
    private static final String PAST_OR_CURRENT_DATE_MESSAGE = ' cannot be a past or current date.';

    // Static map to cache field API names to labels
    // Object API names are converted to lower case for case-insensitive matching
    private static final Map<String, String> FIELD_LABELS;
    private static final Map<String, String> OBJECT_LABELS;
    private static Boolean isInternalUserCached;
    static {
        FIELD_LABELS = new Map<String, String>();
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        for (String apiName : caseFieldMap.keySet()) {
            FIELD_LABELS.put('case.' + apiName, caseFieldMap.get(apiName).getDescribe().getLabel());
        }

        Map<String, Schema.SObjectField> accountFieldMap = Account.SObjectType.getDescribe().fields.getMap();
        for (String apiName : accountFieldMap.keySet()) {
            FIELD_LABELS.put('account.' + apiName, accountFieldMap.get(apiName).getDescribe().getLabel());
        }

        Map<String, Schema.SObjectField> contactFieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        for (String apiName : contactFieldMap.keySet()) {
            FIELD_LABELS.put('contact.' + apiName, contactFieldMap.get(apiName).getDescribe().getLabel());
        }

        Map<String, Schema.SObjectField> accountAffFieldMap = breg_Account_Affiliation__c.SObjectType.getDescribe().fields.getMap();
        for (String apiName : accountAffFieldMap.keySet()) {
            FIELD_LABELS.put('breg_account_affiliation__c.' + apiName, accountAffFieldMap.get(apiName).getDescribe().getLabel());
        }

        OBJECT_LABELS = new Map<String, String>();
        OBJECT_LABELS.put('case', Case.SObjectType.getDescribe().getLabel());
        OBJECT_LABELS.put('account', Account.SObjectType.getDescribe().getLabel());
        OBJECT_LABELS.put('contact', Contact.SObjectType.getDescribe().getLabel());
        OBJECT_LABELS.put('breg_account_affiliation__c', breg_Account_Affiliation__c.SObjectType.getDescribe().getLabel());
    }

    // Get field label by API name
    public static String getFieldLabel(String fieldApiName) {
        return getFieldLabel(fieldApiName, null);
    }
    public static String getFieldLabel(String fieldApiName, String recordName) {
        String label = fieldApiName;
        fieldApiName = fieldApiName.toLowerCase();
        if (FIELD_LABELS.containsKey(fieldApiName)) {
            label = FIELD_LABELS.get(fieldApiName);
        }
        if (String.isNotBlank(recordName)) {
            String objectName = OBJECT_LABELS.get(fieldApiName.substringBefore('.'));
            label += ' on the ' + recordName + ' ' + objectName + ' record';
        }
        return label;
    }

    public static void validateCases(List<Case> caseList) {
        if (caseList == null || caseList.isEmpty()) {
            return;
        }

        for (Case caseRec : caseList) {
            if (checkCaseForValidation(caseRec)) {
                processCaseValidation(caseRec);
            }

            validateAddressStreetFields(caseRec);
        }
    }

    private static void validateAddressStreetFields(Case caseRec) {
        List<String> streetFields = new List<String>{
            'breg_Company_Address__Street__s',
            'breg_Delivery_Address__Street__s',
            'breg_Mailing_Address__Street__s',
            'breg_New_Mailing_Address__Street__s',
            'breg_New_Registrant_Address__Street__s',
            'breg_New_Company_Address__Street__s'
        };

        for (String fieldName : streetFields) {
            String fieldValue = (String) caseRec.get(fieldName);
            if (String.isNotBlank(fieldValue) && (fieldValue.contains('\r') || fieldValue.contains('\n'))) {
                caseRec.addError(
                    'Invalid ' + getFieldLabel('Case.' + fieldName) + ': newline (\\n) or carriage return (\\r) characters are not permitted'
                );
            }
        }
    }

    private static Boolean isInternalUser() {
        if (isInternalUserCached == null) {
            User u = [
                SELECT UserType, IsPortalEnabled
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];

            isInternalUserCached = (u.UserType == 'Standard' && !u.IsPortalEnabled);
        }

        return isInternalUserCached;
    }

    private static Boolean checkCaseForValidation(Case caseRec) {
        if (caseRec.breg_Bypass_Validation__c) {
            return false;
        }

        // Process only NBR forms
        if (caseRec.breg_Form_Code__c == null || !BREGUtils.isNBRForm(caseRec.breg_Form_Code__c)) {
            return false;
        }

        return true;
    }

    public static void processCaseValidation(Case caseRec) {
        System.debug('Validating case: ' + caseRec);

        Date today = Date.today();

        // Validations for Rejected case
        if (caseRec.Status == REJECTED_STATUS && caseRec.breg_ESWM_WFWORKITEM_ID__c == null) {
            // breg_Resubmission_Due_Date__c
            if (caseRec.breg_Resubmission_Due_Date__c == null) {
                caseRec.breg_Resubmission_Due_Date__c.addError(getFieldLabel('Case.breg_Resubmission_Due_Date__c') + REQUIRED_FIELD_MESSAGE);
            }
            // if (caseRec.breg_Resubmission_Due_Date__c < today) { // disabled validation in BREGMO-74
            //     caseRec.breg_Resubmission_Due_Date__c.addError(getFieldLabel('Case.breg_Resubmission_Due_Date__c') + PAST_DATE_MESSAGE);
            // }
            if (caseRec.breg_Resubmission_Due_Date__c > caseRec.breg_Last_Rejection_Date__c?.addDays(40)) {
                caseRec.breg_Resubmission_Due_Date__c.addError(
                    getFieldLabel('Case.breg_Resubmission_Due_Date__c') + ' cannot be more than 40 days in the future form the day it was rejected.'
                );
            }
        }

        // Validations for Approved case
        if (caseRec.Status == APPROVED_STATUS) {
            // breg_Effective_Date__c
            if (caseRec.breg_Effective_Date__c == null) {
                caseRec.breg_Effective_Date__c.addError(getFieldLabel('Case.breg_Effective_Date__c') + REQUIRED_FIELD_MESSAGE);
            }
        }

        // Validations for Completed case
        if (caseRec.Status == COMPLETED_STATUS) {
            // Company Address
            if (caseRec.breg_Form_Code__c != 'LLC-1') {
                if (caseRec.breg_Company_Address__CountryCode__s == null) {
                    caseRec.breg_Company_Address__CountryCode__s.addError(
                        getFieldLabel('Case.breg_Company_Address__CountryCode__s') + REQUIRED_FIELD_MESSAGE
                    );
                }
                if (caseRec.breg_Company_Address__City__s == null) {
                    caseRec.breg_Company_Address__City__s.addError(getFieldLabel('Case.breg_Company_Address__City__s') + REQUIRED_FIELD_MESSAGE);
                }
                if (caseRec.breg_Company_Address__Street__s == null) {
                    caseRec.breg_Company_Address__Street__s.addError(getFieldLabel('Case.breg_Company_Address__Street__s') + REQUIRED_FIELD_MESSAGE);
                }
                if (caseRec.breg_Company_Address__PostalCode__s == null) {
                    caseRec.breg_Company_Address__PostalCode__s.addError(
                        getFieldLabel('Case.breg_Company_Address__PostalCode__s') + REQUIRED_FIELD_MESSAGE
                    );
                }
            }

            // breg_Duration_Period__c and breg_Expiration_Date__c
            if (caseRec.breg_Form_Code__c == 'FLLC-1' || caseRec.breg_Form_Code__c == 'LLC-1' || caseRec.breg_Form_Code__c == 'AG-1') {
                if (caseRec.breg_Duration_Period__c == null) {
                    caseRec.breg_Duration_Period__c.addError(getFieldLabel('Case.breg_Duration_Period__c') + REQUIRED_FIELD_MESSAGE);
                }

                if (caseRec.breg_Duration_Period__c == 'For a specified term to expire on') {
                    if (caseRec.breg_Expiration_Date__c == null) {
                        caseRec.breg_Expiration_Date__c.addError(getFieldLabel('Case.breg_Expiration_Date__c') + REQUIRED_FIELD_MESSAGE);
                    }
                    if (caseRec.breg_Expiration_Date__c <= today) {
                        caseRec.breg_Expiration_Date__c.addError(getFieldLabel('Case.breg_Expiration_Date__c') + PAST_OR_CURRENT_DATE_MESSAGE);
                    }
                }
            }

            // breg_Purposes__c
            // if (caseRec.breg_Form_Code__c == 'PC-1'
            // || caseRec.breg_Form_Code__c == 'SBC-1'
            // || caseRec.breg_Form_Code__c == 'AG-1'
            // || caseRec.breg_Form_Code__c == 'CONS-1') {
            //     if (caseRec.breg_Purposes__c == null) {
            //         caseRec.breg_Purposes__c.addError(getFieldLabel('Case.breg_Purposes__c') + REQUIRED_FIELD_MESSAGE);
            //     }
            // }

            // Stock
            if (
                caseRec.breg_Form_Code__c == 'DC-1' ||
                caseRec.breg_Form_Code__c == 'SBC-1' ||
                caseRec.breg_Form_Code__c == 'CONS-1' ||
                caseRec.breg_Form_Code__c == 'AG-1'
            ) {
                if (caseRec.breg_Stock_Type__c == null) {
                    caseRec.breg_Stock_Type__c.addError(getFieldLabel('Case.breg_Stock_Type__c') + REQUIRED_FIELD_MESSAGE);
                }
                if (caseRec.breg_Stock_Type__c == 'With Stock' && caseRec.breg_Number_of_common_shares__c == null) {
                    caseRec.breg_Number_of_common_shares__c.addError(getFieldLabel('Case.breg_Number_of_common_shares__c') + REQUIRED_FIELD_MESSAGE);
                }
            }
        }

        // General Validations

        // Entity Name
        if (!isInternalUser()) {
            String errorMessage = BREGStartNewBusinessUtils.validateName(
                caseRec.breg_Name_of_the_Entity__c,
                caseRec.breg_Form_Code__c,
                caseRec.breg_Entity_Type__c,
                caseRec.Status
            );
            if (String.isNotBlank(errorMessage)) {
                caseRec.breg_Name_of_the_Entity__c.addError(errorMessage);
            }
        }

        // breg_Resubmission_Received_Date__c
        if (caseRec.breg_Resubmission_Received_Date__c > today) {
            caseRec.breg_Resubmission_Received_Date__c.addError(getFieldLabel('Case.breg_Resubmission_Received_Date__c') + FUTURE_DATE_MESSAGE);
        }

        // breg_Date_Of_Formation__c
        // if (caseRec.breg_Date_Of_Formation__c == null) {
        //     caseRec.breg_Date_Of_Formation__c.addError(getFieldLabel('Case.breg_Date_Of_Formation__c') + REQUIRED_FIELD_MESSAGE);
        // }
        if (caseRec.breg_Date_Of_Formation__c > today) {
            caseRec.breg_Date_Of_Formation__c.addError(getFieldLabel('Case.breg_Date_Of_Formation__c') + FUTURE_DATE_MESSAGE);
        }
    }

    public static void validateCaseRelations(List<Case> caseList) {
        System.debug('Validating case relations for cases: ' + caseList);
        if (caseList == null || caseList.isEmpty()) {
            return;
        }

        // Prepare Case list for validation
        List<Case> casesToValidate = new List<Case>();
        for (Case caseRec : caseList) {
            if (checkCaseForValidation(caseRec)) {
                casesToValidate.add(caseRec);
            }
        }

        if (casesToValidate.isEmpty()) {
            return;
        }

        // Prepare Map of Case Id to Account Affiliation list
        Map<Id, List<breg_Account_Affiliation__c>> caseIdToAffiliationsMap = new Map<Id, List<breg_Account_Affiliation__c>>();
        List<breg_Account_Affiliation__c> accAffiliations = getAccountAffiliations(casesToValidate);
        for (breg_Account_Affiliation__c accAffiliation : accAffiliations) {
            if (!caseIdToAffiliationsMap.containsKey(accAffiliation.breg_Case__c)) {
                caseIdToAffiliationsMap.put(accAffiliation.breg_Case__c, new List<breg_Account_Affiliation__c>());
            }
            caseIdToAffiliationsMap.get(accAffiliation.breg_Case__c).add(accAffiliation);
        }

        for (Case caseRec : casesToValidate) {
            processCaseRelationsValidation(caseRec, caseIdToAffiliationsMap.get(caseRec.Id));
        }
    }

    private static void processCaseRelationsValidation(Case caseRec, List<breg_Account_Affiliation__c> accAffList) {
        System.debug('Validating case relations for case: ' + caseRec);

        // Validate Account Affiliations
        if (accAffList == null)
            accAffList = new List<breg_Account_Affiliation__c>();

        Map<String, List<breg_Account_Affiliation__c>> roleToAccAffsMap = new Map<String, List<breg_Account_Affiliation__c>>();
        for (breg_Account_Affiliation__c accAff : accAffList) {
            // Set Map of Role to Account Affiliations
            if (accAff.breg_Role__c != null) {
                if (!roleToAccAffsMap.containsKey(accAff.breg_Role__c)) {
                    roleToAccAffsMap.put(accAff.breg_Role__c, new List<breg_Account_Affiliation__c>());
                }
                roleToAccAffsMap.get(accAff.breg_Role__c).add(accAff);
            }

            // Validations for Completed case
            if (caseRec.Status == COMPLETED_STATUS || caseRec.Status == APPROVED_STATUS) {
                // breg_Role__c
                if (accAff.breg_Role__c == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Role__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }

                // breg_Officer_Director_Titles__c
                if (accAff.breg_Officer_Director_Titles__c == null && accAff.breg_Role__c == 'Director') {
                    if (caseRec.breg_Form_Code__c == 'AG-1' || caseRec.breg_Form_Code__c == 'CONS-1') {
                        caseRec.addError(
                            getFieldLabel('breg_Account_Affiliation__c.breg_Officer_Director_Titles__c', accAff.Name) + REQUIRED_FIELD_MESSAGE
                        );
                    }
                }

                // breg_Type__c
                if (accAff.breg_Type__c == 'Entity') {
                    if (accAff.breg_Entity_Name__c == null) {
                        caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Entity_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                    }
                } else if (accAff.breg_Type__c == 'Individual') {
                    if (accAff.breg_First_Name__c == null) {
                        caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_First_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                    }
                    if (accAff.breg_Last_Name__c == null) {
                        caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Last_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                    }
                } else if (accAff.breg_Type__c == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Type__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }

                // Address fields
                if (accAff.breg_Address__CountryCode__s == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__CountryCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }
                if (accAff.breg_Address__Street__s == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__Street__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }
                if (accAff.breg_Address__StateCode__s == null && BREGUtils.doesCountryHaveStates(accAff.breg_Address__CountryCode__s)) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__StateCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }
                if (accAff.breg_Address__City__s == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__City__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }
                if (accAff.breg_Address__PostalCode__s == null) {
                    caseRec.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__PostalCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
                }
            }
        }

        if ((caseRec.Status == COMPLETED_STATUS || caseRec.Status == APPROVED_STATUS) && caseRec.Origin == 'Web') {
            // Validate number of Members
            List<breg_Account_Affiliation__c> officers = roleToAccAffsMap.get('Officer');
            List<breg_Account_Affiliation__c> directors = roleToAccAffsMap.get('Director');
            List<breg_Account_Affiliation__c> officersDirectors = roleToAccAffsMap.get('Officer/Director');
            List<breg_Account_Affiliation__c> managers = roleToAccAffsMap.get('Manager');
            List<breg_Account_Affiliation__c> members = roleToAccAffsMap.get('Member');
            List<breg_Account_Affiliation__c> partners = roleToAccAffsMap.get('Partner');

            // PC-1
            if (caseRec.breg_Form_Code__c == 'PC-1') {
                if (officers == null || officers.isEmpty()) {
                    caseRec.addError('Add at least 1 officer to proceed.');
                }
                if (directors == null || directors.isEmpty()) {
                    caseRec.addError('Add at least 1 director to proceed.');
                }
            }
            // SOLE-1
            else if (caseRec.breg_Form_Code__c == 'SOLE-1') {
                if (officers == null || officers.isEmpty()) {
                    caseRec.addError('Add at least 1 officer to proceed.');
                }
            }
            // CONS-1 || AG-1
            else if (caseRec.breg_Form_Code__c == 'CONS-1' || caseRec.breg_Form_Code__c == 'AG-1') {
                if (caseRec.breg_Stock_Type__c == 'With Stock') {
                    if (directors == null || directors.isEmpty()) {
                        caseRec.addError('Add at least 1 director to proceed.');
                    }
                } else if (caseRec.breg_Stock_Type__c == 'Without Stock') {
                    if (directors == null || directors.isEmpty() || directors.size() < 3) {
                        caseRec.addError('Add at least 3 directors to proceed.');
                    }
                }
            }
            // FC-1
            else if (caseRec.breg_Form_Code__c == 'FC-1') {
                if ((officers == null || officers.isEmpty()) && (directors == null || directors.isEmpty())) {
                    caseRec.addError('Add at least 1 officer/director to proceed.');
                }
            }
            // GP-1 || LLP-1 || FLLP-1
            else if (caseRec.breg_Form_Code__c == 'GP-1') {
                // EG 25/11/2025: commented as no Partners section on these forms || caseRec.breg_Form_Code__c == 'LLP-1' || caseRec.breg_Form_Code__c == 'FLLP-1'
                if (partners == null || partners.isEmpty()) {
                    caseRec.addError('Add at least 1 partner to proceed.');
                }
            }
            // LP-1 || FLP-1
            else if (caseRec.breg_Form_Code__c == 'LP-1' || caseRec.breg_Form_Code__c == 'FLP-1') {
                if (partners == null || partners.isEmpty()) {
                    caseRec.addError('Add at least 1 partner to proceed.');
                }
            }
            // LLC-1 || FLLC-1
            else if (caseRec.breg_Form_Code__c == 'LLC-1' || caseRec.breg_Form_Code__c == 'FLLC-1') {
                if (!caseRec.breg_Is_Manager_Managed__c) {
                    if (members == null || members.isEmpty()) {
                        caseRec.addError('Add at least 1 member to proceed.');
                    }
                }
            }
            // DNP-1
            else if (caseRec.breg_Form_Code__c == 'DNP-1') {
                if (directors != null && directors.size() != 0 && directors.size() < 3) {
                    caseRec.addError('The board of directors shall consist of three or more individuals.');
                }
            }
            // SBC-1
            // else if (caseRec.breg_Form_Code__c == 'SBC-1') {
            //     if (directors == null || directors.isEmpty()) {
            //         caseRec.addError('Add at least 1 director to proceed.');
            //     } else {
            //         EG 01/19/2026: commented as no 'Benefit Director' value in breg_Officer_Director_Titles__c. Need to finalize the values with business

            //         Check if at least one director has the role of Benefit Director
            //         Boolean hasBenefitDirector = false;
            //         for (breg_Account_Affiliation__c director : directors) {
            //             if (director.breg_Officer_Director_Titles__c.contains('Benefit Director') || director.breg_Officer_Director_Other_Title__c == 'Benefit Director') {
            //                 hasBenefitDirector = true;
            //                 break;
            //             }
            //         }
            //         if (!hasBenefitDirector) {
            //             caseRec.addError('One of the Directors\' Officer/Director Titles must be "Benefit Director".');
            //         }
            //     }
            // }
        }
    }

    private static List<breg_Account_Affiliation__c> getAccountAffiliations(List<Case> caseList) {
        List<breg_Account_Affiliation__c> accAffiliations = [
            SELECT
                Id,
                Name,
                breg_Case__c,
                breg_Account__c,
                breg_Account__r.Name,
                breg_Account__r.BillingCountryCode,
                breg_Account__r.BillingStreet,
                breg_Account__r.BillingStateCode,
                breg_Account__r.BillingCity,
                breg_Account__r.BillingPostalCode,
                breg_Contact__c,
                breg_Contact__r.Name,
                breg_Contact__r.FirstName,
                breg_Contact__r.LastName,
                breg_Contact__r.MailingCountryCode,
                breg_Contact__r.MailingStreet,
                breg_Contact__r.MailingStateCode,
                breg_Contact__r.MailingCity,
                breg_Contact__r.MailingPostalCode,
                breg_Address__CountryCode__s,
                breg_Address__Street__s,
                breg_Address__StateCode__s,
                breg_Address__City__s,
                breg_Address__PostalCode__s,
                breg_Address_Street_2__c,
                breg_Entity_Location__c,
                breg_Entity_Location_Country__c,
                breg_Entity_Name__c,
                breg_Entity_Type__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Number_of_shares__c,
                breg_Role__c,
                breg_Type__c,
                breg_Officer_Director_Titles__c,
                breg_Officer_Director_Other_Title__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseList
        ];
        return accAffiliations;
    }
}