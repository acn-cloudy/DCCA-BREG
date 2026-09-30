/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: AttestToMailingNoticesBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10172022 - Created for case 00025290
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/17/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class AttestToMailingNoticesBatch implements Database.Batchable<SObject>, Database.Stateful{
    public Map<Date, AttestToMailingNoticesController.Notice> draftsMap;
    public Map<Date, AttestToMailingNoticesController.Notice> noticesMap;
    private String query = 'SELECT Id,TimeDelivered__c FROM Notification__c';
    private Set<Id> notificationIdsToUpdate = new Set<Id>();

    public AttestToMailingNoticesBatch(List<AttestToMailingNoticesController.Notice> notices, List<AttestToMailingNoticesController.Notice> drafts) {
        this.draftsMap = new Map<Date, AttestToMailingNoticesController.Notice>();
        this.noticesMap = new Map<Date, AttestToMailingNoticesController.Notice>();
        for (AttestToMailingNoticesController.Notice n : drafts) {
            draftsMap.put(n.timeDelivered, n);
        }

        for (AttestToMailingNoticesController.Notice n : notices) {
            noticesMap.put(n.timeDelivered, n);
            for (Notification__c notification : n.notifications) {
                notificationIdsToUpdate.add(notification.Id);
            }
        }
        this.query += ' WHERE Id IN :notificationIdsToUpdate';
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Notification__c> notifications = (List<Notification__c>) scope;
        for (Notification__c n : notifications) {
            Date dateDelivered = n.TimeDelivered__c.date();
            AttestToMailingNoticesController.Notice notice = noticesMap.get(dateDelivered);
            n.MailedByAttestation__c = notice.mailedBy;
            n.MailedOnDate__c = notice.mailedDateTime;

            if (this.draftsMap.containsKey(dateDelivered)) {
                n.MailedOnDate__c = this.draftsMap.get(dateDelivered).mailedDateTime;
            }
        }

        update notifications;
    }

    public void finish(Database.BatchableContext bc) {
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
}