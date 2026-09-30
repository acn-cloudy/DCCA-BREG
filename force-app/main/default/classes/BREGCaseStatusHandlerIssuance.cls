/**
 * Handler for the DC-6 Issuance form
 */
public with sharing class BREGCaseStatusHandlerIssuance extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        system.debug('BREGCaseStatusHandlerIssuance: ' + cases);
        system.debug('BREGCaseStatusHandlerIssuance: ' + performActions);
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        Map<Id, Case> mapCasesForCheck = new Map<Id, Case>(casesForCheck);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(mapCasesForCheck, cases, newStatus);
        }
        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(mapCasesForCheck, cases, newStatus);
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
                validateStocksExist(casesForCheck, cases);
            }
            when 'Rejected' {
                validateEntityNameEqualAccName(casesForCheck, cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(Map<Id, Case> mapCasesForUpdate, List<Case> cases, String newStatus) {
        system.debug('BREGCaseStatusHandlerIssuance.performActions: ' + cases);
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R', 'IS');
            }
            when 'Completed' {
                updateStockEntity(mapCasesForUpdate, cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private Map<Id, List<breg_Stock__c>> getStocksByCaseIds(Set<Id> caseIds) {
        Map<Id, List<breg_Stock__c>> caseIdToStocks = new Map<Id, List<breg_Stock__c>>();

        if (caseIds == null || caseIds.isEmpty()) {
            return caseIdToStocks;
        }

        List<breg_Stock__c> stockList = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Start_Date__c
            FROM breg_Stock__c
            WHERE breg_Case__c IN :caseIds
        ];

        for (breg_Stock__c stock : stockList) {
            if (!caseIdToStocks.containsKey(stock.breg_Case__c)) {
                caseIdToStocks.put(stock.breg_Case__c, new List<breg_Stock__c>());
            }
            caseIdToStocks.get(stock.breg_Case__c).add(stock);
        }

        return caseIdToStocks;
    }

    private void validateStocksExist(Map<Id, Case> casesForCheck, List<Case> cases) {
        system.debug('BREGCaseStatusHandlerIssuance.validateStocksExist: ' + cases);

        if (casesForCheck == null || casesForCheck.isEmpty()) {
            return;
        }

        Map<Id, List<breg_Stock__c>> caseIdToStocks = getStocksByCaseIds(casesForCheck.keySet());
        Set<Id> caseIdsWithStock = new Set<Id>(caseIdToStocks.keySet());

        for (Case triggerCase : cases) {
            if (!caseIdsWithStock.contains(triggerCase.Id)) {
                addErrorMessage(triggerCase, '', 'Stock record is required');
            }
        }
    }
    private void updateStockEntity(Map<Id, Case> mapCasesForUpdate, List<Case> cases) {
        system.debug('BREGCaseStatusHandlerIssuance.updateStockEntity: ' + mapCasesForUpdate);

        if (mapCasesForUpdate == null || mapCasesForUpdate.isEmpty()) {
            return;
        }

        Map<Id, List<breg_Stock__c>> caseIdToStocks = getStocksByCaseIds(mapCasesForUpdate.keySet());
        List<breg_Stock__c> stocksToUpdate = new List<breg_Stock__c>();

        for (Case triggerCase : cases) {
            Case caseRecord = mapCasesForUpdate.get(triggerCase.Id);
            if (caseRecord == null)
                continue;

            List<breg_Stock__c> relatedStocks = caseIdToStocks.get(triggerCase.Id);
            if (relatedStocks == null || relatedStocks.isEmpty()) {
                continue;
            }

            for (breg_Stock__c stock : relatedStocks) {
                // stock.breg_Account__c = caseRecord.breg_Entity__c;
                stock.breg_Start_Date__c = caseRecord.breg_Effective_Date__c;
                stocksToUpdate.add(stock);
            }
        }

        if (!stocksToUpdate.isEmpty()) {
            update stocksToUpdate;
        }
    }
}