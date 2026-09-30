public without sharing class BREGCaseControllerWithoutSharing {
    private static final String EXPEDITED_SPEED = 'Expedited';
    @AuraEnabled
    public static void updateCaseSubscriptionCheckbox(Id caseId, Boolean subscriptionCheckbox) {
        if (caseId == null || subscriptionCheckbox == null) {
            throw new AuraHandledException('Input cannot be null');
        }
        try {
            Case c = new Case(Id = caseId, breg_Subscribe_Owner_Free_Email_Alerts__c = subscriptionCheckbox);

            update c;
        } catch (Exception e) {
            System.debug('Error updating case: ' + e.getMessage());
            throw new AuraHandledException('Unable to update case record: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void updateCasesProcessingSpeed(List<Id> caseIds){
        List<Case> casesToUpdate = [SELECT Id FROM Case WHERE Id IN :caseIds];
        for(Case c : casesToUpdate){
            c.breg_Processing_Speed__c = EXPEDITED_SPEED;
        }
        try {
            update casesToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

     @AuraEnabled
    public static void updateCaseContact(Id caseId, Id contactId){
        if (caseId == null || contactId == null) {
            throw new AuraHandledException('Case ID and Contact ID cannot be null');
        }
        try {
            Case c = new Case(Id = caseId, ContactId = contactId);
            update c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getDocumentFromCase(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID cannot be null');
        }

        try {
            Case record = [
                SELECT Id, breg_Document__c, breg_Document__r.breg_Docusign_Document_Id__c, breg_Document_Type__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            if (record.breg_Document__c != null && record.breg_Document__r.breg_Docusign_Document_Id__c != null) {
                return record.breg_Document__r.breg_Docusign_Document_Id__c;
            } else
                return null;
        } catch (Exception e) {
            System.debug('Error retrieving case: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve case record: ' + e.getMessage());
        }
    }
}