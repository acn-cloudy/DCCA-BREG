public interface IEmailAlertTriggerService {
    EmailAlertTrigger__c getEmailAlertTrigger(String type, Id targetId, String relatedRecordId);
    EmailAlertTrigger__c deepCloneNoId(EmailAlertTrigger__c eat);
    void sendEmailAlert(EmailAlertTrigger__c[] alerts, fflib_SObjectUnitOfWork uow);
}