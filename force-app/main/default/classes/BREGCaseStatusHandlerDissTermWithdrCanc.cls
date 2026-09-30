public with sharing class BREGCaseStatusHandlerDissTermWithdrCanc extends BREGCaseStatusHandlerBase {
    private static final String HAWAII_CORPORATIONS_AND_COOPERATIVES = 'D1,D2,P1,A1,A2,A1/A2,C1,C2,C1/C2,D9,S1,G5';
    private static final String PARTNERSHIP_CODES = 'L5, Q5, C6';
    private static final String FOREIGN_PARTNERSHIPS_AND_CORPORATIONS = 'G6, L6, Q6, F1, F2';
    private static final String DOMESTIC_LLC = 'C5';
    private static final String DISSOLVED_TRANSACTION_CODE = 'DS';
    private static Map<String, String> STATUS_TRANS_CODE_MAP = new Map<String, String>{
        'Dissolved (D)' => 'DS',
        'Terminated (T)' => 'TERM',
        'Cancelled (C)' => 'CN',
        'Withdrawn (W)' => 'WD'
    };
    private static final Set<String> SKIP_AFFILIATIONS_END_DATE_FORMCODES = new Set<String>{
        'DC-10', 'DC-13', 'DNP-6', 'DNP-7', 'FC-4', 'FLLC-2', 'GP-4', 'LLC-11', 'LP-4', 'SOLE-7', 'X-6'
    };
    private static final Set<String> AGENT_REPLACED_BY_ENTITY_FORMCODES = new Set<String>{ 'X-6', 'FC-4', 'FLLC-2' };

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(casesForCheck, cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performValidation(List<Case> casesWithAllFields, List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Pending Submission' {
                validatePublicationDates(cases);
            }
            when 'Approved' {
                checkIsRelatedEntityPopulated(casesWithAllFields);
                validatePublicationDates(casesWithAllFields);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R');
            }
            when 'Approved' {
                // do nothing
            }
            when 'Completed' {
                updateRelatedEntityStatuses(cases);
                setRegAgentEndDate(cases);
                setAffiliationsEndDate(cases);
                dissolveGeneralPartnership(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void checkIsRelatedEntityPopulated(List<Case> cases) {
        String errorMessage = 'Case for Change form should be linked with Entity before Approval';
        for (Case caseRecord : cases) {
            if (caseRecord.breg_Entity__c == null) {
                addErrorMessage(caseRecord, 'breg_Entity__c', errorMessage);
            }
        }
    }

    private void validatePublicationDates(List<Case> cases) {
        Set<String> supportedFormCodes = new Set<String>{ 'X-6', 'FLLC-2', 'LLC-11' };
        String intervalError = 'Publication dates must be exactly 7 days apart to satisfy the 4 consecutive weeks requirement.';
        String futureDateError = 'Publication date cannot be future date';
        Date today = Date.today();

        for (Case caseRecord : cases) {
            if (!supportedFormCodes.contains(caseRecord.breg_Form_Code__c)) {
                continue;
            }

            List<Date> publicationDates = new List<Date>{
                caseRecord.breg_Publication_Date_1__c,
                caseRecord.breg_Publication_Date_2__c,
                caseRecord.breg_Publication_Date_3__c,
                caseRecord.breg_Publication_Date_4__c
            };

            List<String> fieldNames = new List<String>{
                'breg_Publication_Date_1__c',
                'breg_Publication_Date_2__c',
                'breg_Publication_Date_3__c',
                'breg_Publication_Date_4__c'
            };

            for (Integer i = 0; i < publicationDates.size(); i++) {
                Date currentDate = publicationDates[i];

                if (currentDate != null && currentDate > today) {
                    addErrorMessage(caseRecord, fieldNames[i], futureDateError);
                }

                if (i > 0) {
                    Date previousDate = publicationDates[i - 1];

                    if (previousDate != null && currentDate != null && currentDate != previousDate.addDays(7)) {
                        addErrorMessage(caseRecord, 'breg_Publication_Date_1__c', intervalError);
                    }
                }
            }
        }
    }

    private void updateRelatedEntityStatuses(List<Case> cases) {
        Map<Id, Case> accRelatedCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case currentCase : cases) {
            if (currentCase.breg_Entity__c != null) {
                accRelatedCaseMap.put(currentCase.breg_Entity__c, currentCase);
            }
        }

        Map<Id, Account> idEntityMap = new Map<Id, Account>(
            [SELECT Id, ParentId, breg_Entity_Type__c FROM Account WHERE Id IN :accRelatedCaseMap.keyset()]
        );
        Map<Id, String> idToNewStatusMap = new Map<Id, String>();

        for (Case currentCase : cases) {
            Id accountId = currentCase.breg_Entity__c;
            if (accountId == null || !idEntityMap.containsKey(accountId)) {
                continue;
            }

            String entityType = currentCase.breg_Entity__r?.breg_Entity_Type__c;
            String newStatus = getStatusByEntityType(entityType);

            if (newStatus != null) {
                idToNewStatusMap.put(accountId, newStatus);
            }
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : idToNewStatusMap.keySet()) {
            Account acc = idEntityMap.get(accId);
            acc.breg_Entity_Status__c = idToNewStatusMap.get(accId);
            acc.breg_Good_Standing__c = false;
            accountUpdatedFieldsMap.put(accId, new Set<String>{ 'breg_Entity_Status__c', 'breg_Good_Standing__c' });
            accountsToUpdate.add(acc);
        }

        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, accRelatedCaseMap);
        }
        
    }

    private String getStatusByEntityType(String entityType) {
        if (entityType == null) {
            return null;
        }

        String newStatus;

        if (HAWAII_CORPORATIONS_AND_COOPERATIVES.contains(entityType)) {
            newStatus = 'Dissolved (D)';
        } else if (PARTNERSHIP_CODES.contains(entityType)) {
            newStatus = 'Cancelled (C)';
        } else if (FOREIGN_PARTNERSHIPS_AND_CORPORATIONS.contains(entityType)) {
            newStatus = 'Withdrawn (W)';
        } else if (DOMESTIC_LLC.contains(entityType)) {
            newStatus = 'Terminated (T)';
        }
        return newStatus;
    }

    private void setRegAgentEndDate(List<Case> cases) {
        Set<Id> agentsIds = new Set<Id>();
        Set<Id> entityIdsForReplacement = new Set<Id>();
        for (Case currentCase : cases) {
            if (isAgentEndDateSkipped(currentCase.breg_Form_Code__c)) {
                continue;
            }
            if (currentCase.breg_Entity__c != null && currentCase.breg_Entity__r.breg_Certified_Register_Agent__c != null) {
                agentsIds.add(currentCase.breg_Entity__r.breg_Certified_Register_Agent__c);
                if (AGENT_REPLACED_BY_ENTITY_FORMCODES.contains(currentCase.breg_Form_Code__c)) {
                    entityIdsForReplacement.add(currentCase.breg_Entity__c);
                }
            }
        }
        Map<Id, breg_Account_Affiliation__c> regAgentsMap = new Map<Id, breg_Account_Affiliation__c>(
            [
                SELECT Id, breg_Account__c, breg_Case__c, breg_Role__c, breg_End_Date__c, breg_Entity__c
                FROM breg_Account_Affiliation__c
                WHERE Id IN :agentsIds
            ]
        );
        Map<Id, Account> entitiesForReplacementMap = getEntitiesForReplacementMap(entityIdsForReplacement);
        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();
        List<breg_Account_Affiliation__c> selfAgentsToInsert = new List<breg_Account_Affiliation__c>();
        for (Case currentCase : cases) {
            if (isAgentEndDateSkipped(currentCase.breg_Form_Code__c)) {
                continue;
            }
            if (currentCase.breg_Entity__c != null && currentCase.breg_Entity__r.breg_Certified_Register_Agent__c != null) {
                breg_Account_Affiliation__c regAgent = regAgentsMap.get(currentCase.breg_Entity__r.breg_Certified_Register_Agent__c);
                regAgent.breg_End_Date__c = currentCase.breg_Effective_Date__c;
                regAgent.breg_Status__c = 'I';
                regAgent.breg_Bypass_Validation_Token__c = Datetime.now();
                affiliationsToUpdate.add(regAgent);

                if (AGENT_REPLACED_BY_ENTITY_FORMCODES.contains(currentCase.breg_Form_Code__c)) {
                    Account entity = entitiesForReplacementMap.get(currentCase.breg_Entity__c);
                    if (entity != null) {
                        selfAgentsToInsert.add(buildSelfAgentAffiliation(entity, currentCase, regAgent.Id));
                    }
                }
            }
        }
        update affiliationsToUpdate;
        insertSelfAgentAffiliations(selfAgentsToInsert);
    }

    private Map<Id, Account> getEntitiesForReplacementMap(Set<Id> entityIdsForReplacement) {
        return new Map<Id, Account>( [
                SELECT
                    Id,
                    Name,
                    breg_Registrant_Address__CountryCode__s,
                    breg_Registrant_Address__Street__s,
                    breg_Registrant_Address__City__s,
                    breg_Registrant_Address__StateCode__s,
                    breg_Registrant_Address__PostalCode__s,
                    breg_Registrant_Address_Street_2__c
                FROM Account
                WHERE Id IN :entityIdsForReplacement
            ]
        );
    }

    private Boolean isAgentEndDateSkipped(String formCode) {
        return SKIP_AFFILIATIONS_END_DATE_FORMCODES.contains(formCode) && !AGENT_REPLACED_BY_ENTITY_FORMCODES.contains(formCode);
    }

    private breg_Account_Affiliation__c buildSelfAgentAffiliation(Account entity, Case currentCase, Id previousAgentAffiliationId) {
        return new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Account__c = entity.Id,
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = entity.Name,
            breg_Role__c = 'Agent',
            breg_Status__c = 'A',
            breg_Start_Date__c = currentCase.breg_Effective_Date__c,
            breg_Case__c = currentCase.Id,
            breg_Previous_Account_Affiliation__c = previousAgentAffiliationId,
            breg_Address__CountryCode__s = entity.breg_Registrant_Address__CountryCode__s,
            breg_Address__Street__s = entity.breg_Registrant_Address__Street__s,
            breg_Address__City__s = entity.breg_Registrant_Address__City__s,
            breg_Address__StateCode__s = entity.breg_Registrant_Address__StateCode__s,
            breg_Address__PostalCode__s = entity.breg_Registrant_Address__PostalCode__s,
            breg_Address_Street_2__c = entity.breg_Registrant_Address_Street_2__c
        );
    }

    private void insertSelfAgentAffiliations(List<breg_Account_Affiliation__c> selfAgentsToInsert) {
        if (selfAgentsToInsert.isEmpty()) {
            return;
        }
        BREGCaseStatusHandlerHelper.populateEntityRelatedFields(selfAgentsToInsert);
        insert selfAgentsToInsert;
        List<Account> entitiesToUpdate = new List<Account>();
        for (breg_Account_Affiliation__c selfAgent : selfAgentsToInsert) {
            entitiesToUpdate.add(new Account(Id = selfAgent.breg_Entity__c, breg_Certified_Register_Agent__c = selfAgent.Id));
        }
        update entitiesToUpdate;
    }

    private void setAffiliationsEndDate(List<Case> cases) {
        Map<Id, Case> caseByEntityMap = new Map<Id, Case>();
        for (Case currentCase : cases) {
            if (SKIP_AFFILIATIONS_END_DATE_FORMCODES.contains(currentCase.breg_Form_Code__c)) {
                continue;
            }
            if (currentCase.breg_Entity__c != null) {
                caseByEntityMap.put(currentCase.breg_Entity__c, currentCase);
            }
        }
        Map<Id, breg_Account_Affiliation__c> affiliationsMap = new Map<Id, breg_Account_Affiliation__c>(
            [
                SELECT Id, breg_Account__c, breg_Case__c, breg_Role__c, breg_End_Date__c, breg_Entity__c
                FROM breg_Account_Affiliation__c
                WHERE breg_Entity__c IN :caseByEntityMap.keySet() AND breg_End_Date__c = NULL AND breg_Status__c != 'I'
            ]
        );
        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();

        for (String affiliationId : affiliationsMap.keySet()) {
            breg_Account_Affiliation__c affiliation = affiliationsMap.get(affiliationId);

            Case relatedCase = caseByEntityMap.get(affiliation.breg_Entity__c);
            if (relatedCase != null) {
                affiliation.breg_End_Date__c = relatedCase.breg_Effective_Date__c;
                affiliation.breg_Status__c = 'I';
                affiliation.breg_Bypass_Validation_Token__c = Datetime.now();
                affiliationsToUpdate.add(affiliation);
            }
        }
        update affiliationsToUpdate;
    }

    private void dissolveGeneralPartnership(List<Case> cases) {
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, List<Id>> caseToEntityMap = new Map<Id, List<Id>>();
        Map<Id, Case> accRelatedCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            if (c.breg_Update_Child_Entity__c && c.breg_Entity__c != null) {
                accRelatedCaseMap.put(c.breg_Entity__c, c);
            }
        }
        List<Account> accountsToUpdate = [
            SELECT Id, ParentId, breg_Entity_Type__c, breg_Entity_Status__c
            FROM Account
            WHERE ParentId IN :accRelatedCaseMap.keySet()
        ];
        for (Account acc : accountsToUpdate) {
            acc.breg_Entity_Status__c = getStatusByEntityType(acc.breg_Entity_Type__c);
            accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Entity_Status__c' });
            Case relatedCase = accRelatedCaseMap.get(acc.ParentId);
            if (relatedCase != null) {
                if (!caseToEntityMap.containsKey(relatedCase.Id)) {
                    caseToEntityMap.put(relatedCase.Id, new List<Id>());
                }
                caseToEntityMap.get(relatedCase.Id).add(acc.Id);
            }
        }
        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, accRelatedCaseMap);
            // TODO - create transactions for child entities
            List<breg_Transaction__c> transactionList = BREGTransactionUtils.upsertTransactionRecordsForChilds(
                new Map<Id, Case>(cases),
                caseToEntityMap,
                'C',
                null
            );
            if (transactionList != null && !transactionList.isEmpty()) {
                 BREGSObjectUpdaterWithoutSharing.upsertRecords(transactionList);
            }
        }
    }
}