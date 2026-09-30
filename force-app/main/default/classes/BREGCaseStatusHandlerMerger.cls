public with sharing class BREGCaseStatusHandlerMerger extends BREGCaseStatusHandlerBase {
    private static final String CREATE_CERTIFICATE_WORKFLOW = 'BREG Create Certificate for Case';

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
        switch on newStatus {
            when 'Approved' {
                Map<Id, List<Id>> caseToMergingEntityIdsMap = getCaseToMergingEntityIdsMap(cases, false);
                validateLinkToEntity(cases, caseToMergingEntityIdsMap);
                checkIfCaseHasAtLeastTwoMergingEntities(cases, caseToMergingEntityIdsMap);
                checkIfMergerCertificateIsGenerated(cases);
            }
            when 'Completed' {
                validateEffectiveDate(getCasesWithAllFields(cases));
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        List<Case> casesWithAllFields = getCasesWithAllFields(cases);
        Map<Id, List<Id>> caseToMergingEntityIdsWithChildGPMap = getCaseToMergingEntityIdsMap(cases, true);
        switch on newStatus {
            when 'Received'{
                upsertTransactionsForEntities(casesWithAllFields, caseToMergingEntityIdsWithChildGPMap, 'R');
            }
            when 'Approved' {
                //createMergerCertificate(cases); // commented in BREG-4482
                upsertTransactionsForEntities(casesWithAllFields, caseToMergingEntityIdsWithChildGPMap, 'A');
            }
            when 'Completed' {
                Map<Id, List<Id>> caseToMergingEntityIdsMap = getCaseToMergingEntityIdsMap(cases, false);
                Map<Id, List<breg_TN_TM_SM__c>> caseToMergingEntityTntmsmMap = getCaseToMergingEntityTntmsmMap(cases, caseToMergingEntityIdsMap);
                updateSurvivingEntity(casesWithAllFields);
                updateMergingEntitiesStatus(cases, caseToMergingEntityIdsMap);
                upsertTransactionsForEntities(casesWithAllFields, caseToMergingEntityIdsWithChildGPMap, 'C');

                if (!caseToMergingEntityTntmsmMap.isEmpty() && caseToMergingEntityTntmsmMap.values().size() > 0) {
                    createSurvivingEntityNewTNTMSM(cases, caseToMergingEntityTntmsmMap);
                    updateTntmsmForMergingEntity(cases, caseToMergingEntityTntmsmMap);
                }
            } when 'Rejected' {
                upsertTransactionsForEntities(casesWithAllFields, caseToMergingEntityIdsWithChildGPMap, 'J');
            }

            when else {
                // do nothing
            }
        }
    }

    private Map<Id, List<Id>> getCaseToMergingEntityIdsMap(List<Case> cases, Boolean withChildGP) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, List<Id>> caseToMergingEntityIdsMap = new Map<Id, List<Id>>();
        Map<Id, Id> entityToCaseIdMap = new Map<Id, Id>();

        List<breg_Account_Affiliation__c> accAffiliations = [
            SELECT Id, breg_Entity__c, breg_Case__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'Merging Entity'
            LIMIT 9000
        ];

        for (breg_Account_Affiliation__c aff : accAffiliations) {
            if (!caseToMergingEntityIdsMap.containsKey(aff.breg_Case__c)) {
                caseToMergingEntityIdsMap.put(aff.breg_Case__c, new List<Id>());
            }
            caseToMergingEntityIdsMap.get(aff.breg_Case__c).add(aff.breg_Entity__c);

            entityToCaseIdMap.put(aff.breg_Entity__c, aff.breg_Case__c);
        }

        if (!withChildGP) {
            return caseToMergingEntityIdsMap;
        }

        List<String> llpTypeApis = new List<String>{ 'Limited Liability Partnership', 'K5', 'K6' };
        Set<Id> llpAccounts = new Map<Id, Account>(
                [
                    SELECT Id
                    FROM Account
                    WHERE Id IN :entityToCaseIdMap.keySet() AND breg_Entity_Type__c IN :llpTypeApis
                    LIMIT 9000
                ]
            )
            .keySet();

        if (llpAccounts.isEmpty()) {
            return caseToMergingEntityIdsMap;
        }

        List<String> gpTypeApis = new List<String>{ 'General Partnership', 'G5', 'G6' };
        List<Account> gpAccounts = [
            SELECT Id, ParentId
            FROM Account
            WHERE ParentId IN :llpAccounts AND breg_Entity_Type__c IN :gpTypeApis
            LIMIT 9000
        ];

        for (Account gp : gpAccounts) {
            Id caseId = entityToCaseIdMap.get(gp.ParentId);
            if (caseId != null) {
                caseToMergingEntityIdsMap.get(caseId).add(gp.Id);
            }
        }

        return caseToMergingEntityIdsMap;
    }

    private Map<Id, List<breg_TN_TM_SM__c>> getCaseToMergingEntityTntmsmMap(List<Case> cases, Map<Id, List<Id>> caseToMergingEntityIdsMap) {
        Map<Id, List<breg_TN_TM_SM__c>> caseToMergingEntityTntmsmMap = new Map<Id, List<breg_TN_TM_SM__c>>();

        List<Id> mergingEntityIds = new List<Id>();
        for (Case c : cases) {
            mergingEntityIds.addAll(caseToMergingEntityIdsMap.get(c.Id));
        }

        List<breg_TN_TM_SM__c> tntmsmList = [
            SELECT
                Id,
                breg_Account__c,
                breg_Cert_Number__c,
                breg_Trade_Name__c,
                breg_Registration_Type__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Type__c,
                breg_Status__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c IN :mergingEntityIds AND breg_Status__c = 'A'
            LIMIT 9000
        ];

        Map<Id, List<breg_TN_TM_SM__c>> accountToTntmsmMap = new Map<Id, List<breg_TN_TM_SM__c>>();

        for (breg_TN_TM_SM__c tntmsm : tntmsmList) {
            if (!accountToTntmsmMap.containsKey(tntmsm.breg_Account__c)) {
                accountToTntmsmMap.put(tntmsm.breg_Account__c, new List<breg_TN_TM_SM__c>());
            }
            accountToTntmsmMap.get(tntmsm.breg_Account__c).add(tntmsm);
        }

        for (Case c : cases) {
            List<breg_TN_TM_SM__c> tntmsmIdsList = new List<breg_TN_TM_SM__c>();

            List<Id> entityIds = caseToMergingEntityIdsMap.get(c.Id);
            if (entityIds == null || entityIds.isEmpty()) {
                continue;
            }

            for (Id entityId : entityIds) {
                List<breg_TN_TM_SM__c> tntmsmForEntity = accountToTntmsmMap.get(entityId);
                if (tntmsmForEntity != null && !tntmsmForEntity.isEmpty()) {
                    tntmsmIdsList.addAll(tntmsmForEntity);
                }
            }

            if (!tntmsmIdsList.isEmpty()) {
                caseToMergingEntityTntmsmMap.put(c.Id, tntmsmIdsList);
            }
        }

        return caseToMergingEntityTntmsmMap;
    }

    private void validateLinkToEntity(List<Case> cases, Map<Id, List<Id>> caseToMergingEntityIdsMap) {
        for (Case c : cases) {
            if (c.breg_Entity__c == null) {
                addErrorMessage(c, null, ERROR_LINKED_ENTITY_REQUIRED);
                continue;
            }

            List<Id> entityIds = caseToMergingEntityIdsMap.get(c.Id);
            if (entityIds == null || entityIds.isEmpty()) {
                addErrorMessage(c, null, ERROR_MERGING_ACC_AFFILIATION_REQUIRED);
                continue;
            }

            if (entityIds.contains(null)) {
                addErrorMessage(c, null, ERROR_LINKED_ENTITY_TO_ACC_AFFILIATION_REQUIRED);
            }
        }
    }

    private void createMergerCertificate(List<Case> cases) {
        for (Case c : cases) {
            startWorkflowAsync(CREATE_CERTIFICATE_WORKFLOW, c.Id);
        }
    }

    private static void startWorkflowAsync(String workflowName, Id recordId) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Case Status Handler Merger, Create merger certificate');
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, null, 'Case Status Handler Merger, Create merger certificate', workflowLogId));
        }
    }

    private void checkIfMergerCertificateIsGenerated(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        List<breg_Document__c> mergerCertificates = [
            SELECT Id, breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :caseIds AND Name LIKE '%Merger Certificate%'
            LIMIT 9000
        ];

        Set<Id> casesWithCertificate = new Set<Id>();
        for (breg_Document__c doc : mergerCertificates) {
            casesWithCertificate.add(doc.breg_Case__c);
        }

        for (Case c : cases) {
            if (!casesWithCertificate.contains(c.Id)) {
                addErrorMessage(c, null, ERROR_MERGER_CERTIFICATE_NOT_GENERATED);
            }
        }
    }

    private void checkIfCaseHasAtLeastTwoMergingEntities(List<Case> cases, Map<Id, List<Id>> caseToMergingEntityIdsMap) {
        for (Case c : cases) {
            List<Id> mergingEntityIds = caseToMergingEntityIdsMap.get(c.Id);
            if (mergingEntityIds == null || mergingEntityIds.size() < 2) {
                addErrorMessage(c, null, ERROR_CASE_MUST_HAVE_AT_LEAST_TWO_MERGING_ENTITIES);
            }
        }
    }

    private void validateEffectiveDate(List<Case> cases) {
        for (Case c : cases) {
            if (c.breg_Effective_Date__c == null || c.breg_Effective_Date__c > Date.today()) {
                addErrorMessage(c, null, ERROR_EFFECTIVE_DATE);
                continue;
            }
        }
    }

    private void updateSurvivingEntity(List<Case> cases) {
        List<Account> entitiesToUpdate = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case c : cases) {
            if (c.breg_Organizing_Articles_Changes__c == 'Changes Attached') {
                if (
                    c.ParentId != null &&
                    (!c.Parent.breg_Form_Configuration__r.breg_Form_Name__c.contains('Amendment') ||
                    c.Parent.breg_Name_of_the_Entity__c == c.breg_Name_of_the_Entity__c)
                ) {
                    entitiesToUpdate.add(new Account(Id = c.breg_Entity__c, Name = c.breg_Name_of_the_Entity__c));
                    entityToCaseMap.put(c.breg_Entity__c, c);
                    accountUpdatedFieldsMap.put(c.breg_Entity__c, new Set<String>{ 'Name' });
                } else {
                    //do nothiing - handled in Amendment case
                }
            }
        }
        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private void updateMergingEntitiesStatus(List<Case> cases, Map<Id, List<Id>> caseToMergingEntityIdsMap) {
        List<Account> entitiesToUpdate = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Case> caseMap = new Map<Id, Case>(cases);
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, breg_Account_Affiliation__c> affiliationByCaseMap = new Map<Id, breg_Account_Affiliation__c>();
        for (Case c : cases) {
            List<Id> entityIds = caseToMergingEntityIdsMap.get(c.Id);
            for (Id entityId : entityIds) {
                entitiesToUpdate.add(new Account(Id = entityId, breg_Entity_Status__c = 'Merged (M)'));
                entityToCaseMap.put(entityId, c);
                accountUpdatedFieldsMap.put(entityId, new Set<String>{ 'breg_Entity_Status__c' });
            }
        }

        List<breg_Account_Affiliation__c> affiliationsToAssign = getAffiliationsToAssign(cases);

        for (breg_Account_Affiliation__c aff : affiliationsToAssign) {
            Case relatedCase = caseMap.get(aff.breg_Case__c);
            if (relatedCase != null) {
                affiliationByCaseMap.put(relatedCase.Id, aff);
            }
        }
        List<breg_Account_Affiliation__c> newAffiliationsToInsert = new List<breg_Account_Affiliation__c>();
        for (Id mergingAccountId : entityToCaseMap.keySet()) {
            Case relatedCase = entityToCaseMap.get(mergingAccountId);
            breg_Account_Affiliation__c aff = affiliationByCaseMap.get(relatedCase.Id);
            if (relatedCase != null && aff != null) {
                breg_Account_Affiliation__c newAff = aff.clone(false, false);
                newAff.Id = null;
                newAff.breg_Entity__c = mergingAccountId;
                newAff.breg_Start_Date__c = relatedCase.breg_Effective_Date__c;
                newAff.breg_Case__c = relatedCase.Id;
                newAffiliationsToInsert.add(newAff);
            }
        }

        if (!newAffiliationsToInsert.isEmpty()) {
            insert newAffiliationsToInsert;
        }

        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private void updateTntmsmForMergingEntity(List<Case> cases, Map<Id, List<breg_TN_TM_SM__c>> caseToMergingEntityTntmsmMap) {
        for (Case c : cases) {
            List<breg_TN_TM_SM__c> mergingEntityTntmsmList = caseToMergingEntityTntmsmMap.get(c.Id);
            List<breg_TN_TM_SM__c> tntmsmListToUpdate = new List<breg_TN_TM_SM__c>();

            for (breg_TN_TM_SM__c tntmsm : mergingEntityTntmsmList) {
                tntmsmListToUpdate.add(new breg_TN_TM_SM__c(Id = tntmsm.Id, breg_End_Date__c = c.breg_Effective_Date__c));
            }

            update tntmsmListToUpdate;
        }
    }

    private void createSurvivingEntityNewTNTMSM(List<Case> cases, Map<Id, List<breg_TN_TM_SM__c>> caseToMergingEntityTntmsmMap) {

        List<String> tntmsmTypes = new List<String>{ 'Trade Name', 'Trademark', 'Service Mark' };
        Map<Id, List<breg_TN_TM_SM__c>> caseToNewTntmsmMap = new Map<Id, List<breg_TN_TM_SM__c>>();
        List<breg_TN_TM_SM__c> allNewTntmsm = new List<breg_TN_TM_SM__c>();

        for (Case c : cases) {
            List<breg_TN_TM_SM__c> mergingEntityTnTmSmList = caseToMergingEntityTntmsmMap.get(c.Id);
            List<breg_TN_TM_SM__c> newTntmsmList = new List<breg_TN_TM_SM__c>();

            for (breg_TN_TM_SM__c tntmsm : mergingEntityTntmsmList) {
                breg_TN_TM_SM__c newTNTMSM = tntmsm.clone(false, false);
                newTNTMSM.breg_Account__c = c.breg_Entity__c;
                newTNTMSM.breg_Start_Date__c = c.breg_Effective_Date__c;
                newTNTMSM.breg_File__c = c.breg_Entity__r.breg_File__c;
                newTNTMSM.breg_File_Suffix__c = c.breg_Entity__r.breg_File_Suffix__c;

                newTntmsmList.add(newTNTMSM);
                allNewTntmsm.add(newTNTMSM);
            }

            caseToNewTntmsmMap.put(c.Id, newTntmsmList);
        }

        insert allNewTntmsm;
        createTransactionsForTNTMSMPR(cases, caseToNewTntmsmMap, tntmsmTypes);

    }

    private void createTransactionsForTNTMSMPR(List<Case> cases, Map<Id, List<breg_TN_TM_SM__c>> caseToNewTntmsmMap, List<String> tntmsmTypes) {
        Map<Id, Case> casesMap = new Map<Id, Case>();
        for (Case c : cases) {
            casesMap.put(c.Id, c);
        }
        Map<Id, List<Id>> caseToTntmsmMap = new Map<Id, List<Id>>();
        Map<Id, List<Id>> caseToPrMap = new Map<Id, List<Id>>();
        for (Case c : cases) {
            List<breg_TN_TM_SM__c> newTntmsmList = caseToNewTntmsmMap.get(c.Id);
            List<Id> tntmsmIds = new List<Id>();
            List<Id> prIds = new List<Id>();

            for (breg_TN_TM_SM__c tntmsm : newTntmsmList) {
                if (tntmsmTypes.contains(tntmsm.breg_Type__c)) {
                    tntmsmIds.add(tntmsm.Id);
                } else if (tntmsm.breg_Type__c == 'Publicity Rights Name') {
                    prIds.add(tntmsm.Id);
                }
            }

            if (!tntmsmIds.isEmpty()) {
                caseToTntmsmMap.put(c.Id, tntmsmIds);
            }
            if (!prIds.isEmpty()) {
                caseToPrMap.put(c.Id, prIds);
            }
        }

        List<breg_Transaction__c> tntrTransactions = BREGTransactionUtils.upsertTransactionRecordsForChilds(casesMap, caseToTntmsmMap, 'C', 'TNTR' );
        List<breg_Transaction__c> prtrTransactions = BREGTransactionUtils.upsertTransactionRecordsForChilds(casesMap, caseToPrMap, 'C', 'PRTR');

        List<breg_Transaction__c> allTransactions = new List<breg_Transaction__c>();
        allTransactions.addAll(tntrTransactions);
        allTransactions.addAll(prtrTransactions);
        upsert allTransactions;
    }

    private void upsertTransactionsForEntities(List<Case> cases, Map<Id, List<Id>> caseToMergingEntityIdsMap, String status) {
        List<breg_Transaction__c> all_transactions = new List<breg_Transaction__c>();
        Map<Id, Case> casesMap = new Map<Id, Case>();
        for (Case c : cases) {
            casesMap.put(c.Id, c);
        }

        Map<Id, Id> caseToMgncEntityMap = new Map<Id, Id>();
        Map<Id, Id> caseToMgEntityMap = new Map<Id, Id>();
        Map<Id, List<Id>> caseToEntityMap = new Map<Id, List<Id>>();
        Boolean hasMgncCases = false;
        for (Case c : cases) {
            if (c.breg_Organizing_Articles_Changes__c == 'Changes Attached') {
                caseToMgncEntityMap.put(c.id, c.Breg_Entity__c);
                hasMgncCases = true;
            } else {
                caseToMgEntityMap.put(c.id, c.Breg_Entity__c);
            }

            caseToEntityMap.put(c.Id, new List<Id>(caseToMergingEntityIdsMap.get(c.Id)));
        }
        List<breg_Transaction__c> mgncTransactions = new List<breg_Transaction__c>();
        List<breg_Transaction__c> mgTransactions = new List<breg_Transaction__c>();
        if(hasMgncCases) {
            mgncTransactions = BREGTransactionUtils.upsertTransactionRecords(casesMap, caseToMgncEntityMap, 'MGNC', status);
        }

        if(!hasMgncCases) {
            mgTransactions = BREGTransactionUtils.upsertTransactionRecords(casesMap, caseToMgEntityMap, 'MG', status);
        }
        List<breg_Transaction__c> mgbyTransactions = BREGTransactionUtils.upsertTransactionRecordsForChilds(casesMap, caseToEntityMap,  status, 'MGBY');
        all_transactions.addAll(mgncTransactions);
        all_transactions.addAll(mgTransactions);
        all_transactions.addAll(mgbyTransactions);
        upsert all_transactions;
    }

    private List<breg_Account_Affiliation__c> getAffiliationsToAssign(List<Case> cases) {
        List<Id> entityIds = new List<Id>();
        for (Case c : cases) {
            entityIds.add(c.breg_Entity__c);
        }
        List<breg_Account_Affiliation__c> affiliationsToAssign = [
            SELECT
                Id,
                Name,
                breg_Affiliation_Name__c,
                breg_Address__c,
                breg_Address_Street_2__c,
                breg_Address_State_Text__c,
                breg_Account__c,
                breg_Contact__c,
                breg_Case__c,
                breg_As_of_Date__c,
                breg_End_Date__c,
                breg_CRA_Address__c,
                breg_Entity_Location__c,
                breg_Entity_Location_Country__c,
                breg_Entity_Name__c,
                breg_Type__c,
                breg_Transaction__c,
                breg_To_Remove__c,
                breg_TN_TM_SM__c,
                breg_Title__c,
                breg_Title_Text__c,
                breg_Titles_Are_Vacant__c,
                breg_Suffix__c,
                breg_Status__c,
                breg_Start_Date__c,
                breg_Signed_By_Last_Name__c,
                breg_Signed_By_First_Name__c,
                breg_Signature__c,
                breg_Role__c,
                breg_Previous_Account_Affiliation__c,
                breg_Person_Sequence__c,
                breg_Person_Flag__c,
                breg_Pending_Transaction__c,
                breg_Office_Held__c,
                breg_Officer_Director_Titles__c,
                breg_Officer_Director_Titles_Formula__c,
                breg_Officer_Director_TitlesText_Formula__c,
                breg_Officer_Director_Other_Title__c,
                breg_Number_of_shares__c,
                breg_Middle_Name__c,
                breg_Last_Name__c,
                breg_First_Name__c,
                breg_File__c,
                breg_External_ID__c,
                breg_Entity__c,
                breg_Entity_Type__c,
                breg_Entity_Type_Description__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityIds AND breg_Role__c = 'Agent' AND breg_Status__c = 'A' AND breg_End_Date__c = NULL
            LIMIT 9000
        ];
        return affiliationsToAssign;
    }
}