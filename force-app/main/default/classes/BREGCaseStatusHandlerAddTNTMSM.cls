/**
 * Handler for the Address Change (ADD-TNTMSM) Form
 */
public without sharing class BREGCaseStatusHandlerAddTNTMSM extends BREGCaseStatusHandlerBase {
    public static final String ADDRESS_CHANGE_TREANSACTION_CODE = 'ADD-TNTMSM';
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
            when 'Pending Submission' {
                validateAddressChange(cases);
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
                BREGTransactionUtils.createTransactionsForTNTMSM(new Map<Id, Case>(cases), 'R');
            }
            when 'Approved' {
                updateTNTMSMAddress(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateAddressChange(List<Case> cases) {
        Map<Id, breg_TN_TM_SM__c> tntmsmMap = getTNTMSMMap(getTNTMSMIds(cases));
        for (Case c : cases) {
            breg_TN_TM_SM__c tntmsm = tntmsmMap.containsKey(c.breg_TN_TM_SM__c) ? tntmsmMap.get(c.breg_TN_TM_SM__c) : null;
            if (tntmsm == null) {
                addErrorMessage(c, null, 'The TN/TM/SM/PRN is not linked to the case.');
                continue;
            }

            if (
                c.breg_New_Mailing_Address__CountryCode__s == tntmsm.breg_Mailing_Address__CountryCode__s &&
                c.breg_New_Mailing_Address__Street__s == tntmsm.breg_Mailing_Address__Street__s &&
                c.breg_New_Mailing_Address__StateCode__s == tntmsm.breg_Mailing_Address__StateCode__s &&
                c.breg_New_Mailing_Address__City__s == tntmsm.breg_Mailing_Address__City__s &&
                c.breg_New_Mailing_Address__PostalCode__s == tntmsm.breg_Mailing_Address__PostalCode__s
            ) {
                addErrorMessage(c, null, 'The address has not changed.');
                continue;
            }
        }
    }

    private Map<SObjectField, SObjectField> getFieldMapping() {
        return new Map<SObjectField, SObjectField>{
            Case.breg_New_Mailing_Address__CountryCode__s => breg_TN_TM_SM__c.breg_Mailing_Address__CountryCode__s,
            Case.breg_New_Mailing_Address__Street__s => breg_TN_TM_SM__c.breg_Mailing_Address__Street__s,
            Case.breg_New_Mailing_Address__StateCode__s => breg_TN_TM_SM__c.breg_Mailing_Address__StateCode__s,
            Case.breg_New_Mailing_Address__City__s => breg_TN_TM_SM__c.breg_Mailing_Address__City__s,
            Case.breg_New_Mailing_Address__PostalCode__s => breg_TN_TM_SM__c.breg_Mailing_Address__PostalCode__s
        };
    }

    private void updateTNTMSMAddress(List<Case> cases) {
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(getTntmsmCaseMap(cases), 'breg_TN_TM_SM__c', getFieldMapping());
    }

    private Map<Id, breg_TN_TM_SM__c> getTNTMSMMap(Set<Id> tntmsmIds) {
        return new Map<Id, breg_TN_TM_SM__c>(
            [
                SELECT
                    Id,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s
                FROM breg_TN_TM_SM__c
                WHERE Id IN :tntmsmIds
            ]
        );
    }

    private Set<Id> getTNTMSMIds(List<Case> cases) {
        Set<Id> tntmsmIds = new Set<Id>();
        for (Case c : cases) {
            tntmsmIds.add(c.breg_TN_TM_SM__c);
        }
        return tntmsmIds;
    }

    private Map<Id, Case> getTntmsmCaseMap(List<Case> cases) {
        Map<Id, Case> tntmsmCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            tntmsmCaseMap.put(c.breg_TN_TM_SM__c, c);
        }
        return tntmsmCaseMap;
    }
}