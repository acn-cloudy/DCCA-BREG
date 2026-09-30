public with sharing class BREGPaymentTriggerHandler extends BREGBaseTriggerHandler {

    private static final String BREG_DIVISION = 'BREG';

    public override void beforeInsert() {
        populateAccountFromContactForBregPayments((List<pymt__PaymentX__c>) this.newList);
    }

    /**
     * When `pymt__Contact__c` is set and `pymt__Account__c` is blank, sets the payment account from the
     * related contact: Person Account contacts and standard contacts both use `Contact.AccountId`.
     * Only payments whose related transaction has `Division__c` equal to BREG are updated.
     */
    private void populateAccountFromContactForBregPayments(List<pymt__PaymentX__c> payments) {
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (pymt__PaymentX__c payment : payments) {
            if (payment.Transaction__c != null
                && payment.pymt__Contact__c != null
                && payment.pymt__Account__c == null) {
                transactionIds.add(payment.Transaction__c);
                contactIds.add(payment.pymt__Contact__c);
            }
        }
        if (transactionIds.isEmpty() || contactIds.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> transactionById = new Map<Id, Transaction__c>(
            [SELECT Id, Division__c FROM Transaction__c WHERE Id IN :transactionIds]
        );

        Map<Id, Contact> payerByContactId = new Map<Id, Contact>(
            [SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds]
        );

        for (pymt__PaymentX__c payment : payments) {
            if (!isBregDivisionFromTransaction(payment.Transaction__c, transactionById)) {
                continue;
            }
            if (payment.pymt__Contact__c == null || payment.pymt__Account__c != null) {
                continue;
            }
            Contact payer = payerByContactId.get(payment.pymt__Contact__c);
            if (payer == null || payer.AccountId == null) {
                continue;
            }
            // Person Account and standard Contact: the paying account is always Contact.AccountId.
            payment.pymt__Account__c = payer.AccountId;
        }
    }

    private Boolean isBregDivisionFromTransaction(Id transactionId, Map<Id, Transaction__c> transactionById) {
        if (transactionId == null) {
            return false;
        }
        Transaction__c trans = transactionById.get(transactionId);
        return trans != null && trans.Division__c == BREG_DIVISION;
    }

    public override void afterInsert() {
        syncTransactionAccount((List<pymt__PaymentX__c>) this.newList);
        updateCasesWithRefundPayment((List<pymt__PaymentX__c>) this.newList);
    }

    private void updateCasesWithRefundPayment(List<pymt__PaymentX__c> payments) {
        Map<Id, List<TransactionLine__c>> paymentIdToLinesMap = getNewPaymentsWithParentAndTransactionLines(payments);
        Map<Id, Id> caseIdToRefundPaymentId = new Map<Id, Id>();
        for (Id paymentId : paymentIdToLinesMap.keySet()) {
            for (TransactionLine__c line : paymentIdToLinesMap.get(paymentId)) {
                if (line.breg_Case__c != null) {
                    caseIdToRefundPaymentId.put(line.breg_Case__c, paymentId);
                }
            }
        }

        if (caseIdToRefundPaymentId.isEmpty()) {
            return;
        }

        List<Case> casesToUpdate = [
            SELECT Id, breg_Refund_Payment__c
            FROM Case
            WHERE Id IN :caseIdToRefundPaymentId.keySet()
        ];

        for (Case c : casesToUpdate) {
            c.breg_Refund_Payment__c = caseIdToRefundPaymentId.get(c.Id);
        }

        update casesToUpdate;
    }

    private void syncTransactionAccount(List<pymt__PaymentX__c> payments) {
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (pymt__PaymentX__c payment : payments) {
            if (payment.Transaction__c != null && payment.pymt__Account__c != null) {
                transactionIds.add(payment.Transaction__c);
                accountIds.add(payment.pymt__Account__c);
            }
        }
        if (transactionIds.isEmpty() || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> bregTransactionById = new Map<Id, Transaction__c>(
            [
                SELECT Id, Account__c, AccountName__c
                FROM Transaction__c
                WHERE Id IN :transactionIds AND Division__c = :BREG_DIVISION
            ]
        );

        Map<Id, Account> accountById = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
        );

        Map<Id, Id> transactionIdToAccountId = new Map<Id, Id>();
        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        for (pymt__PaymentX__c payment : payments) {
            Transaction__c trans = bregTransactionById.get(payment.Transaction__c);
            Account account = accountById.get(payment.pymt__Account__c);
            if (trans == null || account == null) {
                continue;
            }
            if (
                trans.Account__c == null ||
                trans.Account__c != account.Id ||
                String.isBlank(trans.AccountName__c) ||
                trans.AccountName__c != account.Name
            ) {
                trans.Account__c = account.Id;
                trans.AccountName__c = account.Name;
                transactionsToUpdate.add(trans);
            }
        }

        if (!transactionsToUpdate.isEmpty()) {
            update transactionsToUpdate;
        }
    }

    private Map<Id, List<TransactionLine__c>> getNewPaymentsWithParentAndTransactionLines(List<pymt__PaymentX__c> payments) {
        Set<Id> newPaymentIds = new Set<Id>();
        for (pymt__PaymentX__c payment : payments) {
            newPaymentIds.add(payment.Id);
        }

        Map<Id, Id> originalToParentMap = new Map<Id, Id>();
        for (pymt__PaymentX__c p : [
            SELECT Id, pymt__Parent_Transaction__c
            FROM pymt__PaymentX__c
            WHERE Id IN :newPaymentIds AND pymt__Parent_Transaction__c != NULL
        ]) {
            originalToParentMap.put(p.Id, p.pymt__Parent_Transaction__c);
        }

        List<TransactionLine__c> transactionLines = [
            SELECT Id, Payment__c, breg_Case__c
            FROM TransactionLine__c
            WHERE Payment__c IN :originalToParentMap.values()
        ];

        Map<Id, List<TransactionLine__c>> result = new Map<Id, List<TransactionLine__c>>();
        for (Id originalId : originalToParentMap.keySet()) {
            result.put(originalId, new List<TransactionLine__c>());
        }

        for (TransactionLine__c line : transactionLines) {
            for (Id originalId : originalToParentMap.keySet()) {
                if (originalToParentMap.get(originalId) == line.Payment__c) {
                    result.get(originalId).add(line);
                }
            }
        }

        return result;
    }
}