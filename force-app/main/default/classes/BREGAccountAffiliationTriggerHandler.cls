public with sharing class BREGAccountAffiliationTriggerHandler extends BREGBaseTriggerHandler {
    public override void beforeInsert() {
        // Validation is moved to afterInsert,
        // beforeInsert is too early for cross-record validation.
    }

    public override void afterInsert() {
        BREGAccountAffiliationValidator.validateCaseRelations((List<breg_Account_Affiliation__c>) this.newList);
    }

    public override void beforeUpdate() {
        List<breg_Account_Affiliation__c> newAffiliations = (List<breg_Account_Affiliation__c>) this.newList;
        Map<Id, breg_Account_Affiliation__c> oldMapAsMap = (Map<Id, breg_Account_Affiliation__c>) this.oldMap;
        Map<Id, breg_Account_Affiliation__c> newMapAsMap = (Map<Id, breg_Account_Affiliation__c>) this.newMap;

        setEndDate((List<breg_Account_Affiliation__c>) this.newList, oldMapAsMap);
    }

    public override void afterUpdate() {
        List<breg_Account_Affiliation__c> newAffiliations = (List<breg_Account_Affiliation__c>) this.newList;
        Map<Id, breg_Account_Affiliation__c> oldMapAsMap = (Map<Id, breg_Account_Affiliation__c>) this.oldMap;
        Map<Id, breg_Account_Affiliation__c> newMapAsMap = (Map<Id, breg_Account_Affiliation__c>) this.newMap;

        updateRelateTransAdresses((List<breg_Account_Affiliation__c>) this.newList, oldMapAsMap, newMapAsMap);
        updateAccountOnStatusChange((List<breg_Account_Affiliation__c>) this.newList, oldMapAsMap);
    }

    private static void updateRelateTransAdresses(
        List<breg_Account_Affiliation__c> newList,
        Map<Id, breg_Account_Affiliation__c> oldMap,
        Map<Id, breg_Account_Affiliation__c> newMap
    ) {
        Set<Id> endedAffiliationIds = new Set<Id>();
        for (breg_Account_Affiliation__c affiliation : newList) {
            breg_Account_Affiliation__c oldAffiliation = oldMap.get(affiliation.Id);
            if (oldAffiliation.breg_End_Date__c == null && affiliation.breg_End_Date__c != null) {
                endedAffiliationIds.add(affiliation.Id);
            }
        }
        List<breg_Transaction_Address__c> relatedTransAdresses = [
            SELECT Id, breg_End_Date__c, breg_Account_Affiliation__c
            FROM breg_Transaction_Address__c
            WHERE breg_Account_Affiliation__c IN :endedAffiliationIds AND breg_End_Date__c = NULL
        ];
        List<breg_Transaction_Address__c> transAddressesToUpdate = new List<breg_Transaction_Address__c>();
        for (breg_Transaction_Address__c transAddress : relatedTransAdresses) {
            transAddress.breg_End_Date__c = newMap.get(transAddress.breg_Account_Affiliation__c).breg_End_Date__c;
            transAddressesToUpdate.add(transAddress);
        }
        if (!transAddressesToUpdate.isEmpty()) {
            update transAddressesToUpdate;
        }
    }

    private static void setEndDate(List<breg_Account_Affiliation__c> newList, Map<Id, breg_Account_Affiliation__c> oldMap) {
        Map<Id, breg_Account_Affiliation__c> affiliationsToUpdateById = new Map<Id, breg_Account_Affiliation__c>();

        for (breg_Account_Affiliation__c affiliation : newList) {
            breg_Account_Affiliation__c oldAffiliation = oldMap.get(affiliation.Id);
            breg_Account_Affiliation__c previousAff = null;
            String roleToSet = null;
            // Case 1: Entity lookup was set on a "New" role affiliation
            if (oldAffiliation.breg_Entity__c == null && affiliation.breg_Entity__c != null && affiliation.breg_Role__c.contains('New')) {
                String baseRole = affiliation.breg_Role__c.replace('New ', '').trim();
                previousAff = findPreviousAffiliation('breg_Entity__c', affiliation.breg_Entity__c, baseRole, affiliation.Id);
                roleToSet = baseRole;
            }
            // Case 2: TNTMSM lookup was set

            else if (oldAffiliation.breg_TN_TM_SM__c == null && affiliation.breg_TN_TM_SM__c != null) {
                String baseRole = affiliation.breg_Role__c.replace('New ', '').trim();
                previousAff = findPreviousAffiliation('breg_TN_TM_SM__c', affiliation.breg_TN_TM_SM__c, baseRole, affiliation.Id);
                roleToSet = baseRole;
            }

            // Update previous affiliation if found
            if (previousAff != null) {
                previousAff.breg_End_Date__c = affiliation.breg_Start_Date__c;
                previousAff.breg_Status__c = 'I';
                previousAff.breg_Bypass_Validation_Token__c = Datetime.now();
                affiliationsToUpdateById.put(previousAff.Id, previousAff);
            }
        }

        if (!affiliationsToUpdateById.isEmpty()) {
            update affiliationsToUpdateById.values();
        }
    }

    private static void updateAccountOnStatusChange(List<breg_Account_Affiliation__c> newList, Map<Id, breg_Account_Affiliation__c> oldMap) {
        Set<Id> accountIds = new Set<Id>();
        for (breg_Account_Affiliation__c affiliation : newList) {
            breg_Account_Affiliation__c oldAffiliation = oldMap.get(affiliation.Id);
            if (oldAffiliation.breg_Status__c != affiliation.breg_Status__c && affiliation.breg_Entity__c != null && affiliation.breg_Role__c == 'Agent') {
                accountIds.add(affiliation.breg_Entity__c);
            }
        }

        if (!accountIds.isEmpty()) {
            List<Account> accountsToUpdate = new List<Account>();
            for (Account acc : [SELECT Id FROM Account WHERE Id IN :accountIds]) {
                accountsToUpdate.add(acc);
            }
            //call account trigger to recalculate goodstanding
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        }
    }

    /**
     * Finds previous affiliation by field and role using dynamic query
     * @param fieldName - Field to search on ('breg_Entity__c' or 'breg_TN_TM_SM__c')
     * @param fieldValue - Value to search for in the field
     * @param role - Role to search for
     * @param currentAffiliationId - Current affiliation ID to exclude
     * @return breg_Account_Affiliation__c - Previous affiliation record or null
     */
    private static breg_Account_Affiliation__c findPreviousAffiliation(String fieldName, Id fieldValue, String role, Id currentAffiliationId) {
        String query =
            'SELECT Id, breg_End_Date__c ' +
            'FROM breg_Account_Affiliation__c ' +
            'WHERE ' +
            fieldName +
            ' = :fieldValue ' +
            'AND breg_Role__c = :role ' +
            'AND breg_End_Date__c = NULL ' +
            'AND breg_Status__c != \'I\' ' +
            'AND Id != :currentAffiliationId ' +
            'ORDER BY CreatedDate DESC ' +
            'LIMIT 1';

        List<breg_Account_Affiliation__c> results = Database.query(query);
        return results.isEmpty() ? null : results[0];
    }
}