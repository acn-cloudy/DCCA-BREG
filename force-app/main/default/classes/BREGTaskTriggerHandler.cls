public with sharing class BREGTaskTriggerHandler extends BREGBaseTriggerHandler {
    static final String SUBTYPE_EMAIL = 'Email';
    static final String STATUS_OPEN = 'Open';
    static final String EMAIL_SENDING_STATUS_REPEAT = 'Repeat';
    static final Integer MAX_EMAIL_RECIPIENTS = 50;

    public override void afterUpdate() {
        this.startAmazonSesEmailSending();
    }

    public override void afterInsert() {
        this.startAmazonSesEmailSending();
    }

    private void startAmazonSesEmailSending() {
        List<Task> emailTasks = new List<Task>();
        if (!this.oldMap.isEmpty()) {
            Map<Id, Task> oldMapNormalized = (Map<Id, Task>) this.oldMap;
            for (Task newTask : (List<Task>)this.newList) {
                if (newTask.TaskSubtype == SUBTYPE_EMAIL &&
                    newTask.Status == STATUS_OPEN &&
                    newTask.breg_Email_Sending_Status__c == EMAIL_SENDING_STATUS_REPEAT &&
                    newTask.breg_Email_Sending_Status__c != oldMapNormalized.get(newTask.Id).breg_Email_Sending_Status__c &&
                    isAmountOfRecepientsApplicable(newTask))
                {
                    emailTasks.add(newTask);
                }
            }
        }
        else {
            for (Task newTask : (List<Task>)this.newList) {
                if (newTask.TaskSubtype == SUBTYPE_EMAIL &&
                    newTask.Status == STATUS_OPEN &&
                    isAmountOfRecepientsApplicable(newTask))
                {
                    emailTasks.add(newTask);
                }
            }
        }
        if (!emailTasks.isEmpty()) {
            System.enqueueJob(new BREGAmazonSesQueueable(emailTasks));
        }
    }

    private Boolean isAmountOfRecepientsApplicable(Task t) {
        Set<String> recipients = new Set<String>();
        recipients.addAll(BREGAmazonSesEmailService.parseEmails(t.breg_To__c));
        recipients.addAll(BREGAmazonSesEmailService.parseEmails(t.breg_Cc__c));
        recipients.addAll(BREGAmazonSesEmailService.parseEmails(t.breg_Bcc__c));
        return recipients.size() <= MAX_EMAIL_RECIPIENTS;
    }
}