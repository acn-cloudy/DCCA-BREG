public with sharing class BREGCaseStatusHandlerCRAChange extends BREGCaseStatusHandlerBase {
    public static final String CRA_CHANGE_TRANSACTION_CODE = 'CRC';

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                createTransactionsForEntities(createEntityCaseMap(getCasesWithAllFields(cases)));
            }
            when 'Completed' {
                updateAgents(cases);
            }
            when else {
                // do nothing
            }
        }
    }
    private Map<Id, Case> createEntityCaseMap(List<Case> cases) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        return entityCaseMap;
    }

    private void updateAgents(List<Case> cases) {
        List<Id> entityIds = new List<Id>();
        List<Case> currentCases = getCasesWithAllFields(cases);
        Map<Id, Case> entityCaseMap = createEntityCaseMap(currentCases);

        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Map<SObjectField, SObjectField>> perCaseMappings = new Map<Id, Map<SObjectField, SObjectField>>();
        for (Id craAccountId : entityCaseMap.keyset()) {
            Case relatedCase = entityCaseMap.get(craAccountId);
            Boolean isIndividual = relatedCase.breg_Reg_Agent_First_Name__c != null && relatedCase.breg_Reg_Agent_Last_Name__c != null;
            String countryOrState = BREGUtils.mapJurisdictionToPicklists(relatedCase.breg_Entity_Jurisdiction__c);
            Map<SObjectField, SObjectField> mapping = getFieldMapping(
                isIndividual,
                relatedCase.breg_Reg_Agent_Has_Changed__c,
                relatedCase.breg_Reg_Agent_Address_Has_Changed__c,
                relatedCase.breg_Entity_Type_Has_Changed__c,
                relatedCase.breg_Entity_Jurisdiction_Has_Changed__c,
                countryOrState
            );
            perCaseMappings.put(relatedCase.Id, mapping);
        }
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(entityCaseMap, 'Account', perCaseMappings, null);
    }

    private Map<SObjectField, SObjectField> getFieldMapping(
        Boolean isIndividual,
        Boolean agentChanged,
        Boolean addressChanged,
        Boolean entityTypeChanged,
        Boolean jurisdictionChanged,
        String countryOrState
    ) {
        Map<SObjectField, SObjectField> fieldMap = new Map<SObjectField, SObjectField>();
        if (agentChanged) {
            if (isIndividual) {
                fieldMap.put(Case.breg_Reg_Agent_First_Name__c, Account.FirstName__c);
                fieldMap.put(Case.breg_Reg_Agent_Last_Name__c, Account.LastName__c);
            } else {
                fieldMap.put(Case.breg_Reg_Agent_Entity_Name__c, Account.Name);
            }
        }
        if (addressChanged) {
            fieldMap.put(Case.breg_Registered_Agent_Address__CountryCode__s, Account.breg_Registrant_Address__CountryCode__s);
            fieldMap.put(Case.breg_Registered_Agent_Address__Street__s, Account.breg_Registrant_Address__Street__s);
            fieldMap.put(Case.breg_Reg_Agent_Address_Street2__c, Account.breg_Registrant_Address_Street_2__c);
            fieldMap.put(Case.breg_Registered_Agent_Address__StateCode__s, Account.breg_Registrant_Address__StateCode__s);
            fieldMap.put(Case.breg_Registered_Agent_Address__City__s, Account.breg_Registrant_Address__City__s);
            fieldMap.put(Case.breg_Registered_Agent_Address__PostalCode__s, Account.breg_Registrant_Address__PostalCode__s);
        }
        if (entityTypeChanged) {
            fieldMap.put(Case.breg_Entity_Type__c, Account.breg_Entity_Type__c);
        }
        if (jurisdictionChanged) {
            if (countryOrState == 'State') {
                fieldMap.put(Case.breg_Entity_Jurisdiction__c, Account.breg_Formation_State__c);
            } else if (countryOrState == 'Country') {
                fieldMap.put(Case.breg_Entity_Jurisdiction__c, Account.breg_Formation_Country__c);
            }
        }

        return fieldMap;
    }

    private void createTransactionsForEntities(Map<Id, Case> accRelatedCaseMap) {
        if (accRelatedCaseMap.isEmpty())
            return;

        Set<Id> accIds = accRelatedCaseMap.keySet();
        Map<Id, Case> casesMap = new Map<Id, Case>(accRelatedCaseMap.values());
        Map<Id, Account> accountsMap = new Map<Id, Account>(
            [
                SELECT
                    Id,
                    Name,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Street_2__c,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__PostalCode__s,
                    breg_Mailing_Address__CountryCode__s,
                    BillingStreet,
                    breg_Billing_Address_Street_2__c,
                    BillingCity,
                    BillingStateCode,
                    BillingPostalCode,
                    BillingCountryCode,
                    breg_Entity_Type__c,
                    breg_Formation_State__c,
                    breg_Formation_Country__c
                FROM Account
                WHERE Id IN :accIds
            ]
        );

        Map<Id, Id> casesToEntityMap = new Map<Id, Id>();

        for (Case c : casesMap.values()) {
            casesToEntityMap.put(c.Id, c.breg_Entity__c);
        }

        List<breg_Transaction__c> transactionsToInsert = BREGTransactionUtils.upsertTransactionRecords(
            casesMap,
            casesToEntityMap,
            CRA_CHANGE_TRANSACTION_CODE,
            'R'
        );

        if (!transactionsToInsert.isEmpty()) {
            upsert transactionsToInsert;
        }
    }
}