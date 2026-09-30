/**
 * Handler for the DC-7 Statement of Cancellation of Acquired Shares form
 */
public with sharing class BREGCaseStatusHandlerCancAcquiredShares extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        Map<Id, Case> mapCasesForCheck = new Map<Id, Case>(casesForCheck);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(mapCasesForCheck, cases, newStatus);
        }
        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(cases, newStatus);
        }
    }

    private void performValidation(Map<Id, Case> casesForCheck, List<Case> cases, String newStatus) {
        switch on newStatus {
            when 'Pending Submission' {
                //validation actions
            }
            when 'Approved' {
                validateEntityNameEqualAccName(casesForCheck, cases);
            }
            when 'Completed' {
                validateEntityNameEqualAccName(casesForCheck, cases);
                validateShares(casesForCheck, cases);
            }
            when 'Rejected' {
                validateEntityNameEqualAccName(casesForCheck, cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R');
            }
            when 'Completed' {
                updateEntityShares(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateShares(Map<Id, Case> casesForCheck, List<Case> cases) {
        for (Case triggerCase : cases) {
            Case caseRecord = casesForCheck.isEmpty() ? triggerCase : casesForCheck.get(triggerCase.Id);
            String errorMessage;
            if (caseRecord.breg_Cancelled_Shares_Class_Series__c == null || caseRecord.breg_Cancelled_Shares_Count__c == null) {
                errorMessage = REQUIRED_FIELD_MESSAGE;
                addErrorMessage(triggerCase, 'breg_Cancelled_Shares_Class_Series__c', BREGUtils.returnFielLabelByApiName('Case', 'breg_Cancelled_Shares_Class_Series__c') + ': ' +  + errorMessage);
            }
            if (caseRecord.breg_Remaining_Shares_Class_Series__c == null || caseRecord.breg_Remaining_Shares_Count__c == null) {
                errorMessage = REQUIRED_FIELD_MESSAGE;
                addErrorMessage(triggerCase, 'breg_Remaining_Shares_Class_Series__c', BREGUtils.returnFielLabelByApiName('Case', 'breg_Remaining_Shares_Class_Series__c') + ': ' +  + errorMessage);
            }
        }
    }

    private void updateEntityShares(List<Case> cases) {
        Map<Id, Decimal> entityIdToRemainingShares = new Map<Id, Decimal>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();

        for (Case c : cases) {
            system.debug(c.breg_Remaining_Shares_Count__c);
            if (c.breg_Entity__c != null && c.breg_Remaining_Shares_Count__c != null) {
                entityIdToRemainingShares.put(c.breg_Entity__c, c.breg_Remaining_Shares_Count__c);
                entityToCaseMap.put(c.breg_Entity__c, c);
            }
        }

        if (entityIdToRemainingShares.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = [
            SELECT Id, breg_Authorized_Shares_Count__c
            FROM Account
            WHERE Id IN :entityIdToRemainingShares.keySet()
        ];
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();

        for (Account acc : accountsToUpdate) {
            acc.breg_Authorized_Shares_Count__c = entityIdToRemainingShares.get(acc.Id);
            accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Authorized_Shares_Count__c' });
        }

        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }
}