/**
 * Handler for the TNTMSM Cancellation forms (TMSM-CANC,  TN-CANC)
 */
public with sharing class BREGCaseStatusHandlerTNTMSMCancel extends BREGCaseStatusHandlerBase {
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
        // switch on newStatus {
        //     when 'Approved' {
        //     }
        //     when else {
        //         // do nothing
        //     }
        // }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Completed' {
                updateTNTMSMs(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateTNTMSMs(List<Case> cases) {
        Set<Id> ids = getTNTMSMIds(cases);
        Map<Id, breg_TN_TM_SM__c> tnTmSmsMap = getTNTMSMMap(ids);
        List<breg_TN_TM_SM__c> tnTmSmsToUpdate = new List<breg_TN_TM_SM__c>();
        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case c : cases) {
            if (tnTmSmsMap.containsKey(c.breg_TN_TM_SM__c)) {
                entityToCaseMap.put(c.breg_Entity__c, c);
                breg_TN_TM_SM__c tnTmSm = tnTmSmsMap.get(c.breg_TN_TM_SM__c);
                if (c.breg_Effective_Date__c != null) {
                    tnTmSm.breg_Cancellation_Date__c = c.breg_Effective_Date__c;
                }
                tnTmSm.breg_Status__c = 'C';
                tnTmSmsToUpdate.add(tnTmSm);

                if (tnTmSm.breg_Account__c != null) {
                    Account account = new Account();
                    account.Id = tnTmSm.breg_Account__c;
                    if (c.breg_Effective_Date__c != null) {
                        account.breg_End_Date__c = c.breg_Effective_Date__c;
                        accountUpdatedFieldsMap.put(account.Id, new Set<String>{ 'breg_End_Date__c' });
                    }
                    accountsToUpdate.add(account);
                }
            }
        }

        if (!tnTmSmsToUpdate.isEmpty()) {
            update tnTmSmsToUpdate;
        }
        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private Set<Id> getTNTMSMIds(List<Case> cases) {
        Set<Id> ids = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_TN_TM_SM__c != null) {
                ids.add(c.breg_TN_TM_SM__c);
            }
        }
        return ids;
    }

    private Map<Id, breg_TN_TM_SM__c> getTNTMSMMap(Set<Id> ids) {
        return new Map<Id, breg_TN_TM_SM__c>(
            [
                SELECT Id, breg_Cancellation_Date__c, breg_Status__c, breg_Account__c
                FROM breg_TN_TM_SM__c
                WHERE Id IN :ids
            ]
        );
    }
}