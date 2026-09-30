public with sharing class BREGBackfillAccountFormLabelBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer processedCount = 0;
    public Integer updatedCount = 0;
    public Integer errorCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, breg_Formation_Country__c, breg_Formation_Country_Label__c, breg_Formation_State__c, breg_Formation_State_Label__c
                FROM Account
                WHERE
                    (breg_Formation_Country__c != NULL
                    AND (breg_Formation_Country_Label__c = NULL
                    OR breg_Formation_Country_Label__c = ''))
                    OR (breg_Formation_State__c != NULL
                    AND (breg_Formation_State_Label__c = NULL
                    OR breg_Formation_State_Label__c = ''))
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Map<String, String> formationCountryLabelMap = BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode');
        Set<String> countryCodesFromScope = BREGUtils.extractFieldValuesAsSet(scope, 'breg_Formation_Country__c');
        Map<String, String> dependentStateLabelMap = BREGUtils.getStateLabelMapByCountrySet(countryCodesFromScope);

        List<Account> toUpdate = new List<Account>();

        for (Account accountRecord : scope) {
            processedCount++;

            Account accountToUpdate = new Account(Id = accountRecord.Id);
            Boolean changed = false;

            if (String.isBlank(accountRecord.breg_Formation_Country_Label__c) && String.isNotBlank(accountRecord.breg_Formation_Country__c)) {
                String countryLabel = formationCountryLabelMap.containsKey(accountRecord.breg_Formation_Country__c)
                    ? formationCountryLabelMap.get(accountRecord.breg_Formation_Country__c)
                    : accountRecord.breg_Formation_Country__c;
                accountToUpdate.breg_Formation_Country_Label__c = countryLabel;
                changed = true;
            }

            if (String.isBlank(accountRecord.breg_Formation_State_Label__c) && String.isNotBlank(accountRecord.breg_Formation_State__c)) {
                String stateLookupKey = accountRecord.breg_Formation_Country__c + '.' + accountRecord.breg_Formation_State__c;
                String stateLabel = dependentStateLabelMap.containsKey(stateLookupKey)
                    ? dependentStateLabelMap.get(stateLookupKey)
                    : accountRecord.breg_Formation_State__c;
                accountToUpdate.breg_Formation_State_Label__c = stateLabel;
                changed = true;
            }

            if (changed) {
                toUpdate.add(accountToUpdate);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(toUpdate, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    updatedCount++;
                } else {
                    errorCount++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Account update error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'BREGBackfillAccountFormLabelBatch completed. Processed=' + processedCount + ', Updated=' + updatedCount + ', Errors=' + errorCount
        );
    }
}