public with sharing class BREGCaseStatusHandlerCRARegistration extends BREGCaseStatusHandlerBase {
    // Status constants
    private static final String ENTITY_STATUS_ACTIVE = 'Active (A)';

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
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
        // add specific validation for different statuses
        switch on newStatus {
            when 'Completed' {
                validateEntityIsLinked(cases);
            }
            when 'Approved' {
                validateEntityIsLinked(cases);
                // add validation for Approved status if needed
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
                performCRAIndividualRegistration(cases);  
            }
            when 'Completed' {
                performCRAEntityRegistration(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performCRAEntityRegistration(List<Case> cases) {
        Map<Integer, Case> accountIndexToCaseMap = new Map<Integer, Case>();
        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Case> entityIdToCaseMap = new Map<Id, Case>();
        Map<Id, Account> accountMap = getAccountMap(cases);
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();

        for (Case caseRecord : cases) {
            if (caseRecord.breg_Reg_Agent_Type__c == 'Entity' && caseRecord.breg_Entity__c != null) {
                Set<String> updatedFieldsSet = new Set<String>();
                Account linkedEntity = accountMap.get(caseRecord.breg_Entity__c);
                linkedEntity.breg_BRIM_CRA_FL__c = true;
                updatedFieldsSet.add('breg_BRIM_CRA_FL__c');
                if (String.isBlank(linkedEntity.breg_Formation_State__c)) {
                    linkedEntity.breg_Formation_State__c = getFormationState(caseRecord);
                    updatedFieldsSet.add('breg_Formation_State__c');
                }
                linkedEntity.breg_Registrant_Address__CountryCode__s = caseRecord.breg_Registered_Agent_Address__CountryCode__s;
                linkedEntity.breg_Registrant_Address__Street__s = caseRecord.breg_Registered_Agent_Address__Street__s;
                linkedEntity.breg_Registrant_Address__City__s = caseRecord.breg_Registered_Agent_Address__City__s;
                linkedEntity.breg_Registrant_Address__StateCode__s = caseRecord.breg_Registered_Agent_Address__StateCode__s;
                linkedEntity.breg_Registrant_Address__PostalCode__s = caseRecord.breg_Registered_Agent_Address__PostalCode__s;
                linkedEntity.breg_Registrant_Address_Street_2__c = caseRecord.breg_Reg_Agent_Address_Street2__c;
                entityIdToCaseMap.put(caseRecord.breg_Entity__c, caseRecord);
                accountUpdatedFieldsMap.put(caseRecord.breg_Entity__c, updatedFieldsSet);
                accountsToUpdate.add(linkedEntity);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityIdToCaseMap);
        }
    }

    private void performCRAIndividualRegistration(List<Case> cases) {
        List<Case> casesToUpdate = new List<Case>();
        Map<Integer, Case> accountIndexToCaseMap = new Map<Integer, Case>();
        List<Account> accountsToInsert = new List<Account>();

        for (Case caseRecord : cases) {
            if (caseRecord.breg_Reg_Agent_Type__c == 'Individual') {
                Account newAccount = new Account();
                newAccount.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
                newAccount.Name = caseRecord.breg_Reg_Agent_First_Name__c + ' ' + caseRecord.breg_Reg_Agent_Last_Name__c;
                newAccount.breg_BRIM_FILE_NO__c = caseRecord.breg_BRIM_FILE_NO__c;
                newAccount.breg_File__c = caseRecord.breg_File__c;
                newAccount.breg_File_Suffix__c = caseRecord.breg_File_Suffix__c;
                newAccount.breg_BRIM_CRA_FL__c = true;
                newAccount.breg_Registrant_Type__c = 'Individual';
                newAccount.breg_Entity_Type__c = 'CA';

                newAccount.BillingCountryCode = caseRecord.breg_Registered_Agent_Address__CountryCode__s;
                newAccount.BillingStreet = caseRecord.breg_Registered_Agent_Address__Street__s;
                newAccount.BillingCity = caseRecord.breg_Registered_Agent_Address__City__s;
                newAccount.BillingStateCode = caseRecord.breg_Registered_Agent_Address__StateCode__s;
                newAccount.BillingPostalCode = caseRecord.breg_Registered_Agent_Address__PostalCode__s;
                newAccount.breg_Billing_Address_Street_2__c = caseRecord.breg_Reg_Agent_Address_Street2__c;

                newAccount.breg_Registrant_Address__CountryCode__s = caseRecord.breg_Registered_Agent_Address__CountryCode__s;
                newAccount.breg_Registrant_Address__Street__s = caseRecord.breg_Registered_Agent_Address__Street__s;
                newAccount.breg_Registrant_Address__City__s = caseRecord.breg_Registered_Agent_Address__City__s;
                newAccount.breg_Registrant_Address__StateCode__s = caseRecord.breg_Registered_Agent_Address__StateCode__s;
                newAccount.breg_Registrant_Address__PostalCode__s = caseRecord.breg_Registered_Agent_Address__PostalCode__s;
                newAccount.breg_Registrant_Address_Street_2__c = caseRecord.breg_Reg_Agent_Address_Street2__c;

                newAccount.breg_Formation_State__c = getFormationState(caseRecord);

                accountsToInsert.add(newAccount);

                // Track the index of the new account (will be inserted) and its corresponding case record
                accountIndexToCaseMap.put(accountsToInsert.size() - 1, caseRecord);
            }
        }

        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
            Map<Id, Case> accIdToCaseMap = new Map<Id, Case>();
            // After upsert, assign the newly created Account Ids to their corresponding case records
            for (Integer accountIndex : accountIndexToCaseMap.keySet()) {
                Case caseRecord = new Case();
                caseRecord.Id = accountIndexToCaseMap.get(accountIndex).Id;
                caseRecord.breg_Entity__c = accountsToInsert.get(accountIndex).Id;
                casesToUpdate.add(caseRecord);
                accIdToCaseMap.put(accountsToInsert.get(accountIndex).Id, accountIndexToCaseMap.get(accountIndex));
            }
            BREGTransactionUtils.createTransBusinessInfoRecords(accountsToInsert, accIdToCaseMap);
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private String getFormationState(Case caseRecord) {
        String formationState;
        if (
            String.isNotBlank(caseRecord.breg_Registered_Agent_Address__CountryCode__s) && caseRecord.breg_Registered_Agent_Address__CountryCode__s == 'US'
        ) {
            formationState = caseRecord.breg_Registered_Agent_Address__StateCode__s;
        } else {
            formationState = caseRecord.breg_Registered_Agent_Address__CountryCode__s;
        }
        return formationState;
    }

    private void validateEntityIsLinked(List<Case> cases) {
        Map<Id, Account> accountMap = getAccountMap(cases);
        for (Case caseRecord : cases) {
            Account entity = accountMap.get(caseRecord.breg_Entity__c);

            if (caseRecord.breg_Reg_Agent_Type__c == 'Entity' && entity == null) {
                addErrorMessage(caseRecord, 'breg_Entity__c', 'Entity should be linked to the case');
            }

            if (caseRecord.breg_Reg_Agent_Type__c == 'Entity' && entity != null && entity.breg_Entity_Status__c != ENTITY_STATUS_ACTIVE) {
                addErrorMessage(caseRecord, 'breg_Entity__c', 'Entity should be Active to proceed');
            }
        }
    }

    private Map<Id, Account> getAccountMap(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case caseRecord : cases) {
            if (caseRecord.breg_Entity__c != null) {
                entityIds.add(caseRecord.breg_Entity__c);
            }
        }
        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, breg_Entity_Status__c, breg_Formation_State__c FROM Account WHERE Id IN :entityIds]
        );

        return accountMap;
    }
}