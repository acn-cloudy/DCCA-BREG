public with sharing class BREGCaseStatusHandlerPublicityRightsReg extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            //performActions(casesForCheck, newStatus);
        }
    }
}