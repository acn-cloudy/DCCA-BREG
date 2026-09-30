public with sharing class BREGCaseStatusHandlerAbandOfConversion extends BREGCaseStatusHandlerBase {
    private static final String CONVERTED_STATUS = 'Converted (9)';
    private static final String CANCELLED_STATUS = 'Cancelled (C)';
    private static final String CASE_REJECTED_STATUS = 'Rejected';
    private static final String CONVERSION_FORM_CODE = 'X-10';
    private static final String MESSAGE_PARENT_CASE_VALIDATION = 'You should populate Parent Case with Conversion work item for this Entity';
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
        // add specific actions for different statuses
        switch on newStatus {
            when 'Approved' {
                checkParentCase(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R');
            }
            when 'Completed' {
                checkEffectiveDate(cases);
                
            }
            when else {
                // do nothing
            }
        }
    }

    private void checkParentCase(List<Case> cases) {
        Map<Id, Case> queriedCasesMap = getCasesWithParentFields(cases);
        for (Case c : cases) {
            Case fullCase = queriedCasesMap.get(c.Id);
            if (
                fullCase.ParentId == null ||
                fullCase.Parent.breg_Form_Code__c != CONVERSION_FORM_CODE ||
                fullCase.Parent.breg_Entity__c != fullCase.breg_Entity__c
            ) {
                addErrorMessage(c, 'ParentId', MESSAGE_PARENT_CASE_VALIDATION);
                continue;
            }
        }
    }

    private void checkEffectiveDate(List<Case> cases) {
        Map<Id, Case> beforeEffectiveDateMap = new Map<Id, Case>();
        Map<Id, Case> afterEffectiveDateMap = new Map<Id, Case>();
        List<Case> casesWithParentFields = getCasesWithParentFields(cases).values();
        for (Case c : casesWithParentFields) {
            Date today = Date.today();
            if (c.Parent.breg_Effective_Date__c == null) {
                continue;
            }
            if (c.Parent.breg_Effective_Date__c > today) {
                beforeEffectiveDateMap.put(c.breg_Entity__c, c);
            } else if (c.Parent.breg_Effective_Date__c <= today && c.Parent.Status == 'Completed') {
                afterEffectiveDateMap.put(c.breg_Entity__c, c);
            }
        }

        if (!beforeEffectiveDateMap.isEmpty()) {
            closeConversionCases(getParentCases(beforeEffectiveDateMap.values()));
        }
        if (!afterEffectiveDateMap.isEmpty()) {
            updateOriginalEntities(afterEffectiveDateMap);
            updateNewEntities(afterEffectiveDateMap.values());
        }
    }

    private static List<Case> getParentCases(List<Case> cases) {
        Set<Id> parentIds = new Set<Id>();
        for (Case c : cases) {
            parentIds.add(c.ParentId);
        }
        return [SELECT Id, Status FROM Case WHERE Id IN :parentIds];
    }

    private static Map<Id, Case> getCasesWithParentFields(List<Case> cases) {
        return new Map<Id, Case>(
            [
                SELECT
                    Id,
                    CreatedDate,
                    Status,
                    breg_Effective_Date__c,
                    breg_New_Entity_Name__c,
                    breg_File__c,
                    breg_Entity__c,
                    breg_Form_Code__c,
                    ParentId,
                    Parent.breg_Form_Code__c,
                    Parent.Status,
                    Parent.breg_Entity__c,
                    Parent.breg_Effective_Date__c
                FROM Case
                WHERE Id IN :cases
            ]
        );
    }

    private static void closeConversionCases(List<Case> cases) {
        List<Case> casesToUpdate = new List<Case>();
        for (Case c : cases) {
            if (c.Status != CASE_REJECTED_STATUS) {
                c.Status = CASE_REJECTED_STATUS;
                casesToUpdate.add(c);
            }
        }

        update casesToUpdate;
    }

    private static void updateOriginalEntities(Map<Id, Case> afterEffectiveDateMap) {
        Map<Id, Account> entitiesMap = new Map<Id, Account>([SELECT Id, breg_Entity_Status__c FROM Account WHERE Id IN :afterEffectiveDateMap.keySet()]);
        List<AccountHistory> statusChanges = [
            SELECT AccountId, OldValue, NewValue
            FROM AccountHistory
            WHERE AccountId IN :afterEffectiveDateMap.keySet() AND Field = 'breg_Entity_Status__c'
            ORDER BY CreatedDate DESC
        ];
        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (AccountHistory change : statusChanges) {
            Account acc = entitiesMap.get(change.AccountId);
            if (change.NewValue == CONVERTED_STATUS && !accountsToUpdate.contains(acc)) {
                acc.breg_Entity_Status__c = (String) change.OldValue;
                accountsToUpdate.add(acc);
                accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Entity_Status__c' });
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, afterEffectiveDateMap);
        }
    }

    private static void updateNewEntities(List<Case> parentCases) {
        List<Account> entitiesToUpdate = new List<Account>();
        Set<String> newEntitiesNames = new Set<String>();
        Set<String> newEntitiesNumbers = new Set<String>();
        for (Case c : parentCases) {
            newEntitiesNames.add(c.breg_New_Entity_Name__c);
            newEntitiesNumbers.add(c.breg_File__c);
        }
        List<Account> newEntities = [
            SELECT Id, Name, breg_File__c, breg_Entity_Status__c
            FROM Account
            WHERE Name IN :newEntitiesNames AND breg_File__c IN :newEntitiesNumbers
        ];

        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();

        // Build a lookup map for parent cases keyed by Name|File to avoid an inner loop
        Map<String, Case> parentCaseByKey = new Map<String, Case>();
        for (Case pc : parentCases) {
            String pcName = pc.breg_New_Entity_Name__c == null ? '' : pc.breg_New_Entity_Name__c;
            String pcFile = pc.breg_File__c == null ? '' : pc.breg_File__c;
            parentCaseByKey.put(pcName + '|' + pcFile, pc);
        }

        for (Account acc : newEntities) {
            acc.breg_Entity_Status__c = CANCELLED_STATUS;
            entitiesToUpdate.add(acc);
            accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Entity_Status__c' });

            String accName = acc.Name == null ? '' : acc.Name;
            String accFile = acc.breg_File__c == null ? '' : acc.breg_File__c;
            String lookupKey = accName + '|' + accFile;
            if (parentCaseByKey.containsKey(lookupKey)) {
                entityToCaseMap.put(acc.Id, parentCaseByKey.get(lookupKey));
            }
        }

        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }
}