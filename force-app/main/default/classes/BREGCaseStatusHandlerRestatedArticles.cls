/**
 * Handler for the Restated Articles forms (DC-4, DC-5, DNP-4, DNP-5, LLC-4, LLC-5)
 */
public with sharing class BREGCaseStatusHandlerRestatedArticles extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        system.debug('BREGCaseStatusHandlerRestatedArticles: ' + cases);
        system.debug('BREGCaseStatusHandlerRestatedArticles: ' + performActions);
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
        system.debug('BREGCaseStatusHandlerRestatedArticles.performActions: ' + cases);
        switch on newStatus {
            when 'Received' {
                createRestateTransactions(mapCasesForUpdate, 'RS');
            }
            when 'Completed' {
                updateDocumentToPublic(mapCasesForUpdate);
            }
            when else {
                // do nothing
            }
        }
    }

    private void updateDocumentToPublic(Map<Id, Case> casesMap) {
        system.debug('BREGCaseStatusHandlerRestatedArticles.updateDocumentToPublic: ' + casesMap);

        if (casesMap == null || casesMap.isEmpty()) {
            return;
        }

        List<breg_Document__c> docs = [
            SELECT Id, Name, breg_Is_Public__c, breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :casesMap.keySet() AND (Name LIKE '%Approved %' OR Name LIKE '%Rejected %')
        ];

        if (docs.isEmpty()) {
            return;
        }

        List<breg_Document__c> docsToUpdate = new List<breg_Document__c>();

        for (breg_Document__c doc : docs) {
            if (doc.breg_Is_Public__c != true) {
                doc.breg_Is_Public__c = true;
                docsToUpdate.add(doc);
            }
        }

        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
        }
    }

    private void createRestateTransactions(Map<Id, Case> casesMap, String transactionCode) {
        Map<Id, Id> caseToEntityMap = new Map<Id, Id>();
        for (Case c : casesMap.values()) {
            caseToEntityMap.put(c.Id, c.breg_Entity__c);
        }

        if (casesMap == null || casesMap.isEmpty()) {
            return;
        }
         List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(
            casesMap,
            caseToEntityMap,
            transactionCode,
            'R'
        );
        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
        createTransactionsForChildRecords(casesMap, transactionCode);
    }

    private void createTransactionsForChildRecords(Map<Id, Case> casesMap, String transactionCode) {
        List<String> llpTypeApis = new List<String>{ 'LLP', 'Limited Liability Partnership', 'K5', 'K6' };
        Set<Id> entityAccountIds = new Set<Id>();
        for (Case c : casesMap.values()) {
            if (c.breg_Entity__c != null && llpTypeApis.contains(c.breg_Entity__r.breg_Entity_Type__c)) {
                entityAccountIds.add(c.breg_Entity__c);
            }
        }

        if (entityAccountIds.isEmpty()) {
            return;
        }

        List<Account> childAccounts = [
            SELECT Id, ParentId, breg_Entity_Type__c
            FROM Account
            WHERE ParentId IN :entityAccountIds AND breg_Entity_Type__c IN ('General Partnership', 'G5', 'G6')
        ];

        if (childAccounts.isEmpty()) {
            return;
        }

        Map<Id, List<Account>> parentToChildren = new Map<Id, List<Account>>();
        for (Account acc : childAccounts) {
            if (!parentToChildren.containsKey(acc.ParentId)) {
                parentToChildren.put(acc.ParentId, new List<Account>());
            }
            parentToChildren.get(acc.ParentId).add(acc);
        }

        Map<Id, List<Id>> caseToChildAccountIdsMap = new Map<Id, List<Id>>();

        for (Id caseId : casesMap.keySet()) {
            Case c = casesMap.get(caseId);
            if (c == null || c.breg_Entity__c == null || !llpTypeApis.contains(c.breg_Entity__r.breg_Entity_Type__c)) {
                continue;
            }

            List<Account> children = parentToChildren.get(c.breg_Entity__c);
            if (children == null || children.isEmpty()) {
                continue;
            }

            List<Id> childAccountIds = new List<Id>();
            for (Account childAcc : children) {
                childAccountIds.add(childAcc.Id);
            }

            if (!childAccountIds.isEmpty()) {
                caseToChildAccountIdsMap.put(caseId, childAccountIds);
            }
        }

        List<breg_Transaction__c> transactionRecords = BREGTransactionUtils.createMassTransactionRecord(
            casesMap,
            caseToChildAccountIdsMap,
            transactionCode,
            false,
            'R'
        );

        if (!transactionRecords.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactionRecords);
        }
    }
}