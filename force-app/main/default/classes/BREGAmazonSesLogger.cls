public with sharing class BREGAmazonSesLogger {

    public static Map<String, Integer> getNumOfRetriesByTaskId(Set<Id> taskIds) {

        List<breg_Email_Log__c> logs = [
            SELECT  breg_Task_Id__c,
                    breg_Status__c,
                    breg_Error_Message__c
            FROM    breg_Email_Log__c
            WHERE   breg_Task_Id__c IN :taskIds
        ];

        Map<String, Integer> response = new Map<String, Integer>();
        for (breg_Email_Log__c log : logs) {
            if (response.containsKey(log.breg_Task_Id__c)) {
                response.put(log.breg_Task_Id__c, response.get(log.breg_Task_Id__c) + 1);
            }
            else response.put(log.breg_Task_Id__c, 1);
        }
        return response;
    }

    public static List<breg_Email_Log__c> getLogRecords(List<LogWrapper> wrappers) {
        List<breg_Email_Log__c> logs = new List<breg_Email_Log__c>();
        for (LogWrapper wr : wrappers) {
            logs.add(wr.getLogRecord());
        }
        return logs;
    }

    public class LogWrapper {
        @TestVisible String taskId {get; set;}
        @TestVisible String status {get; set;}
        @TestVisible String errorMessage {get; set;}

        public LogWrapper() {}

        public LogWrapper(String taskId, String status, String errorMessage) {
            this.taskId = taskId;
            this.status = status;
            this.errorMessage = errorMessage;
        }

        @TestVisible private breg_Email_Log__c getLogRecord() {
            return new breg_Email_Log__c(
                breg_Task_Id__c = taskId,
                breg_Status__c = status,
                breg_Error_Message__c = errorMessage
            );
        }
    }
}