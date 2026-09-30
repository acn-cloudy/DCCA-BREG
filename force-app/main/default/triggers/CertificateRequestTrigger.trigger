trigger CertificateRequestTrigger on CertificateRequest__c (before insert, after insert, before update, after update, before delete, after delete) {
    TriggerFactory.createAndExecuteHandler(CertificateRequest__c.SObjectType);

}