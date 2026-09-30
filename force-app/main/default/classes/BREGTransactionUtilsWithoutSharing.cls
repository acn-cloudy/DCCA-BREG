public without sharing class BREGTransactionUtilsWithoutSharing {
    public static List<breg_Transaction__c> getExistingTransactions(
        Set<Id> caseIds,
        Set<Id> relatedRecordIds,
        Set<String> transactionCodesToSearch
    ) {
        return [
            SELECT Id, breg_Case__c, breg_Account__c, breg_TN_TM_SM__c, breg_Case__r.breg_Name_of_the_Entity__c
            FROM breg_Transaction__c
            WHERE
                breg_Case__c IN :caseIds
                AND (
                    breg_Account__c IN :relatedRecordIds
                    OR breg_TN_TM_SM__c IN :relatedRecordIds
                    OR (breg_Account__c = NULL AND breg_TN_TM_SM__c = NULL)
                )
                AND breg_Transaction_Code__c IN :transactionCodesToSearch
            ORDER BY CreatedDate DESC
        ];
    }
}