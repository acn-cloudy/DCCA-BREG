/**
 * Handler for the TNTMSM Registrant Name Change form (T-5, TN-RNC)
 */
public with sharing class BREGCaseStatusHandlerTNTMSMRegNameChange extends BREGCaseStatusHandlerBase {
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
            when 'Approved' {
                updateTNTMSMs(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateTNTMSMs(List<Case> cases) {
        List<breg_TN_TM_SM__c> tnTmSmsToUpdate = new List<breg_TN_TM_SM__c>();
        Map<Id, breg_Account_Affiliation__c> caseIdToAccAffsMap = getCaseIdToAccAffsMap(getCaseIds(cases));
        for (Case c : cases) {
            if (c.breg_TN_TM_SM__c != null) {
                breg_TN_TM_SM__c tnTmSm = new breg_TN_TM_SM__c();
                tnTmSm.Id = c.breg_TN_TM_SM__c;

                breg_Account_Affiliation__c accAff = caseIdToAccAffsMap.containsKey(c.Id)
                    ? caseIdToAccAffsMap.get(c.Id)
                    : null;
                if (accAff != null && accAff.breg_Role__c == 'Applicant' && accAff.breg_TN_TM_SM__c == tnTmSm.Id) {
                    if (accAff.breg_Type__c == 'Entity') {
                        tnTmSm.breg_Registrant_Type__c = 'Entity';
                        tnTmSm.breg_Registrant_Name__c = accAff.breg_Entity_Name__c;
                        tnTmSm.breg_Registrant_First_Name__c = null;
                        tnTmSm.breg_Registrant_Last_Name__c = null;
                        tnTmSmsToUpdate.add(tnTmSm);
                    } else if (accAff.breg_Type__c == 'Individual') {
                        tnTmSm.breg_Registrant_Type__c = 'Individual';
                        tnTmSm.breg_Registrant_Name__c = null;
                        tnTmSm.breg_Registrant_First_Name__c = accAff.breg_First_Name__c;
                        tnTmSm.breg_Registrant_Last_Name__c = accAff.breg_Last_Name__c;
                        tnTmSmsToUpdate.add(tnTmSm);
                    }
                }
            }
        }
        if (!tnTmSmsToUpdate.isEmpty()) {
            update tnTmSmsToUpdate;
        }
    }

    private Map<Id, breg_Account_Affiliation__c> getCaseIdToAccAffsMap(Set<Id> caseIds) {
        Map<Id, breg_Account_Affiliation__c> caseIdToAccAffsMap = new Map<Id, breg_Account_Affiliation__c>();

        List<breg_Account_Affiliation__c> accAffs = [
            SELECT Id, breg_Type__c, breg_Entity_Name__c, breg_First_Name__c, breg_Last_Name__c, breg_Role__c, breg_Case__c, breg_TN_TM_SM__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'Applicant' AND breg_TN_TM_SM__c != null LIMIT 1
        ];

        if (accAffs.size() > 0 && !caseIdToAccAffsMap.containsKey(accAffs[0].breg_Case__c)) {
            caseIdToAccAffsMap.put(accAffs[0].breg_Case__c, accAffs[0]);
        }

        return caseIdToAccAffsMap;
    }
}