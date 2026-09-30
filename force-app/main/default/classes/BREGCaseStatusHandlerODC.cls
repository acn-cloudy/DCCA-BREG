public with sharing class BREGCaseStatusHandlerODC extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
            //performValidation(cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(cases, newStatus);
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R', ConstantsHelper.ODC_TRANSACTION_CODE);
            }
            when 'Approved' {
                BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(BREGCaseStatusHandlerHelper.getMembersCaseMap(cases), cases);
                updateEntities(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateEntities(List<Case> cases) {
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case c : cases) {
            if (c.breg_Entity__c != null) {
                entityToCaseMap.put(c.breg_Entity__c, c);
            }
        }
        if (entityToCaseMap.isEmpty()) {
            return;
        }

        List<Account> entitiesToUpdate = new List<Account>();
        for (Account ent : [
            SELECT Id
            FROM Account
            WHERE Id IN :entityToCaseMap.keySet()
        ]) {
            Case cs = entityToCaseMap.get(ent.Id);
            if (cs == null) {
                continue;
            }
            if (cs.breg_Is_Manager_Managed__c) {
                ent.breg_Management_Type__c = 'Manager Managed';
            } else {
                ent.breg_Management_Type__c = 'Member Managed';
            }
            accountUpdatedFieldsMap.put(ent.Id, new Set<String>{ 'breg_Management_Type__c' });

            if (cs.breg_Number_of_initial_members__c != null) {
                ent.breg_Number_of_initial_members__c = cs.breg_Number_of_initial_members__c;
                if (!accountUpdatedFieldsMap.containsKey(ent.Id)) {
                    accountUpdatedFieldsMap.put(ent.Id, new Set<String>());
                }
                accountUpdatedFieldsMap.get(ent.Id).add('breg_Number_of_initial_members__c');
            }

            entitiesToUpdate.add(ent);
        }

        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

}