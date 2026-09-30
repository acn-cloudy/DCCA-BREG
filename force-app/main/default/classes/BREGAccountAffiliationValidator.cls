public with sharing class BREGAccountAffiliationValidator {
    private static final String PENDING_SUBMISSION_STATUS = 'Pending Submission';
    private static final String REQUIRED_FIELD_MESSAGE = ' is a required field. Please fill it to proceed.';

    // Static map to cache field API names to labels
    // Object API names are converted to lower case for case-insensitive matching
    // private static final Map<String, String> FIELD_LABELS;
    // private static final Map<String, String> OBJECT_LABELS;
    // static {
    //     FIELD_LABELS = new Map<String, String>();
    //     Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
    //     for (String apiName : caseFieldMap.keySet()) {
    //         FIELD_LABELS.put('case.' + apiName, caseFieldMap.get(apiName).getDescribe().getLabel());
    //     }

    //     Map<String, Schema.SObjectField> accountFieldMap = Account.SObjectType.getDescribe().fields.getMap();
    //     for (String apiName : accountFieldMap.keySet()) {
    //         FIELD_LABELS.put('account.' + apiName, accountFieldMap.get(apiName).getDescribe().getLabel());
    //     }

    //     Map<String, Schema.SObjectField> contactFieldMap = Contact.SObjectType.getDescribe().fields.getMap();
    //     for (String apiName : contactFieldMap.keySet()) {
    //         FIELD_LABELS.put('contact.' + apiName, contactFieldMap.get(apiName).getDescribe().getLabel());
    //     }

    //     Map<String, Schema.SObjectField> accountAffFieldMap = breg_Account_Affiliation__c.SObjectType.getDescribe().fields.getMap();
    //     for (String apiName : accountAffFieldMap.keySet()) {
    //         FIELD_LABELS.put('breg_account_affiliation__c.' + apiName, accountAffFieldMap.get(apiName).getDescribe().getLabel());
    //     }

    //     OBJECT_LABELS = new Map<String, String>();
    //     OBJECT_LABELS.put('case', Case.SObjectType.getDescribe().getLabel());
    //     OBJECT_LABELS.put('account', Account.SObjectType.getDescribe().getLabel());
    //     OBJECT_LABELS.put('contact', Contact.SObjectType.getDescribe().getLabel());
    //     OBJECT_LABELS.put('breg_account_affiliation__c', breg_Account_Affiliation__c.SObjectType.getDescribe().getLabel());
    // }

    public static void validateCaseRelations(List<breg_Account_Affiliation__c> accAffiliationList) {
        System.debug('Validating case relations for account affilations: ' + accAffiliationList);

        if (accAffiliationList == null || accAffiliationList.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();

        Map<Id, List<breg_Account_Affiliation__c>> caseIdToTriggerAffiliationsMap =
            new Map<Id, List<breg_Account_Affiliation__c>>();

        for (breg_Account_Affiliation__c accAffiliation : accAffiliationList) {
            if (accAffiliation.breg_Case__c != null) {
                caseIds.add(accAffiliation.breg_Case__c);

                if (!caseIdToTriggerAffiliationsMap.containsKey(accAffiliation.breg_Case__c)) {
                    caseIdToTriggerAffiliationsMap.put(
                        accAffiliation.breg_Case__c,
                        new List<breg_Account_Affiliation__c>()
                    );
                }

                caseIdToTriggerAffiliationsMap.get(accAffiliation.breg_Case__c).add(accAffiliation);
            }
        }

        if (caseIds.isEmpty()) {
            return;
        }

        Map<Id, List<breg_Account_Affiliation__c>> caseIdToAffiliationsMap =
            new Map<Id, List<breg_Account_Affiliation__c>>();

        for (breg_Account_Affiliation__c accAffiliation : [
            SELECT
                Id,
                Name,
                breg_Case__c,
                breg_Role__c,
                breg_Type__c,
                breg_Entity_Name__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Address__CountryCode__s,
                breg_Address__Street__s,
                breg_Address__StateCode__s,
                breg_Address__City__s,
                breg_Address__PostalCode__s
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds
        ]) {
            if (!caseIdToAffiliationsMap.containsKey(accAffiliation.breg_Case__c)) {
                caseIdToAffiliationsMap.put(
                    accAffiliation.breg_Case__c,
                    new List<breg_Account_Affiliation__c>()
                );
            }

            caseIdToAffiliationsMap.get(accAffiliation.breg_Case__c).add(accAffiliation);
        }

        List<Case> casesToValidate = getCases(caseIds);

        for (Case caseRec : casesToValidate) {
            processCaseRelationsValidation(
                caseRec,
                caseIdToAffiliationsMap.get(caseRec.Id),
                caseIdToTriggerAffiliationsMap.get(caseRec.Id)
            );
        }
    }

    private static void processCaseRelationsValidation(Case caseRec, List<breg_Account_Affiliation__c> accAffList, List<breg_Account_Affiliation__c> errorTargetList) {
        System.debug('Validating case relations for case: ' + caseRec);
        // Validate Account Affiliations
        if (accAffList == null) 
            accAffList = new List<breg_Account_Affiliation__c>();

        if (errorTargetList == null || errorTargetList.isEmpty()) {
            return;
        }

        breg_Account_Affiliation__c errorTarget = errorTargetList[0];

        Map<String, List<breg_Account_Affiliation__c>> roleToAccAffsMap = new Map<String, List<breg_Account_Affiliation__c>>();
        for (breg_Account_Affiliation__c accAff : accAffList) {
            // Set Map of Role to Account Affiliations
            if (accAff.breg_Role__c != null) {
                if (!roleToAccAffsMap.containsKey(accAff.breg_Role__c)) {
                    roleToAccAffsMap.put(accAff.breg_Role__c, new List<breg_Account_Affiliation__c>());
                }
                roleToAccAffsMap.get(accAff.breg_Role__c).add(accAff);
            }

            // Validations for New case
            // if (caseRec.Status == PENDING_SUBMISSION_STATUS) {
            //     // breg_Role__c
            //     if (accAff.breg_Role__c == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Role__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }

            //     // breg_Office_Held__c
            //     // if (accAff.breg_Office_Held__c == null) {
            //     //&& accAff.breg_Role__c == 'Director'
            //     // if (caseRec.breg_Form_Code__c == 'FC-1' || caseRec.breg_Form_Code__c == 'AG-1' || caseRec.breg_Form_Code__c == 'CONS-1') {
            //     // accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Office_Held__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     // }
            //     // }

            //     // breg_Type__c
            //     if (accAff.breg_Type__c == 'Entity') {
            //         if (accAff.breg_Entity_Name__c == null) {
            //             accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Entity_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //         }
            //     } else if (accAff.breg_Type__c == 'Individual') {
            //         if (accAff.breg_First_Name__c == null) {
            //             accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_First_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //         }
            //         if (accAff.breg_Last_Name__c == null) {
            //             accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Last_Name__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //         }
            //     } else if (accAff.breg_Type__c == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Type__c', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }

            //     // Address fields
            //     if (accAff.breg_Address__CountryCode__s == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__CountryCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }
            //     if (accAff.breg_Address__Street__s == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__Street__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }
            //     if (accAff.breg_Address__StateCode__s == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__StateCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }
            //     if (accAff.breg_Address__City__s == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__City__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }
            //     if (accAff.breg_Address__PostalCode__s == null) {
            //         accAff.addError(getFieldLabel('breg_Account_Affiliation__c.breg_Address__PostalCode__s', accAff.Name) + REQUIRED_FIELD_MESSAGE);
            //     }
            // }
        }
        if ((caseRec.Status == PENDING_SUBMISSION_STATUS || caseRec.Status == 'New') && caseRec.Origin == 'Web') {
            // Validate number of Members
            List<breg_Account_Affiliation__c> officers = roleToAccAffsMap.get('Officer');
            List<breg_Account_Affiliation__c> directors = roleToAccAffsMap.get('Director');
            List<breg_Account_Affiliation__c> managers = roleToAccAffsMap.get('Manager');
            List<breg_Account_Affiliation__c> members = roleToAccAffsMap.get('Member');
            List<breg_Account_Affiliation__c> partners = roleToAccAffsMap.get('Partner');
            String formCode = '';
            if (caseRec.breg_Form_Code__c != null) {
                formCode = caseRec.breg_Form_Code__c?.startsWith('ANN-') ? caseRec.breg_Form_Code__c?.substring(4) : caseRec.breg_Form_Code__c;
            }
            system.debug(formCode);
            // PC-1
            if (formCode == 'PC-1') {
                if (officers == null || officers.isEmpty()) {
                    errorTarget.addError('Add at least 1 officer to proceed.');
                }
                if (directors == null || directors.isEmpty()) {
                    errorTarget.addError('Add at least 1 director to proceed.');
                }
            }
            // SOLE-1
            else if (formCode == 'SOLE-1') {
                if (officers == null || officers.isEmpty()) {
                    errorTarget.addError('Add at least 1 officer to proceed.');
                }
            }
            // CONS-1 || AG-1
            else if (formCode == 'CONS-1' || formCode == 'AG-1') {
                if (officers == null || officers.isEmpty()) {
                    errorTarget.addError('Add at least 1 officer to proceed.');
                }
                if (caseRec.breg_Stock_Type__c == 'With Stock') {
                    if (directors == null || directors.isEmpty()) {
                        errorTarget.addError('Add at least 1 director to proceed.');
                    }
                } else if (caseRec.breg_Stock_Type__c == 'Without Stock') {
                    if (directors == null || directors.isEmpty() || directors.size() < 3) {
                        errorTarget.addError('Add at least 3 directors to proceed.');
                    }
                }
            }
            // GP-1 || LLP-1 || FLLP-1
            else if (formCode == 'GP-1') {
                // EG 25/11/2025: commented as no Partners section on these forms  || formCode == 'LLP-1' || formCode == 'FLLP-1'
                if ((partners == null || partners.isEmpty()) || partners.size() < 2) {
                    errorTarget.addError('Add at least 2 partners to proceed.');
                }
            }
            // LP-1 || FLP-1
            else if (formCode == 'LP-1' || formCode == 'FLP-1') {
                if (partners == null || partners.isEmpty()) {
                    errorTarget.addError('Add at least 1 partner to proceed.');
                }
            }
            // LLC-1 || FLLC-1
            else if (formCode == 'LLC-1' || formCode == 'FLLC-1') {
                if (!caseRec.breg_Is_Manager_Managed__c) {
                    if (members == null || members.isEmpty()) {
                        errorTarget.addError('Add at least 1 member to proceed.');
                    }
                }
            }
            // SBC-1
            // else if (formCode == 'SBC-1') {
            //     if (directors == null || directors.isEmpty()) {
            //         errorTarget.addError('Add at least 1 director to proceed.');
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
            //             errorTarget.addError('One of the Directors\'  Officer/Director Titles must be "Benefit Director".');
            //         }
            //     }
            // }
            // FC-1
            else if (formCode == 'FC-1') {
                if ((officers == null || officers.isEmpty()) && (directors == null || directors.isEmpty())) {
                    errorTarget.addError('Add at least 1 officer/director to proceed.');
                }
            }
            // DNP-1
            else if (formCode == 'DNP-1') {
                if (directors != null && directors.size() > 0 && directors.size() < 3) {
                    errorTarget.addError('The board of directors shall consist of three or more individuals.');
                }
            }
            // ANN-DNP-1
            else if (caseRec.breg_Form_Code__c == 'ANN-DNP-1') {
                if (directors != null && directors.size() > 0 && directors.size() < 3) {
                    errorTarget.addError('Add at least 3 directors to proceed.');
                }
            }
        }
    }

    private static List<Case> getCases(Set<Id> caseIds) {
        List<Case> cases = [
            SELECT Id, Status, Origin, breg_Form_Code__c, breg_Stock_Type__c, breg_Is_Manager_Managed__c
            FROM Case
            WHERE Id IN :caseIds
        ];
        return cases;
    }

    // public static String getFieldLabel(String fieldApiName, String recordName) {
    //     String label = fieldApiName;
    //     fieldApiName = fieldApiName.toLowerCase();
    //     if (FIELD_LABELS.containsKey(fieldApiName)) {
    //         label = FIELD_LABELS.get(fieldApiName);
    //     }
    //     if (String.isNotBlank(recordName)) {
    //         String objectName = OBJECT_LABELS.get(fieldApiName.substringBefore('.'));
    //         label += ' on the ' + recordName + ' ' + objectName + ' record';
    //     }
    //     return label;
    // }
}