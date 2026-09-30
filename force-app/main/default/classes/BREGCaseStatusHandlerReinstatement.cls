public with sharing class BREGCaseStatusHandlerReinstatement extends BREGCaseStatusHandlerBase {
    private static final String REINSTATEMENT_TRANS_CODE = 'RE';
    private static final List<String> DELINQUENT_STATUSES = new List<String>{ 'Annual report 1 yr delinquent (1)', 'Annual report 2 yr delinquent (2)' };
    private static final STRING TWO_YEARS_DELINQUENT_STATUS = 'Annual report 2 yr delinquent (2)';
    private static final List<String> DOMESTIC_ENTITY_TYPES = new List<String>{
        'A1',
        'A2',
        'C1',
        'C2',
        'D9',
        'G5',
        'C5',
        'Q5',
        'K5',
        'L5',
        'D2',
        'D1',
        'P1',
        'S1'
    };
    private static final string DELINQUENT_STATUS_FOR_REINSTATEMENT_ERROR = 'Related Entity should be in one of Delinquent statuses for reinstatement';
    private static final string TWO_YEARS_DELINQUENT_STATUS_FOR_FOREIGN_ERROR = 'Only Domestic related Entity can be reinstated after 2 years of delinquency';
    private static final string REINSTATEMENT_NOT_ALLOWED_FOR_ENTITY_STATUS_ERROR = 'Reinstatement is not allowed for related Entity with status: ';
    private static final List<string> REINSTATEMENT_ALLOWED_STATUSES = new List<string>{ 
        'Adm. Terminated (V)', 
        'Inv. Revoked (R)', 
        'Inv. Cancelled (X)', 
        'Inv. Dissolved (7)'
    }; 

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            super.handleStatusChange(casesForCheck, newStatus, true, false);
            performValidation(casesForCheck, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Approved' {
                validateEntityStatusForReinstatement(cases);
            }
            when 'Completed' {
                validateIsAllowedGenerateReinstatemCert(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                createTransactionsForRelatedEntities(cases, 'R');
            }
            when 'Approved' {
                createTransactionsForEntityChildAccounts(cases, 'A');
                //activateRelatedEntity(cases); //now it is action in docusign workflow for X-4 form
            }
            when 'Completed' {
                reassigneRelatedAnnuals(cases);
                updateRelatedEntity(cases);
            }
            when 'Rejected' {
                updateChildCases(cases, newStatus);
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateEntityStatusForReinstatement(List<Case> cases) {
        Map<Id, Account> relatedEntitiesMap = getRelatedEntittiesMap(cases);
        for (Case c : cases) {
            Account relatedEntity = relatedEntitiesMap.get(c.breg_Entity__c);
            if (relatedEntity == null || !REINSTATEMENT_ALLOWED_STATUSES.contains(relatedEntity.breg_Entity_Status__c)) {
                addErrorMessage(
                    c, 
                    'breg_Entity__c', 
                    REINSTATEMENT_NOT_ALLOWED_FOR_ENTITY_STATUS_ERROR + 
                        (relatedEntity != null ? relatedEntity.breg_Entity_Status__c : 'Unknown'));
            }
        }
    }

    private void validateIsAllowedGenerateReinstatemCert(List<Case> cases) {
        for (Case c : cases) {
            if (c.breg_Is_Allowed_Generate_Reinstatem_Cert__c == false) {
                addErrorMessage(
                    c,
                    'breg_Is_Allowed_Generate_Reinstatem_Cert__c',
                    'Is Allowed Generate Reinstatement Cert: checkbox should be true for case to be completed'
                );
            }
        }
    }

    private void reassigneRelatedAnnuals(List<Case> cases) {
        List<String> closedStatuses = new List<String>{ 'Approved', 'Rejected', 'Completed', 'Expired', 'Withdrawn', 'Bounce Check' };

        Set<Id> caseIds = new Set<Id>();
        Map<Id, Case> parentCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            parentCaseMap.put(c.Id, c);
        }

        // Query all active annual cases with ParentId in the passed case list
        List<Case> allAnnuals = [
            SELECT Id, Status, ParentId, breg_Form_Code__c
            FROM Case
            WHERE ParentId IN :caseIds AND Status NOT IN :closedStatuses AND breg_Form_Code__c LIKE 'ANN-%'
        ];

        // Group annuals cases by parent case ID
        Map<Id, List<Case>> annualsByParentId = new Map<Id, List<Case>>();
        for (Case annual : allAnnuals) {
            if (!annualsByParentId.containsKey(annual.ParentId)) {
                annualsByParentId.put(annual.ParentId, new List<Case>());
            }
            annualsByParentId.get(annual.ParentId).add(annual);
        }

        Group docIGroup = [SELECT Id FROM Group WHERE DeveloperName = 'DOC_I' LIMIT 1];
        Group docRGroup = [SELECT Id FROM Group WHERE DeveloperName = 'DOC_R' LIMIT 1];

        List<Case> annualCasesToAssign = new List<Case>();
        List<Case> parentCasesToUpdate = new List<Case>();

        for (Id parentId : caseIds) {
            List<Case> relatedAnnuals = annualsByParentId.get(parentId);

            if (relatedAnnuals == null || relatedAnnuals.isEmpty()) {
                Case parent = parentCaseMap.get(parentId);
                if (parent != null) {
                    // parent.breg_Is_Allowed_Generate_Reinstatem_Cert__c = true;
                    parent.OwnerId = docRGroup.Id;
                    parentCasesToUpdate.add(parent);
                }
            } else {
                for (Case annual : relatedAnnuals) {
                    annual.OwnerId = docIGroup.Id;
                    annualCasesToAssign.add(annual);
                }
            }
        }

        if (!annualCasesToAssign.isEmpty()) {
            update annualCasesToAssign;
        }
        if (!parentCasesToUpdate.isEmpty()) {
            update parentCasesToUpdate;
        }
    }

    private void updateChildCases(List<Case> cases, String newStatus) {
        List<Id> parentCaseIds = new List<Id>();
        for (Case c : cases) {
            parentCaseIds.add(c.Id);
        }
        List<Case> childCases = [SELECT Id, Status, ParentId FROM Case WHERE ParentId IN :parentCaseIds AND Status = 'Pending Submission'];
        for (Case child : childCases) {
            child.Status = newStatus;
        }
        update childCases;
    }

    private void updateRelatedEntity(List<Case> cases) {
        Map<Id, Account> relatedEntitiesMap = getRelatedEntittiesMap(cases);
        List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Case> accRelatedCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            Account currentEntity = relatedEntitiesMap.get(c.breg_Entity__c);
            if (currentEntity.breg_Entity_Status__c != 'Active (A)') {
                currentEntity.breg_Entity_Status__c = 'Active (A)';
                currentEntity.breg_Good_Standing__c = true;
                accountsToUpdate.add(currentEntity);
            }

            String entityType = currentEntity.breg_Entity_Type__c;
            if (entityType == 'G5' || entityType == 'G6' || entityType == 'General Partnership') {
                accRelatedCaseMap.put(c.breg_Entity__c, c);
            }
        }

        List<Account> childAccounts = [
            SELECT Id, ParentId, breg_Entity_Type__c, breg_Entity_Status__c
            FROM Account
            WHERE ParentId IN :accRelatedCaseMap.keySet()
        ];

        for (Account acc : childAccounts) {
            if (acc.breg_Entity_Status__c != 'Active (A)') {
                acc.breg_Entity_Status__c = 'Active (A)';
                acc.breg_Good_Standing__c = true;
                accountsToUpdate.add(acc);
            }
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
       
        
    }

    private void createTransactionsForRelatedEntities(List<Case> cases, String status) {
        Map<Id, Account> relatedEntitiesMap = getRelatedEntittiesMap(cases);
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        List<Case> casesWithoutEntity = new List<Case>();
        for (Case c : cases) {
            if (c.breg_Entity__c == null) {
                casesWithoutEntity.add(c);
            } else {
                entityCaseMap.put(c.breg_Entity__c, c);
            }
            
        }
        createTransactionsForRelatedAccounts(relatedEntitiesMap.values(), REINSTATEMENT_TRANS_CODE, entityCaseMap, false, status, casesWithoutEntity);
    }

    private void createTransactionsForEntityChildAccounts(List<Case> cases, String status) {
        Map<Id, Account> relatedEntitiesMap = getRelatedEntittiesMap(cases);
        Map<Id, Case> accRelatedCaseMap = new Map<Id, Case>();
        List<Case> casesWithoutEntity = new List<Case>();
        for (Case c : cases) {
            if (c.breg_Entity__c == null) {
                continue;
            } else {
                Account currentEntity = relatedEntitiesMap.get(c.breg_Entity__c);

                String entityType = currentEntity.breg_Entity_Type__c;
                if (entityType == 'K5' || entityType == 'K6' || entityType == 'Limited Liability Partnership') {
                    accRelatedCaseMap.put(c.breg_Entity__c, c);
                }
            }
        }

        List<Account> childAccounts = [
            SELECT Id, ParentId, breg_Entity_Type__c, breg_Entity_Status__c
            FROM Account
            WHERE ParentId IN :accRelatedCaseMap.keySet()
        ];
        createTransactionsForRelatedAccounts(childAccounts, REINSTATEMENT_TRANS_CODE, accRelatedCaseMap, true, status, casesWithoutEntity);
    }

    private void createTransactionsForRelatedAccounts(
        List<Account> accountsToUpdate,
        String transactionCode,
        Map<Id, Case> accRelatedCaseMap,
        boolean isParentCase,
        String status,
        List<Case> casesWithoutEntity
    ) {
        List<breg_Transaction__c> transactionsToInsert = new List<breg_Transaction__c>();
        if (accountsToUpdate.size() > 0) {
            for (Account acc : accountsToUpdate) {
                Case relatedCase = isParentCase ? accRelatedCaseMap.get(acc.ParentId) : accRelatedCaseMap.get(acc.Id);
                breg_Transaction__c newTransaction = BREGTransactionUtils.buildBaseTransactionForRecord(relatedCase, acc.Id, transactionCode, status);
                transactionsToInsert.add(newTransaction);
            }
        }
        if (casesWithoutEntity.size() > 0) {
            for (Case c : casesWithoutEntity) {
                breg_Transaction__c newTransaction = BREGTransactionUtils.buildBaseTransactionForRecord(c, null, transactionCode, status);
                transactionsToInsert.add(newTransaction);
            }
        }
        insert transactionsToInsert;
    }

    private Map<Id, Account> getRelatedEntittiesMap(List<Case> cases) {
        List<Id> entitiyIds = new List<Id>();
        for (Case c : cases) {
            entitiyIds.add(c.breg_Entity__c);
        }
        return new Map<Id, Account>([SELECT Id, ParentId, breg_Entity_Type__c, breg_Entity_Status__c FROM Account WHERE Id IN :entitiyIds]);
    }
}