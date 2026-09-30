public with sharing class BregCaseStatusHandlerRevocation extends BREGCaseStatusHandlerBase {
    private static final String MESSAGE_CORRECTIONS_ARE_NOT_ELIGIBLE_FOR_APPROVAL = 'Revocations are not eligible for approval.';
    private static final String REVOCATION_TRANSACTION_CODE = 'RVKD';
    private static final String DISOLUTION_STATUS = 'Dissolved (D)';
    private static final String ACTIVE_STATUS = 'Active (A)';
    private static final String ANNUAL_REPORT_1_STATUS = 'Annual report 1 yr delinquent (1)';
    private static final String ANNUAL_REPORT_2_STATUS = 'Annual report 2 yr delinquent (2)';
    private static final String DELINQUENT_STATUS = 'D';

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
        }

        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R', REVOCATION_TRANSACTION_CODE);
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R', 'ANN');
            }
            when 'Completed' {
                updateEntityStatus(getEntityCaseMap(cases));
                updateRelatedTransactionsToDelinquent(getEntityCaseMap(cases));
            }
            when 'Rejected' {
            }
            when else {
                // do nothing
            }
        }
    }

    public static void updateCasesOwner(List<Case> cases, String newOwner) {
        Id queueId = BREGUtils.getQueueId(newOwner);
        for (Case c : cases) {
            c.OwnerId = queueId;
        }
        update cases;
    }
    private static void performCorrectionsValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Approved' {
                // do nothing
            }
        }
    }

    private Map<Id, Case> getEntityCaseMap(List<Case> cases) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        return entityCaseMap;
    }


    private void updateRelatedTransactionsToDelinquent(Map<Id, Case> accRelatedCaseMap) {
        List<breg_Transaction__c> transactions = [SELECT Id, breg_Status__c, breg_Account__c FROM breg_Transaction__c WHERE breg_Account__c IN :accRelatedCaseMap.keySet() AND breg_Type__c = 'ANN'];
        Map<Id,Id> transactionIdToAccountIdMap = new Map<Id, Id>();
        for (breg_Transaction__c t : transactions) {
            transactionIdToAccountIdMap.put(t.Id, t.breg_Account__c);
        }
        List<breg_Transaction__c> transactionsToUpdate = new List<breg_Transaction__c>();
        Map<Id, Account> accountsMap = getAccountsWithProcessedAnnualsMap(accRelatedCaseMap.keySet());

        for (breg_Transaction__c t : transactions) {
            Id accId = transactionIdToAccountIdMap.get(t.Id);
            Account a = accountsMap.get(accId);
            if (a == null) {
                continue;
            }
            if (a.Annuals__r.isEmpty()) {
                t.breg_Status__c = DELINQUENT_STATUS;
                transactionsToUpdate.add(t);
            }
        }


        if (!transactionsToUpdate.isEmpty()) {
            update transactionsToUpdate;
        }
    }

    private Map<Id,Account> getAccountsWithProcessedAnnualsMap(Set<Id> accountIds) {
        Map<Id, Account> accountsMap = new Map<Id, Account>(
            [
                SELECT
                    Id,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Street_2__c,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__PostalCode__s,
                    breg_Mailing_Address__CountryCode__s,
                    BillingStreet,
                    breg_Billing_Address_Street_2__c,
                    BillingCity,
                    BillingStateCode,
                    BillingPostalCode,
                    BillingCountryCode,
                    breg_Delinquency_Status_Preview__c,
                    breg_Entity_Status__c,
                    (
                        SELECT breg_Account__c, breg_Status__c, CreatedDate, breg_Filing_Date__c
                        FROM Annuals__r
                        WHERE (
                            breg_Status__c = 'P'
                            OR breg_Status__c = 'NR'
                        )
                        ORDER BY breg_Filing_Date__c DESC
                        LIMIT 1
                    )
                FROM Account
                WHERE Id IN :accountIds
            ]
        );
        return accountsMap;
    }

    private void updateEntityStatus(Map<Id, Case> accRelatedCaseMap) {
        String referenceYear = String.valueOf(DateTime.now().date().year());
        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, Account> accountsMap = getAccountsWithProcessedAnnualsMap(accRelatedCaseMap.keySet());

        for (Id accId : accRelatedCaseMap.keySet()) {
            Case c = accRelatedCaseMap.get(accId);
            Account a = accountsMap.get(accId);
            entityToCaseMap.put(accId, c);
            if (a == null) {
                continue;
            }
            if (a.Annuals__r.isEmpty()) {
                a.breg_Entity_Status__c = ANNUAL_REPORT_1_STATUS;
            } else {
                if (a.Annuals__r[0].breg_Filing_Date__c != null && a.Annuals__r[0].breg_Filing_Date__c >= Date.today().addYears(-1)) {
                    a.breg_Entity_Status__c = ACTIVE_STATUS;
                } else {
                    a.breg_Entity_Status__c = ANNUAL_REPORT_1_STATUS;
                }
            }
            accountUpdatedFieldsMap.put(accId, new Set<String>{ 'breg_Entity_Status__c' });
            accountsToUpdate.add(a);

        }


        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }
}