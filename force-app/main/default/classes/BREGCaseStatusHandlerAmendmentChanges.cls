public with sharing class BREGCaseStatusHandlerAmendmentChanges extends BREGCaseStatusHandlerBase {
    private static final String ERROR_FUTURE_DATE = ' Date cannot be a future date.';

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
                validateAmendmentAdoptionDate(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Received' {
                createEntityTransactions(cases);
                createGPTransactionsForLLP(cases);
            }
            when 'Completed' {
                updateEntities(getEntityCaseMap(cases));
                BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(BREGCaseStatusHandlerHelper.getMembersCaseMap(cases), cases);
                linkStocksToEntityAccounts(cases);
                updateGPEntityDocuments(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateAmendmentAdoptionDate(List<Case> cases) {
        for (Case c : cases) {
            if (c.breg_Form_Code__c == 'DC-2' || c.breg_Form_Code__c == 'DC-3') {
                if (c.breg_Amendment_Adoption_Date__c != null && c.breg_Amendment_Adoption_Date__c > Date.today()) {
                    addErrorMessage(c, 'breg_Amendment_Adoption_Date__c', 'Amendment Adoption' + ERROR_FUTURE_DATE);
                }
                if (c.breg_Written_Consent_Date__c != null && c.breg_Written_Consent_Date__c > Date.today()) {
                    addErrorMessage(c, 'breg_Written_Consent_Date__c', 'Written Consent Date' + ERROR_FUTURE_DATE);
                }
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
    //         SELECT Id, breg_Role__c, breg_Account__c, breg_Entity__c
    //         FROM breg_Account_Affiliation__c
    //         WHERE breg_Entity__c IN :entityCaseMap.keyset() AND breg_Account__c != NULL AND breg_Role__c IN :odmmpsRoles
    //         LIMIT 9000
    //     ];
    //     for (breg_Account_Affiliation__c aff : ODMMPs) {
    //         memberCaseMap.put(aff.breg_Account__c, entityCaseMap.get(aff.breg_Entity__c));
    //     }
    //     return memberCaseMap;
    // }

    private Map<Id, Case> getEntityCaseMap(List<Case> cases) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        return entityCaseMap;
    }

    private Map<SObjectField, SObjectField> getFieldMapping() {
        return new Map<SObjectField, SObjectField>{
            Case.breg_Mailing_Address__CountryCode__s => Account.breg_Mailing_Address__CountryCode__s,
            Case.breg_Mailing_Address__Street__s => Account.breg_Mailing_Address__Street__s,
            Case.breg_Mailing_Address_Number_and_Street_2__c => Account.breg_Mailing_Address_Street_2__c,
            Case.breg_Mailing_Address__StateCode__s => Account.breg_Mailing_Address__StateCode__s,
            Case.breg_Mailing_Address__City__s => Account.breg_Mailing_Address__City__s,
            Case.breg_Mailing_Address__PostalCode__s => Account.breg_Mailing_Address__PostalCode__s,
            Case.breg_Company_Address__CountryCode__s => Account.BillingCountryCode,
            Case.breg_Company_Address__Street__s => Account.BillingStreet,
            Case.breg_Company_Address_Street2__c => Account.breg_Billing_Address_Street_2__c,
            Case.breg_Company_Address__StateCode__s => Account.BillingStateCode,
            Case.breg_Company_Address__City__s => Account.BillingCity,
            Case.breg_Company_Address__PostalCode__s => Account.BillingPostalCode,
            Case.breg_New_Entity_Name__c => Account.Name
        };
    }

    private void updateEntities(Map<Id, Case> accCasesMap) {
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(accCasesMap, 'Account', getFieldMapping());
    }

    private Map<Id, Account> getEntityMap(Set<Id> entityIds) {
        return new Map<Id, Account>(
            [
                SELECT
                    Id,
                    breg_Entity_Type__c,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Street_2__c,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s,
                    BillingCountryCode,
                    BillingStreet,
                    breg_Billing_Address_Street_2__c,
                    BillingStateCode,
                    BillingCity,
                    BillingPostalCode
                FROM Account
                WHERE Id IN :entityIds
            ]
        );
    }

    private Set<Id> getEntityIds(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case c : cases) {
            entityIds.add(c.breg_Entity__c);
            entityIds.add(c.breg_Portal_User_Entity_Selected__c);
        }
        return entityIds;
    }

    private static Boolean isDifferent(Object oldValue, Object newValue) {
        return oldValue != newValue && (oldValue == null || !oldValue.equals(newValue));
    }

    private void linkStocksToEntityAccounts(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, List<breg_Stock__c>> caseIdToStocksMap = getCaseIdToStocksMap(caseIds);
        Map<Id, List<breg_Stock__c>> accountIdToStocksMap = getAccountIdToActiveStocksMap(caseIds);
        List<breg_Stock__c> stocksToUpdate = new List<breg_Stock__c>();
        for (Case c : cases) {
            List<breg_Stock__c> stocks = caseIdToStocksMap.get(c.Id);
            List<breg_Stock__c> accountStocks = accountIdToStocksMap.get(c.breg_Entity__c);
            if (stocks != null && !stocks.isEmpty()) {
                for (breg_Stock__c stock : stocks) {
                    stock.breg_Account__c = c.breg_Entity__c;
                    stock.breg_Start_Date__c = c.breg_Effective_Date__c;
                    stocksToUpdate.add(stock);
                }
            }

            if (accountStocks != null && !accountStocks.isEmpty()) {
                for (breg_Stock__c stock : accountStocks) {
                    stock.breg_Case__c = c.Id;
                    stock.breg_End_Date__c = c.breg_Effective_Date__c;
                    stocksToUpdate.add(stock);
                }
            }
        }
        if (!stocksToUpdate.isEmpty()) {
            update stocksToUpdate;
        }
    }

    private static Map<Id, List<breg_Stock__c>> getAccountIdToActiveStocksMap(Set<Id> accountIds) {
        Map<Id, List<breg_Stock__c>> accountIdToStocksMap = new Map<Id, List<breg_Stock__c>>();
        List<breg_Stock__c> stocks = [
            SELECT Id, CreatedDate, breg_Class_Detail__c, breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c, breg_Per_Value__c, breg_Stock_Amount__c
            FROM breg_Stock__c
            WHERE breg_Account__c IN :accountIds AND breg_End_Date__c = NULL AND breg_Start_Date__c != NULL
            ORDER BY CreatedDate DESC
        ];
        for (breg_Stock__c stock : stocks) {
            if (!accountIdToStocksMap.containsKey(stock.breg_Account__c)) {
                accountIdToStocksMap.put(stock.breg_Account__c, new List<breg_Stock__c>());
            }
            accountIdToStocksMap.get(stock.breg_Account__c).add(stock);
        }
        return accountIdToStocksMap;
    }

    private static Map<Id, List<breg_Stock__c>> getCaseIdToStocksMap(Set<Id> caseIds) {
        Map<Id, List<breg_Stock__c>> caseIdToStocksMap = new Map<Id, List<breg_Stock__c>>();
        List<breg_Stock__c> stocks = [
            SELECT
                Id,
                CreatedDate,
                breg_Class_Detail__c,
                breg_Number_of_Issued_Shares__c,
                breg_Paid_Shares__c,
                breg_Per_Value__c,
                breg_Stock_Amount__c,
                breg_Case__c
            FROM breg_Stock__c
            WHERE breg_Case__c IN :caseIds
            ORDER BY CreatedDate DESC
        ];
        for (breg_Stock__c stock : stocks) {
            if (!caseIdToStocksMap.containsKey(stock.breg_Case__c)) {
                caseIdToStocksMap.put(stock.breg_Case__c, new List<breg_Stock__c>());
            }
            caseIdToStocksMap.get(stock.breg_Case__c).add(stock);
        }
        return caseIdToStocksMap;
    }

    private void updateGPEntityDocuments(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        Set<Id> entityIds = geEntityIds(caseWithFieldsMap.values());
        List<breg_Document__c> llpDocuments = getDocuments(entityIds);
        for (breg_Document__c d : llpDocuments) {
            d.breg_Is_Public__c = true;
        }

        if (!llpDocuments.isEmpty()) {
            update llpDocuments;
        }
    }

    private List<breg_Document__c> getDocuments(Set<Id> entityIds) {
        return [
            SELECT
                Name,
                breg_Account__c,
                breg_Type__c,
                breg_File_Storage_URL__c,
                breg_File_Storage_Id__c,
                breg_Annotation__c,
                breg_Availability__c,
                breg_Available_To_Certify__c,
                breg_Is_Certificate_Of_Good_Standing__c,
                breg_Is_Certified__c,
                breg_Is_Template_Copy__c,
                breg_Price__c,
                breg_Template_Document__c
            FROM breg_Document__c
            WHERE breg_Account__c IN :entityIds AND Name LIKE '%Approved Initial Filing%'
        ];
    }

    private Set<Id> geEntityIds(List<Case> cases) {
        Set<Id> llpEntityIds = new Set<Id>();
        for (Case c : cases) {
            llpEntityIds.add(c.breg_Entity__c);
        }
        return llpEntityIds;
    }

    private Map<Id, Case> getCases(Set<Id> caseIds) {
        return new Map<Id, Case>(
            [
                SELECT
                    breg_Annual__c,
                    breg_Entity__c,
                    breg_No_Changes__c,
                    breg_Entity__r.breg_Entity_Status__c,
                    breg_Entity__r.breg_Entity_Type__c,
                    breg_Entity__r.breg_Status_Effective_Date__c,
                    breg_Entity__r.ParentId,
                    breg_Annual__r.breg_Filing_Year__c,
                    breg_Annual__r.breg_Status__c,
                    breg_Annual__r.breg_No_Changes__c,
                    breg_Annual__r.breg_Account__c
                FROM Case
                WHERE Id IN :caseIds
            ]
        );
    }

    private void createGPTransactionsForLLP(List<Case> cases) {
        Set<Id> llpEntityIds = getLLPEntityIds(cases);

        if (llpEntityIds.isEmpty()) {
            return;
        }

        Map<Id, Account> gpEntityMap = getGPEntityMap(llpEntityIds);

        if (gpEntityMap.isEmpty()) {
            return;
        }

        Map<Id, Case> llpAccountIdToCaseMap = new Map<Id, Case>();
        for (Case iCase : cases) {
            if (llpEntityIds.contains(iCase.breg_Entity__c)) {
                llpAccountIdToCaseMap.put(iCase.breg_Entity__c, iCase);
            }
        }

        Map<Id, Case> validCasesMap = new Map<Id, Case>();
        Map<Id, Id> caseToGPEntityMap = new Map<Id, Id>();

        for (Account gpEntity : gpEntityMap.values()) {
            Case relatedCase = llpAccountIdToCaseMap.get(gpEntity.ParentId);
            if (relatedCase == null || relatedCase.breg_Effective_Date__c == null) {
                continue;
            }
            validCasesMap.put(relatedCase.Id, relatedCase);
            caseToGPEntityMap.put(relatedCase.Id, gpEntity.Id);
        }

        if (validCasesMap.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToGPEntityMap,
            null,
            'R'
        );

        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }

    /**
     * Gets LLP entity IDs from cases
     * @param cases - list of cases
     * @return Set<Id> - set of LLP entity Account IDs
     */
    private Set<Id> getLLPEntityIds(List<Case> cases) {
        Set<Id> llpEntityIds = new Set<Id>();
        for (Case iCase : cases) {
            if (
                iCase.breg_Entity__c != null &&
                (iCase.breg_Entity__r.breg_Entity_Type__c == ConstantsHelper.K5_ENTITY_TYPE ||
                iCase.breg_Entity__r.breg_Entity_Type__c == ConstantsHelper.K6_ENTITY_TYPE)
            ) {
                llpEntityIds.add(iCase.breg_Entity__c);
            }
        }
        return llpEntityIds;
    }

    /**
     * Gets General Partner Account records for LLP entities
     * GP accounts have ParentId pointing to the LLP Account
     * @param llpEntityIds - set of LLP Account IDs
     * @return Map<Id, Account> - map of GP Account ID to GP Account record
     */
    private Map<Id, Account> getGPEntityMap(Set<Id> llpEntityIds) {
        if (llpEntityIds.isEmpty()) {
            return new Map<Id, Account>();
        }

        return new Map<Id, Account>(
            [
                SELECT Id, ParentId
                FROM Account
                WHERE
                    ParentId IN :llpEntityIds
                    AND (breg_Entity_Type__c = :ConstantsHelper.G5_ENTITY_TYPE
                    OR breg_Entity_Type__c = :ConstantsHelper.G6_ENTITY_TYPE)
                LIMIT 10000
            ]
        );
    }

    private void createEntityTransactions(List<Case> cases) {
        List<Case> casesWithFields = getCasesWithAllFields(cases);

        Map<Id, Case> validCasesMap = new Map<Id, Case>();
        Map<Id, Id> caseToEntityMap = new Map<Id, Id>();

        for (Case iCase : casesWithFields) {
            if (iCase.breg_Effective_Date__c != null) {
                validCasesMap.put(iCase.Id, iCase);
                caseToEntityMap.put(iCase.Id, iCase.breg_Entity__c);
            }
        }

        if (validCasesMap.isEmpty()) {
            return;
        }

        List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(
            validCasesMap,
            caseToEntityMap,
            null,
            'R'
        );

        if (!transactions.isEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
    }
}