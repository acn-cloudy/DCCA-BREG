public with sharing class BREGAnnualTriggerHandler {

    /**
     * Populates the breg_Unique_Key__c field on insert and update.
     * The value is a concatenation of breg_Account__c and breg_Filing_Year__c.
     * 
     * @param newList  List of new records being inserted or updated.
     */
    public static void populateUniqueKey(List<breg_Annual__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        for (breg_Annual__c record : newList) {
            if (record.breg_Account__c != null && record.breg_Filing_Year__c != null) {
                record.breg_Unique_Key__c = record.breg_Account__c + '-' + record.breg_Filing_Year__c;
            } else {
                // Clear unique key if any component is missing
                record.breg_Unique_Key__c = null;
            }
        }
    }
}