/**
 * Handler for the TNTMSM Renewal forms (T-1, T-2, T-3)
 */
public with sharing class BREGCaseStatusHandlerTNTMSMRenewal extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        system.debug('BREGCaseStatusHandlerTNTMSMRenewal: ' + cases);
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
            performValidation(cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(cases, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        switch on newStatus {
            when 'Pending Submission' {
                checkDateOfTheFirstUse(cases);
            }
            when 'Approved' {
                checkTNTMSMIsLinked(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void checkTNTMSMIsLinked(List<Case> cases) {
        String errorMessage = 'TN/TM/SM is required to approve a TN/TM/SM Renewal filing.';
        for (Case caseRecord : cases) {
            if (caseRecord.breg_TNTMSM_Registration_Type__c == 'Renewal' && caseRecord.breg_TN_TM_SM__c == null) {
                addErrorMessage(caseRecord, 'breg_TN_TM_SM__c', errorMessage);
            }
        }
    }

    private void checkDateOfTheFirstUse(List<Case> cases) {
        system.debug('TNTMSMRenewal:' + cases);
        String errorMessage = 'The date of first use cannot be a future date.';
        for (Case caseRecord : cases) {
            if (caseRecord.breg_TNTMSM_First_Used_Anywhere__c > Date.today() || caseRecord.breg_TNTMSM_First_Used_Hawaii__c > Date.today()) {
                addErrorMessage(caseRecord, '', errorMessage);
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Approved' {
                updateExpirationDate(cases);
            }
            when 'Completed' {
                updateTNTMSMs(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateExpirationDate(List<Case> cases) {
        Map<Id, Date> previousExpirationDateByCaseId = getPreviousExpirationDateByCaseId(cases);
        List<Case> casesToUpdate = new List<Case>();
        for (Case c : cases) {
            Case cToUpdate = new Case();
            cToUpdate.Id = c.Id;

            Date baseExpirationDate = previousExpirationDateByCaseId.get(c.Id);
            if (baseExpirationDate != null) {
                cToUpdate.breg_Expiration_Date__c = baseExpirationDate.addYears(5);
            } else {
                // Add 5 years to the effective date to set the expiration date for new registrations.
                cToUpdate.breg_Expiration_Date__c = c.breg_Effective_Date__c != null ? c.breg_Effective_Date__c.addYears(5).addDays(-1) : null;
            }
            casesToUpdate.add(cToUpdate);
        }
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private Map<Id, Date> getPreviousExpirationDateByCaseId(List<Case> cases) {
        Map<Id, Date> previousExpirationDateByCaseId = new Map<Id, Date>();
        Map<Id, String> lookupKeyByCaseId = new Map<Id, String>();
        Set<String> descriptions = new Set<String>();
        Set<String> certificates = new Set<String>();

        for (Case c : cases) {
            if (
                c.breg_TNTMSM_Registration_Type__c != 'Renewal' ||
                String.isBlank(c.breg_TNTMSM_Description__c) ||
                String.isBlank(c.breg_TNTMSM_Certificate__c)
            ) {
                continue;
            }

            lookupKeyByCaseId.put(c.Id, buildDescriptionCertificateKey(c.breg_TNTMSM_Description__c, c.breg_TNTMSM_Certificate__c));
            descriptions.add(c.breg_TNTMSM_Description__c);
            certificates.add(c.breg_TNTMSM_Certificate__c);
        }

        if (lookupKeyByCaseId.isEmpty()) {
            return previousExpirationDateByCaseId;
        }

        Map<String, Date> previousExpirationDateByLookupKey = new Map<String, Date>();

        for (breg_TN_TM_SM__c tntmsm : [
            SELECT Id, Name, breg_Cert_Number__c, breg_Expiration_Date__c
            FROM breg_TN_TM_SM__c
            WHERE Name IN :descriptions
                AND breg_Cert_Number__c IN :certificates
                AND breg_Expiration_Date__c != NULL
            ORDER BY breg_Expiration_Date__c DESC, CreatedDate DESC
        ]) {
            String lookupKey = buildDescriptionCertificateKey(tntmsm.Name, tntmsm.breg_Cert_Number__c);
            if (!previousExpirationDateByLookupKey.containsKey(lookupKey)) {
                previousExpirationDateByLookupKey.put(lookupKey, tntmsm.breg_Expiration_Date__c);
            }
        }

        for (Id caseId : lookupKeyByCaseId.keySet()) {
            Date previousExpirationDate = previousExpirationDateByLookupKey.get(lookupKeyByCaseId.get(caseId));
            if (previousExpirationDate != null) {
                previousExpirationDateByCaseId.put(caseId, previousExpirationDate);
            }
        }

        return previousExpirationDateByCaseId;
    }

    private String buildDescriptionCertificateKey(String description, String certificate) {
        return description + '|' + certificate;
    }

    private void updateTNTMSMs(List<Case> cases) {
        List<breg_TN_TM_SM__c> tnTmSmsToUpdate = new List<breg_TN_TM_SM__c>();
        Map<Id, breg_TN_TM_SM__c> tnTmSmsMap = getTNTMSMMap(getTNTMSMIds(cases));
        Map<Id, breg_Account_Affiliation__c> caseIdToAccAffsMap = getCaseIdToAccAffsMap(getCaseIds(cases));
        for (Case c : cases) {
            breg_Account_Affiliation__c accAff = caseIdToAccAffsMap.get(c.Id);
            if (tnTmSmsMap.containsKey(c.breg_TN_TM_SM__c)) {
                breg_TN_TM_SM__c tnTmSm = tnTmSmsMap.get(c.breg_TN_TM_SM__c);
                tnTmSm.breg_Expiration_Date__c = c.breg_Expiration_Date__c;
                if (c.breg_TNTMSM_Registration_Type__c == 'Renewal' || c.breg_Is_Renewal__c) {
                    if (tnTmSm.breg_Status__c == 'E') {
                        tnTmSm.breg_Status__c = 'A';
                    }
                }
                if (accAff != null) {
                    tnTmSm.breg_Mailing_Address__City__s = accAff.breg_Address__City__s;
                    tnTmSm.breg_Mailing_Address__StateCode__s = accAff.breg_Address__StateCode__s;
                    tnTmSm.breg_Mailing_Address__Street__s = accAff.breg_Address__Street__s;
                    tnTmSm.breg_Mailing_Address__PostalCode__s = accAff.breg_Address__PostalCode__s;
                    tnTmSm.breg_Mailing_Address__CountryCode__s = accAff.breg_Address__CountryCode__s;
                }
                if (c.breg_TNTMSM_Classification__c != null) {
                    tnTmSm.breg_TM_SM_Category__c = c.breg_TNTMSM_Classification__c;
                }
                tnTmSmsToUpdate.add(tnTmSm);
            }
        }
        if (!tnTmSmsToUpdate.isEmpty()) {
            update tnTmSmsToUpdate;
        }
    }

    private Map<Id, breg_TN_TM_SM__c> getTNTMSMMap(Set<Id> ids) {
        return new Map<Id, breg_TN_TM_SM__c>(
            [
                SELECT Id, breg_Expiration_Date__c, breg_Status__c
                FROM breg_TN_TM_SM__c
                WHERE Id IN :ids
            ]
        );
    }

    private Set<Id> getTNTMSMIds(List<Case> cases) {
        Set<Id> ids = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_TN_TM_SM__c != null) {
                ids.add(c.breg_TN_TM_SM__c);
            }
        }
        return ids;
    }

    private Map<Id, breg_Account_Affiliation__c> getCaseIdToAccAffsMap(Set<Id> caseIds) {
        Map<Id, breg_Account_Affiliation__c> caseIdToAccAffsMap = new Map<Id, breg_Account_Affiliation__c>();

        List<breg_Account_Affiliation__c> accAffs = [
            SELECT
                Id,
                breg_Type__c,
                breg_Entity_Name__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Role__c,
                breg_Case__c,
                breg_Address__CountryCode__s,
                breg_Address__StateCode__s,
                breg_Address__City__s,
                breg_Address__Street__s,
                breg_Address__PostalCode__s,
                breg_Address_Street_2__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND (breg_Role__c = 'Applicant' OR breg_Role__c = 'New Applicant')
        ];

        for (breg_Account_Affiliation__c accAff : accAffs) {
            if (!caseIdToAccAffsMap.containsKey(accAff.breg_Case__c)) {
                caseIdToAccAffsMap.put(accAff.breg_Case__c, accAff);
            }
        }
        return caseIdToAccAffsMap;
    }
}