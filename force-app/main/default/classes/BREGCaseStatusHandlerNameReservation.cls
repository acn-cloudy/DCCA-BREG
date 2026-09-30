/**
 * Handler for the X-1 Name Reservation form
 */
public with sharing class BREGCaseStatusHandlerNameReservation extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        system.debug('BREGCaseStatusHandlerNameReservation: ' + cases);
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        Map<Id, Case> mapCasesForCheck = new Map<Id, Case>(casesForCheck);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(mapCasesForCheck, cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(mapCasesForCheck, cases, newStatus);
        }
    }

    private void performValidation(Map<Id, Case> casesForCheck, List<Case> cases, String newStatus) {
        switch on newStatus {
            when 'Pending Submission' {
                validateEntityName(casesForCheck, cases);
            }
            when 'Approved' {
                validateEntityName(casesForCheck, cases);
                validateApplicantInfo(casesForCheck, cases);
            }
            when 'Completed' {
                validateEntityName(casesForCheck, cases);
            }
            when 'Rejected' {
                validateEntityName(casesForCheck, cases);
            }
            when else {
                // do nothing
            }
        }
    }

     private void performActions(Map<Id, Case> casesForCheck, List<Case> cases, String newStatus) {
        switch on newStatus {
            when 'Completed' {
                updateEntityStatus(casesForCheck, cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateEntityStatus(Map<Id, Case> casesForCheck, List<Case> cases) {
        List<Account> entitiesToUpdate = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case c : cases) {
            if (c.breg_Name_Reservation__c != null ) {
                entitiesToUpdate.add(new Account(Id = c.breg_Name_Reservation__c, breg_Entity_Status__c = 'Active (A)'));
                entityToCaseMap.put(c.breg_Name_Reservation__c, c);
                accountUpdatedFieldsMap.put(c.breg_Name_Reservation__c, new Set<String>{ 'breg_Entity_Status__c' });
            } else {
                //do nothiing - handled in Amendment case
            }
        }
        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private void validateEntityName(Map<Id, Case> casesForCheck, List<Case> cases) {
        system.debug('BREGCaseStatusHandlerNameReservation.validateEntityName: ' + cases);

        for (Case triggerCase : cases) {
            Case caseRecord = casesForCheck.isEmpty() ? triggerCase : casesForCheck.get(triggerCase.Id);
            String entityName = caseRecord.breg_Name_of_the_Entity__c;
            String entityType = caseRecord.breg_Entity_Type__c;
            String errorMessage;
            List<String> requiredWords = new List<String>();
            switch on entityType {
                when 'D1', 'P1', 'S1', 'CORPORATION' {
                    requiredWords.addAll(new List<String>{ 'CORPORATION', 'INCORPORATED', 'LIMITED', 'CORP.', 'INC.', 'LTD.' });
                    errorMessage = ERROR_ENTITY_TYPE_DOMESTIC_CORP;
                }
                when 'L5', 'LIMITED PARTNERSHIP' {
                    requiredWords.addAll(new List<String>{ 'LIMITED PARTNERSHIP', 'L.P.', 'LP' });
                    errorMessage = ERROR_ENTITY_TYPE_LP;
                }
                when 'Q5', 'Q6', 'LIMITED LIABILITY LIMITED PARTNERSHIP' {
                    requiredWords.addAll(new List<String>{ 'LIMITED LIABILITY LIMITED PARTNERSHIP', 'L.L.L.P.', 'LLLP' });
                    errorMessage = ERROR_ENTITY_TYPE_LLLP;
                }
                when 'C5', 'LIMITED LIABILITY COMPANY' {
                    requiredWords.addAll(
                        new List<String>{ 'LIMITED LIABILITY COMPANY', 'L.L.C.', 'LLC', 'LIMITED LIABILITY LAW COMPANY', 'L.L.L.C.', 'LLLC' }
                    );
                    errorMessage = ERROR_ENTITY_TYPE_LLC;
                }
                when 'K5', 'LIMITED LIABILITY PARTNERSHIP' {
                    requiredWords.addAll(
                        new List<String>{
                            'REGISTERED LIMITED LIABILITY PARTNERSHIP',
                            'R.L.L.P.',
                            'LLP',
                            'LIMITED LIABILITY LAW PARTNERSHIP',
                            'L.L.P.',
                            'RLLP'
                        }
                    );
                    errorMessage = ERROR_ENTITY_TYPE_LLP;
                }
                when 'C1', 'C2', 'COOPERATIVE' {
                    requiredWords.addAll(new List<String>{ 'COOPERATIVE', 'COOP.', 'CO-OP' });
                    errorMessage = ERROR_ENTITY_TYPE_COOPERATIVE;
                }
                when else {
                    continue;
                }
            }

            if (requiredWords.isEmpty()) {
                continue;
            }

            Boolean hasRequiredWord = false;
            for (String word : requiredWords) {
                if (checkEntityNameContainsWord(entityName, word)) {
                    hasRequiredWord = true;
                    break;
                }
            }

            if (!hasRequiredWord) {
                addErrorMessage(triggerCase, 'breg_New_Entity_Name__c', errorMessage);
            }
        }
    }

    private boolean checkEntityNameContainsWord(String entityName, String word) {
        return entityName.toUpperCase().contains(word);
    }

    private void validateApplicantInfo(Map<Id, Case> casesForCheck, List<Case> cases) {
        system.debug('BREGCaseStatusHandlerNameReservation.validateApplicantInfo: ' + cases);
        Set<Id> caseIds = casesForCheck.isEmpty() ? getCaseIds(cases) : casesForCheck.keySet();
        Map<Id, List<breg_Account_Affiliation__c>> applicantsByCase = getApplicantsByCase(caseIds);

        for (Case triggerCase : cases) {
            Case caseRecord = casesForCheck.isEmpty() ? triggerCase : casesForCheck.get(triggerCase.Id);
            List<breg_Account_Affiliation__c> applicants = applicantsByCase.get(caseRecord.Id);

            if (applicants == null || applicants.isEmpty()) {
                addErrorMessage(triggerCase, '', ERROR_APPLICANT_REQUIRED);
                continue;
            }

            for (breg_Account_Affiliation__c applicant : applicants) {
                if (
                    String.isBlank(applicant.breg_Address__City__s) ||
                    String.isBlank(applicant.breg_Address__CountryCode__s) ||
                    String.isBlank(applicant.breg_Address__PostalCode__s) ||
                    String.isBlank(applicant.breg_Address__StateCode__s) ||
                    String.isBlank(applicant.breg_Address__Street__s)
                ) {
                    addErrorMessage(triggerCase, '', ERROR_APPLICANT_ADDRESS_REQUIRED);
                }
                if (applicant.breg_Type__c == 'Entity' && String.isBlank(applicant.breg_Entity_Name__c)) {
                    addErrorMessage(triggerCase, 'breg_Entity_Name__c', ERROR_APPLICANT_ENTITY_NAME_REQUIRED);
                } else if (
                    applicant.breg_Type__c == 'Individual' && (String.isBlank(applicant.breg_First_Name__c) || String.isBlank(applicant.breg_Last_Name__c))
                ) {
                    addErrorMessage(triggerCase, 'breg_Last_Name__c', ERROR_APPLICANT_NAME_REQUIRED);
                }
            }
        }
    }
    private Map<Id, List<breg_Account_Affiliation__c>> getApplicantsByCase(Set<Id> caseIds) {
        Map<Id, List<breg_Account_Affiliation__c>> result = new Map<Id, List<breg_Account_Affiliation__c>>();

        if (caseIds.isEmpty()) {
            return result;
        }

        List<breg_Account_Affiliation__c> affiliations = [
            SELECT
                Id,
                breg_Case__c,
                breg_Role__c,
                breg_Address__City__s,
                breg_Address__CountryCode__s,
                breg_Address__PostalCode__s,
                breg_Address__StateCode__s,
                breg_Address__Street__s,
                breg_Type__c,
                breg_Entity_Name__c,
                breg_First_Name__c,
                breg_Last_Name__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'Applicant'
        ];

        for (breg_Account_Affiliation__c aff : affiliations) {
            if (!result.containsKey(aff.breg_Case__c)) {
                result.put(aff.breg_Case__c, new List<breg_Account_Affiliation__c>());
            }
            result.get(aff.breg_Case__c).add(aff);
        }

        return result;
    }
}