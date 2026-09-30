trigger PVLErrorHandlerTrigger on PVLErrorHandler__e (after insert) {
    List<PVLErrorHandler__e> processes = Trigger.new;
    List<Application_Log__c> logs = new List<Application_Log__c>();
    for(PVLErrorHandler__e process: processes) {
        Application_Log__c log = new Application_Log__c();
        log.Debug_Level__c = process.Debug_Level__c;
        log.Type__c = process.Type__c;
        log.Reference_Id__c = process.Reference_Id__c;
        log.Message__c = process.Message__c;
        log.Stack_Trace__c = process.Stack_Trace__c;
        log.Status__c = 'New';
        logs.add(log);
    }
    insert logs;

}