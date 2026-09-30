public with sharing class BREGBackfillCaseLabelBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer processedCount = 0;
    public Integer updatedCount = 0;
    public Integer errorCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    breg_Entity_Jurisdiction__c,
                    breg_Entity_Jurisdiction_Label__c,
                    breg_Formation_State__c,
                    breg_Formation_State_Label__c,
                    breg_New_Entity_Jurisdiction__c,
                    breg_New_Entity_Jurisdiction_Label__c,
                    breg_New_Formation_State__c,
                    breg_New_Formation_State_Label__c
                FROM Case
                WHERE
                    (breg_Entity_Jurisdiction__c != NULL
                    OR breg_Formation_State__c != NULL
                    OR breg_New_Entity_Jurisdiction__c != NULL
                    OR breg_New_Formation_State__c != NULL)
                    AND (breg_Entity_Jurisdiction_Label__c = NULL
                    OR breg_Formation_State_Label__c = NULL
                    OR breg_New_Entity_Jurisdiction_Label__c = NULL
                    OR breg_New_Formation_State_Label__c = NULL)
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        Map<String, String> jurisdictionLabelMap = BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode');
        Set<String> allJurisdictionCodes = BREGUtils.extractFieldValuesAsSet(scope, 'breg_Entity_Jurisdiction__c');
        allJurisdictionCodes.addAll(BREGUtils.extractFieldValuesAsSet(scope, 'breg_New_Entity_Jurisdiction__c'));
        Map<String, String> dependentStateLabelMap = BREGUtils.getStateLabelMapByCountrySet(allJurisdictionCodes);

        List<Case> toUpdate = new List<Case>();

        for (Case c : scope) {
            processedCount++;

            Boolean changed = false;
            Case cUpdate = new Case(Id = c.Id);

            if (String.isBlank(c.breg_Entity_Jurisdiction_Label__c) && String.isNotBlank(c.breg_Entity_Jurisdiction__c)) {
                cUpdate.breg_Entity_Jurisdiction_Label__c = jurisdictionLabelMap.containsKey(c.breg_Entity_Jurisdiction__c)
                    ? jurisdictionLabelMap.get(c.breg_Entity_Jurisdiction__c)
                    : c.breg_Entity_Jurisdiction__c;
                changed = true;
            }

            if (String.isBlank(c.breg_Formation_State_Label__c) && String.isNotBlank(c.breg_Formation_State__c)) {
                String stateLookupKey = c.breg_Entity_Jurisdiction__c + '.' + c.breg_Formation_State__c;
                cUpdate.breg_Formation_State_Label__c = dependentStateLabelMap.containsKey(stateLookupKey)
                    ? dependentStateLabelMap.get(stateLookupKey)
                    : c.breg_Formation_State__c;
                changed = true;
            }

            if (String.isBlank(c.breg_New_Entity_Jurisdiction_Label__c) && String.isNotBlank(c.breg_New_Entity_Jurisdiction__c)) {
                cUpdate.breg_New_Entity_Jurisdiction_Label__c = jurisdictionLabelMap.containsKey(c.breg_New_Entity_Jurisdiction__c)
                    ? jurisdictionLabelMap.get(c.breg_New_Entity_Jurisdiction__c)
                    : c.breg_New_Entity_Jurisdiction__c;
                changed = true;
            }

            if (String.isBlank(c.breg_New_Formation_State_Label__c) && String.isNotBlank(c.breg_New_Formation_State__c)) {
                String stateLookupKey = c.breg_New_Entity_Jurisdiction__c + '.' + c.breg_New_Formation_State__c;
                cUpdate.breg_New_Formation_State_Label__c = dependentStateLabelMap.containsKey(stateLookupKey)
                    ? dependentStateLabelMap.get(stateLookupKey)
                    : c.breg_New_Formation_State__c;
                changed = true;
            }

            if (changed) {
                toUpdate.add(cUpdate);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(toUpdate, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    updatedCount++;
                } else {
                    errorCount++;
                    for (Database.Error e : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Case update error: ' + e.getStatusCode() + ' - ' + e.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'BREGBackfillCaseLabelBatch completed. Processed=' + processedCount + ', Updated=' + updatedCount + ', Errors=' + errorCount
        );
    }
}