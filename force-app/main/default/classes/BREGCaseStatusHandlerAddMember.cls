public with sharing class BREGCaseStatusHandlerAddMember extends BREGCaseStatusHandlerBase {
    public static final String ADDRESS_CHANGE_TREANSACTION_CODE = 'ADD-MEMBER';
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
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R');
            }
            when 'Approved' {
                BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(BREGCaseStatusHandlerHelper.getMembersCaseMap(cases), cases);
            }
            when else {
                // do nothing
            }
        }
    }

    // private Map<Id, Case> getMembersCaseMap(List<Case> cases) {
    //     Map<Id, Case> entityCaseMap = new Map<Id, Case>();
    //     Map<Id, Case> memberCaseMap = new Map<Id, Case>();
    //     for (Case c : cases) {
    //         entityCaseMap.put(c.breg_Entity__c, c);
    //     }
    //     List<String> odmmpsRoles = new List<String>{ 'Officer', 'Director', 'Member', 'Manager', 'Partner' };
    //     List<breg_Account_Affiliation__c> ODMMPs = [
    //         SELECT Id, breg_Role__c, breg_Account__c, breg_Contact__c, breg_Entity__c
    //         FROM breg_Account_Affiliation__c
    //         WHERE breg_Entity__c IN :entityCaseMap.keyset() AND breg_Account__c != NULL AND breg_Role__c IN :odmmpsRoles
    //         LIMIT 9000
    //     ];
    //     for (breg_Account_Affiliation__c aff : ODMMPs) {
    //         if (aff.breg_Contact__c != null) {
    //             memberCaseMap.put(aff.breg_Contact__c, entityCaseMap.get(aff.breg_Entity__c));
    //         } else if (aff.breg_Account__c != null) {
    //             memberCaseMap.put(aff.breg_Account__c, entityCaseMap.get(aff.breg_Entity__c));
    //         }
    //     }
    //     return memberCaseMap;
    // }

    // private static Boolean isDifferent(Object oldValue, Object newValue) {
    //     return oldValue != newValue && (oldValue == null || !oldValue.equals(newValue));
    // }
}