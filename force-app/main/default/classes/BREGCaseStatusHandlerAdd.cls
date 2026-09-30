/**
 * Handler for the Adress Change Form (ADD)
 */
public without sharing class BREGCaseStatusHandlerAdd extends BREGCaseStatusHandlerBase {
    public static final String ADDRESS_CHANGE_TRANSACTION_CODE = 'ADD';
    public static Integer counter = 0;
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
            performValidation(cases, newStatus);
        }

        if (performActions && counter < 1) {
            counter++;
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(cases, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Pending Submission' {
                validateAddressChange(cases);
            }
            when 'Approved' {
                validateEntityIsPopulated(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateEntityIsPopulated(List<Case> cases) {
        Map<Id, Account> entityMap = getEntityMap(getEntityIds(cases));
        for (Case c : cases) {
            Account entity = entityMap.containsKey(c.breg_Entity__c) ? entityMap.get(c.breg_Entity__c) : null;
            if (entity == null) {
                addErrorMessage(c, null, 'The entity is not linked to the case.');
                continue;
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R'); 
                BREGTransactionUtils.createTransactionsForEntityChildAccounts(new Map<Id, Case>(cases), 'R');
            }
            when 'Approved' {
                updateEntitiesAddress(getEntityCaseMap(cases));
                updateEntitiesAddress(getChildEntityCaseMap(cases));
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateAddressChange(List<Case> cases) {
        Map<Id, Account> entityMap = getEntityMap(getEntityIds(cases));
        for (Case c : cases) {
            Account entity = entityMap.containsKey(c.breg_Portal_User_Entity_Selected__c) ? entityMap.get(c.breg_Portal_User_Entity_Selected__c) : null;
            // if (entity == null) {
            //     addErrorMessage(c, null, 'The entity is not linked to the case.');
            //     continue;
            // }

            if (c.breg_Mailing_Address_Has_Changed__c == false && c.breg_Company_Address_Has_Changed__c == false) {
                addErrorMessage(c, null, 'Changes are required to submit the form. Please review your filing information.');
                continue;
            }

            if (
                c.breg_Mailing_Address_Has_Changed__c == true &&
                c.breg_New_Mailing_Address__CountryCode__s == entity.breg_Mailing_Address__CountryCode__s &&
                c.breg_New_Mailing_Address__Street__s == entity.breg_Mailing_Address__Street__s &&
                c.breg_New_Mailing_Address_Street_2__c == entity.breg_Mailing_Address_Street_2__c &&
                c.breg_New_Mailing_Address__StateCode__s == entity.breg_Mailing_Address__StateCode__s &&
                c.breg_New_Mailing_Address_State_Text__c == entity.breg_Billing_Address_State_Text__c &&
                c.breg_New_Mailing_Address__City__s == entity.breg_Mailing_Address__City__s &&
                c.breg_New_Mailing_Address__PostalCode__s == entity.breg_Mailing_Address__PostalCode__s
            ) {
                addErrorMessage(c, null, 'The mailing address has not changed.');
                continue;
            }

            if (
                c.breg_Company_Address_Has_Changed__c == true &&
                c.breg_New_Company_Address__CountryCode__s == entity.BillingCountryCode &&
                c.breg_New_Company_Address__Street__s == entity.BillingStreet &&
                c.breg_New_Company_Address_Street_2__c == entity.breg_Billing_Address_Street_2__c &&
                c.breg_New_Company_Address__StateCode__s == entity.BillingStateCode &&
                c.breg_New_Company_Address_State_Text__c == entity.breg_Billing_Address_State_Text__c &&
                c.breg_New_Company_Address__City__s == entity.BillingCity &&
                c.breg_New_Company_Address__PostalCode__s == entity.BillingPostalCode
            ) {
                addErrorMessage(c, null, 'The principal address has not changed.');
                continue;
            }
        }
    }

    private Map<Id, Case> getEntityCaseMap(List<Case> cases) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        return entityCaseMap;
    }

    private void updateEntitiesAddress(Map<Id, Case> accCasesMap) {
        if (accCasesMap == null || accCasesMap.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();

        for (Id accountId : accCasesMap.keySet()) {
            Case sourceCase = accCasesMap.get(accountId);

            if (sourceCase == null) {
                continue;
            }

            Account targetAccount = new Account(Id = accountId);
            Set<String> updatedFields = new Set<String>();
            if (sourceCase.breg_Mailing_Address_Has_Changed__c == true) {
                updateAccountField(targetAccount, Account.breg_Mailing_Address__CountryCode__s, sourceCase.get(Case.breg_New_Mailing_Address__CountryCode__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address__Street__s, sourceCase.get(Case.breg_New_Mailing_Address__Street__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address_Street_2__c, sourceCase.get(Case.breg_New_Mailing_Address_Street_2__c), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address_Street_3__c, null, updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address__StateCode__s, sourceCase.get(Case.breg_New_Mailing_Address__StateCode__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address_State_Text__c, sourceCase.get(Case.breg_New_Mailing_Address_State_Text__c), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address__City__s, sourceCase.get(Case.breg_New_Mailing_Address__City__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Mailing_Address__PostalCode__s, sourceCase.get(Case.breg_New_Mailing_Address__PostalCode__s), updatedFields);
            }

            if (sourceCase.breg_Company_Address_Has_Changed__c == true) {
                updateAccountField(targetAccount, Account.BillingCountryCode, sourceCase.get(Case.breg_New_Company_Address__CountryCode__s), updatedFields);
                updateAccountField(targetAccount, Account.BillingStreet, sourceCase.get(Case.breg_New_Company_Address__Street__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Billing_Address_Street_2__c, sourceCase.get(Case.breg_New_Company_Address_Street_2__c), updatedFields);
                updateAccountField(targetAccount, Account.breg_Billing_Address_Street_3__c, null, updatedFields);
                updateAccountField(targetAccount, Account.BillingStateCode, sourceCase.get(Case.breg_New_Company_Address__StateCode__s), updatedFields);
                updateAccountField(targetAccount, Account.breg_Billing_Address_State_Text__c, sourceCase.get(Case.breg_New_Company_Address_State_Text__c), updatedFields);
                updateAccountField(targetAccount, Account.BillingCity, sourceCase.get(Case.breg_New_Company_Address__City__s), updatedFields);
                updateAccountField(targetAccount, Account.BillingPostalCode, sourceCase.get(Case.breg_New_Company_Address__PostalCode__s), updatedFields);
            }

            if (!updatedFields.isEmpty()) {
                accountsToUpdate.add(targetAccount);
                accountUpdatedFieldsMap.put(targetAccount.Id, updatedFields);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, accCasesMap);
        }
    }

    private static void updateAccountField(Account targetAccount, SObjectField field, Object newValue, Set<String> updatedFields) {
        targetAccount.put(field, newValue);
        updatedFields.add(field.getDescribe().getName());
    }

    private Map<Id, Case> getChildEntityCaseMap(List<Case> cases) {
        Map<Id, Account> relatedEntitiesMap = getEntityMap(getEntityIds(cases));
        Map<Id, Case> accRelatedCaseMap = new Map<Id, Case>();
        List<Account> entitiesToUpdate = new List<Account>();
        for (Case c : cases) {
            Account currentEntity = relatedEntitiesMap.get(c.breg_Entity__c);
            String entityType = currentEntity.breg_Entity_Type__c;
            if (entityType == 'C5' || entityType == 'C6' || entityType == 'LLC') {
                accRelatedCaseMap.put(c.breg_Entity__c, c);
            }
        }

        List<Account> accountsToUpddate = [
            SELECT Id, ParentId, breg_Entity_Type__c, breg_Entity_Status__c
            FROM Account
            WHERE ParentId IN :accRelatedCaseMap.keySet()
        ];
        return accRelatedCaseMap;
    }

    private Map<Id, Account> getEntityMap(Set<Id> entityIds) {
        return new Map<Id, Account>(
            [
                SELECT
                    Id,
                    breg_Entity_Type__c,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Street_2__c,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address_State_Text__c,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s,
                    BillingCountryCode,
                    BillingStreet,
                    breg_Billing_Address_Street_2__c,
                    BillingStateCode,
                    breg_Billing_Address_State_Text__c,
                    BillingCity,
                    BillingPostalCode
                FROM Account
                WHERE Id IN :entityIds
            ]
        );
    }

    private Set<Id> getEntityIds(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case c : cases) {
            entityIds.add(c.breg_Entity__c);
            entityIds.add(c.breg_Portal_User_Entity_Selected__c);
        }
        return entityIds;
    }
}