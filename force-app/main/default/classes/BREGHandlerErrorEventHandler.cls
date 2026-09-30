public without sharing class BREGHandlerErrorEventHandler {
    public static void handleEvents(List<BREG_Handler_Error__e> events) {
        List<Case> casesToUpdate = new List<Case>();
        for (BREG_Handler_Error__e event : events) {
            if (String.isBlank(event.Case_Id__c)) {
                continue;
            }
            String logJson = JSON.serialize(new Map<String, Object>{
                'caseId'       => event.Case_Id__c,
                'userId'       => event.User_Id__c,
                'errorMessage' => event.Error_Message__c,
                'stackTrace'   => event.Stack_Trace__c,
                'timestamp'    => event.Timestamp__c != null ? event.Timestamp__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : null
            });
            casesToUpdate.add(new Case(
                Id = (Id) event.Case_Id__c,
                breg_Handler_Log_Message__c = logJson
            ));
        }
        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, false);
        }
    }
}