public with sharing class BREGCaseStatusHandlerX7ChangeCRA extends BREGCaseStatusHandlerBase {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String K6_ENTITY_TYPE = 'K6';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String G6_ENTITY_TYPE = 'G6';
    private static final String TRANSACTION_CODE_AGC = 'AGC';

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(casesForCheck, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Approved' {
                validateEntityIsLinked(cases);
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
                createEntityTransactions(cases);
                createGPTransactionsForLLP(cases);
            }
            when 'Completed' {
                updateAgentRelationship(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    /**
     * Validates if entity is linked to the cases
     * Verifies that the Account record actually exists in the database
     * @param cases - list of cases
     */
    private void validateEntityIsLinked(List<Case> cases) {
        Map<Id, Account> entityMap = getEntityMap(getEntityIds(cases));
        for (Case iCase : cases) {
            if (iCase.breg_Entity__c == null) {
                addErrorMessage(iCase, 'breg_Entity__c', 'The entity is not linked to the case.');
                continue;
            }
            Account entity = entityMap.containsKey(iCase.breg_Entity__c) ? entityMap.get(iCase.breg_Entity__c) : null;
            if (entity == null) {
                addErrorMessage(iCase, 'breg_Entity__c', 'The entity is not linked to the case.');
                continue;
            }
        }
    }

    /**
     * Gets entity Account IDs from cases
     * @param cases - list of cases
     * @return Set<Id> - set of entity Account IDs
     */
    private Set<Id> getEntityIds(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case iCase : cases) {
            if (iCase.breg_Entity__c != null) {
                entityIds.add(iCase.breg_Entity__c);
            }
        }
        return entityIds;
    }

    /**
     * Gets Account records by their IDs
     * @param entityIds - set of Account IDs
     * @return Map<Id, Account> - map of Account ID to Account record
     */
    private Map<Id, Account> getEntityMap(Set<Id> entityIds) {
        if (entityIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        return new Map<Id, Account>(
            [
                SELECT Id
                FROM Account
                WHERE Id IN :entityIds
            ]
        );
    }

    /**
     * Creates transactions for entity accounts upon approval
     * @param cases - list of cases
     */
    private void createEntityTransactions(List<Case> cases) {
        List<Case> casesWithFields = getCasesWithAllFields(cases);

        Map<Id, Case> validCasesMap = new Map<Id, Case>();
        Map<Id, Id> caseToEntityMap = new Map<Id, Id>();

        for (Case iCase : casesWithFields) {
            if (iCase.breg_Effective_Date__c != null) {
                validCasesMap.put(iCase.Id, iCase);
                caseToEntityMap.put(iCase.Id, iCase.breg_Entity__c);
            }
        }

        if (validCasesMap.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToEntityMap,
            TRANSACTION_CODE_AGC,
            'R'
        );

        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    /**
     * Updates agent relationship: always creates new agent account
     * Sets end date on old agent affiliation and start date on new agent affiliation
     * @param cases - list of cases
     */
    private void updateAgentRelationship(List<Case> cases) {
        List<Case> casesWithFields = getCasesWithAllFields(cases);

        Map<Id, breg_Account_Affiliation__c> caseIdToNewAgentAffiliationMap = getNewAgentAffiliationsByCase(casesWithFields);

        Set<Id> entityIds = new Set<Id>();
        for (Case iCase : casesWithFields) {
            if (iCase.breg_Entity__c != null) {
                entityIds.add(iCase.breg_Entity__c);
            }
        }

        if (entityIds.isEmpty()) {
            return;
        }

        Map<Id, breg_Account_Affiliation__c> entityIdToOldAgentAffiliationMap = getEntityAgentAffiliations(entityIds);

        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();
        List<breg_Account_Affiliation__c> affiliationsToInsert = new List<breg_Account_Affiliation__c>();
        List<Account> accountsToInsert = new List<Account>();
        Map<Id, Id> entityIdToNewAffiliationIdMap = new Map<Id, Id>();
        Map<Id, Account> newAgentAffiliationIdToAccountMap = new Map<Id, Account>();
        Map<Id, Case> newAgentAffiliationIdToCaseMap = new Map<Id, Case>();
        Map<Id, breg_Account_Affiliation__c> caseIdToNewEntityAffiliationMap = new Map<Id, breg_Account_Affiliation__c>();
        Map<Id, Account> caseIdToNewAccountMap = new Map<Id, Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, Case> accIdToCaseMap = new Map<Id, Case>();

        for (Case iCase : casesWithFields) {
            if (iCase.breg_Entity__c == null || iCase.breg_Effective_Date__c == null) {
                continue;
            }
            entityToCaseMap.put(iCase.breg_Entity__c, iCase);

            breg_Account_Affiliation__c oldAgentAffiliation = entityIdToOldAgentAffiliationMap.get(iCase.breg_Entity__c);

            if (oldAgentAffiliation != null) {
                if (oldAgentAffiliation.breg_Case__c == iCase.Id) {
                    continue; // if the current agent affiliation is from the same case, skip updating it to avoid conflicts with new agent affiliation
                }
                oldAgentAffiliation.breg_End_Date__c = iCase.breg_Effective_Date__c;
                oldAgentAffiliation.breg_Status__c = 'I';
                oldAgentAffiliation.breg_Bypass_Validation_Token__c = Datetime.now();
                affiliationsToUpdate.add(oldAgentAffiliation);
            }

            breg_Account_Affiliation__c newAgentCaseAffiliation = caseIdToNewAgentAffiliationMap.get(iCase.Id);
            if (newAgentCaseAffiliation == null) {
                continue;
            }

            Id newAgentAccountId = null;
            if (newAgentCaseAffiliation.breg_Account__c != null) {
                newAgentAccountId = newAgentCaseAffiliation.breg_Account__c;
            } else {
                Account newAgentAccount = createAgentAccountFromAffiliation(newAgentCaseAffiliation);
                accountsToInsert.add(newAgentAccount);
                newAgentAffiliationIdToAccountMap.put(newAgentCaseAffiliation.Id, newAgentAccount);
                newAgentAffiliationIdToCaseMap.put(newAgentCaseAffiliation.Id, iCase);
                caseIdToNewAccountMap.put(iCase.Id, newAgentAccount);
            }

            newAgentCaseAffiliation.breg_Entity__c = iCase.breg_Entity__c;
            newAgentCaseAffiliation.breg_Start_Date__c = iCase.breg_Effective_Date__c;
            newAgentCaseAffiliation.breg_Role__c = 'Agent';
            newAgentCaseAffiliation.breg_Status__c = 'A';
            newAgentCaseAffiliation.breg_Bypass_Validation_Token__c = Datetime.now();
            affiliationsToUpdate.add(newAgentCaseAffiliation);
            caseIdToNewEntityAffiliationMap.put(iCase.Id, newAgentCaseAffiliation);
            entityIdToNewAffiliationIdMap.put(iCase.breg_Entity__c, newAgentCaseAffiliation.Id);
        }

        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;

            List<breg_Account_Affiliation__c> caseAffiliationsToUpdate = new List<breg_Account_Affiliation__c>();
            for (Id caseAffiliationId : newAgentAffiliationIdToAccountMap.keySet()) {
                Account acc = newAgentAffiliationIdToAccountMap.get(caseAffiliationId);
                if (acc == null || acc.Id == null) {
                    continue;
                }
                caseAffiliationsToUpdate.add(
                    new breg_Account_Affiliation__c(
                        Id = caseAffiliationId,
                        breg_Account__c = acc.Id,
                    breg_Bypass_Validation_Token__c = Datetime.now()
                    )
                );
                Case relatedCase = newAgentAffiliationIdToCaseMap.get(caseAffiliationId);
                if (relatedCase != null) {
                    accIdToCaseMap.put(acc.Id, relatedCase);
                }
            }
            BREGTransactionUtils.createTransBusinessInfoRecords(accountsToInsert, accIdToCaseMap);
            if (!caseAffiliationsToUpdate.isEmpty()) {
                update caseAffiliationsToUpdate;
            }
            for (Id caseId : caseIdToNewEntityAffiliationMap.keySet()) {
                breg_Account_Affiliation__c newEntityAff = caseIdToNewEntityAffiliationMap.get(caseId);
                Account newAccount = caseIdToNewAccountMap.get(caseId);
                if (newAccount != null && newAccount.Id != null) {
                    newEntityAff.breg_Account__c = newAccount.Id;
                } else {
                    breg_Account_Affiliation__c caseAff = caseIdToNewAgentAffiliationMap.get(caseId);
                    if (caseAff != null && newAgentAffiliationIdToAccountMap.containsKey(caseAff.Id)) {
                        Account acc = newAgentAffiliationIdToAccountMap.get(caseAff.Id);
                        newEntityAff.breg_Account__c = acc.Id;
                    }
                }
            }
        }
        if (!affiliationsToUpdate.isEmpty()) {
            for (breg_Account_Affiliation__c affiliation : affiliationsToUpdate) {
                affiliation.breg_Bypass_Validation_Token__c =
                    Datetime.now().addSeconds(1);
            }

            update affiliationsToUpdate;
        }

        if (!entityIdToNewAffiliationIdMap.isEmpty()) {
            List<Account> entitiesToUpdate = new List<Account>();
            for (Id entityId : entityIdToNewAffiliationIdMap.keySet()) {
                entitiesToUpdate.add(new Account(Id = entityId, breg_Certified_Register_Agent__c = entityIdToNewAffiliationIdMap.get(entityId)));
                accountUpdatedFieldsMap.put(entityId, new Set<String>{ 'breg_Certified_Register_Agent__c' });
            }
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    /**
     * Gets new agent affiliations from cases (for getting new agent information)
     * @param cases - list of cases
     * @return Map<Id, breg_Account_Affiliation__c> - map of case ID to new agent affiliation
     */
    private Map<Id, breg_Account_Affiliation__c> getNewAgentAffiliationsByCase(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        for (Case iCase : cases) {
            caseIds.add(iCase.Id);
        }

        if (caseIds.isEmpty()) {
            return new Map<Id, breg_Account_Affiliation__c>();
        }

        List<breg_Account_Affiliation__c> affiliations = [
            SELECT
                Id,
                breg_Case__c,
                breg_Role__c,
                breg_Type__c,
                breg_Entity__c,
                breg_Account__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Entity_Name__c,
                breg_Address__Street__s,
                breg_Address_Street_2__c,
                breg_Address__City__s,
                breg_Address__StateCode__s,
                breg_Address__PostalCode__s,
                breg_Address__CountryCode__s
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'New Agent'
            LIMIT 10000
        ];

        Map<Id, breg_Account_Affiliation__c> caseIdToNewAgentAffiliationMap = new Map<Id, breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            caseIdToNewAgentAffiliationMap.put(affiliation.breg_Case__c, affiliation);
        }

        return caseIdToNewAgentAffiliationMap;
    }

    /**
     * Gets current agent affiliations for entities (where breg_Entity__c = entity.Id)
     * @param entityIds - set of entity Account IDs
     * @return Map<Id, breg_Account_Affiliation__c> - map of entity ID to agent affiliation
     */
    private Map<Id, breg_Account_Affiliation__c> getEntityAgentAffiliations(Set<Id> entityIds) {
        if (entityIds.isEmpty()) {
            return new Map<Id, breg_Account_Affiliation__c>();
        }

        List<breg_Account_Affiliation__c> affiliations = [
            SELECT Id, breg_Account__c, breg_Entity__c, breg_Role__c, breg_End_Date__c, breg_Case__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityIds AND breg_Role__c = 'Agent' AND breg_End_Date__c = NULL AND breg_Status__c != 'I'
            LIMIT 10000
        ];

        Map<Id, breg_Account_Affiliation__c> entityIdToAffiliationMap = new Map<Id, breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            entityIdToAffiliationMap.put(affiliation.breg_Entity__c, affiliation);
        }

        return entityIdToAffiliationMap;
    }

    /**
     * Creates Account record from affiliation data
     * @param affiliation - account affiliation
     * @return Account - agent account record
     */
    private Account createAgentAccountFromAffiliation(breg_Account_Affiliation__c affiliation) {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account agentAccount = new Account(RecordTypeId = bregAccountRecordTypeId);
        if (affiliation.breg_Type__c == 'Entity') {
            agentAccount.Name = affiliation.breg_Entity_Name__c;
            agentAccount.breg_Registrant_Type__c = 'Entity';
        } else {
            String firstName = affiliation.breg_First_Name__c != null ? affiliation.breg_First_Name__c : '';
            String lastName = affiliation.breg_Last_Name__c != null ? affiliation.breg_Last_Name__c : '';
            agentAccount.Name = (firstName + ' ' + lastName).trim();
            agentAccount.breg_Registrant_Type__c = 'Individual';
        }
        agentAccount.BillingCountryCode = affiliation.breg_Address__CountryCode__s;
        agentAccount.BillingStreet = affiliation.breg_Address__Street__s;
        agentAccount.BillingCity = affiliation.breg_Address__City__s;
        agentAccount.BillingStateCode = affiliation.breg_Address__StateCode__s;
        agentAccount.BillingPostalCode = affiliation.breg_Address__PostalCode__s;
        agentAccount.breg_Billing_Address_Street_2__c = affiliation.breg_Address_Street_2__c;

        return agentAccount;
    }

    /**
     * Creates transactions for General Partner accounts when the entity is an LLP
     * @param cases - list of cases
     */
    private void createGPTransactionsForLLP(List<Case> cases) {
        Set<Id> llpEntityIds = getLLPEntityIds(cases);

        if (llpEntityIds.isEmpty()) {
            return;
        }

        Map<Id, Account> gpEntityMap = getGPEntityMap(llpEntityIds);

        if (gpEntityMap.isEmpty()) {
            return;
        }

        Map<Id, Case> llpAccountIdToCaseMap = new Map<Id, Case>();
        for (Case iCase : cases) {
            if (llpEntityIds.contains(iCase.breg_Entity__c)) {
                llpAccountIdToCaseMap.put(iCase.breg_Entity__c, iCase);
            }
        }

        Map<Id, Case> validCasesMap = new Map<Id, Case>();
        Map<Id, Id> caseToGPEntityMap = new Map<Id, Id>();

        for (Account gpEntity : gpEntityMap.values()) {
            Case relatedCase = llpAccountIdToCaseMap.get(gpEntity.ParentId);
            if (relatedCase == null || relatedCase.breg_Effective_Date__c == null) {
                continue;
            }
            validCasesMap.put(relatedCase.Id, relatedCase);
            caseToGPEntityMap.put(relatedCase.Id, gpEntity.Id);
        }

        if (validCasesMap.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToGPEntityMap,
            TRANSACTION_CODE_AGC,
            'R'
        );

        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    /**
     * Gets LLP entity IDs from cases
     * @param cases - list of cases
     * @return Set<Id> - set of LLP entity Account IDs
     */
    private Set<Id> getLLPEntityIds(List<Case> cases) {
        Set<Id> llpEntityIds = new Set<Id>();
        for (Case iCase : cases) {
            if (
                iCase.breg_Entity__c != null &&
                (iCase.breg_Entity__r.breg_Entity_Type__c == K5_ENTITY_TYPE ||
                iCase.breg_Entity__r.breg_Entity_Type__c == K6_ENTITY_TYPE)
            ) {
                llpEntityIds.add(iCase.breg_Entity__c);
            }
        }
        return llpEntityIds;
    }

    /**
     * Gets General Partner Account records for LLP entities
     * GP accounts have ParentId pointing to the LLP Account
     * @param llpEntityIds - set of LLP Account IDs
     * @return Map<Id, Account> - map of GP Account ID to GP Account record
     */
    private Map<Id, Account> getGPEntityMap(Set<Id> llpEntityIds) {
        if (llpEntityIds.isEmpty()) {
            return new Map<Id, Account>();
        }

        return new Map<Id, Account>(
            [
                SELECT Id, ParentId
                FROM Account
                WHERE ParentId IN :llpEntityIds AND (breg_Entity_Type__c = :G5_ENTITY_TYPE OR breg_Entity_Type__c = :G6_ENTITY_TYPE)
                LIMIT 10000
            ]
        );
    }
}