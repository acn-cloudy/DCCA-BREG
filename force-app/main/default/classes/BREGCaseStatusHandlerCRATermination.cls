public with sharing class BREGCaseStatusHandlerCRATermination extends BREGCaseStatusHandlerBase {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String K6_ENTITY_TYPE = 'K6';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String G6_ENTITY_TYPE = 'G6';
    private static final String TRANSACTION_CODE_TERM = 'CRT';

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
                terminateCRA(cases);
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
            TRANSACTION_CODE_TERM,
            'R'
        );

        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
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
            TRANSACTION_CODE_TERM,
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

    /**
     * Terminates CRA based on its type
     * Case → Account Affiliation (role = 'CRA') → CRA Account (breg_Entity__c)
     * Account Affiliation: breg_Entity__c = CRA Account, breg_Type__c = Type from affiliation
     * If CRA is Individual or Non Registered Entity (Type == null): mark as Terminated
     * If CRA is Entity (Type == 'Entity'): remove CRA flag from the entity
     * Also updates all entities associated with this CRA to 'Not in Good Standing' and end dates their agent records
     * Agent Affiliation: breg_Entity__c = Entity Account, breg_Account__c = CRA Account (agent)
     * Exception: Merged out entities with irrevocable agent are not impacted
     * @param cases - list of cases
     */
    private void terminateCRA(List<Case> cases) {
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        List<Case> casesWithFields = getCasesWithAllFields(cases);
        Set<Id> caseIds = new Set<Id>();
        Map<Id, Date> caseIdToEffectiveDateMap = new Map<Id, Date>();
        Map<Id, Case> caseIdToCaseMap = new Map<Id, Case>();
        Set<Id> craAccountIds = new Set<Id>();

        for (Case iCase : casesWithFields) {
            craAccountIds.add(iCase.breg_Entity__c);
            caseIds.add(iCase.Id);
            caseIdToEffectiveDateMap.put(iCase.Id, iCase.breg_Effective_Date__c);
            caseIdToCaseMap.put(iCase.Id, iCase);
        }

        if (craAccountIds.isEmpty()) {
            return;
        }

        // Get CRA Accounts with their details
        Map<Id, Account> craAccountsMap = new Map<Id, Account>(
            [
                SELECT Id, breg_BRIM_CRA_FL__c, breg_Entity_Status__c
                FROM Account
                WHERE Id IN :craAccountIds
                LIMIT 10000
            ]
        );

        List<Account> craAccountsToUpdate = new List<Account>();
        Map<Id, Date> craAccountIdToEffectiveDateMap = new Map<Id, Date>();

        // Process CRA Accounts and collect effective dates
        for (Id caseId : caseIds) {
            Case iCase = caseIdToCaseMap.get(caseId);
            entityToCaseMap.put(iCase.breg_Entity__c, iCase);

            // Use affiliation's breg_Entity__c, or fallback to case's breg_Entity__c
            Id craAccountId = iCase.breg_Entity__c;

            if (craAccountId == null) {
                continue;
            }

            Account craAccount = craAccountsMap.get(craAccountId);
            if (craAccount == null) {
                continue;
            }

            Date effectiveDate = caseIdToEffectiveDateMap.get(caseId);
            if (effectiveDate != null) {
                craAccountIdToEffectiveDateMap.put(craAccount.Id, effectiveDate);
            }

            Account craToUpdate = new Account(
                Id = craAccount.Id,
                breg_BRIM_CRA_FL__c = false,
                breg_Registrant_Address__CountryCode__s = null,
                breg_Registrant_Address__Street__s = null,
                breg_Registrant_Address_Street_2__c = null,
                breg_Registrant_Address__StateCode__s = null,
                breg_Registrant_Address__City__s = null,
                breg_Registrant_Address__PostalCode__s = null
            );
            accountUpdatedFieldsMap.put(
                iCase.breg_Entity__c,
                new Set<String>{
                    'breg_BRIM_CRA_FL__c',
                    'breg_Registrant_Address__CountryCode__s',
                    'breg_Registrant_Address__Street__s',
                    'breg_Registrant_Address_Street_2__c',
                    'breg_Registrant_Address__StateCode__s',
                    'breg_Registrant_Address__City__s',
                    'breg_Registrant_Address__PostalCode__s'
                }
            );
            
            craAccountsToUpdate.add(craToUpdate);
        }

        updateAssociatedEntities(craAccountIds, craAccountIdToEffectiveDateMap, entityToCaseMap);

        if (!craAccountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(craAccountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    /**
     * Updates all entities associated with terminated CRA Accounts
     * Sets entities to 'Not in Good Standing' and end dates their agent affiliations
     * Exception: Merged out entities with irrevocable agent are not impacted
     * @param craAccountIds - set of CRA Account IDs
     * @param craAccountIdToEffectiveDateMap - map of CRA Account ID to effective date
     */
    private void updateAssociatedEntities(Set<Id> craAccountIds, Map<Id, Date> craAccountIdToEffectiveDateMap, Map<Id, Case> entityToCaseMap) {
        if (craAccountIds.isEmpty()) {
            return;
        }
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();

        // Query for Agent affiliations where breg_Account__c (the CRA agent) is in the terminated CRA accounts
        List<breg_Account_Affiliation__c> agentAffiliations = [
            SELECT Id, breg_Account__c, breg_Entity__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Account__c IN :craAccountIds AND breg_Role__c = 'Agent' AND breg_End_Date__c = NULL AND breg_Status__c != 'I'
            LIMIT 10000
        ];

        if (agentAffiliations.isEmpty()) {
            return;
        }

        Set<Id> entityAccountIds = new Set<Id>();
        for (breg_Account_Affiliation__c affiliation : agentAffiliations) {
            if (affiliation.breg_Entity__c != null) {
                entityAccountIds.add(affiliation.breg_Entity__c);
            }
        }

        Map<Id, Account> entityAccountsMap = new Map<Id, Account>(
            [
                SELECT Id, breg_Entity_Status__c
                FROM Account
                WHERE Id IN :entityAccountIds
                LIMIT 10000
            ]
        );

        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();
        Set<Id> processedEntityIds = new Set<Id>();
        List<Account> entitiesToUpdate = new List<Account>();

        for (breg_Account_Affiliation__c affiliation : agentAffiliations) {
            if (affiliation.breg_Entity__c == null) {
                continue;
            }

            Account entityAccount = entityAccountsMap.get(affiliation.breg_Entity__c);
            if (entityAccount == null) {
                continue;
            }

            Boolean isMergedOut = entityAccount.breg_Entity_Status__c == 'Merged (M)';

            if (isMergedOut) {
                continue;
            }

            Date effectiveDate = craAccountIdToEffectiveDateMap.get(affiliation.breg_Account__c);
            if (effectiveDate == null) {
                effectiveDate = Date.today();
            }

            affiliation.breg_End_Date__c = effectiveDate;
            affiliationsToUpdate.add(affiliation);

            if (!processedEntityIds.contains(affiliation.breg_Entity__c)) {
                entitiesToUpdate.add(new Account(Id = affiliation.breg_Entity__c, breg_Good_Standing__c = false));
                accountUpdatedFieldsMap.put(affiliation.breg_Entity__c, new Set<String>{ 'breg_Good_Standing__c' });
                processedEntityIds.add(affiliation.breg_Entity__c);
            }
        }

        if (!affiliationsToUpdate.isEmpty()) {
            update affiliationsToUpdate;
        }

        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }
}