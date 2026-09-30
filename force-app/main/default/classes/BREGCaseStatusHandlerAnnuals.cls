/**
 * Handler for the Annual Forms (ANN-AG-1, ANN-CONS-1, ANN-DC-1, ANN-DNP-1, ANN-FC-1, ANN-FLLC-1, ANN-FLLP-1, ANN-FLP-1, ANN-GP-1, ANN-LLC-1, ANN-LLP-1, ANN-LP-1, ANN-PC-1, ANN-SBC-1, ANN-SOLE-1)
 */
public without sharing class BREGCaseStatusHandlerAnnuals extends BREGCaseStatusHandlerBase {
    private static final String ANNUAL_IS_NOT_ELIGIBLE_FOR_APPROVAL = 'Annual is not eligible for approval.';
    private static final List<String> ANNUALS_WITH_NATURE_OF_BUSINESS_FIELD = new List<String>{ 
        'ANN-DC-1', 
        'ANN-DNP-1', 
        'ANN-FC-1', 
        'ANN-FLLC-1', 
        'ANN-FLLP-1', 
        'ANN-FLP-1', 
        'ANN-GP-1', 
        'ANN-LLC-1', 
        'ANN-LLP-1', 
        'ANN-LP-1', 
        'ANN-PC-1', 
        'ANN-SBC-1', 
        'ANN-SOLE-1',
        'ANN-AG-1',
        'ANN-CONS-1'
    };
    private static final List<String> ANNUALS_WITH_STOCKS = new List<String>{ 
        'ANN-AG-1', 
        'ANN-CONS-1', 
        'ANN-DC-1', 
        'ANN-PC-1', 
        'ANN-SBC-1'
    };
    private static final List<String> ANNUALS_WITH_FORMATION_STATE_FIELD = new List<String>{ 
        'ANN-FC-1',
        'ANN-GP-1',
        'ANN-LP-1'
    };
    
    private static final List<String> ANNUALS_WITH_MEMBERS = new List<String>{ 
        'ANN-LLC-1',
        'ANN-FLLC-1'
    };
    private static final List<String> ANNUALS_WITH_STOCKS_DECISIONS = new List<String>{ 
        'ANN-AG-1',
        'ANN-CONS-1'
    };
    private static final Set<String> ENTITY_TYPE_WITH_STOCKS_ENTITY_TYPES = new Set<String>{ 'A1', 'C1' };
    private static final Set<String> ENTITY_TYPE_WITHOUT_STOCKS_ENTITY_TYPES = new Set<String>{ 'A2', 'C2' };

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
            performValidation(cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Approved' {
                performAnnualEligibilityValidation(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Pending Submission'{
                //replaced update annuals to Received according to BREGMO-60
            }
            when 'Received' {
                expireDraftAnnualCases(cases);
                updateAnnual(cases, newStatus);
                updateGPAnnual(cases, newStatus);
                setEffectiveDateFromAnnual(cases);
                incrementAnnualDueDate(cases);
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R'); 
                BREGTransactionUtils.createTransactionsForEntityChildAccounts(new Map<Id, Case>(cases), 'R');
                setEffectiveDateFromAnnual(cases);

            }
            when 'Approved' {
                List<Case> casesWitChanges = new List<Case>();
                for (Case c : cases) {
                    if (c.breg_No_Changes__c == false) {
                        casesWitChanges.add(c);
                    }
                }
                BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(
                    BREGCaseStatusHandlerHelper.getAccountAffiliationCaseMap(casesWitChanges, true),
                    casesWitChanges
                );
                updateAnnual(cases, newStatus);
                updateGPAnnual(cases, newStatus);
                updateEntity(cases);
                updateGPEntity(cases);
                
            }
            // BREG-3720: removed Completed updateAnnual as per new requirements
            // when 'Completed' { 
            //     updateAnnual(cases, newStatus);
            // }
            when 'Rejected' {
                updateAnnual(cases, newStatus);
                updateGPAnnual(cases, newStatus);
            }
            when else {
                // do nothing
            }
        }
    }

    private void expireDraftAnnualCases(List<Case> cases) {
        Set<Id> annualIds = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_Annual__c != null) {
                annualIds.add(c.breg_Annual__c);
            }
        }
        if (annualIds.isEmpty()) {
            return;
        }

        Set<Id> processedCaseIds = getCaseIds(cases);
        List<Case> draftCasesToExpire = [
            SELECT Id, Status, breg_Annual__c
            FROM Case
            WHERE breg_Annual__c IN :annualIds
                AND Id NOT IN :processedCaseIds
                AND (Status = 'New' OR Status = 'Pending Submission')
        ];

        if (draftCasesToExpire.isEmpty()) {
            return;
        }

        for (Case draftCase : draftCasesToExpire) {
            draftCase.Status = 'Expired';
        }
        update draftCasesToExpire;
    }

    private void incrementAnnualDueDate(List<Case> cases){
        Map<Id, Account> accountMap = getEntityMap(cases);

        Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>();
        for(Case c : cases){
            Account existingAccount = c.breg_Entity__c != null ? accountMap.get(c.breg_Entity__c) : null;
            if(existingAccount != null && existingAccount.breg_Annuals_Due_Date__c != null){
                Account acc = new Account(Id = c.breg_Entity__c);
                Integer targetYear = Date.today().year() + 1;
                Integer yearDelta = targetYear - existingAccount.breg_Annuals_Due_Date__c.year();
                acc.breg_Annuals_Due_Date__c = existingAccount.breg_Annuals_Due_Date__c.addYears(yearDelta);
                accountsToUpdateMap.put(acc.Id, acc);
            }
        }
        if(!accountsToUpdateMap.isEmpty()){
            update accountsToUpdateMap.values();
        }
    }

    private void setEffectiveDateFromAnnual(List<Case> cases){
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        List<Case> casesToUpdate = new List<Case>();

        for(Case c : cases){
            if(c.breg_Annual__r != null && c.breg_Annual__r.breg_Filing_Date__c != null){
                c.breg_Effective_Date__c = c.breg_Annual__r.breg_Filing_Date__c;
                casesToUpdate.add(c);
            }
        }

        if(!casesToUpdate.isEmpty()){
            update casesToUpdate;
        }
    }

    private void createTransactionsForGPEntity(List<Case> cases) {
        Map<Id, Case> gpCases = new Map<Id, Case>();
        List<String> llpFormSuffixes = new List<String>{ 'K5', 'K6', 'LLP' };
        for (Case c : cases) {
            if (c.breg_File_Suffix__c != null && llpFormSuffixes.contains(c.breg_File_Suffix__c)) {
                gpCases.put(c.Id, c);
            }
        }
        if (!gpCases.isEmpty()) {
            BREGTransactionUtils.createTransactionsForEntityChildAccounts(gpCases, 'R');
        }
    }

    private void updateAnnual(List<Case> cases, String newStatus) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        Map<Id, breg_Annual__c> annualsToUpdateMap = new Map<Id, breg_Annual__c>();

        for (Case c : cases) {
            Case caseWithFields = caseWithFieldsMap.get(c.Id);
            if (caseWithFields.breg_Annual__c != null) {
                breg_Annual__c annual = new breg_Annual__c();
                annual.Id = caseWithFields.breg_Annual__c;

                // BREG-3720: removed Completed updateAnnual as per new requirements
                applyAnnualStatusUpdate(
                    annual,
                    newStatus,
                    caseWithFields.breg_Entity__r?.breg_Entity_Status__c,
                    c.Id,
                    caseWithFields.breg_No_Changes__c
                );
                annualsToUpdateMap.put(annual.Id, annual);
            }
        }

        if (!annualsToUpdateMap.isEmpty()) {
            update annualsToUpdateMap.values();
        }
    }

    private void updateGPAnnual(List<Case> cases, String newStatus){
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        List<Case> llpCases = new List<Case>();
        Map<Id, breg_Annual__c> annualsToUpdateMap = new Map<Id, breg_Annual__c>();
        Map<Id, String> entityAnnualFilingYearMap = new Map<Id, String>();
        Set<Id> llpAccountsIds = new Set<Id>();
        List<breg_Annual__c> gpAnnualsToUpdate = new List<breg_Annual__c>();
        for(Case c : cases){
            Case caseWithFields = caseWithFieldsMap.get(c.Id);
            if (
                caseWithFields?.breg_Entity__r != null &&
                (caseWithFields.breg_Entity__r.breg_Entity_Type__c == 'K5' || caseWithFields.breg_Entity__r.breg_Entity_Type__c == 'K6')
            ) {
                llpCases.add(caseWithFields);
                llpAccountsIds.add(caseWithFields.breg_Entity__c);
                if (caseWithFields.breg_Entity__c != null && caseWithFields.breg_Annual_Report_Filing_Year__c != null) {
                    entityAnnualFilingYearMap.put(caseWithFields.breg_Entity__c, caseWithFields.breg_Annual_Report_Filing_Year__c);
                }
            }
        }
        if (!llpCases.isEmpty()){
            gpAnnualsToUpdate = [
                SELECT Id, breg_Status__c, breg_Account__c, breg_Account__r.ParentId, breg_Filing_Year__c, breg_Account__r.breg_Entity_Status__c 
                FROM breg_Annual__c 
                WHERE breg_Account__r.ParentId IN :llpAccountsIds AND breg_Filing_Year__c IN :entityAnnualFilingYearMap.values()];

        }
        for (breg_Annual__c gpAnnual : gpAnnualsToUpdate){
            String filingYear = entityAnnualFilingYearMap.get(gpAnnual.breg_Account__r.ParentId);
            if(filingYear != null && filingYear == gpAnnual.breg_Filing_Year__c){
                breg_Annual__c annual = new breg_Annual__c();
                annual.Id = gpAnnual.Id;
                applyAnnualStatusUpdate(annual, newStatus, gpAnnual.breg_Account__r?.breg_Entity_Status__c, null, null);
                annualsToUpdateMap.put(annual.Id, annual);
            }
        }

        if (!annualsToUpdateMap.isEmpty()) {
            update annualsToUpdateMap.values();
        }
    }

    private void applyAnnualStatusUpdate(
        breg_Annual__c annual,
        String newStatus,
        String entityStatus,
        Id caseId,
        Boolean noChanges
    ) {
        if (newStatus == 'Received') {
            annual.breg_Status__c = 'F';
            annual.breg_Received_Date__c = DateTime.now();
            if (caseId != null) {
                annual.breg_Case__c = caseId;
            }
        } else if (newStatus == 'Approved') {
            annual.breg_Status__c = 'P';
            if (noChanges != null) {
                annual.breg_No_Changes__c = noChanges;
            }
        } else if (newStatus == 'Rejected') {
            annual.breg_Status__c = getRejectedAnnualStatus(entityStatus);
        }
    }

    private String getRejectedAnnualStatus(String entityStatus) {
        if (
            entityStatus == 'Annual report 1 yr delinquent (1)' ||
            entityStatus == 'Annual report 2 yr delinquent (2)'
        ) {
            return 'D';
        }
        return 'N';
    }

    private static Map<Id, Account> getAccountsWithTBIFields(Set<Id> entityIds) {
        List<Schema.FieldSetMember> fsmList = Account.SObjectType.getDescribe().fieldSets.getMap().get('BREG_TBI_Fields_Set').getFields();

        List<String> selectFields = new List<String>{ 'Id' };
        for (Schema.FieldSetMember fsm : fsmList) {
            selectFields.add(fsm.getFieldPath());
        }

        String soql =
            'SELECT breg_Mailing_Address__StateCode__s, breg_Mailing_Address__CountryCode__s, ' +
            'breg_Mailing_Address__Street__s, breg_Mailing_Address_Street_2__c, breg_Mailing_Address__City__s, breg_Mailing_Address_State_Text__c, ' +
            'breg_Mailing_Address__PostalCode__s, BillingCountryCode, BillingStreet, breg_Billing_Address_Street_2__c, ' +
            'BillingStateCode, breg_Billing_Address_State_Text__c, BillingCity, BillingPostalCode, ' +
            String.join(selectFields, ', ') +
            ' FROM Account WHERE Id IN :entityIds';
        List<Account> accList = (List<Account>) Database.query(soql);

        return new Map<Id, Account>(accList);
    }

    private void updateEntity(List<Case> cases) {
        updateEntities(cases, null);
    }

    private void updateEntities(List<Case> cases, Map<Id, List<Id>> caseIdToTargetAccountMap) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();

        List<breg_Stock__c> stocksToUpdate = new List<breg_Stock__c>();
        Set<Id> entityIds = new Set<Id>();
        for (Case c : cases) {
            Case caseWithFields = caseWithFieldsMap.get(c.Id);
            List<Id> targetAccountIds = caseIdToTargetAccountMap != null && caseIdToTargetAccountMap.containsKey(c.Id)
                ? caseIdToTargetAccountMap.get(c.Id)
                : new List<Id>{ caseWithFields?.breg_Entity__c };
            for (Id targetAccountId : targetAccountIds) {
                if (targetAccountId != null) {
                    entityIds.add(targetAccountId);
                }
            }
        }
        if (entityIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> accountIdToDelinquentAnnualCountMap = getAccountIdToDelinquentAnnualCountMap(entityIds);
        Map<Id, Integer> accountIdToLatestProcessedAnnualYearMap = getAccountIdToLatestProcessedAnnualYearMap(entityIds);
        Map<Id, List<breg_Stock__c>> accountIdToActiveStocksMap = getAccountIdToActiveStocksMap(entityIds);
        Map<Id, List<breg_Stock__c>> caseIdToNewStocksMap = getCaseIdToNewStocksMap(caseIds);
        Map<Id, Account> accountsToUpdateMap = getAccountsWithTBIFields(entityIds);
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, Case> casesWithAddressChangesMap = new Map<Id, Case>();
        List<Account> accountsWithChangedAddress = new List<Account>();
        Map<String, String> stateCodeValueLabelMap = BREGUtils.getPicklistLabelMap('Account', 'breg_Mailing_Address__StateCode__s');
        Map<String, String> countryCodeValueLabelMap = BREGUtils.getPicklistLabelMap('Account', 'breg_Mailing_Address__CountryCode__s');
        Map<String, String> countryCodeLabelValueMap = BREGUtils.getPicklistLabelToValueMap('Account', 'breg_Mailing_Address__CountryCode__s');
        // Dynamically get fields from FieldSet instead of hardcoding
        List<String> fieldsToTrack = BREGCaseStatusHandlerHelper.getFieldsFromFieldSet('Account', 'BREG_TBI_Fields_Set');

        for (Case c : cases) {
            Case caseWithFields = caseWithFieldsMap.get(c.Id);
            List<Id> targetAccountIds = caseIdToTargetAccountMap != null && caseIdToTargetAccountMap.containsKey(c.Id)
                ? caseIdToTargetAccountMap.get(c.Id)
                : new List<Id>{ caseWithFields?.breg_Entity__c };

            for (Id targetAccountId : targetAccountIds) {
                Account accountToUpdate = targetAccountId != null ? accountsToUpdateMap.get(targetAccountId) : null;
                Set<String> updatedFields = new Set<String>();

                if (caseWithFields != null && accountToUpdate != null) {
                    Integer caseAnnualYear = BREGAnnualRobotUtil.parseInteger(caseWithFields.breg_Annual__r.breg_Filing_Year__c);
                    Integer latestProcessedAnnualYear = accountIdToLatestProcessedAnnualYearMap.get(accountToUpdate.Id);
                    Boolean hasLaterProcessedAnnual = caseAnnualYear != null &&
                        latestProcessedAnnualYear != null &&
                        latestProcessedAnnualYear > caseAnnualYear;
                    Integer delinquentAnnualCount = accountIdToDelinquentAnnualCountMap.containsKey(accountToUpdate.Id)
                        ? accountIdToDelinquentAnnualCountMap.get(accountToUpdate.Id)
                        : 0;
                    if (delinquentAnnualCount == 0) {
                        accountToUpdate.breg_Entity_Status__c = 'Active (A)';
                        accountToUpdate.breg_Good_Standing__c = true;
                    } else if (!hasLaterProcessedAnnual) {
                        if (delinquentAnnualCount >= 3) {
                            accountToUpdate.breg_Entity_Status__c = 'Annual report 2 yr delinquent (2)';
                        } else {
                            accountToUpdate.breg_Entity_Status__c = 'Annual report 1 yr delinquent (1)';
                        }
                    }

                    if (caseWithFields.breg_No_Changes__c == false) {
                        // common logic for all forms
                        // update mailing address
                        Map<SObjectField, SObjectField> fieldMapping = getFieldMapping();
                        // update state code
                        if (stateCodeValueLabelMap.containsKey(caseWithFields.breg_Mailing_Address__StateCode__s)) {
                            fieldMapping.put(Account.breg_Mailing_Address__StateCode__s, Case.breg_Mailing_Address__StateCode__s);
                        } else {
                            fieldMapping.put(Account.breg_Mailing_Address_State_Text__c, Case.breg_Mailing_Address_State__c);
                        }

                        Boolean addressIsChanged = false;
                        for (SObjectField accField : fieldMapping.keySet()) {
                            SObjectField caseField = fieldMapping.get(accField);

                            Object newValue = caseWithFields.get(caseField);
                            Object oldValue = accountToUpdate.get(accField);

                            if (caseField == Case.breg_Mailing_Address__CountryCode__s) {
                                // update country code
                                if (countryCodeValueLabelMap.containsKey(caseWithFields.breg_Mailing_Address__CountryCode__s)) {
                                    newValue = (Object) caseWithFields.breg_Mailing_Address__CountryCode__s;
                                } else if (countryCodeLabelValueMap.containsKey(caseWithFields.breg_Mailing_Address__CountryCode__s)) {
                                    newValue = (Object) countryCodeLabelValueMap.get(caseWithFields.breg_Mailing_Address__CountryCode__s);
                                } else {
                                    newValue = null;
                                }
                            }

                            if (newValue != oldValue) {
                                accountToUpdate.put(accField, newValue);
                                addressIsChanged = true;
                            }
                        }
                        if (addressIsChanged) {
                            //accountToUpdate.breg_Billing_Address_Street_3__c = null;
                            //accountToUpdate.breg_Mailing_Address_Street_3__c = null;
                            casesWithAddressChangesMap.put(c.Id, c);
                            accountsWithChangedAddress.add(accountToUpdate);
                        }

                        if (
                            ANNUALS_WITH_NATURE_OF_BUSINESS_FIELD.contains(caseWithFields.breg_Form_Code__c)
                            && caseWithFields.breg_Entity_Nature_Of_Business__c != null
                        ) {
                            accountToUpdate.breg_Purpose__c = caseWithFields.breg_Entity_Nature_Of_Business__c;
                        }

                        if (ANNUALS_WITH_STOCKS.contains(caseWithFields.breg_Form_Code__c)) {
                            handleStocks(caseWithFields, stocksToUpdate, accountIdToActiveStocksMap, caseIdToNewStocksMap, accountToUpdate);
                        }

                        // Comment in BREGMO-378, Approved by Ben Holden
                        // if (
                        //     ANNUALS_WITH_FORMATION_STATE_FIELD.contains(caseWithFields.breg_Form_Code__c)
                        //     && caseWithFields.breg_Formation_State__c != null
                        // ) {
                        //     accountToUpdate.breg_Formation_State__c = caseWithFields.breg_Formation_State__c;
                        // }

                        if (
                            (
                                ANNUALS_WITH_MEMBERS.contains(caseWithFields.breg_Form_Code__c)
                                || (
                                    ANNUALS_WITH_STOCKS_DECISIONS.contains(caseWithFields.breg_Form_Code__c)
                                    && ENTITY_TYPE_WITHOUT_STOCKS_ENTITY_TYPES.contains(caseWithFields.breg_Entity_Type__c)
                                )
                            )
                            && caseWithFields.breg_Number_of_initial_members__c != null
                        ) {
                            accountToUpdate.breg_Number_of_initial_members__c = caseWithFields.breg_Number_of_initial_members__c;
                        }

                        if (
                            ANNUALS_WITH_STOCKS_DECISIONS.contains(caseWithFields.breg_Form_Code__c) 
                            && ENTITY_TYPE_WITH_STOCKS_ENTITY_TYPES.contains(caseWithFields.breg_Entity_Type__c)
                            && caseWithFields.breg_Number_of_Shareholders__c != null
                        ) {
                            accountToUpdate.breg_Number_of_Shareholders__c = caseWithFields.breg_Number_of_Shareholders__c;
                        }

                        if (
                            ANNUALS_WITH_STOCKS_DECISIONS.contains(caseWithFields.breg_Form_Code__c) 
                            && ENTITY_TYPE_WITHOUT_STOCKS_ENTITY_TYPES.contains(caseWithFields.breg_Entity_Type__c)
                            && caseWithFields.breg_Membership_Fees_Received__c != null
                        ) {
                            accountToUpdate.breg_Membership_Fees_Received__c = caseWithFields.breg_Membership_Fees_Received__c;
                        }
                    }

                    //accountsToUpdate.add(accountToUpdate);
                    // Automatically detect changed fields for logging
                    updatedFields = BREGCaseStatusHandlerHelper.getChangedFields(null, accountToUpdate, fieldsToTrack);
                    entityToCaseMap.put(accountToUpdate.Id, c);
                    accountUpdatedFieldsMap.put(accountToUpdate.Id, updatedFields);
                }
            }
        }

        if (!stocksToUpdate.isEmpty()) {
            update stocksToUpdate;
        }
        if (!accountsToUpdateMap.values().isEmpty()) {
            List<Account> accountsToUpdate = accountsToUpdateMap.values();
            update accountsToUpdate;

            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private static Map<SObjectField, SObjectField> getFieldMapping() {
        Map<SObjectField, SObjectField> result = new Map<SObjectField, SObjectField>{
            Account.breg_Mailing_Address__CountryCode__s => Case.breg_Mailing_Address__CountryCode__s,
            Account.breg_Mailing_Address__Street__s => Case.breg_Mailing_Address__Street__s,
            Account.breg_Mailing_Address_Street_2__c => Case.breg_Mailing_Address_Number_and_Street_2__c,
            Account.breg_Mailing_Address__City__s => Case.breg_Mailing_Address__City__s,
            Account.breg_Mailing_Address__StateCode__s => Case.breg_Mailing_Address__StateCode__s,
            Account.breg_Mailing_Address_State_Text__c => Case.breg_Mailing_Address_State__c,
            Account.breg_Mailing_Address__PostalCode__s => Case.breg_Mailing_Address__PostalCode__s,
            Account.BillingCountryCode => Case.breg_Company_Address__CountryCode__s,
            Account.BillingStreet => Case.breg_Company_Address__Street__s,
            Account.breg_Billing_Address_Street_2__c => Case.breg_Company_Address_Street2__c,
            Account.BillingStateCode => Case.breg_Company_Address__StateCode__s,
            Account.breg_Billing_Address_State_Text__c => Case.breg_Company_Address_State__c,
            Account.BillingCity => Case.breg_Company_Address__City__s,
            Account.BillingPostalCode => Case.breg_Company_Address__PostalCode__s
        };

        return result;
    }

    private void handleStocks(
        Case caseWithFields,
        List<breg_Stock__c> stocksToUpdate,
        Map<Id, List<breg_Stock__c>> accountIdToActiveStocksMap,
        Map<Id, List<breg_Stock__c>> caseIdToNewStocksMap,
        Account accountToUpdate
    ) {
        List<breg_Stock__c> activeStocks = accountIdToActiveStocksMap.containsKey(accountToUpdate.Id)
            ? accountIdToActiveStocksMap.get(accountToUpdate.Id)
            : new List<breg_Stock__c>();

        List<breg_Stock__c> newStocks = caseIdToNewStocksMap.containsKey(caseWithFields.Id)
            ? caseIdToNewStocksMap.get(caseWithFields.Id)
            : new List<breg_Stock__c>();

        Set<Id> activeStockProcessedIds = new Set<Id>();
        Set<Id> newStockProcessedIds = new Set<Id>();

        // update existing stocks
        for (breg_Stock__c newStock : newStocks) {
            if (newStockProcessedIds.contains(newStock.Id)) {
                continue;
            }
            for (breg_Stock__c activeStock : activeStocks) {
                if (activeStockProcessedIds.contains(activeStock.Id)) {
                    continue;
                }
                if (
                    newStock.breg_Stock_Class__c == activeStock.breg_Stock_Class__c &&
                    newStock.breg_Number_of_Issued_Shares__c == activeStock.breg_Number_of_Issued_Shares__c &&
                    newStock.breg_Paid_Shares__c != activeStock.breg_Paid_Shares__c
                ) {
                    activeStock.breg_End_Date__c = caseWithFields.breg_Effective_Date__c;
                    newStock.breg_Account__c = accountToUpdate.Id;
                    newStock.breg_Start_Date__c = caseWithFields.breg_Effective_Date__c;
                    activeStockProcessedIds.add(activeStock.Id);
                    newStockProcessedIds.add(newStock.Id);
                    stocksToUpdate.add(activeStock);
                    stocksToUpdate.add(newStock);
                    break;
                }
            }
        }
    }

    private void updateGPEntity(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseWithFieldsMap = getCases(caseIds);
        Map<Id, Case> accountIdToCaseMap = getAccountIdToCaseMap(caseWithFieldsMap.values());
        Set<Id> llpEntityIds = getLLPEntityIds(caseWithFieldsMap.values());
        List<breg_Document__c> llpDocuments = getDocuments(llpEntityIds);
        Map<Id, List<breg_Document__c>> accountIdToDocumentMap = getAccountIdToDocumentMap(llpDocuments);

        Map<Id, Account> gpEntityMap = getGPEntityMap(llpEntityIds);
        List<breg_Annual__c> gpAnnuals = getAnnuals(gpEntityMap.keySet());
        Map<Id, List<breg_Annual__c>> accountIdToGPAnnualMap = getAccountIdToAnnualMap(gpAnnuals);

        List<Case> gpCases = new List<Case>();
        Map<Id, List<Id>> gpCaseIdToTargetAccountMap = new Map<Id, List<Id>>();
        List<breg_Annual__c> annualsToUpdate = new List<breg_Annual__c>();
        List<breg_Document__c> documentsToInsert = new List<breg_Document__c>();

        for (Account gpEntity : gpEntityMap.values()) {
            Case caseWithFields = accountIdToCaseMap.containsKey(gpEntity.ParentId) ? accountIdToCaseMap.get(gpEntity.ParentId) : null;
            if (caseWithFields != null) {
                gpCases.add(caseWithFields);
                if (!gpCaseIdToTargetAccountMap.containsKey(caseWithFields.Id)) {
                    gpCaseIdToTargetAccountMap.put(caseWithFields.Id, new List<Id>());
                }
                gpCaseIdToTargetAccountMap.get(caseWithFields.Id).add(gpEntity.Id);
            }

            // update gp annual status
            List<breg_Annual__c> annuals = accountIdToGPAnnualMap.containsKey(gpEntity.Id)
                ? accountIdToGPAnnualMap.get(gpEntity.Id)
                : new List<breg_Annual__c>();
            for (breg_Annual__c annual : annuals) {
                if (annual.breg_Filing_Year__c == caseWithFields?.breg_Annual__r?.breg_Filing_Year__c) {
                    annual.breg_Status__c = caseWithFields?.breg_Annual__r?.breg_Status__c;
                    annualsToUpdate.add(annual);
                }
            }

            // copy over the documentation
            List<breg_Document__c> documents = accountIdToDocumentMap.containsKey(gpEntity.ParentId)
                ? accountIdToDocumentMap.get(gpEntity.ParentId)
                : new List<breg_Document__c>();
            for (breg_Document__c d : documents) {
                breg_Document__c newDoc = d.clone(false, false, false, false);
                newDoc.breg_Account__c = gpEntity.Id;
                newDoc.breg_Is_Public__c = false;
                documentsToInsert.add(newDoc);
            }
        }

        if (!gpCases.isEmpty()) {
            updateEntities(gpCases, gpCaseIdToTargetAccountMap);
        }
        if (!annualsToUpdate.isEmpty()) {
            update annualsToUpdate;
        }
        if (!documentsToInsert.isEmpty()) {
            insert documentsToInsert;
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
            WHERE breg_Account__c IN :entityIds
        ];
    }

    private Map<Id, List<breg_Document__c>> getAccountIdToDocumentMap(List<breg_Document__c> documents) {
        Map<Id, List<breg_Document__c>> accountIdToDocumentMap = new Map<Id, List<breg_Document__c>>();
        for (breg_Document__c d : documents) {
            List<breg_Document__c> docs = accountIdToDocumentMap.containsKey(d.breg_Account__c)
                ? accountIdToDocumentMap.get(d.breg_Account__c)
                : new List<breg_Document__c>();
            docs.add(d);
            accountIdToDocumentMap.put(d.breg_Account__c, docs);
        }
        return accountIdToDocumentMap;
    }

    private Map<Id, Case> getAccountIdToCaseMap(List<Case> cases) {
        Map<Id, Case> accountIdToCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            accountIdToCaseMap.put(c.breg_Entity__c, c);
        }
        return accountIdToCaseMap;
    }

    private List<breg_Annual__c> getAnnuals(Set<Id> entityIds) {
        return [
            SELECT breg_Account__c, breg_Filing_Year__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :entityIds
        ];
    }

    private Map<Id, List<breg_Annual__c>> getAccountIdToAnnualMap(List<breg_Annual__c> gpAnnuals) {
        Map<Id, List<breg_Annual__c>> accountIdToAnnualMap = new Map<Id, List<breg_Annual__c>>();
        for (breg_Annual__c a : gpAnnuals) {
            List<breg_Annual__c> annuals = accountIdToAnnualMap.containsKey(a.breg_Account__c)
                ? accountIdToAnnualMap.get(a.breg_Account__c)
                : new List<breg_Annual__c>();
            annuals.add(a);
            accountIdToAnnualMap.put(a.breg_Account__c, annuals);
        }
        return accountIdToAnnualMap;
    }

    private Set<Id> getLLPEntityIds(List<Case> cases) {
        Set<Id> llpEntityIds = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_Entity__r?.breg_Entity_Type__c == 'K5' || c.breg_Entity__r?.breg_Entity_Type__c == 'K6') {
                llpEntityIds.add(c.breg_Entity__c);
            }
        }
        return llpEntityIds;
    }

    private Map<Id, Account> getGPEntityMap(Set<Id> llpEntityIds) {
        return new Map<Id, Account>(
            [
                SELECT Id, ParentId
                FROM Account
                WHERE ParentId IN :llpEntityIds AND (breg_Entity_Type__c = 'G5' OR breg_Entity_Type__c = 'G6')
            ]
        );
    }

    private Map<Id, List<breg_Stock__c>> getAccountIdToActiveStocksMap(Set<Id> accountIds) {
        Map<Id, List<breg_Stock__c>> accountIdToActiveStocksMap = new Map<Id, List<breg_Stock__c>>();

        List<breg_Stock__c> stocks = [
            SELECT Id, breg_Account__c, breg_End_Date__c, breg_Case__c, breg_Start_Date__c, breg_Stock_Class__c, breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c
            FROM breg_Stock__c
            WHERE
                breg_Account__c IN :accountIds
                AND breg_Start_Date__c != NULL
                AND breg_End_Date__c = NULL
        ];
        for (breg_Stock__c s : stocks) {
            if (!accountIdToActiveStocksMap.containsKey(s.breg_Account__c)) {
                accountIdToActiveStocksMap.put(s.breg_Account__c, new List<breg_Stock__c>());
            }
            accountIdToActiveStocksMap.get(s.breg_Account__c).add(s);
        }

        return accountIdToActiveStocksMap;
    }

    private Map<Id, List<breg_Stock__c>> getCaseIdToNewStocksMap(Set<Id> caseIds) {
        Map<Id, List<breg_Stock__c>> caseIdToNewStocksMap = new Map<Id, List<breg_Stock__c>>();

        List<breg_Stock__c> stocks = [
            SELECT Id, breg_Account__c, breg_End_Date__c, breg_Case__c, breg_Start_Date__c, breg_Stock_Class__c, breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c
            FROM breg_Stock__c
            WHERE
                breg_Case__c IN :caseIds
                AND breg_Start_Date__c = NULL
                AND breg_End_Date__c = NULL
        ];
        for (breg_Stock__c s : stocks) {
            if (!caseIdToNewStocksMap.containsKey(s.breg_Case__c)) {
                caseIdToNewStocksMap.put(s.breg_Case__c, new List<breg_Stock__c>());
            }
            caseIdToNewStocksMap.get(s.breg_Case__c).add(s);
        }

        return caseIdToNewStocksMap;
    }

    private Map<Id, Integer> getAccountIdToDelinquentAnnualCountMap(Set<Id> accountIds) {
        List<breg_Annual__c> annuals = [
            SELECT breg_Account__c, breg_Status__c, breg_Filing_Year__c, breg_Filing_Date__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :accountIds AND breg_Status__c != 'P' AND breg_Status__c != 'NR'
        ];
        Date quarterStartDate = getQuarterStartDate(Date.today());
        Map<Id, Integer> accountIdToDelinquentAnnualCountMap = new Map<Id, Integer>();
        for (breg_Annual__c a : annuals) {
            if (a.breg_Filing_Date__c != null && a.breg_Filing_Date__c == quarterStartDate) {
                continue;
            }
            Integer delinquentAnnualCurrentCount = accountIdToDelinquentAnnualCountMap.containsKey(a.breg_Account__c)
                ? accountIdToDelinquentAnnualCountMap.get(a.breg_Account__c)
                : 0;
            accountIdToDelinquentAnnualCountMap.put(a.breg_Account__c, delinquentAnnualCurrentCount + 1);
            
        }

        return accountIdToDelinquentAnnualCountMap;
    }

    private Map<Id, Integer> getAccountIdToLatestProcessedAnnualYearMap(Set<Id> accountIds) {
        Map<Id, Integer> latestProcessedAnnualYearByAccountId = new Map<Id, Integer>();
        for (breg_Annual__c annual : [
            SELECT breg_Account__c, breg_Filing_Year__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :accountIds AND breg_Status__c = 'P'
        ]) {
            Integer annualYear = BREGAnnualRobotUtil.parseInteger(annual.breg_Filing_Year__c);
            Integer latestAnnualYear = latestProcessedAnnualYearByAccountId.get(annual.breg_Account__c);
            if (annualYear != null && (latestAnnualYear == null || annualYear > latestAnnualYear)) {
                latestProcessedAnnualYearByAccountId.put(annual.breg_Account__c, annualYear);
            }
        }
        return latestProcessedAnnualYearByAccountId;
    }

    private void performAnnualEligibilityValidation(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> casesMap = getCases(caseIds);
        // important to pass the cases from trigger context, not the casesMap
        Map<Id, Account> entityMap = getEntityMap(cases);
        Set<Id> conflictingTransactionEntityIds = getConflictingTransactionEntityIds(entityMap.keySet(), casesMap.values());
        Set<Id> dishonoredCheckEntityIds = new Set<Id>();
        if (entityMap.size() > 0) {
            dishonoredCheckEntityIds = getDishonoredCheckEntityIds(entityMap.keySet());
        }

        for (Case c : cases) {
            Case caseWithFields = casesMap.get(c.Id);
            String errorMessage = ANNUAL_IS_NOT_ELIGIBLE_FOR_APPROVAL;
            Account entity = entityMap.get(c.breg_Entity__c);

            if (
                caseWithFields.breg_No_Changes__c == false &&
                (
                    isMailingAddressIncomplete(caseWithFields) ||
                    isPrincipalAddressIncomplete(caseWithFields)
                )
            ) {
                addErrorMessage(
                    c,
                    null,
                    'Mailing address and principal office address are required when changes are made to an annual report.'
                );
                continue;
            }

            // entity and annual existence check
            if (caseWithFields.breg_Annual__c == null || entity == null) {
                errorMessage += ' Annual or Entity is blank.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
            // entity status check
            if (
                entity.breg_Entity_Status__c != 'Active (A)' &&
                entity.breg_Entity_Status__c != 'Annual report 1 yr delinquent (1)' &&
                entity.breg_Entity_Status__c != 'Annual report 2 yr delinquent (2)'
            ) {
                errorMessage += ' Entity not in Active (A), Annual report 1 yr delinquent (1) or Annual report 2 yr delinquent (2) status.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
            // conflicting transactions check
            if (conflictingTransactionEntityIds.contains(entity.Id)) {
                errorMessage += ' No conflicting transactions must be pending in the system such as - ADD, X-8, X-7, DC-2, DNP-2, LLC-2, ODC.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
            // dishonored check
            if (dishonoredCheckEntityIds.contains(entity.Id)) {
                errorMessage += ' Entity must not have dishonored check.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
            // delinquent period is active check
            if (
                entity.breg_Entity_Status__c == 'Annual report 2 yr delinquent (2)' &&
                entity.breg_Status_Effective_Date__c != null &&
                entity.breg_Status_Effective_Date__c.addDays(60) < Date.today()
            ) {
                errorMessage += ' The delinquent filing period is not active.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
            // GP entity check
            if ((entity.breg_Entity_Type__c == 'G5' || entity.breg_Entity_Type__c == 'G6') && entity.ParentId != null) {
                errorMessage += ' GP entity has a corresponding LLP, filing is not required.';
                addErrorMessage(c, null, errorMessage);
                continue;
            }
        }
    }

    private static Boolean isMailingAddressIncomplete(Case caseRecord) {
        return String.isBlank(caseRecord.breg_Mailing_Address__Street__s) ||
            String.isBlank(caseRecord.breg_Mailing_Address__City__s) ||
            String.isBlank(caseRecord.breg_Mailing_Address__PostalCode__s) ||
            String.isBlank(caseRecord.breg_Mailing_Address__CountryCode__s) ||
            (
                String.isBlank(caseRecord.breg_Mailing_Address__StateCode__s) &&
                String.isBlank(caseRecord.breg_Mailing_Address_State__c)
            );
    }

    private static Boolean isPrincipalAddressIncomplete(Case caseRecord) {
        return String.isBlank(caseRecord.breg_Company_Address__Street__s) ||
            String.isBlank(caseRecord.breg_Company_Address__City__s) ||
            String.isBlank(caseRecord.breg_Company_Address__PostalCode__s) ||
            String.isBlank(caseRecord.breg_Company_Address__CountryCode__s) ||
            (
                String.isBlank(caseRecord.breg_Company_Address__StateCode__s) &&
                String.isBlank(caseRecord.breg_Company_Address_State__c)
            );
    }

    private Set<Id> getDishonoredCheckEntityIds(Set<Id> entityIds) {
        Set<Id> dishonoredCheckEntityIds = new Set<Id>();

        Map<Id, Case> allEntityCasesMap = new Map<Id, Case>(
            [
                SELECT breg_Entity__c
                FROM Case
                WHERE breg_Entity__c IN :entityIds
            ]
        );

        List<pymt__PaymentX__c> dishonoredPayments = [
            SELECT breg_Case__c, breg_Case__r.breg_Entity__c
            FROM pymt__PaymentX__c
            WHERE
                breg_Case__c IN :allEntityCasesMap.keySet()
                AND (pymt__Status__c = 'Error'
                OR pymt__Status__c = 'Chargeback'
                OR pymt__Status__c = 'Voided'
                OR pymt__Status__c = 'Reversed')
        ];

        for (pymt__PaymentX__c p : dishonoredPayments) {
            dishonoredCheckEntityIds.add(p.breg_Case__r.breg_Entity__c);
        }

        return dishonoredCheckEntityIds;
    }

    private Map<Id, Account> getEntityMap(List<Case> cases) {
        Set<Id> entityIds = getEntityIds(cases);
        return new Map<Id, Account>(
            [
                SELECT Id, breg_Entity_Status__c, breg_Entity_Type__c, breg_Status_Effective_Date__c, ParentId, breg_Annuals_Due_Date__c
                FROM Account
                WHERE Id IN :entityIds
            ]
        );
    }

    private Set<Id> getEntityIds(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_Entity__c != null) {
                entityIds.add(c.breg_Entity__c);
            }
        }
        return entityIds;
    }

    private Map<Id, Case> getCases(Set<Id> caseIds) {
        return new Map<Id, Case>(
            [
                SELECT
                    breg_Annual__c,
                    breg_Entity__c,
                    breg_Entity_Type__c,
                    breg_No_Changes__c,
                    breg_Entity__r.breg_Entity_Status__c,
                    breg_Entity__r.breg_Entity_Type__c,
                    breg_Entity__r.breg_Status_Effective_Date__c,
                    breg_Entity__r.ParentId,
                    breg_Annual__r.breg_Filing_Year__c,
                    breg_Annual_Report_Filing_Year__c,
                    breg_Annual__r.breg_Status__c,
                    breg_Annual__r.breg_No_Changes__c,
                    breg_Annual__r.breg_Account__c,
                    breg_Submission_Date__c,
                    breg_Form_Code__c,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Number_and_Street_2__c,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address_State__c,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s,
                    breg_Company_Address__CountryCode__s,
                    breg_Company_Address__Street__s,
                    breg_Company_Address_Street2__c,
                    breg_Company_Address__StateCode__s,
                    breg_Company_Address_State__c,
                    breg_Company_Address__City__s,
                    breg_Company_Address__PostalCode__s,
                    //breg_Annual_Activities__c,
                    breg_Number_of_Shareholders__c,
                    breg_Number_of_initial_members__c,
                    breg_Membership_Fees_Received__c,
                    breg_Entity_Nature_Of_Business__c,
                    breg_Formation_State__c,
                    breg_Partnership_Location__c,
                    breg_Effective_Date__c,
                    breg_Authorized_Shares_Class_Series__c,
                    breg_Authorized_Shares_Count__c,
                    breg_Par_Value_Of_Each_Share__c,
                    breg_Par_Total__c,
                    breg_Outstanding_Shares_Class_Series__c,
                    breg_Outstanding_Shares_Count__c,
                    breg_Paid_In_Amount__c,
                    Subject,
                    CaseNumber,
                    breg_Purposes__c
                FROM Case
                WHERE Id IN :caseIds
            ]
        );
    }

    private Set<Id> getConflictingTransactionEntityIds(Set<Id> entityIds, List<Case> annualCases) {
        Set<Id> conflictingTransactionEntityIds = new Set<Id>();
        if (entityIds == null || entityIds.isEmpty()) {
            return conflictingTransactionEntityIds;
        }

        List<Case> conflictingTransactions = [
            SELECT Id, breg_Entity__c, breg_Submission_Date__c
            FROM Case
            WHERE
                breg_Entity__c IN :entityIds
                AND (breg_Form_Configuration__r.breg_Form_Code__c = 'ADD'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'X-8'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'X-7'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'DC-2'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'DNP-2'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'LLC-2'
                OR breg_Form_Configuration__r.breg_Form_Code__c = 'ODC')
                AND Status != 'Approved'
                AND Status != 'Rejected'
                AND Status != 'Completed'
                AND Status != 'Expired'
                AND Status != 'Purged'
                AND Status != 'Pending Submission'
        ];

        for (Case c : conflictingTransactions) {
            if (c.breg_Entity__c == null) {
                continue;
            }

            Boolean isConflicting = true;
            for (Case annualCase : annualCases) {
                if (
                    annualCase.breg_Entity__c == c.breg_Entity__c && 
                    annualCase.Id != c.Id && 
                    annualCase.breg_Submission_Date__c != null && 
                    c.breg_Submission_Date__c != null && 
                    c.breg_Submission_Date__c > annualCase.breg_Submission_Date__c
                ) {
                    isConflicting = false;
                    break;
                }
            }

            if (isConflicting) {
                conflictingTransactionEntityIds.add(c.breg_Entity__c);
            }
        }

        return conflictingTransactionEntityIds;
    }

    /**
     * Returns the day the quarter starts for the given date
     */
    public Date getQuarterStartDate(Date inputDate) {
        Integer month = inputDate.month();
        Integer year = inputDate.year();
        Date quarterStartDate;
        if (month >= 1 && month <= 3) {
            quarterStartDate = Date.newInstance(year, 1, 1);
        } else if (month >= 4 && month <= 6) {
            quarterStartDate = Date.newInstance(year, 4, 1);
        } else if (month >= 7 && month <= 9) {
            quarterStartDate = Date.newInstance(year, 7, 1);
        } else {
            quarterStartDate = Date.newInstance(year, 10, 1);
        }
        return quarterStartDate;
    }
}