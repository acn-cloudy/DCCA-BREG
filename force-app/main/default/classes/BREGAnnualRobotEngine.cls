public with sharing class BREGAnnualRobotEngine {
    private static final Set<String> GP_ENTITY_TYPES = new Set<String>{ 'G5', 'G6' };

    public class EvaluationContext {
        public Set<Id> currentBatchCaseIds = new Set<Id>();
        public Set<Id> caseIdsWithPaidTransactions = new Set<Id>();
        public Set<Id> caseIdsWithPublicInitialFilingDocuments = new Set<Id>();
        public Set<Id> caseIdsWithConflictingTransactions = new Set<Id>();
        public Set<Id> entityIdsWithBouncedGp = new Set<Id>();
        public Map<Id, List<breg_Account_Affiliation__c>> caseAffiliationsByCaseId = new Map<Id, List<breg_Account_Affiliation__c>>();
        public Map<Id, List<breg_Account_Affiliation__c>> entityAffiliationsByEntityId = new Map<Id, List<breg_Account_Affiliation__c>>();
        public Map<Id, List<breg_Stock__c>> caseStocksByCaseId = new Map<Id, List<breg_Stock__c>>();
        public Map<Id, List<breg_Stock__c>> entityStocksByEntityId = new Map<Id, List<breg_Stock__c>>();
        public Map<Id, breg_Account_Affiliation__c> activeAgentByEntityId = new Map<Id, breg_Account_Affiliation__c>();
        public Map<Id, List<breg_Annual__c>> annualsByEntityId = new Map<Id, List<breg_Annual__c>>();
        public Map<Id, Integer> annualCaseCountByAnnualId = new Map<Id, Integer>();
        public Map<Id, List<Case>> relatedAnnualCasesByEntityId = new Map<Id, List<Case>>();
        public Map<Id, breg_WEB_WEB_FILING_INFO__c> webFilingInfoByCaseId = new Map<Id, breg_WEB_WEB_FILING_INFO__c>();
    }

    public static List<Case> queryCases(Set<Id> caseIds) {
        return BREGAnnualRobotWithoutSharing.queryCases(caseIds);
    }

    public static List<Case> expandWithEligibleEntityAnnualCases(List<Case> loadedCases) {
        return BREGAnnualRobotWithoutSharing.expandWithEligibleEntityAnnualCases(loadedCases);
    }

    public static EvaluationContext buildContext(List<Case> loadedCases) {
        EvaluationContext context = new EvaluationContext();
        Set<Id> caseIds = new Set<Id>();
        Set<Id> entityIds = new Set<Id>();
        Set<Id> annualIds = new Set<Id>();

        for (Case currentCase : loadedCases) {
            caseIds.add(currentCase.Id);
            context.currentBatchCaseIds.add(currentCase.Id);
            if (currentCase.breg_Entity__c != null) {
                entityIds.add(currentCase.breg_Entity__c);
            }
            if (currentCase.breg_Annual__c != null) {
                annualIds.add(currentCase.breg_Annual__c);
            }
        }

        addPaidTransactions(caseIds, context);
        addPublicInitialFilingDocuments(caseIds, context);
        addConflictingTransactions(loadedCases, entityIds, context);
        addBouncedGpEntities(entityIds, context);
        addCaseAffiliations(caseIds, context);
        addEntityAffiliations(entityIds, context);
        addCaseStocks(caseIds, context);
        addEntityStocks(entityIds, context);
        addActiveAgents(entityIds, context);
        addAnnuals(entityIds, context);
        addAnnualCaseCounts(annualIds, context);
        addRelatedAnnualCases(entityIds, context);
        addWebFilingInfos(caseIds, context);
        return context;
    }

    private static void addAnnualCaseCounts(Set<Id> annualIds, EvaluationContext context) {
        if (annualIds.isEmpty()) {
            return;
        }

        for (Case annualCase : BREGAnnualRobotWithoutSharing.getAnnualCaseCounts(annualIds)) {
            Id annualId = annualCase.breg_Annual__c;
            Integer currentCount = context.annualCaseCountByAnnualId.containsKey(annualId)
                ? context.annualCaseCountByAnnualId.get(annualId)
                : 0;
            context.annualCaseCountByAnnualId.put(annualId, currentCount + 1);
        }
    }

    private static void addPaidTransactions(Set<Id> caseIds, EvaluationContext context) {
        if (caseIds.isEmpty()) {
            return;
        }

        for (TransactionLine__c line : BREGAnnualRobotWithoutSharing.getPaidTransactionLines(caseIds)) {
            context.caseIdsWithPaidTransactions.add(line.breg_Case__c);
        }
    }

    private static void addPublicInitialFilingDocuments(Set<Id> caseIds, EvaluationContext context) {
        if (caseIds.isEmpty()) {
            return;
        }

        for (breg_Document__c documentRecord : BREGAnnualRobotWithoutSharing.getPublicCaseDocuments(caseIds)) {
            if (isInitialFilingDocument(documentRecord) && documentRecord.breg_Case__c != null) {
                context.caseIdsWithPublicInitialFilingDocuments.add(documentRecord.breg_Case__c);
            }
        }
    }

    private static void addConflictingTransactions(
        List<Case> annualCases,
        Set<Id> entityIds,
        EvaluationContext context
    ) {
        if (annualCases.isEmpty() || entityIds.isEmpty()) {
            return;
        }

        List<Case> conflictingTransactions = BREGAnnualRobotWithoutSharing.getConflictingTransactionCases(entityIds);
        for (Case annualCase : annualCases) {
            for (Case conflictingCase : conflictingTransactions) {
                if (
                    annualCase.breg_Entity__c == conflictingCase.breg_Entity__c &&
                    annualCase.Id != conflictingCase.Id &&
                    !(
                        annualCase.breg_Submission_Date__c != null &&
                        conflictingCase.breg_Submission_Date__c != null &&
                        conflictingCase.breg_Submission_Date__c > annualCase.breg_Submission_Date__c
                    )
                ) {
                    context.caseIdsWithConflictingTransactions.add(annualCase.Id);
                    break;
                }
            }
        }
    }

    private static void addBouncedGpEntities(Set<Id> entityIds, EvaluationContext context) {
        if (entityIds.isEmpty()) {
            return;
        }

        for (Account relatedGp : BREGAnnualRobotWithoutSharing.getBouncedGpAccounts(entityIds)) {
            context.entityIdsWithBouncedGp.add(relatedGp.ParentId);
        }
    }

    private static void addEntityAffiliations(Set<Id> entityIds, EvaluationContext context) {
        if (entityIds.isEmpty()) {
            return;
        }

        for (breg_Account_Affiliation__c affiliation : BREGAnnualRobotWithoutSharing.getEntityAffiliations(entityIds)) {
            addAffiliation(context.entityAffiliationsByEntityId, affiliation.breg_Entity__c, affiliation);
        }
    }

    private static void addCaseAffiliations(Set<Id> caseIds, EvaluationContext context) {
        for (breg_Account_Affiliation__c affiliation : BREGAnnualRobotWithoutSharing.getCaseAffiliations(caseIds)) {
            addAffiliation(context.caseAffiliationsByCaseId, affiliation.breg_Case__c, affiliation);
        }
    }

    private static void addCaseStocks(Set<Id> caseIds, EvaluationContext context) {
        for (breg_Stock__c stock : BREGAnnualRobotWithoutSharing.getCaseStocks(caseIds)) {
            addStock(context.caseStocksByCaseId, stock.breg_Case__c, stock);
        }
    }

    private static void addEntityStocks(Set<Id> entityIds, EvaluationContext context) {
        for (breg_Stock__c stock : BREGAnnualRobotWithoutSharing.getEntityStocks(entityIds)) {
            addStock(context.entityStocksByEntityId, stock.breg_Account__c, stock);
        }
    }

    private static void addActiveAgents(Set<Id> entityIds, EvaluationContext context) {
        if (entityIds.isEmpty()) {
            return;
        }

        for (breg_Account_Affiliation__c affiliation : BREGAnnualRobotWithoutSharing.getActiveAgents(entityIds)) {
            if (!context.activeAgentByEntityId.containsKey(affiliation.breg_Entity__c)) {
                context.activeAgentByEntityId.put(affiliation.breg_Entity__c, affiliation);
            }
        }
    }

    private static void addAnnuals(Set<Id> entityIds, EvaluationContext context) {
        if (entityIds.isEmpty()) {
            return;
        }

        for (breg_Annual__c annualRecord : BREGAnnualRobotWithoutSharing.getAnnuals(entityIds)) {
            addAnnualRecord(context.annualsByEntityId, annualRecord.breg_Account__c, annualRecord);
        }
    }

    private static void addRelatedAnnualCases(Set<Id> entityIds, EvaluationContext context) {
        if (entityIds.isEmpty()) {
            return;
        }

        for (Case relatedAnnualCase : BREGAnnualRobotWithoutSharing.getRelatedAnnualCases(entityIds)) {
            if (!context.relatedAnnualCasesByEntityId.containsKey(relatedAnnualCase.breg_Entity__c)) {
                context.relatedAnnualCasesByEntityId.put(relatedAnnualCase.breg_Entity__c, new List<Case>());
            }
            context.relatedAnnualCasesByEntityId.get(relatedAnnualCase.breg_Entity__c).add(relatedAnnualCase);
        }
    }

    private static void addWebFilingInfos(Set<Id> caseIds, EvaluationContext context) {
        if (caseIds.isEmpty()) {
            return;
        }

        for (breg_WEB_WEB_FILING_INFO__c filingInfo : BREGAnnualRobotWithoutSharing.getWebFilingInfos(caseIds)) {
            Id caseId = filingInfo.breg_WEB_Case__c;
            if (caseId != null) {
                context.webFilingInfoByCaseId.put(caseId, filingInfo);
            }
        }
    }

    private static void addAffiliation(
        Map<Id, List<breg_Account_Affiliation__c>> affiliationsByEntityId,
        Id entityId,
        breg_Account_Affiliation__c affiliation
    ) {
        if (entityId == null || affiliation == null) {
            return;
        }
        if (!affiliationsByEntityId.containsKey(entityId)) {
            affiliationsByEntityId.put(entityId, new List<breg_Account_Affiliation__c>());
        }
        affiliationsByEntityId.get(entityId).add(affiliation);
    }

    private static void addAnnualRecord(Map<Id, List<breg_Annual__c>> annualsByEntityId, Id entityId, breg_Annual__c annualRecord) {
        if (entityId == null || annualRecord == null) {
            return;
        }
        if (!annualsByEntityId.containsKey(entityId)) {
            annualsByEntityId.put(entityId, new List<breg_Annual__c>());
        }
        annualsByEntityId.get(entityId).add(annualRecord);
    }

    private static void addStock(Map<Id, List<breg_Stock__c>> stocksByParentId, Id parentId, breg_Stock__c stock) {
        if (parentId == null || stock == null) {
            return;
        }
        if (!stocksByParentId.containsKey(parentId)) {
            stocksByParentId.put(parentId, new List<breg_Stock__c>());
        }
        stocksByParentId.get(parentId).add(stock);
    }

    private static Boolean isInitialFilingDocument(breg_Document__c documentRecord) {
        if (documentRecord == null) {
            return false;
        }

        if (documentRecord.breg_Is_Initial_Filing__c == true) {
            return true;
        }

        if (String.isBlank(documentRecord.Name)) {
            return false;
        }

        return documentRecord.Name.contains('Initial Filing') ||
            documentRecord.Name.contains('Resubmittal Filing') ||
            documentRecord.Name.contains('_Document.pdf') ||
            documentRecord.Name.contains('_NA.pdf') ||
            documentRecord.Name.contains('_.pdf');
    }
}