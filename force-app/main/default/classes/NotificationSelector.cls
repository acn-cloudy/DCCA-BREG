public with sharing class NotificationSelector {
    public static List<Notification__c> getNotifications(String recordId) {
        return [Select Id, RecipientEmail__c, Name, Status__c,FailedReason__c, ScheduleForPrint__c, SaveRecordId__c, PrintStatus__c,
                License__c, DocGeneratorSettings__c, DocumentTemplateName__c, SendtoPrinter__c, TimeDelivered__c, ScheduledTime__c, 
                TimeSent__c from Notification__c where Id =: recordId];
    }
    public static List<Notification__c> getNotifications(List<String> notificationIds) {
        return [Select Id, RecipientEmail__c, Content__c, RecordId__c, License__c, ScheduleForPrint__c, PrintStatus__c,
            SaveRecordId__c, DocGeneratorSettings__c, DocumentTemplateName__c, SendtoPrinter__c from Notification__c where Id in: notificationIds];
    }
    public static List<Notification__c> getAuditNotificationsByLicenseIds(List<String> licenseIds) {
        return [Select Id, RecipientEmail__c, Content__c, RecordId__c, License__c, SaveRecordId__c, Scheduled__c, PrintStatus__c,
        ScheduleForPrint__c,DocGeneratorSettings__c, DocumentTemplateName__c, 
        SendtoPrinter__c from Notification__c where License__c in: licenseIds and 
        Status__c = 'Scheduled' and SendToPrinter__c = true ];
    }

}