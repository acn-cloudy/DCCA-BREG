/**
 * Handler for the Resignation of Certified Registered Agent (X-9)
 */
public with sharing class BREGCaseStatusHandlerResignationCRA extends BREGCaseStatusHandlerBase {
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String K6_ENTITY_TYPE = 'K6';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String G6_ENTITY_TYPE = 'G6';
    private static final String TRANSACTION_CODE_AGR = 'AGR';
    private static final String ERROR_EFFECTIVE_DATE_REQUIRED = 'This is a required field. Please fill this field to proceed.';
    private static final String ERROR_EFFECTIVE_DATE_IN_FUTURE = 'Case status cannot be changed to Completed before the effective date.';

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
            when 'Completed' {
                validateEffectiveDate(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    /**
     * Validates that the effective date has been reached before allowing status change to Completed
     * @param cases - list of cases
     */
    private void validateEffectiveDate(List<Case> cases) {
        Date today = Date.today();
        for (Case iCase : cases) {
            if (iCase.breg_Effective_Date__c == null) {
                addErrorMessage(iCase, 'breg_Effective_Date__c', ERROR_EFFECTIVE_DATE_REQUIRED);
                continue;
            }
            if (iCase.breg_Effective_Date__c > today) {
                addErrorMessage(iCase, null, ERROR_EFFECTIVE_DATE_IN_FUTURE);
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
                disassociateRegisteredAgent(cases);
            }
            when else {
                // do nothing
            }
        }
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
            TRANSACTION_CODE_AGR,
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
        Map<Id, Id> caseToLLPEntityMap = new Map<Id, Id>();
        Map<Id, Id> caseToGPEntityMap = new Map<Id, Id>();

        for (Account gpEntity : gpEntityMap.values()) {
            Case relatedCase = llpAccountIdToCaseMap.get(gpEntity.ParentId);
            if (relatedCase == null || relatedCase.breg_Effective_Date__c == null) {
                continue;
            }
            validCasesMap.put(relatedCase.Id, relatedCase);
            caseToLLPEntityMap.put(relatedCase.Id, relatedCase.breg_Entity__c);
            caseToGPEntityMap.put(relatedCase.Id, gpEntity.Id);
        }

        if (validCasesMap.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> llpTransactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToLLPEntityMap,
            TRANSACTION_CODE_AGR,
            'R'
        );

        List<breg_Transaction__c> gpTransactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToGPEntityMap,
            TRANSACTION_CODE_AGR,
            'R'
        );

        List<breg_Transaction__c> transactionsToUpsert = new List<breg_Transaction__c>();
        transactionsToUpsert.addAll(llpTransactions);
        transactionsToUpsert.addAll(gpTransactions);

        if (!transactionsToUpsert.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords( transactionsToUpsert);
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
     * Disassociates the registered agent on the effective date
     * Sets end date on Account Affiliation and marks entity as not in good standing
     * @param cases - list of cases
     */
    private void disassociateRegisteredAgent(List<Case> cases) {
        List<Case> casesWithFields = getCasesWithAllFields(cases);
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();
        List<Account> entitiesToUpdate = new List<Account>();

        for (Case currentCase : casesWithFields) {
            if (
                currentCase.breg_Entity__c == null ||
                currentCase.breg_Effective_Date__c == null ||
                currentCase.breg_Entity__r.breg_Certified_Register_Agent__c == null
            ) {
                continue;
            }

            entityToCaseMap.put(currentCase.breg_Entity__c, currentCase);

            // Find and update the certified registered agent affiliation
            if (currentCase.breg_Entity__r.breg_Certified_Register_Agent__c == null) {
                continue;
            }
            breg_Account_Affiliation__c currentAgent = new breg_Account_Affiliation__c(Id = currentCase.breg_Entity__r.breg_Certified_Register_Agent__c);
            currentAgent.breg_End_Date__c = currentCase.breg_Effective_Date__c;
            currentAgent.breg_Status__c = 'I';
            currentAgent.breg_Bypass_Validation_Token__c = Datetime.now();
            affiliationsToUpdate.add(currentAgent);

            // Process Account Affiliations from the subquery
            /*if (currentCase.Account_Affiliations__r != null && !currentCase.Account_Affiliations__r.isEmpty()) {
                for (breg_Account_Affiliation__c aff : currentCase.Account_Affiliations__r) {
                    // Find and update 'Recipient' affiliation
                    if (aff.breg_Role__c == 'Recipient') {
                        aff.breg_Status__c = 'A';
                        aff.breg_Entity__c = currentCase.breg_Entity__c;
                        aff.breg_Start_Date__c = currentCase.breg_Effective_Date__c;
                        affiliationsToUpdate.add(aff);
                        break;
                    }
                }
            }*/ 
            //Commented according requirements in BREG-4319

            // Mark entity as not in good standing and clear certified registered agent
            Account entityToUpdate = new Account(
                Id = currentCase.breg_Entity__c,
                breg_Good_Standing__c = false,
                breg_Certified_Register_Agent__c = null
            );
            accountUpdatedFieldsMap.put(entityToUpdate.Id, new Set<String>{ 'breg_Good_Standing__c', 'breg_Certified_Register_Agent__c' });
            entitiesToUpdate.add(entityToUpdate);
        }

        if (!affiliationsToUpdate.isEmpty()) {
            update affiliationsToUpdate;
        }

        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }
}